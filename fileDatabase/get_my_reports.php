<?php
/**
 * get_my_reports.php — le proprie segnalazioni e i propri contributi, con l'esito.
 *
 * PERCHE' SERVE: chi manda una correzione oggi non sa piu' niente. Senza un
 * ritorno, la seconda segnalazione non arriva mai — e una comunita' che
 * segnala una volta sola non e' una comunita'. Qui ci sono lo stato, la
 * motivazione del rifiuto e i campi effettivamente accettati.
 *
 * 15/09: la schermata "Le mie segnalazioni" ha tre schede (richiesta di
 * Ismail), quindi la risposta porta anche:
 *   app_reports  i problemi dell'app mandati da "Segnala un problema", con lo
 *                stato e la risposta di chi li ha gestiti;
 *   recipe_reports  le ricette pubbliche di altri che si sono segnalate (21/09);
 *   foods        i propri alimenti proposti al database (non i privati);
 *   recipes      le proprie ricette proposte per "Consigliate".
 * Alimenti e ricette tolti dalla libreria dopo l'approvazione ci sono lo
 * stesso, con `removed: true`: restano un contributo di chi li ha scritti.
 *
 * Restituisce solo i dati di chi chiede (`user_mail`): non c'e' autenticazione
 * in questa app (vedi PROBLEMS), quindi il filtro per email e' il solo confine
 * che possiamo mettere. Nessun dato di altri utenti passa da qui, nemmeno il
 * nome di chi ha deciso.
 *
 * Ogni parte si controlla da sola: un server senza una migrazione restituisce
 * quella lista vuota, non un errore per tutta la schermata.
 *
 * Richiede: community_comune.php, db_config.php; le migrazioni del 12/09 per le
 * segnalazioni, quella del 15/09 per lo stato dei problemi.
 */

/*
 * IL FILE COMUNE, CONTROLLATO PRIMA DI CHIEDERLO.
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

require communityRichiediFile('db_config.php');
require_once __DIR__ . '/auth.php';

// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$userMail = emailAutenticata($conn, trim((string) ($_GET['user_mail'] ?? '')));
if ($userMail === '') {
    communityErrore('user_mail mancante.');
}

// ---------------------------------------------------------------------------
// Segnalazioni sui dati degli alimenti
// ---------------------------------------------------------------------------
$segnalazioni = [];
$migrazioneMancante = !communityColonnaEsiste($conn, 'na_food_reports', 'status');
if (!$migrazioneMancante) {
    $haProposte = communityColonnaEsiste($conn, 'na_food_reports', 'proposed_json');

    $colonne = 'id, food_name, barcode, issue, status, created_at, reviewed_at, review_note'
        . ($haProposte ? ', kind, proposed_json, accepted_json' : '');

    $stmt = $conn->prepare(
        "SELECT $colonne FROM na_food_reports WHERE user_mail = ? ORDER BY created_at DESC LIMIT 100"
    );
    $stmt->bind_param('s', $userMail);
    $stmt->execute();
    $res = $stmt->get_result();

    $ids = [];
    while ($r = $res->fetch_assoc()) {
        $proposti = [];
        $accettati = [];
        if ($haProposte) {
            $p = json_decode((string) ($r['proposed_json'] ?? ''), true);
            $a = json_decode((string) ($r['accepted_json'] ?? ''), true);
            $proposti = is_array($p) ? array_keys($p) : [];
            $accettati = is_array($a) ? array_keys($a) : [];
        }
        $id = (int) $r['id'];
        $segnalazioni[$id] = [
            'id'             => $id,
            'food_name'      => $r['food_name'],
            'barcode'        => $r['barcode'],
            'issue'          => $r['issue'],
            'kind'           => $r['kind'] ?? 'correzione',
            'status'         => $r['status'],
            'created_at'     => $r['created_at'],
            'reviewed_at'    => $r['reviewed_at'],
            'review_note'    => $r['review_note'],
            // Nomi dei campi, non i valori: all'app serve dire "3 campi proposti,
            // 2 accettati", e i valori li ha gia' chi li ha scritti.
            'proposed_fields' => $proposti,
            'accepted_fields' => $accettati,
            'photos'          => [],
        ];
        $ids[] = $id;
    }
    $stmt->close();

    // Le foto in una query sola, come in get_public_recipes: con cento
    // segnalazioni, una query ciascuna sarebbe centouno interrogazioni.
    if ($ids !== [] && communityColonnaEsiste($conn, 'na_report_photos', 'url')) {
        $segnaposto = implode(',', array_fill(0, count($ids), '?'));
        $stmt = $conn->prepare(
            "SELECT report_id, url, role FROM na_report_photos
              WHERE report_id IN ($segnaposto) ORDER BY sort_order, id"
        );
        $stmt->bind_param(str_repeat('i', count($ids)), ...$ids);
        $stmt->execute();
        $foto = $stmt->get_result();
        while ($f = $foto->fetch_assoc()) {
            $idSeg = (int) $f['report_id'];
            if (isset($segnalazioni[$idSeg])) {
                $segnalazioni[$idSeg]['photos'][] = ['url' => $f['url'], 'role' => $f['role']];
            }
        }
        $stmt->close();
    }
}

// ---------------------------------------------------------------------------
// Segnalazioni su una ricetta pubblica (21/09)
// ---------------------------------------------------------------------------
$segnalazioniRicette = [];
if (communityColonnaEsiste($conn, 'na_recipe_reports', 'status')) {
    $stmt = $conn->prepare(
        'SELECT id, recipe_id, recipe_name, issue, note, status, created_at, reviewed_at, review_note
           FROM na_recipe_reports WHERE user_mail = ? ORDER BY created_at DESC LIMIT 100'
    );
    $stmt->bind_param('s', $userMail);
    $stmt->execute();
    $res = $stmt->get_result();
    while ($r = $res->fetch_assoc()) {
        $segnalazioniRicette[] = [
            'id'          => (int) $r['id'],
            'recipe_id'   => (int) $r['recipe_id'],
            'recipe_name' => $r['recipe_name'],
            'issue'       => $r['issue'],
            'note'        => $r['note'],
            'status'      => $r['status'],
            'created_at'  => $r['created_at'],
            'reviewed_at' => $r['reviewed_at'],
            'review_note' => $r['review_note'],
        ];
        // L'autore della ricetta NON esce da qui: chi ha segnalato non deve
        // sapere di chi e' la ricetta piu' di quanto gia' vedesse in app.
    }
    $stmt->close();
}

// ---------------------------------------------------------------------------
// Problemi dell'app (15/09)
// ---------------------------------------------------------------------------
$problemi = [];
if (communityColonnaEsiste($conn, 'na_reports', 'problem_description')) {
    $haTipo = communityColonnaEsiste($conn, 'na_reports', 'kind');
    $haStato = communityColonnaEsiste($conn, 'na_reports', 'status');
    $stmt = $conn->prepare(
        'SELECT id, problem_description, created_at'
        . ($haTipo ? ', kind, screen' : '')
        . ($haStato ? ', status, admin_note, handled_at' : '')
        . ' FROM na_reports WHERE user_email = ? ORDER BY created_at DESC LIMIT 100'
    );
    $stmt->bind_param('s', $userMail);
    $stmt->execute();
    $res = $stmt->get_result();
    while ($r = $res->fetch_assoc()) {
        $problemi[] = [
            'id'          => (int) $r['id'],
            'description' => $r['problem_description'],
            'kind'        => $r['kind'] ?? null,
            'screen'      => $r['screen'] ?? null,
            'status'      => $r['status'] ?? 'open',
            'admin_note'  => $r['admin_note'] ?? null,
            'created_at'  => $r['created_at'],
            'handled_at'  => $r['handled_at'] ?? null,
        ];
    }
    $stmt->close();
}

// ---------------------------------------------------------------------------
// Alimenti e ricette proposti (15/09)
// ---------------------------------------------------------------------------
$alimenti = [];
if (communityColonnaEsiste($conn, 'na_custom_foods', 'shared_status')) {
    $haRimozione = communityColonnaEsiste($conn, 'na_custom_foods', 'author_removed_at');
    $stmt = $conn->prepare(
        'SELECT id, food_name, brand, calories, image_url, shared_status, shared_at, reviewed_at, review_note'
        . ($haRimozione ? ', author_removed_at' : '')
        . " FROM na_custom_foods WHERE user_mail = ? AND shared_status <> 'private'
           ORDER BY shared_at DESC, id DESC LIMIT 200"
    );
    $stmt->bind_param('s', $userMail);
    $stmt->execute();
    $res = $stmt->get_result();
    while ($r = $res->fetch_assoc()) {
        $alimenti[] = [
            'id'            => (int) $r['id'],
            'name'          => $r['food_name'],
            'brand'         => $r['brand'] ?? '',
            'calories'      => (float) $r['calories'],
            'image_url'     => $r['image_url'] ?? '',
            'shared_status' => $r['shared_status'],
            'shared_at'     => $r['shared_at'],
            'reviewed_at'   => $r['reviewed_at'],
            'review_note'   => $r['review_note'],
            'removed'       => !empty($r['author_removed_at']),
        ];
    }
    $stmt->close();
}

$ricette = [];
if (communityColonnaEsiste($conn, 'na_recipes', 'shared_status')) {
    $haRimozione = communityColonnaEsiste($conn, 'na_recipes', 'author_removed_at');
    $haLike = communityColonnaEsiste($conn, 'na_recipe_likes', 'recipe_id');
    $stmt = $conn->prepare(
        'SELECT r.id, r.recipe_name, r.image_url, r.shared_status, r.shared_at, r.reviewed_at, r.review_note'
        . ($haRimozione ? ', r.author_removed_at, r.meal_types, r.course' : '')
        . ($haLike ? ', (SELECT COUNT(*) FROM na_recipe_likes l WHERE l.recipe_id = r.id) AS likes' : '')
        . " FROM na_recipes r WHERE r.user_mail = ? AND r.shared_status <> 'private'
           ORDER BY r.shared_at DESC, r.id DESC LIMIT 200"
    );
    $stmt->bind_param('s', $userMail);
    $stmt->execute();
    $res = $stmt->get_result();
    while ($r = $res->fetch_assoc()) {
        $ricette[] = [
            'id'            => (int) $r['id'],
            'name'          => $r['recipe_name'],
            'image_url'     => $r['image_url'] ?? '',
            'shared_status' => $r['shared_status'],
            'shared_at'     => $r['shared_at'],
            'reviewed_at'   => $r['reviewed_at'],
            'review_note'   => $r['review_note'],
            'removed'       => !empty($r['author_removed_at']),
            'meal_types'    => $r['meal_types'] ?? '',
            'course'        => $r['course'] ?? '',
            'likes'         => (int) ($r['likes'] ?? 0),
        ];
    }
    $stmt->close();
}

$conn->close();

$risposta = [
    'status'         => 'success',
    'reports'        => array_values($segnalazioni),
    'recipe_reports' => $segnalazioniRicette,
    'app_reports'    => $problemi,
    'foods'          => $alimenti,
    'recipes'        => $ricette,
];
if ($migrazioneMancante) {
    $risposta['migration_missing'] = true;
}
echo json_encode($risposta);
