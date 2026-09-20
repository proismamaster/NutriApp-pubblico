<?php
/**
 * alimenti.php — gli alimenti personali proposti al database pubblico.
 *
 * Ricalcato sulla schermata 5A dei mockup: selettore a pillola In attesa /
 * Pubblici / Rifiutati, griglia di schede con foto (o segnaposto), la
 * striscia dei quattro valori principali e i due pulsanti. Rifiuta si accende
 * solo quando c'e' una motivazione, perche' la vede chi ha proposto.
 *
 * Qui non c'e' niente da confrontare: l'alimento non esiste altrove, si legge
 * e si decide. La scheda deve sembrare una schedina di prodotto, non un modulo.
 *
 * Approvare NON copia l'alimento in `na_off_products`: lo rende visibile agli
 * altri restando dov'e'. Spostarlo vorrebbe dire avere lo stesso alimento in
 * due tabelle che divergono al primo aggiornamento dell'autore — la stessa
 * ragione per cui la coda e' uno stato e non una copia.
 *
 * 15/09: un alimento approvato e' del database (l'autore non lo ritira e non lo
 * modifica piu'; se lo cancella resta pubblico, segnato "tolto dall'autore").
 * Qualsiasi admin lo puo' ritirare dalla scheda, anche se l'ha approvato un
 * altro. Ricerca su tutti i campi, filtro per revisore, ordinamento.
 */

declare(strict_types=1);
require __DIR__ . '/_comune.php';
richiediAccesso();

$messaggio = null;
$tipoMessaggio = 'esito';

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    richiediToken();
    $id = (int) ($_POST['id'] ?? 0);
    $azione = (string) ($_POST['azione'] ?? '');
    $nota = trim((string) ($_POST['nota'] ?? ''));

    $stmt = $conn->prepare('SELECT food_name, shared_status FROM na_custom_foods WHERE id = ? LIMIT 1');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $riga = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$riga) {
        $messaggio = 'Alimento non trovato.';
        $tipoMessaggio = 'avviso';
    } elseif ($azione === 'approva') {
        $chi = adminCorrente()['email'];
        $stmt = $conn->prepare(
            'UPDATE na_custom_foods
                SET shared_status = "approved", reviewed_at = NOW(), reviewed_by = ?, review_note = NULL
              WHERE id = ?'
        );
        $stmt->bind_param('si', $chi, $id);
        $stmt->execute();
        $stmt->close();
        registra($conn, 'approve', 'custom_food', $id, (string) $riga['food_name'],
            ['shared_status' => $riga['shared_status']], ['shared_status' => 'approved']);
        $messaggio = 'Alimento pubblicato: ' . $riga['food_name'];
    } elseif ($azione === 'rifiuta') {
        if ($nota === '') {
            $messaggio = 'Scrivi una motivazione: la vedrà chi ha proposto l\'alimento.';
            $tipoMessaggio = 'avviso';
        } else {
            $chi = adminCorrente()['email'];
            $stmt = $conn->prepare(
                'UPDATE na_custom_foods
                    SET shared_status = "rejected", reviewed_at = NOW(), reviewed_by = ?, review_note = ?
                  WHERE id = ?'
            );
            $stmt->bind_param('ssi', $chi, $nota, $id);
            $stmt->execute();
            $stmt->close();
            registra($conn, 'reject', 'custom_food', $id, (string) $riga['food_name'],
                ['shared_status' => $riga['shared_status']], ['shared_status' => 'rejected'], $nota);
            $messaggio = 'Alimento rifiutato: ' . $riga['food_name'];
        }
    } elseif ($azione === 'ritira') {
        [$messaggio, $tipoMessaggio] = ritiraPubblicazione($conn, 'custom_food', $id, $nota);
    }
}

$stato = (string) ($_GET['stato'] ?? 'pending');
if (!in_array($stato, ['pending', 'approved', 'rejected'], true)) {
    $stato = 'pending';
}
$haRimozione = colonnaEsiste($conn, 'na_custom_foods', 'author_removed_at');

// Filtro per revisore: i nomi sono quelli che compaiono davvero, come nel registro.
$revisori = [];
$res = $conn->query("SELECT DISTINCT reviewed_by FROM na_custom_foods WHERE reviewed_by IS NOT NULL AND reviewed_by <> '' ORDER BY reviewed_by");
while ($res && ($r = $res->fetch_row())) {
    $revisori[] = (string) $r[0];
}
$revisore = (string) ($_GET['revisore'] ?? '');
if ($revisore !== '' && !in_array($revisore, $revisori, true)) {
    $revisore = '';
}

// Ricerca su tutti i campi (14/09, allargata il 15/09).
$cerca = testoCercato();
$campiCerca = [
    'f.food_name', 'f.brand', 'f.barcode', 'f.categories', 'f.ingredients', 'f.review_note', 'f.reviewed_by',
    'u.email', 'u.first_name', 'u.last_name', 'CAST(f.id AS CHAR)',
];

$colonneOrdine = [
    'data' => ['Proposto il', 'f.shared_at'],
    'nome' => ['Nome', 'f.food_name'],
    'marca' => ['Marca', 'f.brand'],
    'kcal' => ['Calorie', 'f.calories'],
    'autore' => ['Autore', 'u.first_name'],
    'revisione' => ['Deciso il', 'f.reviewed_at'],
];
[$ordine, $ordinaPer, $verso] = ordinamento($colonneOrdine, 'data');

$dove = ['f.shared_status = ?'];
$tipi = 's';
$par = [$stato];
if ($revisore !== '') {
    $dove[] = 'f.reviewed_by = ?';
    $tipi .= 's';
    $par[] = $revisore;
}
if ($cerca !== '') {
    $dove[] = '(' . implode(' LIKE ? OR ', $campiCerca) . ' LIKE ?)';
    $tipi .= str_repeat('s', count($campiCerca));
    array_push($par, ...array_fill(0, count($campiCerca), comeLike($cerca)));
}

$sql = 'SELECT f.id, f.food_name, f.brand, f.barcode, f.image_url, f.calories, f.carbs,
               f.proteins, f.fats, f.base_weight_g, f.shared_at, f.shared_status, f.reviewed_by,
               f.reviewed_at, f.review_note, u.first_name'
    . ($haRimozione ? ', f.author_removed_at' : ', NULL AS author_removed_at') . '
          FROM na_custom_foods f
          LEFT JOIN na_users u ON u.email = f.user_mail
         WHERE ' . implode(' AND ', $dove) . "
         ORDER BY $ordine, f.id
         LIMIT 200";
$stmt = $conn->prepare($sql);
$stmt->bind_param($tipi, ...$par);
$stmt->execute();
$res = $stmt->get_result();

$schede = '';
while ($f = $res->fetch_assoc()) {
    $per = (float) ($f['base_weight_g'] ?: 100);
    $foto = trim((string) ($f['image_url'] ?? ''));
    $sotto = implode(' · ', array_filter([(string) ($f['brand'] ?? ''), (string) ($f['barcode'] ?? '')]));

    $schede .= '<div class="scheda-voce" id="a' . (int) $f['id'] . '">'
        . ($foto !== ''
            ? '<div class="immagine"><img src="' . e($foto) . '" alt="" loading="lazy"></div>'
            : '<div class="immagine vuota"><svg width="28" height="28" viewBox="0 0 24 24" fill="none"><rect x="3" y="5" width="18" height="14" rx="2" stroke="#7D857A" stroke-width="1.6"/><circle cx="9" cy="10.5" r="1.6" fill="#7D857A"/><path d="M4 16l5-4 4 3 3-2.5 4 3.5" stroke="#7D857A" stroke-width="1.6" stroke-linejoin="round"/></svg>nessuna foto</div>')
        . '<div class="corpo">'
        . '<div><div class="nome">' . e((string) $f['food_name']) . '</div>'
        . ($sotto !== '' ? '<div class="sotto">' . e($sotto) . '</div>' : '') . '</div>'
        . '<div class="striscia"><div class="striscia-titolo">Per ' . num($per) . ' g</div><div class="macro">'
        . '<div><b>' . num($f['calories']) . '</b><small>kcal</small></div>'
        . '<div><b>' . num($f['carbs']) . '</b><small>carb. g</small></div>'
        . '<div><b>' . num($f['proteins']) . '</b><small>prot. g</small></div>'
        . '<div><b>' . num($f['fats']) . '</b><small>grassi g</small></div>'
        . '</div></div>'
        . '<div class="chi-propone">Proposto da ' . e((string) ($f['first_name'] ?: 'Anonimo'))
        . ' · ' . e(attesa((string) $f['shared_at']))
        // Modificabile in ogni stato, anche dopo la pubblicazione (14/09):
        // approvare non deve voler dire congelare un errore.
        . ' · <a class="modifica" href="alimento.php?id=' . (int) $f['id'] . '">Modifica</a></div>';

    if ($stato === 'pending') {
        $schede .= '<form method="post" class="decidi">' . campoToken()
            . '<input type="hidden" name="id" value="' . (int) $f['id'] . '">'
            . '<input type="text" name="nota" maxlength="255" placeholder="Motivazione (solo per il rifiuto)">'
            . '<div class="bottoni" style="margin-top:8px">'
            . '<button class="principale" name="azione" value="approva">Approva</button>'
            . '<button class="rischio" name="azione" value="rifiuta">Rifiuta</button></div>'
            . '</form>';
    } elseif ($stato === 'approved') {
        $schede .= '<div class="pubblicato-da">Pubblicato da ' . e(nomeAdmin($conn, $f['reviewed_by']))
            . ($f['reviewed_at'] ? ' il ' . e(date('d/m/Y', strtotime((string) $f['reviewed_at']))) : '')
            . ($f['author_removed_at'] ? ' · <span class="pastiglia neutro">tolto dall\'autore</span>' : '') . '</div>'
            . '<form method="post" class="ritira">' . campoToken()
            . '<input type="hidden" name="id" value="' . (int) $f['id'] . '">'
            . '<input type="text" name="nota" maxlength="255" placeholder="Motivo del ritiro" required>'
            . '<button class="piccolo rischio" name="azione" value="ritira">Ritira</button></form>';
    } else {
        $schede .= '<div class="deciso no">Rifiutato da ' . e(nomeAdmin($conn, $f['reviewed_by']))
            . ($f['review_note'] ? ': ' . e((string) $f['review_note']) : '') . '</div>';
    }
    $schede .= '</div></div>';
}
$stmt->close();

$selettore = '<div class="schede">';
foreach (['pending' => 'In attesa', 'approved' => 'Pubblici', 'rejected' => 'Rifiutati'] as $v => $et) {
    $selettore .= '<a href="' . e(conParametri(['stato' => $v])) . '"'
        . ($stato === $v ? ' class="attiva"' : '') . '>' . e($et) . '</a>';
}
$selettore .= '</div>';

$opzioniRevisori = '<option value="">Tutti</option>';
foreach ($revisori as $r) {
    $opzioniRevisori .= '<option value="' . e($r) . '"' . ($r === $revisore ? ' selected' : '') . '>' . e(nomeAdmin($conn, $r)) . '</option>';
}

$ricerca = '<form class="filtri" method="get" style="margin-top:14px">'
    . '<input type="hidden" name="stato" value="' . e($stato) . '">'
    . campoCerca($cerca, 'qualsiasi campo: nome, marca, codice, ingredienti, persona')
    . '<label><span>Deciso da</span><select name="revisore">' . $opzioniRevisori . '</select></label>'
    . sceltaOrdinamento($colonneOrdine, $ordinaPer, $verso)
    . '<button class="principale" type="submit">Cerca</button></form>';

$html = ($messaggio !== null ? '<div class="' . $tipoMessaggio . '">' . e($messaggio) . '</div>' : '')
    . $selettore
    . $ricerca
    . ($schede === ''
        ? '<div class="vuoto">Nessun alimento in questo stato</div>'
        : '<div class="griglia-schede">' . $schede . '</div>')
    . scriptRifiutoConMotivazione();

pagina('Alimenti proposti', $html, 'alimenti.php');
