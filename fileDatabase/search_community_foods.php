<?php
/**
 * search_community_foods.php — gli alimenti approvati nella ricerca di tutti
 * (2026-09-14).
 *
 * PERCHE' ESISTE: fino al 13/09 approvare un alimento nel pannello cambiava
 * solo uno stato. Nessun endpoint lo restituiva agli altri utenti, quindi
 * l'approvazione non si vedeva da nessuna parte. "Quando l'admin approva un
 * alimento, questo deve essere visualizzato" (Ismail, 14/09).
 *
 * Restituisce SOLO gli alimenti con `shared_status = 'approved'`, di
 * qualunque utente, e SOLO colonne di contenuto: niente `user_mail`, niente
 * tracce della revisione. Chi cerca vede l'alimento, non chi l'ha creato.
 * L'alimento resta nella libreria del suo autore, che puo' continuare a
 * modificarlo; l'admin lo puo' correggere da admin/alimento.php.
 *
 * Stessa ricerca di search_crea_foods.php: prima tutte le parole (AND), e se
 * non trova niente basta una parola (OR).
 *
 * Senza la migrazione 2026-09-12_collaborazione_community risponde con zero
 * risultati invece di un errore: la ricerca dell'app ha altre fonti, e una
 * fonte vuota non deve farla sembrare rotta.
 */

declare(strict_types=1);

require 'db_config.php';
header('Content-Type: application/json; charset=utf-8');

function rispondiAlimenti(array $alimenti, ?string $nota = null): void
{
    $corpo = ['status' => 'success', 'foods' => $alimenti];
    if ($nota !== null) {
        $corpo['message'] = $nota;
    }
    echo json_encode($corpo, JSON_UNESCAPED_UNICODE);
    exit;
}

$query = trim((string) ($_GET['query'] ?? ''));
if (mb_strlen($query) < 2) {
    rispondiAlimenti([]);
}

$esistenti = [];
$res = $conn->query('SHOW COLUMNS FROM na_custom_foods');
while ($res && ($r = $res->fetch_assoc())) {
    $esistenti[$r['Field']] = true;
}
if (!isset($esistenti['shared_status'])) {
    rispondiAlimenti([], 'migrazione 2026-09-12_collaborazione_community mancante');
}

// Lista chiusa di colonne, incrociata con quelle che esistono davvero: una
// colonna aggiunta domani a na_custom_foods non esce da qui finche' qualcuno
// non decide che deve uscire.
$volute = [
    'id', 'food_name', 'brand', 'barcode', 'image_url', 'base_weight_g',
    'calories', 'proteins', 'carbs', 'fats', 'water', 'fibers', 'sugars',
    'saturated_fats', 'monounsaturated_fats', 'polyunsaturated_fats', 'trans_fats',
    'cholesterol', 'sodium',
    'vit_a', 'vit_b1', 'vit_b2', 'vit_b3', 'vit_b5', 'vit_b6', 'vit_b7', 'vit_b9',
    'vit_b11', 'vit_b12', 'vit_c', 'vit_d', 'vit_e', 'vit_k',
    'biotin', 'boron', 'calcium', 'chloride', 'choline', 'chromium', 'cobalt',
    'copper', 'fluoride', 'iodine', 'iron', 'magnesium', 'manganese', 'molybdenum',
    'phosphorus', 'potassium', 'selenium', 'silicon', 'sulfur', 'tin', 'vanadium', 'zinc',
    'nutriscore_grade', 'nova_group', 'allergens', 'labels', 'serving_size',
    'categories', 'ingredients', 'quantity',
];
$colonne = array_values(array_filter($volute, static fn($c) => isset($esistenti[$c])));
$lista = implode(', ', array_map(static fn($c) => '`' . $c . '`', $colonne));

$parole = array_values(array_filter(
    preg_split('/\s+/u', $query) ?: [],
    static fn($p) => mb_strlen($p) > 2
));
if ($parole === []) {
    $parole = [$query];
}

function cercaComunita(mysqli $conn, string $lista, array $parole, string $query, string $modo): array
{
    $condizioni = [];
    $tipi = '';
    $valori = [];
    foreach ($parole as $parola) {
        $condizioni[] = 'food_name LIKE ?';
        $tipi .= 's';
        $valori[] = '%' . $parola . '%';
    }
    $colla = $modo === 'OR' ? ' OR ' : ' AND ';
    $sql = "SELECT $lista FROM na_custom_foods
             WHERE shared_status = 'approved' AND (" . implode($colla, $condizioni) . ")
             ORDER BY (food_name = ?) DESC, (food_name LIKE ?) DESC, LENGTH(food_name) ASC
             LIMIT 100";
    $tipi .= 'ss';
    $valori[] = $query;
    $valori[] = $query . '%';

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return [];
    }
    $stmt->bind_param($tipi, ...$valori);
    $stmt->execute();
    $res = $stmt->get_result();
    $trovati = [];
    while ($riga = $res->fetch_assoc()) {
        $trovati[] = $riga;
    }
    $stmt->close();
    return $trovati;
}

$alimenti = cercaComunita($conn, $lista, $parole, $query, 'AND');
if ($alimenti === []) {
    $alimenti = cercaComunita($conn, $lista, $parole, $query, 'OR');
}
rispondiAlimenti($alimenti);
