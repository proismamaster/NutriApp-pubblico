<?php
/**
 * ricette.php — le ricette proposte per la sezione "Consigliate" dell'app.
 *
 * Ricalcato sulla schermata 5B dei mockup: stessa griglia degli alimenti, ma la
 * scheda porta le note dell'autore e la tabella degli ingredienti con pesi ed
 * energia — e' da li' che si giudica una ricetta, non dal nome.
 *
 * Il server rifiuta gia' di proporre una ricetta senza ingredienti
 * (share_recipe.php), quindi qui non dovrebbero arrivarne di vuote — se ne
 * compare una, qualcosa ha scritto nel database senza passare dall'endpoint.
 *
 * 15/09: categorie a lista chiusa (pasti, portata, dieta) che l'autore sceglie
 * proponendo e che qui si correggono prima di pubblicare: "Per te" nell'app
 * sceglie in base al pasto, quindi una ricetta senza pasto non comparirebbe
 * mai fra quelle del momento. Ricetta approvata = del database; qualsiasi admin
 * la ritira. Ricerca su tutti i campi, ingredienti compresi, e ordinamento.
 */

declare(strict_types=1);
require __DIR__ . '/_comune.php';
richiediAccesso();

const PASTI = ['colazione' => 'Colazione', 'pranzo' => 'Pranzo', 'cena' => 'Cena', 'spuntino' => 'Spuntino'];
const PORTATE = [
    'primo' => 'Primo', 'secondo' => 'Secondo', 'piatto_unico' => 'Piatto unico', 'contorno' => 'Contorno',
    'dolce' => 'Dolce', 'bevanda' => 'Bevanda', 'altro' => 'Altro',
];
const DIETE = ['vegetariana' => 'Vegetariana', 'vegana' => 'Vegana', 'senza_glutine' => 'Senza glutine'];

$haCategorie = colonnaEsiste($conn, 'na_recipes', 'meal_types');
$haLike = colonnaEsiste($conn, 'na_recipe_likes', 'recipe_id');

$messaggio = null;
$tipoMessaggio = 'esito';

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    richiediToken();
    $id = (int) ($_POST['id'] ?? 0);
    $azione = (string) ($_POST['azione'] ?? '');
    $nota = trim((string) ($_POST['nota'] ?? ''));

    $stmt = $conn->prepare(
        'SELECT recipe_name, shared_status' . ($haCategorie ? ', meal_types, course, diet_tags' : '') . ' FROM na_recipes WHERE id = ? LIMIT 1'
    );
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $riga = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$riga) {
        $messaggio = 'Ricetta non trovata.';
        $tipoMessaggio = 'avviso';
    } elseif ($azione === 'approva') {
        // Le categorie del modulo vincono su quelle dell'autore; valori fuori
        // lista si scartano.
        $pasti = array_values(array_intersect(array_map('strval', (array) ($_POST['pasti'] ?? [])), array_keys(PASTI)));
        $portata = (string) ($_POST['portata'] ?? '');
        $diete = array_values(array_intersect(array_map('strval', (array) ($_POST['diete'] ?? [])), array_keys(DIETE)));

        if ($haCategorie && ($pasti === [] || !isset(PORTATE[$portata]))) {
            $messaggio = 'Scegli almeno un pasto e la portata prima di pubblicare: "Per te" consiglia in base al pasto.';
            $tipoMessaggio = 'avviso';
        } else {
            $chi = adminCorrente()['email'];
            if ($haCategorie) {
                $pastiTesto = implode(',', $pasti);
                $dieteTesto = $diete === [] ? null : implode(',', $diete);
                $stmt = $conn->prepare(
                    'UPDATE na_recipes
                        SET shared_status = "approved", reviewed_at = NOW(), reviewed_by = ?, review_note = NULL,
                            meal_types = ?, course = ?, diet_tags = ?
                      WHERE id = ?'
                );
                $stmt->bind_param('ssssi', $chi, $pastiTesto, $portata, $dieteTesto, $id);
            } else {
                $stmt = $conn->prepare(
                    'UPDATE na_recipes
                        SET shared_status = "approved", reviewed_at = NOW(), reviewed_by = ?, review_note = NULL
                      WHERE id = ?'
                );
                $stmt->bind_param('si', $chi, $id);
            }
            $stmt->execute();
            $stmt->close();
            $dopo = ['shared_status' => 'approved'];
            if ($haCategorie) {
                $dopo += ['meal_types' => $pastiTesto, 'course' => $portata, 'diet_tags' => $dieteTesto];
            }
            registra($conn, 'approve', 'recipe', $id, (string) $riga['recipe_name'],
                ['shared_status' => $riga['shared_status']], $dopo);
            $messaggio = 'Ricetta pubblicata in Consigliate: ' . $riga['recipe_name'];
        }
    } elseif ($azione === 'rifiuta') {
        if ($nota === '') {
            $messaggio = 'Scrivi una motivazione: la vedrà chi ha proposto la ricetta.';
            $tipoMessaggio = 'avviso';
        } else {
            $chi = adminCorrente()['email'];
            $stmt = $conn->prepare(
                'UPDATE na_recipes
                    SET shared_status = "rejected", reviewed_at = NOW(), reviewed_by = ?, review_note = ?
                  WHERE id = ?'
            );
            $stmt->bind_param('ssi', $chi, $nota, $id);
            $stmt->execute();
            $stmt->close();
            registra($conn, 'reject', 'recipe', $id, (string) $riga['recipe_name'],
                ['shared_status' => $riga['shared_status']], ['shared_status' => 'rejected'], $nota);
            $messaggio = 'Ricetta rifiutata: ' . $riga['recipe_name'];
        }
    } elseif ($azione === 'ritira') {
        [$messaggio, $tipoMessaggio] = ritiraPubblicazione($conn, 'recipe', $id, $nota);
    }
}

$stato = (string) ($_GET['stato'] ?? 'pending');
if (!in_array($stato, ['pending', 'approved', 'rejected'], true)) {
    $stato = 'pending';
}
$haRimozione = colonnaEsiste($conn, 'na_recipes', 'author_removed_at');

$revisori = [];
$res = $conn->query("SELECT DISTINCT reviewed_by FROM na_recipes WHERE reviewed_by IS NOT NULL AND reviewed_by <> '' ORDER BY reviewed_by");
while ($res && ($r = $res->fetch_row())) {
    $revisori[] = (string) $r[0];
}
$revisore = (string) ($_GET['revisore'] ?? '');
if ($revisore !== '' && !in_array($revisore, $revisori, true)) {
    $revisore = '';
}

// Ricerca su tutti i campi (14/09, allargata il 15/09), ingredienti compresi.
$cerca = testoCercato();
$campiCerca = ['r.recipe_name', 'r.notes', 'r.review_note', 'r.reviewed_by', 'u.email', 'u.first_name', 'u.last_name', 'CAST(r.id AS CHAR)'];
if ($haCategorie) {
    array_push($campiCerca, 'r.meal_types', 'r.course', 'r.diet_tags');
}

$colonneOrdine = [
    'data' => ['Proposta il', 'r.shared_at'],
    'nome' => ['Nome', 'r.recipe_name'],
    'autore' => ['Autore', 'u.first_name'],
    'revisione' => ['Decisa il', 'r.reviewed_at'],
];
if ($haCategorie) {
    $colonneOrdine['portata'] = ['Portata', 'r.course'];
}
if ($haLike) {
    $colonneOrdine['like'] = ['Like', 'n_like'];
}
[$ordine, $ordinaPer, $verso] = ordinamento($colonneOrdine, 'data');

$dove = ['r.shared_status = ?'];
$tipi = 's';
$par = [$stato];
if ($revisore !== '') {
    $dove[] = 'r.reviewed_by = ?';
    $tipi .= 's';
    $par[] = $revisore;
}
if ($cerca !== '') {
    $dove[] = '(' . implode(' LIKE ? OR ', $campiCerca) . ' LIKE ?'
        . ' OR EXISTS (SELECT 1 FROM na_recipe_ingredients i WHERE i.recipe_id = r.id AND i.food_name LIKE ?))';
    $tipi .= str_repeat('s', count($campiCerca) + 1);
    array_push($par, ...array_fill(0, count($campiCerca) + 1, comeLike($cerca)));
}

$sql = 'SELECT r.id, r.recipe_name, r.`portion`, r.notes, r.image_url, r.shared_at,
               r.shared_status, r.reviewed_by, r.reviewed_at, r.review_note, u.first_name'
    . ($haCategorie ? ', r.meal_types, r.course, r.diet_tags' : ', NULL AS meal_types, NULL AS course, NULL AS diet_tags')
    . ($haRimozione ? ', r.author_removed_at' : ', NULL AS author_removed_at')
    . ($haLike ? ', (SELECT COUNT(*) FROM na_recipe_likes l WHERE l.recipe_id = r.id) AS n_like' : ', 0 AS n_like') . '
          FROM na_recipes r
          LEFT JOIN na_users u ON u.email = r.user_mail
         WHERE ' . implode(' AND ', $dove) . "
         ORDER BY $ordine, r.id
         LIMIT 100";
$stmt = $conn->prepare($sql);
$stmt->bind_param($tipi, ...$par);
$stmt->execute();
$res = $stmt->get_result();

$ricette = [];
$ids = [];
while ($r = $res->fetch_assoc()) {
    $r['ingredienti'] = [];
    $ricette[(int) $r['id']] = $r;
    $ids[] = (int) $r['id'];
}
$stmt->close();

// Gli ingredienti in una query sola: con cento ricette, una query ciascuna
// sarebbero centouno interrogazioni per disegnare una pagina.
if ($ids !== []) {
    $segnaposto = implode(',', array_fill(0, count($ids), '?'));
    $stmt = $conn->prepare(
        "SELECT recipe_id, food_name, weight_g, calories
           FROM na_recipe_ingredients WHERE recipe_id IN ($segnaposto) ORDER BY id"
    );
    $stmt->bind_param(str_repeat('i', count($ids)), ...$ids);
    $stmt->execute();
    $ing = $stmt->get_result();
    while ($r = $ing->fetch_assoc()) {
        $ricette[(int) $r['recipe_id']]['ingredienti'][] = $r;
    }
    $stmt->close();
}

/** Le caselle delle categorie, gia' spuntate con quelle scelte dall'autore. */
function sceltaCategorie(array $r): string
{
    $pastiScelti = array_filter(explode(',', (string) $r['meal_types']));
    $dieteScelte = array_filter(explode(',', (string) $r['diet_tags']));
    $html = '<fieldset class="scegli-categorie"><legend>Categorie</legend><div class="opzioni">';
    foreach (PASTI as $v => $et) {
        $html .= '<label><input type="checkbox" name="pasti[]" value="' . $v . '"' . (in_array($v, $pastiScelti, true) ? ' checked' : '') . '>' . $et . '</label>';
    }
    $html .= '</div><select name="portata"><option value="">Portata…</option>';
    foreach (PORTATE as $v => $et) {
        $html .= '<option value="' . $v . '"' . ($v === (string) $r['course'] ? ' selected' : '') . '>' . $et . '</option>';
    }
    $html .= '</select><div class="opzioni">';
    foreach (DIETE as $v => $et) {
        $html .= '<label><input type="checkbox" name="diete[]" value="' . $v . '"' . (in_array($v, $dieteScelte, true) ? ' checked' : '') . '>' . $et . '</label>';
    }
    return $html . '</div></fieldset>';
}

/** Le categorie come pastiglie, per le ricette gia' decise. */
function pastiglieCategorie(array $r): string
{
    $pezzi = [];
    foreach (array_filter(explode(',', (string) $r['meal_types'])) as $p) {
        $pezzi[] = '<span class="pastiglia neutro">' . e(PASTI[$p] ?? $p) . '</span>';
    }
    if (!empty($r['course'])) {
        $pezzi[] = '<span class="pastiglia ok">' . e(PORTATE[$r['course']] ?? (string) $r['course']) . '</span>';
    }
    foreach (array_filter(explode(',', (string) $r['diet_tags'])) as $d) {
        $pezzi[] = '<span class="pastiglia attesa">' . e(DIETE[$d] ?? $d) . '</span>';
    }
    return $pezzi === [] ? '' : '<div class="categorie-ricetta">' . implode('', $pezzi) . '</div>';
}

$schede = '';
foreach ($ricette as $r) {
    $kcal = 0.0;
    $peso = 0.0;
    $righeIng = '';
    foreach ($r['ingredienti'] as $i) {
        $kcal += (float) $i['calories'];
        $peso += (float) $i['weight_g'];
        $righeIng .= '<div class="voce"><span class="taglia">' . e((string) $i['food_name']) . '</span>'
            . '<span>' . num($i['weight_g']) . ' g</span><span>' . num($i['calories']) . ' kcal</span></div>';
    }
    if ($righeIng === '') {
        $righeIng = '<div class="voce spento"><span>Nessun ingrediente: non doveva arrivare qui.</span></div>';
    }
    $foto = trim((string) ($r['image_url'] ?? ''));

    $schede .= '<div class="scheda-voce" id="r' . (int) $r['id'] . '">'
        . ($foto !== ''
            ? '<div class="immagine"><img src="' . e($foto) . '" alt="" loading="lazy"></div>'
            : '<div class="immagine vuota"><svg width="28" height="28" viewBox="0 0 24 24" fill="none"><rect x="3" y="5" width="18" height="14" rx="2" stroke="#7D857A" stroke-width="1.6"/><circle cx="9" cy="10.5" r="1.6" fill="#7D857A"/><path d="M4 16l5-4 4 3 3-2.5 4 3.5" stroke="#7D857A" stroke-width="1.6" stroke-linejoin="round"/></svg>nessuna foto</div>')
        . '<div class="corpo">'
        . '<div><div class="nome">' . e((string) $r['recipe_name']) . '</div>'
        . '<div class="sotto">Porzioni: ' . e((string) $r['portion']) . ' · ' . num($peso) . ' g in tutto · ' . num($kcal) . ' kcal'
        . ($haLike ? ' · ' . (int) $r['n_like'] . ' like' : '') . '</div></div>'
        . ($stato !== 'pending' ? pastiglieCategorie($r) : '')
        . (!empty($r['notes']) ? '<div class="nota-ricetta">' . nl2br(e((string) $r['notes'])) . '</div>' : '')
        . '<div class="striscia ingredienti"><div class="intestazione"><span>Ingrediente</span><span style="text-align:right">Peso</span><span style="text-align:right">Energia</span></div>'
        . $righeIng . '</div>'
        . '<div class="chi-propone">Proposta da ' . e((string) ($r['first_name'] ?: 'Anonimo'))
        . ' · ' . e(attesa((string) $r['shared_at'])) . '</div>';

    if ($stato === 'pending') {
        $schede .= '<form method="post" class="decidi">' . campoToken()
            . '<input type="hidden" name="id" value="' . (int) $r['id'] . '">'
            . ($haCategorie ? sceltaCategorie($r) : '')
            . '<input type="text" name="nota" maxlength="255" placeholder="Motivazione (solo per il rifiuto)">'
            . '<div class="bottoni" style="margin-top:8px">'
            . '<button class="principale" name="azione" value="approva">Approva</button>'
            . '<button class="rischio" name="azione" value="rifiuta">Rifiuta</button></div>'
            . '</form>';
    } elseif ($stato === 'approved') {
        $schede .= '<div class="pubblicato-da">Pubblicata da ' . e(nomeAdmin($conn, $r['reviewed_by']))
            . ($r['reviewed_at'] ? ' il ' . e(date('d/m/Y', strtotime((string) $r['reviewed_at']))) : '')
            . ($r['author_removed_at'] ? ' · <span class="pastiglia neutro">tolta dall\'autore</span>' : '') . '</div>'
            . '<form method="post" class="ritira">' . campoToken()
            . '<input type="hidden" name="id" value="' . (int) $r['id'] . '">'
            . '<input type="text" name="nota" maxlength="255" placeholder="Motivo del ritiro" required>'
            . '<button class="piccolo rischio" name="azione" value="ritira">Ritira</button></form>';
    } else {
        $schede .= '<div class="deciso no">Rifiutata da ' . e(nomeAdmin($conn, $r['reviewed_by']))
            . ($r['review_note'] ? ': ' . e((string) $r['review_note']) : '') . '</div>';
    }
    $schede .= '</div></div>';
}

$selettore = '<div class="schede">';
foreach (['pending' => 'In attesa', 'approved' => 'Pubbliche', 'rejected' => 'Rifiutate'] as $v => $et) {
    $selettore .= '<a href="' . e(conParametri(['stato' => $v])) . '"'
        . ($stato === $v ? ' class="attiva"' : '') . '>' . e($et) . '</a>';
}
$selettore .= '</div>';

$opzioniRevisori = '<option value="">Tutti</option>';
foreach ($revisori as $rev) {
    $opzioniRevisori .= '<option value="' . e($rev) . '"' . ($rev === $revisore ? ' selected' : '') . '>' . e(nomeAdmin($conn, $rev)) . '</option>';
}

$ricerca = '<form class="filtri" method="get" style="margin-top:14px">'
    . '<input type="hidden" name="stato" value="' . e($stato) . '">'
    . campoCerca($cerca, 'qualsiasi campo: nome, note, ingrediente, categoria, persona')
    . '<label><span>Decisa da</span><select name="revisore">' . $opzioniRevisori . '</select></label>'
    . sceltaOrdinamento($colonneOrdine, $ordinaPer, $verso)
    . '<button class="principale" type="submit">Cerca</button></form>';

$html = ($messaggio !== null ? '<div class="' . $tipoMessaggio . '">' . e($messaggio) . '</div>' : '')
    . $selettore
    . $ricerca
    . ($schede === ''
        ? '<div class="vuoto">Nessuna ricetta in questo stato</div>'
        : '<div class="griglia-schede">' . $schede . '</div>')
    . scriptRifiutoConMotivazione();

pagina('Ricette proposte', $html, 'ricette.php');
