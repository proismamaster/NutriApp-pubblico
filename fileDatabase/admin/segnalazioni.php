<?php
/**
 * segnalazioni.php — la coda delle segnalazioni sui dati.
 *
 * Ricalcato sulla schermata 3B dei mockup: tre filtri e il pulsante Filtra,
 * poi una riga per segnalazione con due pastiglie di prova — verde "N campi
 * proposti", ambra "N foto" — o la scritta spenta "solo segnalata" quando non
 * c'e' niente da verificare. Quelle righe si devono riconoscere a colpo
 * d'occhio: sono le sole che si possono solo prendere in parola.
 */

declare(strict_types=1);
require __DIR__ . '/_comune.php';
richiediAccesso();

$stato = (string) ($_GET['stato'] ?? 'pending');
$tipo = (string) ($_GET['tipo'] ?? '');
$soloProve = ($_GET['prove'] ?? '') === '1';

if (!in_array($stato, ['pending', 'accepted', 'rejected', 'tutti'], true)) {
    $stato = 'pending';
}
$tipiValidi = [
    'valori' => 'valori nutrizionali',
    'nome' => 'nome o marca',
    'categoria' => 'categoria',
    'immagine' => 'foto',
    'duplicato' => 'doppione',
    'altro' => 'altro',
];
if ($tipo !== '' && !isset($tipiValidi[$tipo])) {
    $tipo = '';
}

$dove = [];
$tipi = '';
$par = [];
if ($stato !== 'tutti') {
    $dove[] = 'r.status = ?';
    $tipi .= 's';
    $par[] = $stato;
}
if ($tipo !== '') {
    $dove[] = 'r.issue = ?';
    $tipi .= 's';
    $par[] = $tipo;
}
// Ricerca libera su tutti i campi (14/09, allargata il 15/09): alimento,
// codice, problema, campo e valore proposti, nota, fonte, persona, numero.
$cerca = testoCercato();
if ($cerca !== '') {
    $campiCerca = [
        'r.food_name', 'r.barcode', 'r.issue', 'r.field_name', 'r.suggested_value', 'r.note', 'r.source',
        'r.review_note', 'u.email', 'u.first_name', 'u.last_name', 'CAST(r.id AS CHAR)',
    ];
    $dove[] = '(' . implode(' LIKE ? OR ', $campiCerca) . ' LIKE ?)';
    $tipi .= str_repeat('s', count($campiCerca));
    array_push($par, ...array_fill(0, count($campiCerca), comeLike($cerca)));
}
$clausola = $dove === [] ? '' : ' WHERE ' . implode(' AND ', $dove);

$colonneOrdine = [
    'attesa' => ['In attesa da', 'r.created_at'],
    'alimento' => ['Alimento', 'r.food_name'],
    'problema' => ['Problema', 'r.issue'],
    'da' => ['Da', 'u.first_name'],
    'stato' => ['Stato', 'r.status'],
];
[$ordine, $ordinaPer, $verso] = ordinamento($colonneOrdine, 'attesa');

$sql = "SELECT r.id, r.food_name, r.barcode, r.issue, r.kind, r.status, r.created_at,
               r.proposed_json, u.first_name,
               (SELECT COUNT(*) FROM na_report_photos p WHERE p.report_id = r.id) AS n_foto
          FROM na_food_reports r
          LEFT JOIN na_users u ON u.email = r.user_mail
          $clausola
          ORDER BY $ordine, r.id
          LIMIT 300";
$stmt = $conn->prepare($sql);
if ($tipi !== '') {
    $stmt->bind_param($tipi, ...$par);
}
$stmt->execute();
$res = $stmt->get_result();

$righe = '';
$quante = 0;
while ($r = $res->fetch_assoc()) {
    $nCampi = 0;
    if (!empty($r['proposed_json'])) {
        $decodificato = json_decode((string) $r['proposed_json'], true);
        $nCampi = is_array($decodificato) ? count($decodificato) : 0;
    }
    $nFoto = (int) $r['n_foto'];
    // Il filtro "con prove" si applica qui e non in SQL: dipende dal contenuto
    // del JSON, che il database non sa contare.
    if ($soloProve && $nCampi === 0 && $nFoto === 0) {
        continue;
    }
    $quante++;

    $prove = '';
    if ($nCampi > 0) {
        $prove .= '<span class="pastiglia ok">' . $nCampi . ($nCampi === 1 ? ' campo proposto' : ' campi proposti') . '</span>';
    }
    if ($nFoto > 0) {
        $prove .= '<span class="pastiglia attesa">' . $nFoto . ' foto</span>';
    }
    if ($prove === '') {
        $prove = '<span class="spento" style="font-size:12px">solo segnalata</span>';
    }

    $problema = $tipiValidi[$r['issue']] ?? (string) $r['issue'];
    if ($r['kind'] === 'nuovo') {
        $problema .= ' · alimento nuovo';
    }

    $righe .= '<div class="riga">'
        . '<div class="taglia"><a class="nome-link" href="segnalazione.php?id=' . (int) $r['id'] . '">'
        . e($r['food_name'] ?: '(senza nome)') . '</a>'
        . ($r['barcode'] ? '<div class="codice">' . e($r['barcode']) . '</div>' : '') . '</div>'
        . '<span class="secondario" style="font-size:12.5px">' . e($problema) . '</span>'
        . '<div class="prove">' . $prove . '</div>'
        . '<span style="font-size:12.5px">' . e($r['first_name'] ?: 'Anonimo') . '</span>'
        . '<span class="secondario ' . classeAttesa($r['created_at']) . '" style="font-size:12.5px">' . e(attesa($r['created_at'])) . '</span>'
        . pastiglia((string) $r['status'])
        . '</div>';
}
$stmt->close();

$opzioni = static function (array $valori, string $scelto): string {
    $out = '';
    foreach ($valori as $valore => $etichetta) {
        $sel = ((string) $valore === $scelto) ? ' selected' : '';
        $out .= '<option value="' . e((string) $valore) . '"' . $sel . '>' . e($etichetta) . '</option>';
    }
    return $out;
};

$filtri = '<form class="filtri" method="get">'
    . campoCerca($cerca, 'qualsiasi campo: alimento, codice, valore, nota, persona')
    . '<label><span>Stato</span><select name="stato">'
    . $opzioni(['tutti' => 'Tutte', 'pending' => 'Aperte', 'accepted' => 'Accettate', 'rejected' => 'Rifiutate'], $stato)
    . '</select></label>'
    . '<label><span>Problema</span><select name="tipo" style="min-width:170px">'
    . $opzioni(['' => 'Tutti i problemi', 'valori' => 'Valori nutrizionali', 'nome' => 'Nome o marca',
        'categoria' => 'Categoria', 'immagine' => 'Foto', 'duplicato' => 'Doppione', 'altro' => 'Altro'], $tipo)
    . '</select></label>'
    . '<label><span>Con prove</span><select name="prove" style="min-width:200px">'
    . $opzioni(['' => 'Tutte', '1' => 'Solo con foto o proposta'], $soloProve ? '1' : '')
    . '</select></label>'
    . sceltaOrdinamento($colonneOrdine, $ordinaPer, $verso)
    . '<button class="principale" type="submit">Filtra</button>'
    . '</form>';

$tabella = '<div class="riquadro coda">'
    . testaOrdinabile([
        ['Alimento', 'alimento'], ['Problema', 'problema'], ['Prove', null], ['Da', 'da'], ['In attesa da', 'attesa'], ['Stato', 'stato'],
    ], $ordinaPer, $verso)
    . ($righe === '' ? '<div class="vuoto">Nessuna segnalazione con questi filtri</div>' : $righe)
    . '</div>';

pagina('Segnalazioni', $filtri . $tabella, 'segnalazioni.php');
