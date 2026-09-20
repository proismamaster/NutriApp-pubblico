<?php
/**
 * share_recipe.php — propone o ritira UNA ricetta per la sezione "Consigliate"
 * (punto 3 della collaborazione, ROADMAP).
 *
 * Nessun consenso generale come per gli alimenti: una ricetta e' un contenuto
 * scritto dalla persona, con un nome e delle note che ha composto lei. Si
 * propone una per una, di proposito.
 *
 * share=1 → `pending` (proposta, invisibile agli altri fino all'approvazione)
 * share=0 → `private` (ritirata, anche se era gia' pubblica)
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

communityRichiediMigrazione($conn, 'na_recipes', 'shared_status');

$stmt = $conn->prepare('SELECT shared_status FROM na_recipes WHERE id = ? AND user_mail = ? LIMIT 1');
$stmt->bind_param('is', $id, $userMail);
$stmt->execute();
$riga = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$riga) {
    communityErrore('Ricetta non trovata fra le tue: id ' . $id);
}

$statoPrecedente = $riga['shared_status'];

/*
 * UNA RICETTA SENZA INGREDIENTI NON SI PROPONE.
 *
 * In "Consigliate" una ricetta si giudica dai suoi ingredienti e dalle sue
 * calorie: senza ingredienti la scheda e' vuota, i valori sono zero, e chi
 * rivede non ha niente su cui decidere. Meglio dirlo qui che farla arrivare in
 * coda e scartarla dopo.
 */
if ($condividi) {
    $stmt = $conn->prepare('SELECT COUNT(*) AS n FROM na_recipe_ingredients WHERE recipe_id = ?');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $nIngredienti = (int) ($stmt->get_result()->fetch_assoc()['n'] ?? 0);
    $stmt->close();
    if ($nIngredienti === 0) {
        communityErrore('Ricetta senza ingredienti: non si puo\' proporre.', ['reason' => 'no_ingredients']);
    }
}

if ($condividi && $statoPrecedente === 'approved') {
    communityOk(['shared_status' => 'approved', 'changed' => false]);
}

// Approvata = del database (15/09, decisione di Ismail): l'autore non la ritira.
if (!$condividi && $statoPrecedente === 'approved') {
    communityErrore(
        'Questa ricetta e\' pubblica e fa parte del database: non si puo\' ritirare. Se contiene un errore, segnalalo.',
        ['reason' => 'locked', 'shared_status' => 'approved']
    );
}

/*
 * CATEGORIE A LISTA CHIUSA (15/09), obbligatorie per proporre.
 *
 * Pasti adatti (almeno uno) e portata servono a "Consigliate": "Per te" sceglie
 * in base al pasto dell'ora, e i filtri lavorano su questi valori. Senza, una
 * ricetta approvata non comparirebbe mai fra quelle del momento. Le etichette
 * di dieta sono facoltative. Valori fuori lista si scartano, non si salvano.
 * Solo se la migrazione del 15/09 c'e': prima, la proposta resta com'era.
 */
$haCategorie = communityColonnaEsiste($conn, 'na_recipes', 'meal_types');
$pasti = null;
$portata = null;
$diete = null;
if ($condividi && $haCategorie) {
    $lista = static fn($v): array => is_array($v) ? array_values(array_unique(array_map('strval', $v))) : [];
    $sceltiPasti = array_values(array_intersect($lista($dati['meal_types'] ?? null), ['colazione', 'pranzo', 'cena', 'spuntino']));
    $portata = (string) ($dati['course'] ?? '');
    $scelteDiete = array_values(array_intersect($lista($dati['diet_tags'] ?? null), ['vegetariana', 'vegana', 'senza_glutine']));
    if ($sceltiPasti === [] || !in_array($portata, ['primo', 'secondo', 'piatto_unico', 'contorno', 'dolce', 'bevanda', 'altro'], true)) {
        communityErrore('Scegli almeno un pasto e la portata della ricetta.', ['reason' => 'categories_missing']);
    }
    $pasti = implode(',', $sceltiPasti);
    $diete = $scelteDiete === [] ? null : implode(',', $scelteDiete);
}

$nuovoStato = $condividi ? 'pending' : 'private';
// Una ricetta gia' in attesa puo' comunque aggiornare le sue categorie.
if ($statoPrecedente === $nuovoStato && !($condividi && $haCategorie)) {
    communityOk(['shared_status' => $nuovoStato, 'changed' => false]);
}

if ($condividi && $haCategorie) {
    // `shared_at` prima di `shared_status`: MySQL applica le assegnazioni in
    // ordine, e l'IF deve leggere lo stato di prima (in attesa da quando?).
    $stmt = $conn->prepare(
        'UPDATE na_recipes
            SET shared_at = IF(shared_status = "pending", shared_at, NOW()), shared_status = "pending",
                meal_types = ?, course = ?, diet_tags = ?
          WHERE id = ? AND user_mail = ?'
    );
    $stmt->bind_param('sssis', $pasti, $portata, $diete, $id, $userMail);
} elseif ($condividi) {
    $stmt = $conn->prepare(
        'UPDATE na_recipes SET shared_status = "pending", shared_at = NOW()
          WHERE id = ? AND user_mail = ?'
    );
} else {
    $stmt = $conn->prepare(
        'UPDATE na_recipes
            SET shared_status = "private", shared_at = NULL,
                reviewed_at = NULL, reviewed_by = NULL, review_note = NULL
          WHERE id = ? AND user_mail = ?'
    );
}
if (!($condividi && $haCategorie)) {
    $stmt->bind_param('is', $id, $userMail);
}

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
