<?php
/**
 * utenti.php — cercare un utente e vedere cosa ha fatto (2026-09-14).
 *
 * PERCHE' ESISTE: "filtri utili per l'admin per cercare utenti, pasti ecc."
 * (Ismail). Finora per rispondere a "chi ha proposto questo?" o "questo utente
 * ha segnalato altro?" serviva phpMyAdmin.
 *
 * Due viste nello stesso file: l'elenco con la ricerca (nome, cognome, email)
 * e il dettaglio di un utente con profilo, alimenti, ricette, segnalazioni e
 * diario alimentare filtrabile per date, pasto e alimento.
 *
 * IL DIARIO LO VEDE SOLO IL PROPRIETARIO. Quello che una persona mangia e il
 * suo peso sono dati sulla salute, la categoria piu' protetta dal GDPR: un
 * revisore deve giudicare alimenti e segnalazioni, e per farlo non gli serve
 * sapere cosa ha cenato qualcuno. Peso, obiettivo e ultima attivita' del diario
 * seguono la stessa regola. Il revisore vede nome, email e contributi.
 *
 * Solo lettura: niente in questa pagina scrive sul database.
 */

declare(strict_types=1);
require __DIR__ . '/_comune.php';
richiediAccesso();

$proprietario = (adminCorrente()['role'] ?? '') === 'owner';

/** Una tabella che potrebbe non esserci ancora (migrazione non eseguita). */
function tabellaEsiste(mysqli $conn, string $nome): bool
{
    $stmt = $conn->prepare('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?');
    $stmt->bind_param('s', $nome);
    $stmt->execute();
    $n = (int) ($stmt->get_result()->fetch_row()[0] ?? 0);
    $stmt->close();
    return $n > 0;
}

/** Tutte le righe di una query preparata. */
function righe(mysqli $conn, string $sql, string $tipi = '', array $par = []): array
{
    $stmt = $conn->prepare($sql);
    if ($tipi !== '') {
        $stmt->bind_param($tipi, ...$par);
    }
    $stmt->execute();
    $res = $stmt->get_result();
    $tutte = [];
    while ($r = $res->fetch_assoc()) {
        $tutte[] = $r;
    }
    $stmt->close();
    return $tutte;
}

/**
 * Stato di un alimento o di una ricetta. pastiglia() dice "Aperta" per
 * `pending`, che e' la parola giusta per una segnalazione ma non per un
 * alimento proposto.
 */
function statoCondivisione(string $stato): string
{
    $mappa = [
        'private' => ['neutro', 'Privato'], 'pending' => ['attesa', 'In attesa'],
        'approved' => ['ok', 'Pubblico'], 'rejected' => ['no', 'Rifiutato'],
    ];
    [$classe, $testo] = $mappa[$stato] ?? ['neutro', $stato];
    return '<span class="pastiglia stato ' . $classe . '">' . e($testo) . '</span>';
}

function dataItaliana(?string $data): string
{
    return $data ? date('d/m/Y', strtotime($data)) : '—';
}

$haDiario = tabellaEsiste($conn, 'na_nutri_entries');
$haSegnalazioni = tabellaEsiste($conn, 'na_food_reports');
$id = (int) ($_GET['id'] ?? 0);

// ===========================================================================
// Elenco
// ===========================================================================
if ($id <= 0) {
    $cerca = testoCercato();
    $sql = 'SELECT u.id, u.first_name, u.last_name, u.email, u.created_at,
                   (SELECT COUNT(*) FROM na_custom_foods f WHERE f.user_mail = u.email) AS n_alimenti'
        . ($haSegnalazioni ? ', (SELECT COUNT(*) FROM na_food_reports r WHERE r.user_mail = u.email) AS n_segnalazioni' : ', 0 AS n_segnalazioni')
        . ($haDiario && $proprietario ? ', (SELECT MAX(e.entry_date) FROM na_nutri_entries e WHERE e.user_mail = u.email) AS ultimo_diario' : ', NULL AS ultimo_diario')
        . ' FROM na_users u';
    $tipi = '';
    $par = [];
    if ($cerca !== '') {
        $sql .= " WHERE (u.first_name LIKE ? OR u.last_name LIKE ? OR u.email LIKE ?
                   OR CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, '')) LIKE ?
                   OR CAST(u.id AS CHAR) LIKE ?)";
        $like = comeLike($cerca);
        $tipi = 'sssss';
        $par = [$like, $like, $like, $like, $like];
    }
    // Ordinamento a colonne (15/09). "Ultimo diario" solo per il proprietario,
    // come la colonna stessa.
    $colonneOrdine = [
        'iscritto' => ['Iscritto', 'u.created_at'],
        'nome' => ['Nome', "CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, ''))"],
        'cognome' => ['Cognome', 'u.last_name'],
        'email' => ['Email', 'u.email'],
        'alimenti' => ['Alimenti', 'n_alimenti'],
        'segnalazioni' => ['Segnalazioni', 'n_segnalazioni'],
    ];
    if ($proprietario) {
        $colonneOrdine['diario'] = ['Ultimo diario', 'ultimo_diario'];
    }
    [$ordine, $ordinaPer, $verso] = ordinamento($colonneOrdine, 'iscritto', 'desc');
    $sql .= " ORDER BY $ordine, u.id DESC LIMIT 50";
    $utenti = righe($conn, $sql, $tipi, $par);

    $elenco = '';
    foreach ($utenti as $u) {
        $nome = trim((string) $u['first_name'] . ' ' . (string) $u['last_name']);
        $elenco .= '<div class="riga">'
            . '<a class="nome-link taglia" href="utenti.php?id=' . (int) $u['id'] . '">' . e($nome !== '' ? $nome : '(senza nome)') . '</a>'
            . '<span class="secondario taglia">' . e((string) $u['email']) . '</span>'
            . '<span class="secondario cifre">dal ' . e(dataItaliana((string) $u['created_at'])) . '</span>'
            . '<span class="cifre">' . (int) $u['n_alimenti'] . ' alim.</span>'
            . '<span class="cifre">' . (int) $u['n_segnalazioni'] . ' segn.</span>'
            . '<span class="secondario cifre">' . ($proprietario ? 'diario ' . e(dataItaliana($u['ultimo_diario'])) : '') . '</span>'
            . '</div>';
    }

    $html = '<form class="filtri" method="get">'
        . campoCerca($cerca, 'nome, cognome, email o numero')
        . sceltaOrdinamento($colonneOrdine, $ordinaPer, $verso)
        . '<button class="principale" type="submit">Cerca</button>'
        . ($cerca !== '' ? '<a class="bottone" href="utenti.php">Azzera</a>' : '')
        . '</form>'
        . '<p class="riepilogo">' . ($cerca === ''
            ? 'Gli ultimi ' . count($utenti) . ' iscritti.'
            : '<b>' . count($utenti) . '</b> ' . (count($utenti) === 1 ? 'utente trovato' : 'utenti trovati')
                . (count($utenti) === 50 ? ' (i primi 50: restringi la ricerca)' : '') . '.')
        . '</p>'
        . '<div class="riquadro utenti">'
        . testaOrdinabile([
            ['Nome', 'nome'], ['Email', 'email'], ['Iscritto', 'iscritto'], ['Alimenti', 'alimenti'],
            ['Segnalazioni', 'segnalazioni'], ['Ultimo diario', $proprietario ? 'diario' : null],
        ], $ordinaPer, $verso)
        . ($elenco === '' ? '<div class="vuoto">Nessun utente con questa ricerca</div>' : $elenco)
        . '</div>';

    pagina('Utenti', $html, 'utenti.php');
    exit;
}

// ===========================================================================
// Dettaglio
// ===========================================================================
$trovati = righe($conn, 'SELECT * FROM na_users WHERE id = ? LIMIT 1', 'i', [$id]);
if ($trovati === []) {
    http_response_code(404);
    pagina('Utente non trovato', '<a class="torna" href="utenti.php">&larr; utenti</a><div class="vuoto">Nessun utente con questo numero.</div>', 'utenti.php');
    exit;
}
$u = $trovati[0];
$email = (string) $u['email'];
$nome = trim((string) $u['first_name'] . ' ' . (string) $u['last_name']);

$eta = '—';
if (!empty($u['birth_date'])) {
    $nascita = DateTime::createFromFormat('!Y-m-d', substr((string) $u['birth_date'], 0, 10));
    if ($nascita) {
        $eta = $nascita->diff(new DateTime('today'))->y . ' anni';
    }
}

$fatti = ['Email' => $email, 'Iscritto il' => dataItaliana((string) $u['created_at'])];
if ($proprietario) {
    $fatti['Età'] = $eta;
    $fatti['Altezza'] = (float) $u['height'] > 0 ? num($u['height'], 0) . ' cm' : '—';
    $fatti['Peso'] = (float) $u['current_weight'] > 0 ? num($u['current_weight']) . ' kg' : '—';
    $fatti['Obiettivo'] = (float) $u['target_weight'] > 0 ? num($u['target_weight']) . ' kg' : '—';
    $fatti['Calorie al giorno'] = (float) $u['calorie_goal'] > 0 ? num($u['calorie_goal'], 0) . ' kcal' : '—';
}
if (array_key_exists('share_custom_foods', $u)) {
    $fatti['Condivide i suoi alimenti'] = (int) $u['share_custom_foods'] === 1 ? 'sì' : 'no';
}

$html = '<a class="torna" href="utenti.php">&larr; utenti</a><div class="riquadro fatti" style="max-width:520px">';
foreach ($fatti as $k => $v) {
    $html .= '<div class="riga"><span>' . e($k) . '</span><span class="taglia">' . e($v) . '</span></div>';
}
$html .= '</div>';

// --- Contributi ------------------------------------------------------------
$alimenti = righe($conn,
    'SELECT id, food_name, calories, base_weight_g, shared_status FROM na_custom_foods
      WHERE user_mail = ? ORDER BY food_name LIMIT 100', 's', [$email]);
$html .= '<h2>Alimenti personali (' . count($alimenti) . ')</h2>';
if ($alimenti === []) {
    $html .= '<div class="riquadro"><div class="vuoto">Nessun alimento personale</div></div>';
} else {
    $html .= '<div class="riquadro contributi">';
    foreach ($alimenti as $a) {
        $html .= '<div class="riga">'
            . '<a class="nome-link taglia" href="alimento.php?id=' . (int) $a['id'] . '">' . e((string) $a['food_name']) . '</a>'
            . '<span class="secondario cifre">' . num($a['calories'], 0) . ' kcal</span>'
            . statoCondivisione((string) $a['shared_status'])
            . '</div>';
    }
    $html .= '</div>';
}

$ricette = righe($conn,
    'SELECT id, recipe_name, shared_status FROM na_recipes WHERE user_mail = ? ORDER BY recipe_name LIMIT 100', 's', [$email]);
$html .= '<h2>Ricette (' . count($ricette) . ')</h2>';
if ($ricette === []) {
    $html .= '<div class="riquadro"><div class="vuoto">Nessuna ricetta</div></div>';
} else {
    $html .= '<div class="riquadro contributi">';
    foreach ($ricette as $r) {
        $stato = (string) ($r['shared_status'] ?? 'private');
        $html .= '<div class="riga"><span class="taglia" style="font-weight:600">' . e((string) $r['recipe_name']) . '</span>'
            . '<span></span>' . statoCondivisione($stato) . '</div>';
    }
    $html .= '</div>';
}

if ($haSegnalazioni) {
    $segnalazioni = righe($conn,
        'SELECT id, food_name, issue, status, created_at FROM na_food_reports
          WHERE user_mail = ? ORDER BY created_at DESC LIMIT 50', 's', [$email]);
    $html .= '<h2>Segnalazioni (' . count($segnalazioni) . ')</h2>';
    if ($segnalazioni === []) {
        $html .= '<div class="riquadro"><div class="vuoto">Nessuna segnalazione</div></div>';
    } else {
        $html .= '<div class="riquadro contributi">';
        foreach ($segnalazioni as $s) {
            $html .= '<div class="riga">'
                . '<a class="nome-link taglia" href="segnalazione.php?id=' . (int) $s['id'] . '">' . e((string) ($s['food_name'] ?: '(senza nome)')) . '</a>'
                . '<span class="secondario cifre">' . e(dataItaliana((string) $s['created_at'])) . '</span>'
                . pastiglia((string) $s['status'])
                . '</div>';
        }
        $html .= '</div>';
    }
}

// --- Diario ----------------------------------------------------------------
$html .= '<h2>Diario alimentare</h2>';
if (!$proprietario) {
    $html .= '<div class="riquadro"><div class="vuoto">Il diario è visibile solo al proprietario del pannello: sono dati sulla salute.</div></div>';
} elseif (!$haDiario) {
    $html .= '<div class="riquadro"><div class="vuoto">La tabella del diario non c\'è in questo database.</div></div>';
} else {
    $dataValida = static fn(string $d): bool => (bool) preg_match('/^\d{4}-\d{2}-\d{2}$/', $d);
    $dal = trim((string) ($_GET['dal'] ?? ''));
    $al = trim((string) ($_GET['al'] ?? ''));
    $dal = $dataValida($dal) ? $dal : date('Y-m-d', strtotime('-6 days'));
    $al = $dataValida($al) ? $al : date('Y-m-d');
    if ($dal > $al) {
        [$dal, $al] = [$al, $dal];
    }
    $pasti = ['' => 'Tutti i pasti', 'Colazione' => 'Colazione', 'Pranzo' => 'Pranzo', 'Cena' => 'Cena', 'Snack' => 'Snack'];
    $pasto = (string) ($_GET['pasto'] ?? '');
    if (!isset($pasti[$pasto])) {
        $pasto = '';
    }
    $cibo = mb_substr(trim((string) ($_GET['cibo'] ?? '')), 0, 100);

    $sql = 'SELECT entry_date, meal_type, food_name, weight_g, calories FROM na_nutri_entries
             WHERE user_mail = ? AND entry_date BETWEEN ? AND ?';
    $tipi = 'sss';
    $par = [$email, $dal, $al];
    if ($pasto !== '') {
        $sql .= ' AND meal_type = ?';
        $tipi .= 's';
        $par[] = $pasto;
    }
    if ($cibo !== '') {
        $sql .= ' AND food_name LIKE ?';
        $tipi .= 's';
        $par[] = comeLike($cibo);
    }
    $sql .= " ORDER BY entry_date DESC, FIELD(meal_type, 'Colazione', 'Pranzo', 'Cena', 'Snack'), id LIMIT 500";
    $voci = righe($conn, $sql, $tipi, $par);

    $opzioniPasto = '';
    foreach ($pasti as $v => $et) {
        $opzioniPasto .= '<option value="' . e($v) . '"' . ($v === $pasto ? ' selected' : '') . '>' . e($et) . '</option>';
    }
    $html .= '<form class="filtri" method="get"><input type="hidden" name="id" value="' . $id . '">'
        . '<label><span>Dal</span><input type="date" name="dal" value="' . e($dal) . '"></label>'
        . '<label><span>Al</span><input type="date" name="al" value="' . e($al) . '"></label>'
        . '<label><span>Pasto</span><select name="pasto">' . $opzioniPasto . '</select></label>'
        . '<label class="cerca"><span>Alimento</span><input type="search" name="cibo" maxlength="100" value="' . e($cibo) . '" placeholder="es. pasta"></label>'
        . '<button class="principale" type="submit">Filtra</button></form>';

    $giorni = [];
    $totale = 0.0;
    foreach ($voci as $v) {
        $giorni[(string) $v['entry_date']] = true;
        $totale += (float) $v['calories'];
    }
    $nGiorni = count($giorni);
    $html .= '<p class="riepilogo"><b>' . count($voci) . '</b> ' . (count($voci) === 1 ? 'voce' : 'voci')
        . ' in <b>' . $nGiorni . '</b> ' . ($nGiorni === 1 ? 'giorno' : 'giorni')
        . ($nGiorni > 0 ? ' · media <b>' . num($totale / $nGiorni, 0) . ' kcal</b> nei giorni registrati' : '')
        . ((float) $u['calorie_goal'] > 0 ? ' (obiettivo ' . num($u['calorie_goal'], 0) . ')' : '')
        . (count($voci) === 500 ? ' · mostrate le prime 500: restringi le date' : '')
        . '</p>';

    if ($voci === []) {
        $html .= '<div class="riquadro"><div class="vuoto">Nessuna voce con questi filtri</div></div>';
    } else {
        $html .= '<div class="riquadro diario"><div class="riga testa"><span>Data</span><span>Pasto</span><span>Alimento</span>'
            . '<span class="destra">Grammi</span><span class="destra">Energia</span></div>';
        foreach ($voci as $v) {
            $html .= '<div class="riga">'
                . '<span class="cifre">' . e(dataItaliana((string) $v['entry_date'])) . '</span>'
                . '<span class="secondario">' . e((string) $v['meal_type']) . '</span>'
                . '<span class="taglia">' . e((string) $v['food_name']) . '</span>'
                . '<span class="destra cifre">' . num($v['weight_g'], 0) . ' g</span>'
                . '<span class="destra cifre">' . num($v['calories'], 0) . ' kcal</span>'
                . '</div>';
        }
        $html .= '</div>';
    }
}

pagina($nome !== '' ? $nome : $email, $html, 'utenti.php');
