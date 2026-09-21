<?php
/**
 * save_recipe_report.php — un utente segnala una ricetta pubblica (21/09).
 *
 * DIVERSO DAGLI ALTRI DUE:
 *  - save_report.php raccoglie i problemi dell'APP;
 *  - save_food_report.php i dati sbagliati di un ALIMENTO del database;
 *  - qui il soggetto e' una RICETTA scritta da un'altra persona e pubblicata
 *    in "Consigliate". Non si propone una correzione: chi legge una ricetta
 *    altrui non puo' riscriverla, puo' solo dire che c'e' un problema. Chi
 *    vuole una versione sua se ne fa una copia privata (vedi la modifica di
 *    una ricetta pubblica in recipe_list_page.dart).
 *
 * NON CAMBIA NIENTE nella ricetta: la riga nasce `pending` e la vede solo chi
 * rivede dal pannello. Va detto anche all'utente, altrimenti si aspetta che la
 * ricetta sparisca subito.
 *
 * Richiede: community_comune.php, db_config.php e la migrazione
 * 2026-09-21_segnalazioni_ricette.sql.
 */

/*
 * IL FILE COMUNE, CONTROLLATO PRIMA DI CHIEDERLO.
 *
 * `require` di un file assente e' un errore fatale: la risposta diventa un
 * avviso PHP piu' un 500, e dall'app si vede solo "errore" senza dire quale.
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
$recipeId = (int) ($dati['recipe_id'] ?? 0);
$issue    = trim((string) ($dati['issue'] ?? ''));
$nota     = trim((string) ($dati['note'] ?? ''));

if ($userMail === '' || $recipeId <= 0 || $issue === '') {
    communityErrore('Dati mancanti: servono user_mail, recipe_id e issue.');
}
if (!in_array($issue, NA_TIPI_SEGNALAZIONE_RICETTA, true)) {
    communityErrore(
        'Tipo di problema non valido: ' . $issue . '. Ammessi: ' . implode(', ', NA_TIPI_SEGNALAZIONE_RICETTA) . '.'
    );
}

communityRichiediMigrazione($conn, 'na_recipe_reports', 'status', '2026-09-21_segnalazioni_ricette.sql');

if (!communityUtenteEsiste($conn, $userMail)) {
    communityErrore('Utente non trovato: ' . $userMail);
}

/*
 * LA RICETTA DEVE ESISTERE ED ESSERE PUBBLICA.
 *
 * Nome e autore si copiano QUI dentro la segnalazione: se poi la ricetta viene
 * cancellata o rinominata, chi rivede deve comunque capire di cosa si
 * parlava. Le altre tabelle delle segnalazioni fanno lo stesso con il nome
 * dell'alimento.
 */
$stmt = $conn->prepare('SELECT recipe_name, user_mail, shared_status FROM na_recipes WHERE id = ? LIMIT 1');
$stmt->bind_param('i', $recipeId);
$stmt->execute();
$ricetta = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$ricetta) {
    communityErrore('Ricetta non trovata: ' . $recipeId);
}
if (($ricetta['shared_status'] ?? 'private') !== 'approved') {
    // Una ricetta privata la vede solo chi l'ha scritta: non c'e' niente da
    // segnalare, e accettare la riga darebbe a chiunque un modo per sapere
    // che quella ricetta esiste.
    communityErrore('Questa ricetta non e\' pubblica: non si segnala.', ['reason' => 'not_public']);
}
if (($ricetta['user_mail'] ?? '') === $userMail) {
    // Segnalare la propria non ha senso: chi la vuole cambiare la modifica, e
    // chi non la vuole piu' pubblica la ritira da "Le mie ricette".
    communityErrore('Questa ricetta e\' tua: modificala o ritirala invece di segnalarla.', ['reason' => 'own_recipe']);
}

/*
 * DOPPIONI: la stessa persona che segnala due volte lo stesso problema sulla
 * stessa ricetta non aggiunge informazione, aggiunge lavoro a chi rivede.
 * Vale solo finche' la prima e' aperta: se e' stata gestita e il problema si
 * ripresenta, va potuta segnalare di nuovo. Stessa regola di
 * save_food_report.php.
 */
$stmt = $conn->prepare(
    'SELECT id FROM na_recipe_reports
      WHERE user_mail = ? AND recipe_id = ? AND issue = ? AND status = "pending" LIMIT 1'
);
$stmt->bind_param('sis', $userMail, $recipeId, $issue);
$stmt->execute();
$giaAperta = $stmt->get_result()->fetch_assoc();
$stmt->close();

if ($giaAperta) {
    // `already` e' un esito positivo, non un errore: dal punto di vista di chi
    // usa l'app la segnalazione c'e'. Dirgli "errore" lo farebbe ritentare.
    communityOk([
        'already'   => true,
        'report_id' => (int) $giaAperta['id'],
        'message'   => 'Segnalazione gia\' aperta per questa ricetta.',
    ]);
}

$nomeRicetta = mb_substr((string) $ricetta['recipe_name'], 0, 255);
$autore = (string) ($ricetta['user_mail'] ?? '');
$notaDaSalvare = $nota === '' ? null : mb_substr($nota, 0, 2000);

$stmt = $conn->prepare(
    'INSERT INTO na_recipe_reports (user_mail, recipe_id, recipe_name, author_mail, issue, note)
     VALUES (?, ?, ?, ?, ?, ?)'
);
$stmt->bind_param('sissss', $userMail, $recipeId, $nomeRicetta, $autore, $issue, $notaDaSalvare);

if (!$stmt->execute()) {
    $errore = $stmt->error;
    $stmt->close();
    communityErrore('Salvataggio non riuscito: ' . $errore);
}

$id = (int) $stmt->insert_id;
$stmt->close();
$conn->close();

communityOk([
    'report_id' => $id,
    'message'   => 'Segnalazione registrata: la guarda chi rivede i contenuti.',
]);
