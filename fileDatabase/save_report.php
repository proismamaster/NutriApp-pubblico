<?php
/**
 * save_report.php — riceve una segnalazione dall'app.
 *
 * Aggiornato il 2026-09-05 per il mockup "Report Problem": oltre al testo
 * libero arrivano il tipo di problema, la schermata su cui si verifica, un
 * contatto facoltativo e — solo se l'utente acconsente — qualche informazione
 * tecnica sul dispositivo.
 *
 * Richiede la migrazione 2026-09-05_segnalazioni_e_unita.sql.
 */

include 'db_config.php';
require_once 'auth.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(["status" => "error", "message" => "Metodo non consentito."]);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true) ?: [];

// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$email = emailAutenticata($conn, trim((string) ($data['user_email'] ?? '')));
$problem = trim($data['problem_description'] ?? '');

if ($email === '' || $problem === '') {
    echo json_encode(["status" => "error", "message" => "Dati mancanti."]);
    exit;
}

// Lista chiusa: un tipo inventato dal client renderebbe inutile il
// raggruppamento, che e' il motivo per cui questa colonna esiste.
$tipiValidi = ['bug', 'data', 'sync', 'idea', 'other'];
$kind = in_array($data['kind'] ?? '', $tipiValidi, true) ? $data['kind'] : null;

$screen = trim($data['screen'] ?? '');
$screen = $screen === '' ? null : mb_substr($screen, 0, 60);

$contact = trim($data['contact_email'] ?? '');
if ($contact !== '' && !filter_var($contact, FILTER_VALIDATE_EMAIL)) {
    echo json_encode(["status" => "error", "message" => "Indirizzo di contatto non valido."]);
    exit;
}
$contact = $contact === '' ? null : $contact;

// Arriva solo se l'utente ha lasciato acceso l'interruttore: se il campo non
// c'e', resta NULL. Tagliata alla lunghezza della colonna, cosi' una stringa
// inattesa non fa fallire l'inserimento.
$diag = trim($data['diagnostics'] ?? '');
$diag = $diag === '' ? null : mb_substr($diag, 0, 500);

// Controllo spam invariato: una segnalazione al giorno per account.
$stmt = $conn->prepare("SELECT id FROM na_reports WHERE user_email = ? AND DATE(created_at) = CURDATE()");
$stmt->bind_param('s', $email);
$stmt->execute();
$gia = $stmt->get_result()->num_rows > 0;
$stmt->close();

if ($gia) {
    // Il codice serve all'app per tradurre: il messaggio qui sotto resta
    // italiano ed e' solo la riserva per le versioni vecchie.
    echo json_encode([
        "status" => "error",
        "code" => "report_daily_limit",
        "message" => "Hai già inviato una segnalazione oggi. Riprova domani.",
    ]);
    exit;
}

// Query preparata al posto della concatenazione con real_escape_string: qui
// entra testo scritto liberamente dall'utente, ed e' il posto in cui conviene
// meno affidarsi a un escape manuale.
$stmt = $conn->prepare(
    "INSERT INTO na_reports (user_email, problem_description, kind, screen, contact_email, diagnostics)
     VALUES (?, ?, ?, ?, ?, ?)"
);
if (!$stmt) {
    echo json_encode(["status" => "error", "message" => "Errore SQL: " . $conn->error]);
    exit;
}
$stmt->bind_param('ssssss', $email, $problem, $kind, $screen, $contact, $diag);

if ($stmt->execute()) {
    echo json_encode(["status" => "success", "message" => "Segnalazione inviata con successo!"]);
} else {
    echo json_encode(["status" => "error", "message" => "Errore durante l'invio: " . $stmt->error]);
}

$stmt->close();
$conn->close();
