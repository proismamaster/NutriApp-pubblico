<?php
/**
 * admin.php — cosa ha deciso un admin, e cosa di quello e' ancora in vigore (15/09).
 *
 * Richiesta di Ismail: vedere tutti gli alimenti e le modifiche accettate da un
 * determinato admin, con la possibilita' per QUALSIASI admin di toglierli anche
 * se li ha approvati un altro. Serve quando un revisore sbaglia piu' volte: il
 * registro dice le decisioni una per una, qui si vede cosa ne e' rimasto.
 *
 * Ritirare non cancella: stato `rejected` col motivo, e il registro scrive chi
 * ha ritirato cosa (ritiraPubblicazione in _comune.php). Le modifiche ai valori
 * si annullano con il pulsante del registro, che rimette i valori di prima.
 *
 * Email degli admin: solo il proprietario le vede, come nella gestione account.
 * Agli altri basta il nome.
 */

declare(strict_types=1);
require __DIR__ . '/_comune.php';
richiediAccesso();

$proprietario = (adminCorrente()['role'] ?? '') === 'owner';
$messaggio = null;
$tipoMessaggio = 'esito';

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    richiediToken();
    $tipo = (string) ($_POST['tipo'] ?? '');
    if (in_array($tipo, ['custom_food', 'recipe'], true)) {
        [$messaggio, $tipoMessaggio] = ritiraPubblicazione(
            $conn, $tipo, (int) ($_POST['id'] ?? 0), trim((string) ($_POST['nota'] ?? ''))
        );
    }
}

$haRimozione = colonnaEsiste($conn, 'na_custom_foods', 'author_removed_at');
$id = (int) ($_GET['id'] ?? 0);

// ===========================================================================
// Elenco degli admin
// ===========================================================================
if ($id <= 0) {
    $cerca = testoCercato();
    $colonneOrdine = [
        'nome' => ['Nome', 'a.display_name'],
        'ruolo' => ['Ruolo', 'a.role'],
        'alimenti' => ['Alimenti pubblicati', 'n_alimenti'],
        'ricette' => ['Ricette pubblicate', 'n_ricette'],
        'decisioni' => ['Decisioni', 'n_decisioni'],
        'accesso' => ['Ultimo accesso', 'a.last_login_at'],
    ];
    [$ordine, $ordinaPer, $verso] = ordinamento($colonneOrdine, 'nome');

    $sql = "SELECT a.id, a.display_name, a.email, a.role, a.active, a.last_login_at,
                   (SELECT COUNT(*) FROM na_custom_foods f WHERE f.reviewed_by = a.email AND f.shared_status = 'approved') AS n_alimenti,
                   (SELECT COUNT(*) FROM na_recipes r WHERE r.reviewed_by = a.email AND r.shared_status = 'approved') AS n_ricette,
                   (SELECT COUNT(*) FROM na_review_log l WHERE l.admin_email = a.email) AS n_decisioni
              FROM na_admins a";
    $tipi = '';
    $par = [];
    if ($cerca !== '') {
        // L'email si cerca solo se la vede chi cerca.
        $sql .= $proprietario
            ? ' WHERE (a.display_name LIKE ? OR a.email LIKE ? OR a.role LIKE ?)'
            : ' WHERE (a.display_name LIKE ? OR a.role LIKE ?)';
        $n = $proprietario ? 3 : 2;
        $tipi = str_repeat('s', $n);
        $par = array_fill(0, $n, comeLike($cerca));
    }
    $sql .= " ORDER BY $ordine, a.id";
    $stmt = $conn->prepare($sql);
    if ($tipi !== '') {
        $stmt->bind_param($tipi, ...$par);
    }
    $stmt->execute();
    $res = $stmt->get_result();

    $righe = '';
    while ($a = $res->fetch_assoc()) {
        $attivo = (int) $a['active'] === 1;
        $righe .= '<div class="riga">'
            . '<span class="taglia"><a class="nome-link' . ($attivo ? '' : ' barrato') . '" href="admin.php?id=' . (int) $a['id'] . '">'
            . e((string) $a['display_name']) . '</a>'
            . ($proprietario ? '<div class="codice">' . e((string) $a['email']) . '</div>' : '') . '</span>'
            . '<span><span class="pastiglia ' . ($a['role'] === 'owner' ? 'ok' : 'neutro') . '">'
            . e($a['role'] === 'owner' ? 'Proprietario' : 'Revisore') . '</span></span>'
            . '<span class="cifre">' . (int) $a['n_alimenti'] . '</span>'
            . '<span class="cifre">' . (int) $a['n_ricette'] . '</span>'
            . '<span class="cifre">' . (int) $a['n_decisioni'] . '</span>'
            . '<span class="secondario" style="font-size:12px">'
            . e($a['last_login_at'] ? date('d/m H:i', strtotime((string) $a['last_login_at'])) : 'mai') . '</span>'
            . '</div>';
    }
    $stmt->close();

    $html = '<form class="filtri" method="get">'
        . campoCerca($cerca, $proprietario ? 'nome, email o ruolo' : 'nome o ruolo')
        . sceltaOrdinamento($colonneOrdine, $ordinaPer, $verso)
        . '<button class="principale" type="submit">Cerca</button></form>'
        . '<p class="riepilogo">Apri un admin per vedere cosa ha pubblicato e toglierlo, anche se non l\'hai approvato tu.</p>'
        . '<div class="riquadro elenco-admin">'
        . testaOrdinabile([
            ['Nome', 'nome'], ['Ruolo', 'ruolo'], ['Alimenti', 'alimenti'], ['Ricette', 'ricette'],
            ['Decisioni', 'decisioni'], ['Ultimo accesso', 'accesso'],
        ], $ordinaPer, $verso)
        . ($righe === '' ? '<div class="vuoto">Nessun admin con questa ricerca</div>' : $righe)
        . '</div>';

    pagina('Admin', $html, 'admin.php');
    exit;
}

// ===========================================================================
// Un admin
// ===========================================================================
$stmt = $conn->prepare('SELECT id, display_name, email, role, active FROM na_admins WHERE id = ? LIMIT 1');
$stmt->bind_param('i', $id);
$stmt->execute();
$admin = $stmt->get_result()->fetch_assoc();
$stmt->close();
if (!$admin) {
    http_response_code(404);
    pagina('Admin non trovato', '<div class="vuoto">Nessun admin con questo numero. <a href="admin.php">Torna all\'elenco</a></div>', 'admin.php');
    exit;
}
$email = (string) $admin['email'];
$cerca = testoCercato();

/** Il modulo "Ritira" di un alimento o di una ricetta. */
$moduloRitira = static function (string $tipo, int $idOggetto): string {
    return '<form method="post" class="ritira">' . campoToken()
        . '<input type="hidden" name="tipo" value="' . e($tipo) . '">'
        . '<input type="hidden" name="id" value="' . $idOggetto . '">'
        . '<input type="text" name="nota" maxlength="255" placeholder="Motivo del ritiro" required>'
        . '<button class="piccolo rischio" type="submit">Ritira</button></form>';
};

// --- alimenti pubblicati da questo admin -----------------------------------
$colonneAlimenti = [
    'nome' => ['Nome', 'f.food_name'],
    'marca' => ['Marca', 'f.brand'],
    'data' => ['Pubblicato il', 'f.reviewed_at'],
    'autore' => ['Autore', 'u.first_name'],
];
[$ordineAlimenti, $ordinaPer, $verso] = ordinamento($colonneAlimenti, 'data', 'desc');
$condizioneCerca = $cerca === '' ? '' : ' AND (f.food_name LIKE ? OR f.brand LIKE ? OR f.barcode LIKE ? OR u.first_name LIKE ? OR CAST(f.id AS CHAR) LIKE ?)';
$stmt = $conn->prepare(
    'SELECT f.id, f.food_name, f.brand, f.reviewed_at, u.first_name'
    . ($haRimozione ? ', f.author_removed_at' : ', NULL AS author_removed_at')
    . " FROM na_custom_foods f LEFT JOIN na_users u ON u.email = f.user_mail
       WHERE f.shared_status = 'approved' AND f.reviewed_by = ?" . $condizioneCerca
    . " ORDER BY $ordineAlimenti LIMIT 300"
);
// bind_param vuole variabili: la lista si costruisce prima.
$par = $cerca === '' ? [$email] : array_merge([$email], array_fill(0, 5, comeLike($cerca)));
$stmt->bind_param(str_repeat('s', count($par)), ...$par);
$stmt->execute();
$res = $stmt->get_result();
$righeAlimenti = '';
while ($f = $res->fetch_assoc()) {
    $righeAlimenti .= '<div class="riga">'
        . '<span class="taglia"><a class="nome-link" href="alimento.php?id=' . (int) $f['id'] . '">' . e((string) $f['food_name']) . '</a>'
        . ($f['author_removed_at'] ? ' <span class="pastiglia neutro">tolto dall\'autore</span>' : '') . '</span>'
        . '<span class="secondario taglia">' . e((string) ($f['brand'] ?: '—')) . '</span>'
        . '<span class="secondario cifre">' . e($f['reviewed_at'] ? date('d/m/Y', strtotime((string) $f['reviewed_at'])) : '—') . '</span>'
        . '<span class="taglia">' . e((string) ($f['first_name'] ?: 'Anonimo')) . '</span>'
        . $moduloRitira('custom_food', (int) $f['id'])
        . '</div>';
}
$stmt->close();

// --- ricette pubblicate da questo admin ------------------------------------
$condizioneCercaRicette = $cerca === '' ? '' : ' AND (r.recipe_name LIKE ? OR u.first_name LIKE ? OR CAST(r.id AS CHAR) LIKE ?)';
$stmt = $conn->prepare(
    'SELECT r.id, r.recipe_name, r.reviewed_at, u.first_name'
    . (colonnaEsiste($conn, 'na_recipes', 'author_removed_at') ? ', r.author_removed_at' : ', NULL AS author_removed_at')
    . " FROM na_recipes r LEFT JOIN na_users u ON u.email = r.user_mail
       WHERE r.shared_status = 'approved' AND r.reviewed_by = ?" . $condizioneCercaRicette
    . ' ORDER BY r.reviewed_at DESC LIMIT 300'
);
$par = $cerca === '' ? [$email] : array_merge([$email], array_fill(0, 3, comeLike($cerca)));
$stmt->bind_param(str_repeat('s', count($par)), ...$par);
$stmt->execute();
$res = $stmt->get_result();
$righeRicette = '';
while ($r = $res->fetch_assoc()) {
    $righeRicette .= '<div class="riga">'
        . '<span class="taglia" style="font-weight:600">' . e((string) $r['recipe_name'])
        . ($r['author_removed_at'] ? ' <span class="pastiglia neutro">tolta dall\'autore</span>' : '') . '</span>'
        . '<span class="secondario cifre">' . e($r['reviewed_at'] ? date('d/m/Y', strtotime((string) $r['reviewed_at'])) : '—') . '</span>'
        . '<span class="taglia">' . e((string) ($r['first_name'] ?: 'Anonimo')) . '</span>'
        . $moduloRitira('recipe', (int) $r['id'])
        . '</div>';
}
$stmt->close();

// --- modifiche ai valori ancora in vigore ----------------------------------
$condizioneCercaLog = $cerca === '' ? '' : ' AND (target_label LIKE ? OR after_json LIKE ?)';
$stmt = $conn->prepare(
    "SELECT id, action, target_type, target_label, after_json, created_at FROM na_review_log
      WHERE admin_email = ? AND action IN ('accept', 'edit') AND undone_at IS NULL" . $condizioneCercaLog
    . ' ORDER BY created_at DESC LIMIT 300'
);
$par = $cerca === '' ? [$email] : array_merge([$email], array_fill(0, 2, comeLike($cerca)));
$stmt->bind_param(str_repeat('s', count($par)), ...$par);
$stmt->execute();
$res = $stmt->get_result();
$righeModifiche = '';
while ($l = $res->fetch_assoc()) {
    $dopo = json_decode((string) $l['after_json'], true);
    $campi = is_array($dopo) ? implode(', ', array_map('etichettaCampo', array_keys($dopo))) : '—';
    $righeModifiche .= '<div class="riga">'
        . '<span class="taglia" style="font-weight:600">' . e((string) $l['target_label']) . '</span>'
        . '<span class="secondario" style="font-size:12.5px">' . e($l['target_type'] === 'food_report' ? 'correzione accettata' : 'modifica dal pannello') . '</span>'
        . '<span class="taglia" style="font-size:12.5px">' . e($campi) . '</span>'
        . '<span class="secondario cifre">' . e(date('d/m/Y', strtotime((string) $l['created_at']))) . '</span>'
        . '<form method="post" action="registro.php" style="margin:0">' . campoToken()
        . '<input type="hidden" name="id" value="' . (int) $l['id'] . '">'
        . '<button class="piccolo" type="submit">Annulla</button></form>'
        . '</div>';
}
$stmt->close();

$html = ($messaggio !== null ? '<div class="' . $tipoMessaggio . '">' . e($messaggio) . '</div>' : '')
    . '<p class="riepilogo"><a href="admin.php">← Tutti gli admin</a> · '
    . e($admin['role'] === 'owner' ? 'Proprietario' : 'Revisore')
    . ((int) $admin['active'] === 1 ? '' : ' · disattivato')
    . ($proprietario ? ' · ' . e($email) : '')
    . ' · <a href="registro.php?persona=' . e(rawurlencode($email)) . '">tutte le sue decisioni nel registro</a></p>'
    . '<form class="filtri" method="get"><input type="hidden" name="id" value="' . $id . '">'
    . campoCerca($cerca, 'nome, marca, codice o autore')
    . sceltaOrdinamento($colonneAlimenti, $ordinaPer, $verso)
    . '<button class="principale" type="submit">Cerca</button></form>'
    . '<h2 class="sezione-admin">Alimenti pubblicati</h2>'
    . '<div class="riquadro pubblicati-alimenti">'
    . testaOrdinabile([['Nome', 'nome'], ['Marca', 'marca'], ['Pubblicato', 'data'], ['Autore', 'autore'], ['Ritira dal database', null]], $ordinaPer, $verso)
    . ($righeAlimenti === '' ? '<div class="vuoto">Nessun alimento pubblicato ancora in vigore</div>' : $righeAlimenti)
    . '</div>'
    . '<h2 class="sezione-admin">Ricette pubblicate</h2>'
    . '<div class="riquadro pubblicati-ricette"><div class="riga testa"><span>Ricetta</span><span>Pubblicata</span><span>Autore</span><span>Ritira</span></div>'
    . ($righeRicette === '' ? '<div class="vuoto">Nessuna ricetta pubblicata ancora in vigore</div>' : $righeRicette)
    . '</div>'
    . '<h2 class="sezione-admin">Modifiche ai valori in vigore</h2>'
    . '<div class="riquadro modifiche-admin"><div class="riga testa"><span>Su</span><span>Tipo</span><span>Campi</span><span>Quando</span><span></span></div>'
    . ($righeModifiche === '' ? '<div class="vuoto">Nessuna modifica in vigore</div>' : $righeModifiche)
    . '</div>';

pagina((string) $admin['display_name'], $html, 'admin.php');
