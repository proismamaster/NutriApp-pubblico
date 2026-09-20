<?php
/**
 * reset_password.php — ultimo passo del recupero password (2026-09-14).
 *
 * L'app lo chiamava da mesi, ma il file non era mai esistito: ne' nel repo
 * (verificato con git log --all il 12/09) ne' sul server (GET: 404 il 14/09).
 * Il recupero finiva quindi sempre in "Email non trovata o codice errato",
 * anche con il codice giusto.
 *
 * Due modi, con gli stessi campi (POST form-urlencoded, come send_otp.php):
 *   email, otp, check_only=1      controlla il codice SENZA consumarlo
 *   email, otp, new_password      ricontrolla il codice e cambia la password
 *
 * PERCHE' IL CODICE SI CONTROLLA DUE VOLTE: l'app lo verifica al passo 2 per
 * dire subito se e' sbagliato, ma il cambio vero non si fida di un "l'ho gia'
 * verificato" detto dal telefono. Non si appoggia a verify_otp.php, che
 * cancella il codice appena lo trova giusto ed e' fatto per la registrazione.
 *
 * PERCHE' I TENTATIVI: sei cifre sono un milione di combinazioni, e senza un
 * limite si provano tutte nei 15 minuti di validita'. Al quinto errore il
 * codice viene cancellato.
 *
 * Ogni risposta ha un `code` fisso che l'app traduce: ok, bad_request,
 * missing_migration, invalid_password, expired, wrong_code (con `remaining`),
 * too_many, no_account, server_error.
 *
 * Richiede la migrazione 2026-09-14_recupero_password.sql.
 */

declare(strict_types=1);

require 'db_config.php';
// db_config.php manda gia' JSON; il charset esplicito tiene giuste le lettere
// accentate dei messaggi anche se un giorno quel file cambiasse.
header('Content-Type: application/json; charset=utf-8');

const MAX_TENTATIVI = 5;
// Stessa soglia della registrazione (signup.dart): una password scelta qui non
// deve poter essere piu' debole di una scelta al primo accesso.
const MIN_PASSWORD = 8;
// Oltre i 72 byte bcrypt ignora il resto in silenzio: meglio dirlo che
// accettare una password di cui conta solo l'inizio.
const MAX_PASSWORD_BYTE = 72;

function rispondi(string $status, string $code, string $message, array $extra = []): void
{
    echo json_encode(
        ['status' => $status, 'code' => $code, 'message' => $message] + $extra,
        JSON_UNESCAPED_UNICODE
    );
    exit;
}

function cancellaCodici(mysqli $conn, string $email): void
{
    $stmt = $conn->prepare('DELETE FROM na_otp_codes WHERE email = ?');
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $stmt->close();
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    rispondi('error', 'bad_request', 'Metodo non consentito.');
}

$email = trim((string) ($_POST['email'] ?? ''));
$otp = trim((string) ($_POST['otp'] ?? ''));
$soloControllo = (string) ($_POST['check_only'] ?? '') === '1';
$nuova = (string) ($_POST['new_password'] ?? '');

if ($email === '' || $otp === '' || (!$soloControllo && $nuova === '')) {
    rispondi('error', 'bad_request', 'Dati mancanti.');
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    rispondi('error', 'bad_request', 'Email non valida.');
}
if (!preg_match('/^\d{6}$/', $otp)) {
    rispondi('error', 'bad_request', 'Il codice è di 6 cifre.');
}

// Senza la colonna dei tentativi il limite non si puo' applicare: meglio
// fermarsi e dirlo che cambiare password senza protezione.
$colonna = $conn->query("SHOW COLUMNS FROM na_otp_codes LIKE 'attempts'");
if (!$colonna || $colonna->num_rows === 0) {
    rispondi(
        'error',
        'missing_migration',
        'Recupero password non ancora attivo sul server: manca la migrazione 2026-09-14_recupero_password.sql.'
    );
}

// La password si controlla PRIMA del codice: un errore di battitura sulla
// password non deve bruciare un tentativo.
if (!$soloControllo) {
    if (mb_strlen($nuova) < MIN_PASSWORD) {
        rispondi('error', 'invalid_password', 'La password deve avere almeno ' . MIN_PASSWORD . ' caratteri.');
    }
    if (strlen($nuova) > MAX_PASSWORD_BYTE) {
        rispondi('error', 'invalid_password', 'La password è troppo lunga.');
    }
}

// Il codice piu' recente ancora valido. send_otp.php cancella i precedenti a
// ogni invio, quindi di norma ce n'e' uno solo.
$stmt = $conn->prepare(
    'SELECT id, code FROM na_otp_codes
     WHERE email = ? AND expires_at > CURRENT_TIMESTAMP
     ORDER BY id DESC LIMIT 1'
);
$stmt->bind_param('s', $email);
$stmt->execute();
$riga = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$riga) {
    rispondi('error', 'expired', 'Codice scaduto o mai richiesto: chiedine uno nuovo.');
}
$id = (int) $riga['id'];
$max = MAX_TENTATIVI;

// Il tentativo si prenota PRIMA di confrontare, con una sola UPDATE
// condizionata: due richieste in parallelo non possono superare il limite
// leggendo entrambe "4 tentativi" prima che una delle due ne scriva uno.
$stmt = $conn->prepare('UPDATE na_otp_codes SET attempts = attempts + 1 WHERE id = ? AND attempts < ?');
$stmt->bind_param('ii', $id, $max);
$stmt->execute();
$prenotato = $stmt->affected_rows === 1;
$stmt->close();

if (!$prenotato) {
    cancellaCodici($conn, $email);
    rispondi('error', 'too_many', 'Troppi tentativi sbagliati: chiedi un codice nuovo.');
}

if (!hash_equals((string) $riga['code'], $otp)) {
    $stmt = $conn->prepare('SELECT attempts FROM na_otp_codes WHERE id = ?');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $usati = (int) ($stmt->get_result()->fetch_assoc()['attempts'] ?? $max);
    $stmt->close();

    $rimasti = $max - $usati;
    if ($rimasti <= 0) {
        cancellaCodici($conn, $email);
        rispondi('error', 'too_many', 'Troppi tentativi sbagliati: chiedi un codice nuovo.');
    }
    rispondi('error', 'wrong_code', 'Codice sbagliato.', ['remaining' => $rimasti]);
}

// Codice giusto: il tentativo prenotato si restituisce. Controllarlo al
// passo 2 e di nuovo al passo 3 non deve avvicinare nessuno al blocco.
$stmt = $conn->prepare('UPDATE na_otp_codes SET attempts = attempts - 1 WHERE id = ? AND attempts > 0');
$stmt->bind_param('i', $id);
$stmt->execute();
$stmt->close();

// L'account si cerca solo DOPO il codice giusto: chi non legge quella casella
// di posta non puo' usare questo endpoint per scoprire quali email sono
// registrate.
$stmt = $conn->prepare('SELECT id FROM na_users WHERE email = ? LIMIT 1');
$stmt->bind_param('s', $email);
$stmt->execute();
$utente = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$utente) {
    rispondi('error', 'no_account', 'Nessun account con questa email.');
}

if ($soloControllo) {
    rispondi('success', 'ok', 'Codice valido.');
}

$hash = password_hash($nuova, PASSWORD_BCRYPT);
$idUtente = (int) $utente['id'];
$stmt = $conn->prepare('UPDATE na_users SET password_hash = ? WHERE id = ?');
$stmt->bind_param('si', $hash, $idUtente);
if (!$stmt->execute()) {
    rispondi('error', 'server_error', 'Password non aggiornata: errore del database.');
}
$stmt->close();

// Il codice ha fatto il suo lavoro: non deve poter cambiare la password una
// seconda volta.
cancellaCodici($conn, $email);

// Chi conosceva la vecchia password non deve restare dentro: cambiare la
// password chiude TUTTE le sessioni aperte di quell'account (19/09).
$fuori = $conn->prepare('DELETE FROM na_sessions WHERE user_mail = ?');
$fuori->bind_param('s', $email);
$fuori->execute();
$fuori->close();

rispondi('success', 'ok', 'Password aggiornata.');
