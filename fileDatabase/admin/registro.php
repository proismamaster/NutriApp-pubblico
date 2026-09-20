<?php
/**
 * registro.php — cosa e' stato deciso, da chi, e il pulsante per tornare
 * indietro.
 *
 * Ricalcato sulla schermata 6B dei mockup: filtri per persona e per data,
 * "Cosa" colorato come il resto del pannello, le righe annullate barrate e in
 * grigio con la nota "annullata il ... da ...", e il pulsante Annulla a pillola.
 *
 * PERCHE' L'ANNULLA E' LA RAGIONE PER CUI QUESTO REGISTRO ESISTE
 * Accettare una correzione scrive su `na_off_products`, che ha 214.000 righe e
 * nessun'altra copia. Senza il valore di prima, una decisione sbagliata e'
 * definitiva. `before_json` lo conserva, e questa pagina lo rimette a posto.
 *
 * IL REGISTRO NON SI RISCRIVE: annullare aggiunge una riga e marca quella
 * vecchia come annullata. Una riga cancellata renderebbe il registro inutile
 * proprio nel caso in cui serve.
 */

declare(strict_types=1);
require __DIR__ . '/_comune.php';
richiediAccesso();

$messaggio = null;
$tipoMessaggio = 'esito';

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    richiediToken();
    $idRiga = (int) ($_POST['id'] ?? 0);

    $stmt = $conn->prepare('SELECT * FROM na_review_log WHERE id = ? LIMIT 1');
    $stmt->bind_param('i', $idRiga);
    $stmt->execute();
    $riga = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$riga) {
        $messaggio = 'Riga non trovata.';
        $tipoMessaggio = 'avviso';
    } elseif ($riga['undone_at'] !== null) {
        $messaggio = 'Questa decisione era già stata annullata.';
        $tipoMessaggio = 'avviso';
    } else {
        $prima = $riga['before_json'] ? json_decode((string) $riga['before_json'], true) : [];
        $prima = is_array($prima) ? $prima : [];
        $fatto = [];

        if ($riga['target_type'] === 'food_report') {
            // Rimettiamo i valori di prima sul prodotto, e la segnalazione
            // torna aperta: annullare vuol dire "quella decisione non vale",
            // non "la segnalazione non e' mai esistita".
            $stmt = $conn->prepare('SELECT barcode FROM na_food_reports WHERE id = ? LIMIT 1');
            $idSeg = (int) $riga['target_id'];
            $stmt->bind_param('i', $idSeg);
            $stmt->execute();
            $seg = $stmt->get_result()->fetch_assoc();
            $stmt->close();

            $barcode = trim((string) ($seg['barcode'] ?? ''));
            if ($prima !== [] && $barcode !== '') {
                $campiTipo = campiAmmessi($conn, 'na_off_products');
                $daRimettere = [];
                foreach ($prima as $campo => $valore) {
                    if (isset($campiTipo[$campo])) {
                        $daRimettere[$campo] = $valore;
                    }
                }
                if ($daRimettere !== []) {
                    applicaValori($conn, 'na_off_products', 'barcode', $barcode, $campiTipo, $daRimettere);
                    $fatto[] = count($daRimettere) . ' valori ripristinati';
                }
            }
            $stmt = $conn->prepare(
                'UPDATE na_food_reports
                    SET status = "pending", reviewed_at = NULL, reviewed_by = NULL,
                        review_note = NULL, accepted_json = NULL
                  WHERE id = ?'
            );
            $stmt->bind_param('i', $idSeg);
            $stmt->execute();
            $stmt->close();
            $fatto[] = 'segnalazione riaperta';
        } elseif ($riga['action'] === 'edit' && $riga['target_type'] === 'custom_food') {
            // Modifica di un alimento dal pannello (14/09): si rimettono i
            // valori di prima, filtrati dalla stessa lista chiusa che li ha
            // scritti. Lo stato di condivisione non c'entra e non si tocca.
            $campiTipo = campiAlimentoPersonale($conn)['tipi'];
            $daRimettere = array_intersect_key($prima, $campiTipo);
            if ($daRimettere !== []) {
                applicaValori($conn, 'na_custom_foods', 'id', (string) (int) $riga['target_id'], $campiTipo, $daRimettere);
                $fatto[] = count($daRimettere) . ' valori ripristinati';
            }
        } elseif ($riga['target_type'] === 'custom_food' || $riga['target_type'] === 'recipe') {
            $tabellaOggetto = $riga['target_type'] === 'recipe' ? 'na_recipes' : 'na_custom_foods';
            $statoPrima = (string) ($prima['shared_status'] ?? 'pending');
            if (!in_array($statoPrima, ['private', 'pending', 'approved', 'rejected'], true)) {
                $statoPrima = 'pending';
            }
            // Un ritiro (15/09) si annulla rimettendo anche chi l'aveva
            // approvato e quando: senza, l'alimento tornerebbe pubblico senza
            // un revisore, e la pagina di quell'admin lo perderebbe.
            $revisorePrima = isset($prima['reviewed_by']) ? (string) $prima['reviewed_by'] : null;
            $dataPrima = isset($prima['reviewed_at']) ? (string) $prima['reviewed_at'] : null;
            $idOggetto = (int) $riga['target_id'];
            // Nome di tabella scelto qui dentro fra due costanti, mai
            // dall'input: e' il solo modo per interpolarlo senza rischi.
            $stmt = $conn->prepare(
                "UPDATE `$tabellaOggetto`
                    SET shared_status = ?, reviewed_at = ?, reviewed_by = ?, review_note = NULL
                  WHERE id = ?"
            );
            $stmt->bind_param('sssi', $statoPrima, $dataPrima, $revisorePrima, $idOggetto);
            $stmt->execute();
            $stmt->close();
            $fatto[] = 'stato riportato a ' . $statoPrima;
        } elseif ($riga['target_type'] === 'app_report') {
            // Problema dell'app (15/09): torna lo stato di prima, con la nota e
            // chi l'aveva gestito.
            $statoPrima = (string) ($prima['status'] ?? 'open');
            if (!in_array($statoPrima, ['open', 'resolved', 'closed'], true)) {
                $statoPrima = 'open';
            }
            $notaPrima = isset($prima['admin_note']) ? (string) $prima['admin_note'] : null;
            $chiPrima = isset($prima['handled_by']) ? (string) $prima['handled_by'] : null;
            $quandoPrima = isset($prima['handled_at']) ? (string) $prima['handled_at'] : null;
            $idOggetto = (int) $riga['target_id'];
            $stmt = $conn->prepare('UPDATE na_reports SET status = ?, admin_note = ?, handled_by = ?, handled_at = ? WHERE id = ?');
            $stmt->bind_param('ssssi', $statoPrima, $notaPrima, $chiPrima, $quandoPrima, $idOggetto);
            $stmt->execute();
            $stmt->close();
            $fatto[] = 'problema riportato a ' . $statoPrima;
        }

        $chi = adminCorrente()['email'];
        $stmt = $conn->prepare('UPDATE na_review_log SET undone_at = NOW(), undone_by = ? WHERE id = ?');
        $stmt->bind_param('si', $chi, $idRiga);
        $stmt->execute();
        $stmt->close();

        registra($conn, 'undo', (string) $riga['target_type'], (int) $riga['target_id'],
            (string) $riga['target_label'], null, $prima, 'annullata la decisione #' . $idRiga);
        $messaggio = 'Decisione annullata: ' . implode(', ', $fatto) . '.';
    }
}

// ---------------------------------------------------------------------------
// Filtri: persona e data
// ---------------------------------------------------------------------------
$persona = trim((string) ($_GET['persona'] ?? ''));
$dal = trim((string) ($_GET['dal'] ?? ''));
if ($dal !== '' && !preg_match('/^\d{4}-\d{2}-\d{2}$/', $dal)) {
    $dal = '';
}

// Le persone sono quelle che compaiono davvero nel registro, non un elenco
// scritto a mano: un admin disattivato deve restare filtrabile, perche' le sue
// decisioni ci sono ancora.
$persone = [];
$res = $conn->query('SELECT DISTINCT admin_email FROM na_review_log ORDER BY admin_email');
while ($res && ($p = $res->fetch_row())) {
    $persone[] = (string) $p[0];
}
if ($persona !== '' && !in_array($persona, $persone, true)) {
    $persona = '';
}

$dove = [];
$tipi = '';
$par = [];
if ($persona !== '') {
    $dove[] = 'admin_email = ?';
    $tipi .= 's';
    $par[] = $persona;
}
if ($dal !== '') {
    $dove[] = 'created_at >= ?';
    $tipi .= 's';
    $par[] = $dal . ' 00:00:00';
}
// Ricerca su tutti i campi della riga (15/09): nome, persona, azione, motivo,
// valori scritti, numero dell'oggetto.
$cerca = testoCercato();
if ($cerca !== '') {
    $dove[] = '(target_label LIKE ? OR admin_email LIKE ? OR action LIKE ? OR target_type LIKE ?
                OR note LIKE ? OR after_json LIKE ? OR undone_by LIKE ? OR CAST(target_id AS CHAR) LIKE ?)';
    $tipi .= str_repeat('s', 8);
    array_push($par, ...array_fill(0, 8, comeLike($cerca)));
}
$colonneOrdine = [
    'quando' => ['Quando', 'created_at'],
    'chi' => ['Chi', 'admin_email'],
    'cosa' => ['Cosa', 'action'],
    'su' => ['Su', 'target_label'],
    'tipo' => ['Tipo di oggetto', 'target_type'],
];
[$ordine, $ordinaPer, $verso] = ordinamento($colonneOrdine, 'quando', 'desc');
$sql = 'SELECT * FROM na_review_log' . ($dove ? ' WHERE ' . implode(' AND ', $dove) : '')
    . " ORDER BY $ordine, id DESC LIMIT 200";
$stmt = $conn->prepare($sql);
if ($tipi !== '') {
    $stmt->bind_param($tipi, ...$par);
}
$stmt->execute();
$res = $stmt->get_result();

$azioni = [
    'accept' => 'Accettata', 'reject' => 'Rifiutata', 'approve' => 'Approvato', 'edit' => 'Modificato',
    'undo' => 'Annullamento', 'withdraw' => 'Ritirato', 'resolve' => 'Risolto', 'close' => 'Chiuso', 'reopen' => 'Riaperto',
];
$tipiOggetto = ['food_report' => 'segnalazione', 'custom_food' => 'alimento', 'recipe' => 'ricetta', 'app_report' => 'problema app'];

$righe = '';
while ($r = $res->fetch_assoc()) {
    $annullata = $r['undone_at'] !== null;
    $campi = '—';
    if (in_array($r['action'], ['reject', 'withdraw', 'close'], true) && !empty($r['note'])) {
        $campi = (string) $r['note'];
    } elseif (!empty($r['after_json']) && $r['action'] !== 'undo') {
        $dopo = json_decode((string) $r['after_json'], true);
        if (is_array($dopo) && !array_key_exists('shared_status', $dopo)) {
            $campi = implode(', ', array_keys($dopo));
        }
    }

    $azione = '';
    if ($annullata) {
        $azione = '<span class="nota-annullata">annullata il ' . e(date('d/m H:i', strtotime((string) $r['undone_at'])))
            . ' da ' . e((string) $r['undone_by']) . '</span>';
    } elseif ($r['action'] !== 'undo') {
        $azione = '<form method="post" style="margin:0">' . campoToken()
            . '<input type="hidden" name="id" value="' . (int) $r['id'] . '">'
            . '<button class="piccolo" type="submit">Annulla</button></form>';
    }

    $righe .= '<div class="riga">'
        . '<span class="quando cifre' . ($annullata ? ' barrato' : '') . '">' . e(date('d/m H:i', strtotime((string) $r['created_at']))) . '</span>'
        . '<span class="chi-decide taglia' . ($annullata ? ' barrato' : '') . '">' . e(nomeAdmin($conn, (string) $r['admin_email'])) . '</span>'
        . '<span class="cosa ' . e((string) $r['action']) . ($annullata ? ' barrato' : '') . '">' . e($azioni[$r['action']] ?? (string) $r['action']) . '</span>'
        . '<div class="' . ($annullata ? 'barrato' : '') . '" style="min-width:0">'
        . '<div class="su-nome taglia">' . e((string) ($r['target_label'] ?: '#' . $r['target_id'])) . '</div>'
        . '<div class="su-tipo">' . e($tipiOggetto[$r['target_type']] ?? (string) $r['target_type']) . '</div></div>'
        . '<span class="campi taglia' . ($annullata ? ' barrato' : '') . '">' . e($campi) . '</span>'
        . '<div class="destra">' . $azione . '</div>'
        . '</div>';
}
$stmt->close();

$opzioniPersone = '<option value="">Tutti</option>';
foreach ($persone as $p) {
    $opzioniPersone .= '<option value="' . e($p) . '"' . ($p === $persona ? ' selected' : '') . '>' . e($p) . '</option>';
}

$filtri = '<form class="filtri" method="get">'
    . campoCerca($cerca, 'nome, persona, azione, motivo o valore')
    . '<label><span>Persona</span><select name="persona" style="min-width:200px">' . $opzioniPersone . '</select></label>'
    . '<label><span>Dal</span><input type="date" name="dal" value="' . e($dal) . '"></label>'
    . sceltaOrdinamento($colonneOrdine, $ordinaPer, $verso)
    . '<button class="principale" type="submit">Filtra</button>'
    . (($persona !== '' || $dal !== '' || $cerca !== '') ? '<a class="bottone" href="registro.php" style="padding:9px 14px;font-size:12.5px">Azzera filtri</a>' : '')
    . '</form>';

$html = ($messaggio !== null ? '<div class="' . $tipoMessaggio . '">' . e($messaggio) . '</div>' : '')
    . $filtri
    . '<div class="riquadro registro">'
    . testaOrdinabile([
        ['Quando', 'quando'], ['Chi', 'chi'], ['Cosa', 'cosa'], ['Su', 'su'], ['Campi o motivo', null], ['Azione', null, 'destra'],
    ], $ordinaPer, $verso)
    . ($righe === '' ? '<div class="vuoto">Nessuna voce con questi filtri</div>' : $righe)
    . '</div>';

pagina('Registro delle decisioni', $html, 'registro.php');
