<?php
/**
 * get_public_recipes.php — le ricette pubbliche per la sezione "Consigliate"
 * (punto 3 della collaborazione, ROADMAP).
 *
 * Restituisce SOLO `shared_status = 'approved'`: una ricetta in attesa non si
 * vede, ed e' il motivo per cui la coda esiste. Finche' nessuno approva, questa
 * sezione e' vuota — corretto, non rotto.
 *
 * FORMA DELLA RISPOSTA: identica a get_recipes.php, piu' `author_name` e
 * `shared_status`. Cosi' il modello Recipe di Dart la legge senza casi
 * speciali, invece di avere due formati per la stessa cosa. Dal 15/09 anche
 * `meal_types`, `course`, `diet_tags`, `likes_count` e `liked_by_me`.
 *
 * COSA NON ESCE DA QUI: l'email di chi l'ha scritta. Il nome proprio si', ed
 * e' quello che l'utente ha messo nel profilo; se manca, "Anonimo". Nessun
 * indirizzo, nessun cognome: chi condivide una ricetta non sta pubblicando i
 * propri contatti.
 *
 * Parametri (GET, tutti facoltativi):
 *   user_mail  segna le proprie ricette (is_mine) e dice quali hanno gia' il
 *              suo like. Dal 17/09 le proprie NON si escludono piu': Ismail non
 *              trovava in Consigliate la ricetta appena approvata, e
 *              "approvata" deve voler dire visibile, anche a chi l'ha scritta
 *   limit      quante al massimo (default 100, tetto 300)
 *   mode       nuove (default) · piaciute · per_te  (15/09)
 *   now_meal   il pasto dell'ora del telefono, per "per_te": colazione ·
 *              pranzo · cena · spuntino. L'ora la sa il telefono, non il
 *              server, che puo' stare in un altro fuso.
 *   meal, course, diet  filtri a lista chiusa
 *   q          testo: nome, note o un ingrediente
 *
 * I like contati nel punteggio sono quelli DEGLI ALTRI (18/09): l'autore puo'
 * votare la propria ricetta, ma il suo voto non la fa salire.
 *
 * "PER TE", IN UNA RIGA: punteggio = 3 se la ricetta va bene per il pasto di
 * adesso + 1,5 x ln(1 + like) + 2 x 0,5^(giorni dalla pubblicazione / 14).
 * Il pasto pesa di piu' perche' e' la domanda dell'utente ("cosa mangio ora?").
 * I like crescono piano (logaritmo): dieci ricette famose non devono coprire
 * tutte le altre per sempre. La novita' vale la meta' ogni due settimane, cosi'
 * una ricetta appena pubblicata ha la sua occasione anche senza like.
 *
 * Richiede: community_comune.php, db_config.php e la migrazione
 * 2026-09-12_collaborazione_community.sql; per categorie e like quella del 15/09.
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

require communityRichiediFile('db_config.php');
require_once __DIR__ . '/auth.php';

if (!communityColonnaEsiste($conn, 'na_recipes', 'shared_status')) {
    // Elenco vuoto e non errore: il server indietro con le migrazioni non deve
    // far comparire un messaggio rosso in una scheda che sarebbe comunque
    // vuota. Il campo `migration_missing` lo dice a chi legge la risposta.
    echo json_encode(['status' => 'success', 'recipes' => [], 'migration_missing' => true]);
    exit;
}

// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$userMail = emailAutenticata($conn, trim((string) ($_GET['user_mail'] ?? '')));
$limite = (int) ($_GET['limit'] ?? 100);
if ($limite <= 0 || $limite > 300) {
    $limite = 100;
}

$haCategorie = communityColonnaEsiste($conn, 'na_recipes', 'meal_types');
$haLike = communityColonnaEsiste($conn, 'na_recipe_likes', 'recipe_id');

$pastiValidi = ['colazione', 'pranzo', 'cena', 'spuntino'];
$modo = (string) ($_GET['mode'] ?? 'nuove');
if (!in_array($modo, ['nuove', 'piaciute', 'per_te'], true)) {
    $modo = 'nuove';
}
$pastoAdesso = (string) ($_GET['now_meal'] ?? '');
$filtroPasto = (string) ($_GET['meal'] ?? '');
$filtroPortata = (string) ($_GET['course'] ?? '');
$filtroDieta = (string) ($_GET['diet'] ?? '');
$cerca = mb_substr(trim((string) ($_GET['q'] ?? '')), 0, 100);

/*
 * Il nome dell'autore arriva da na_users con una LEFT JOIN: se l'account e'
 * stato cancellato la ricetta resta, e con una JOIN normale sparirebbe
 * dall'elenco senza motivo apparente.
 */
$sql = 'SELECT r.id, r.recipe_name, r.`portion`, r.notes, r.image_url, r.shared_status,
               r.shared_at, r.reviewed_at, u.first_name'
    . ($haCategorie ? ', r.meal_types, r.course, r.diet_tags' : '')
    . ($haLike ? ', (SELECT COUNT(*) FROM na_recipe_likes l WHERE l.recipe_id = r.id) AS likes_count' : '')
    // Il punteggio di "Per te" usa questi, non likes_count: dal 18/09 si puo'
    // votare la propria ricetta, e il voto dell'autore non deve farla salire.
    . ($haLike ? ', (SELECT COUNT(*) FROM na_recipe_likes l3 WHERE l3.recipe_id = r.id AND l3.user_mail <> r.user_mail) AS likes_others' : '')
    . ($haLike && $userMail !== '' ? ', EXISTS (SELECT 1 FROM na_recipe_likes l2 WHERE l2.recipe_id = r.id AND l2.user_mail = ?) AS liked_by_me' : '')
    . ($userMail !== '' ? ', (r.user_mail = ?) AS is_mine' : '')
    . ' FROM na_recipes r
          LEFT JOIN na_users u ON u.email = r.user_mail
         WHERE r.shared_status = "approved"';
$tipi = '';
$par = [];
if ($haLike && $userMail !== '') {
    $tipi .= 's';
    $par[] = $userMail;
}
if ($userMail !== '') {
    $tipi .= 's';
    $par[] = $userMail;
}
if ($haCategorie && in_array($filtroPasto, $pastiValidi, true)) {
    $sql .= ' AND FIND_IN_SET(?, r.meal_types) > 0';
    $tipi .= 's';
    $par[] = $filtroPasto;
}
if ($haCategorie && in_array($filtroPortata, ['primo', 'secondo', 'piatto_unico', 'contorno', 'dolce', 'bevanda', 'altro'], true)) {
    $sql .= ' AND r.course = ?';
    $tipi .= 's';
    $par[] = $filtroPortata;
}
if ($haCategorie && in_array($filtroDieta, ['vegetariana', 'vegana', 'senza_glutine'], true)) {
    $sql .= ' AND FIND_IN_SET(?, r.diet_tags) > 0';
    $tipi .= 's';
    $par[] = $filtroDieta;
}
if ($cerca !== '') {
    $like = '%' . addcslashes($cerca, '%_\\') . '%';
    $sql .= ' AND (r.recipe_name LIKE ? OR r.notes LIKE ?
                   OR EXISTS (SELECT 1 FROM na_recipe_ingredients i WHERE i.recipe_id = r.id AND i.food_name LIKE ?))';
    $tipi .= 'sss';
    array_push($par, $like, $like, $like);
}

// "Per te" si ordina in PHP (la formula ha un logaritmo e una potenza): si
// prendono le 300 piu' recenti e si ordinano. Le altre due modalita' bastano
// alla query.
if ($modo === 'piaciute' && $haLike) {
    $sql .= ' ORDER BY likes_count DESC, COALESCE(r.reviewed_at, r.shared_at) DESC, r.id DESC LIMIT ?';
    $tipi .= 'i';
    $par[] = $limite;
} elseif ($modo === 'per_te') {
    $sql .= ' ORDER BY COALESCE(r.reviewed_at, r.shared_at) DESC, r.id DESC LIMIT 300';
} else {
    $sql .= ' ORDER BY COALESCE(r.reviewed_at, r.shared_at) DESC, r.id DESC LIMIT ?';
    $tipi .= 'i';
    $par[] = $limite;
}

$stmt = $conn->prepare($sql);
if ($tipi !== '') {
    $stmt->bind_param($tipi, ...$par);
}
$stmt->execute();
$risultato = $stmt->get_result();

$ricette = [];
$ids = [];
$adesso = time();
while ($riga = $risultato->fetch_assoc()) {
    $nome = trim((string) ($riga['first_name'] ?? ''));
    $pasti = array_values(array_filter(explode(',', (string) ($riga['meal_types'] ?? ''))));
    $likes = (int) ($riga['likes_count'] ?? 0);

    $pubblicata = strtotime((string) ($riga['reviewed_at'] ?: $riga['shared_at'])) ?: $adesso;
    $giorni = max(0, ($adesso - $pubblicata) / 86400);
    $likesAltri = (int) ($riga['likes_others'] ?? $likes);
    $punteggio = (in_array($pastoAdesso, $pasti, true) ? 3.0 : 0.0)
        + 1.5 * log(1 + $likesAltri)
        + 2.0 * pow(0.5, $giorni / 14);

    $ricette[(int) $riga['id']] = [
        'id'            => (int) $riga['id'],
        'recipe_name'   => $riga['recipe_name'],
        'image_url'     => $riga['image_url'] ?? '',
        'portion'       => $riga['portion'],
        'notes'         => $riga['notes'],
        // Le ricette degli altri non hanno un "preferito" tuo: il campo resta
        // per non cambiare forma alla risposta, sempre 0.
        'is_favorite'   => 0,
        'shared_status' => $riga['shared_status'],
        'author_name'   => $nome !== '' ? $nome : 'Anonimo',
        'meal_types'    => implode(',', $pasti),
        'course'        => $riga['course'] ?? '',
        'diet_tags'     => $riga['diet_tags'] ?? '',
        'likes_count'   => $likes,
        'liked_by_me'   => (int) ($riga['liked_by_me'] ?? 0) === 1,
        'is_mine'       => (int) ($riga['is_mine'] ?? 0) === 1,
        'published_at'  => date('c', $pubblicata),
        'score'         => round($punteggio, 3),
        'ingredients'   => [],
    ];
    $ids[] = (int) $riga['id'];
}
$stmt->close();

if ($modo === 'per_te') {
    // uasort tiene le chiavi (gli id), che servono sotto per gli ingredienti.
    uasort($ricette, static fn(array $a, array $b): int => ($b['score'] <=> $a['score']) ?: ($b['id'] <=> $a['id']));
    $ricette = array_slice($ricette, 0, $limite, true);
    $ids = array_keys($ricette);
}

/*
 * Gli ingredienti in UNA query invece di una per ricetta.
 *
 * get_recipes.php ne fa una per ricetta, e per le proprie (poche) va bene. Qui
 * l'elenco e' di tutti: con 100 ricette sarebbero 101 interrogazioni per
 * disegnare una lista. Lo IN va costruito con i segnaposto, non con i valori
 * incollati: sono interi gia' convertiti, ma incollarli renderebbe questa riga
 * l'unica del file a fidarsi dell'input.
 */
if ($ids !== []) {
    $segnaposto = implode(',', array_fill(0, count($ids), '?'));
    $stmt = $conn->prepare("SELECT * FROM na_recipe_ingredients WHERE recipe_id IN ($segnaposto)");
    $stmt->bind_param(str_repeat('i', count($ids)), ...$ids);
    $stmt->execute();
    $ing = $stmt->get_result();
    while ($riga = $ing->fetch_assoc()) {
        $idRicetta = (int) $riga['recipe_id'];
        if (isset($ricette[$idRicetta])) {
            $ricette[$idRicetta]['ingredients'][] = $riga;
        }
    }
    $stmt->close();
}

$conn->close();

// array_values: le chiavi sono gli id, e con quelle json_encode produrrebbe un
// oggetto al posto di una lista — il client si aspetta una lista.
echo json_encode(['status' => 'success', 'mode' => $modo, 'recipes' => array_values($ricette)]);
