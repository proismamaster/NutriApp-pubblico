<?php
/**
 * share_custom_food.php — propone o ritira UN alimento personale (punto 2
 * della collaborazione, ROADMAP: "possibilita' di escludere un singolo
 * alimento").
 *
 * share=1 → `pending`: proposto, invisibile agli altri finche' non e' approvato.
 * share=0 → `private`: ritirato, solo finche' non e' approvato. Dal 15/09 un
 *           alimento approvato e' del database (decisione di Ismail): l'autore
 *           non lo ritira piu', risponde `reason: locked`. Toglierlo dal
 *           pubblico lo puo' fare solo un admin dal pannello.
 *
 * L'alimento deve appartenere a chi chiede: `WHERE id = ? AND user_mail = ?`.
 * Senza la seconda condizione chiunque conoscesse un id potrebbe pubblicare o
 * ritirare l'alimento di un altro — l'app non ha autenticazione (vedi
 * PROBLEMS), quindi l'appartenenza e' l'unico controllo disponibile.
 *
 * Richiede: community_comune.php, db_config.php e la migrazione
 * 2026-09-12_collaborazione_community.sql.
 */

/*
 * IL FILE COMUNE, CONTROLLATO PRIMA DI CHIEDERLO.
 *
 * `require` di un file assente e' un errore fatale: la risposta diventa un
 * avviso PHP piu' un 500, e dall'app si vede solo "errore" senza dire quale.
 * E' esattamente cio' che il 07/09 ha tenuto giu' il salvataggio ricette per
 * tre sessioni, con `recipe_ingredient_columns.php` rimasto a terra. Cinque
 * righe qui dentro — non in un altro file condiviso, che si romperebbe allo
 * stesso modo — e chi carica via FTP legge il nome di cio' che manca.
 */
if (!is_file(__DIR__ . '/community_comune.php')) {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'status'  => 'error',
        'message' => 'File mancante sul server: community_comune.php — va caricato via FTP nella stessa cartella di questo script.',
    ]);
    exit;
}

require_once __DIR__ . '/community_comune.php';
communityAvvia();
communitySoloPost();

require communityRichiediFile('db_config.php');
require_once __DIR__ . '/auth.php';

$dati = communityCorpo();
// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$userMail = emailAutenticata($conn, trim((string) ($dati['user_mail'] ?? '')));
$id = (int) ($dati['id'] ?? 0);

if ($userMail === '' || $id <= 0 || !array_key_exists('share', $dati)) {
    communityErrore('Dati mancanti: servono user_mail, id e share.');
}

$condividi = filter_var($dati['share'], FILTER_VALIDATE_BOOLEAN);

communityRichiediMigrazione($conn, 'na_custom_foods', 'shared_status');

$stmt = $conn->prepare('SELECT shared_status FROM na_custom_foods WHERE id = ? AND user_mail = ? LIMIT 1');
$stmt->bind_param('is', $id, $userMail);
$stmt->execute();
$riga = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$riga) {
    communityErrore('Alimento non trovato fra i tuoi: id ' . $id);
}

$statoPrecedente = $riga['shared_status'];
$nuovoStato = $condividi ? 'pending' : 'private';

// Riproporre una cosa gia' approvata la farebbe tornare in coda e sparire dal
// database pubblico nel frattempo: non e' cio' che chiede chi tocca un
// interruttore gia' acceso. Nessuna scrittura, e lo stato vero nella risposta.
if ($condividi && $statoPrecedente === 'approved') {
    communityOk(['shared_status' => 'approved', 'changed' => false]);
}

// Approvato = del database (15/09): l'autore non lo ritira.
if (!$condividi && $statoPrecedente === 'approved') {
    communityErrore(
        'Questo alimento e\' pubblico e fa parte del database: non si puo\' ritirare. Se contiene un errore, segnalalo.',
        ['reason' => 'locked', 'shared_status' => 'approved']
    );
}

if ($statoPrecedente === $nuovoStato) {
    communityOk(['shared_status' => $nuovoStato, 'changed' => false]);
}

if ($condividi) {
    $stmt = $conn->prepare(
        'UPDATE na_custom_foods SET shared_status = "pending", shared_at = NOW()
          WHERE id = ? AND user_mail = ?'
    );
} else {
    // La revisione precedente va dimenticata: se domani lo ripropone, deve
    // essere giudicato di nuovo, non arrivare con il timbro di prima.
    $stmt = $conn->prepare(
        'UPDATE na_custom_foods
            SET shared_status = "private", shared_at = NULL,
                reviewed_at = NULL, reviewed_by = NULL, review_note = NULL
          WHERE id = ? AND user_mail = ?'
    );
}
$stmt->bind_param('is', $id, $userMail);

if (!$stmt->execute()) {
    $messaggio = $stmt->error;
    $stmt->close();
    communityErrore('Stato non aggiornato: ' . $messaggio);
}
$stmt->close();
$conn->close();

communityOk([
    'shared_status' => $nuovoStato,
    'changed'       => true,
    'was'           => $statoPrecedente,
]);
