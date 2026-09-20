<?php
/**
 * toggle_recipe_like.php — mette o toglie il like a una ricetta pubblica (15/09).
 *
 * POST JSON: { user_mail, recipe_id, like: true|false }
 * Risponde:  { status, liked, likes_count }
 *
 * REGOLE
 *  - Solo ricette approvate: una ricetta in attesa non la vede nessuno, quindi
 *    un like li' sarebbe arrivato da una richiesta scritta a mano.
 *  - Anche alle proprie (18/09): senza cuore la propria ricetta sembrava rotta.
 *    Il voto entra nel numero mostrato ma NON nel punteggio di "Per te", che
 *    conta i like degli altri (get_public_recipes.php): votarsi non fa salire.
 *  - Un like per persona: lo garantisce la chiave doppia di na_recipe_likes,
 *    non un controllo qui (due richieste insieme lo scavalcherebbero).
 *    Rimettere un like gia' messo non e' un errore: risponde lo stato vero.
 *
 * Richiede: community_comune.php, db_config.php, migrazione 2026-09-15.
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
require_once __DIR__ . '/auth.php';
communityAvvia();
communitySoloPost();

require communityRichiediFile('db_config.php');

$dati = communityCorpo();
// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$userMail = emailAutenticata($conn, trim((string) ($dati['user_mail'] ?? '')));
$idRicetta = (int) ($dati['recipe_id'] ?? 0);

if ($userMail === '' || $idRicetta <= 0 || !array_key_exists('like', $dati)) {
    communityErrore('Dati mancanti: servono user_mail, recipe_id e like.');
}
$metti = filter_var($dati['like'], FILTER_VALIDATE_BOOLEAN);

if (!communityColonnaEsiste($conn, 'na_recipe_likes', 'recipe_id')) {
    communityErrore('Migrazione mancante: eseguire fileDatabase/migrations/2026-09-15_community_ricette_pannello.sql su phpMyAdmin.');
}
if (!communityUtenteEsiste($conn, $userMail)) {
    communityErrore('Utente non trovato.');
}

$stmt = $conn->prepare('SELECT user_mail, shared_status FROM na_recipes WHERE id = ? LIMIT 1');
$stmt->bind_param('i', $idRicetta);
$stmt->execute();
$ricetta = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$ricetta || $ricetta['shared_status'] !== 'approved') {
    communityErrore('Ricetta non pubblica.', ['reason' => 'not_public']);
}
if ($metti) {
    $stmt = $conn->prepare('INSERT IGNORE INTO na_recipe_likes (recipe_id, user_mail) VALUES (?, ?)');
} else {
    $stmt = $conn->prepare('DELETE FROM na_recipe_likes WHERE recipe_id = ? AND user_mail = ?');
}
$stmt->bind_param('is', $idRicetta, $userMail);
$stmt->execute();
$stmt->close();

$stmt = $conn->prepare('SELECT COUNT(*) AS n FROM na_recipe_likes WHERE recipe_id = ?');
$stmt->bind_param('i', $idRicetta);
$stmt->execute();
$totale = (int) ($stmt->get_result()->fetch_assoc()['n'] ?? 0);
$stmt->close();
$conn->close();

communityOk(['liked' => $metti, 'likes_count' => $totale]);
