<?php
/**
 * get_product_by_barcode.php — il prodotto dietro un codice a barre.
 *
 * ORDINE DELLE FONTI
 *  1. la libreria personale di CHI CHIEDE (`na_custom_foods`, filtrata per
 *     email): e' il suo prodotto, corretto da lui, e vince su tutto;
 *  2. `na_off_products`, l'archivio OpenFoodFacts gia' importato qui dentro:
 *     e' la stessa fonte che usa la ricerca per nome, ed e' immediata;
 *  3. OpenFoodFacts dal vivo, per i codici che qui non ci sono ancora.
 *
 * TRE COSE SISTEMATE DOPO IL TEST DI RELEASE DEL 19/09
 *  - la libreria veniva cercata SENZA filtro sull'utente: il codice a barre di
 *    un alimento privato di un altro utente restituiva il suo alimento, nome
 *    compreso. Ora serve `user_mail`, e senza quel parametro la libreria non
 *    si guarda affatto;
 *  - `na_off_products` non veniva mai interrogata: si usciva su internet anche
 *    per prodotti gia' presenti qui;
 *  - il ramo OpenFoodFacts non restituiva ne' `barcode` ne' marca, foto,
 *    porzione e quantita': il prodotto scansionato arrivava all'app senza
 *    codice, e chi lo segnalava mandava una segnalazione che il pannello non
 *    poteva applicare. Inoltre i micronutrienti di OFF sono in GRAMMI per
 *    100 g, mentre l'app li vuole in mg (e in µg per alcune vitamine): senza
 *    conversione sodio, calcio, ferro e vitamine arrivavano mille o un milione
 *    di volte piu' bassi. Il commento diceva "* 1000", il codice non lo faceva.
 */

declare(strict_types=1);
require 'db_config.php';
require_once 'auth.php';

header('Content-Type: application/json; charset=utf-8');

$barcode = trim((string) ($_GET['barcode'] ?? ''));
// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$userMail = emailAutenticata($conn, trim((string) ($_GET['user_mail'] ?? '')));

if ($barcode === '') {
    echo json_encode(['status' => 'error', 'message' => 'Nessun codice a barre fornito.', 'code' => 'missing_barcode']);
    exit;
}

/** Tutte le colonne numeriche di una riga, piu' i campi testuali indicati. */
function rigaProdotto(array $riga, array $testuali, string $fonte): array
{
    $fuori = [];
    foreach ($riga as $colonna => $valore) {
        if (in_array($colonna, ['id', 'user_mail', 'created_at', 'updated_at', 'fetched_at', 'last_update'], true)) {
            continue;
        }
        if (in_array($colonna, $testuali, true)) {
            $fuori[$colonna] = $valore === null ? '' : (string) $valore;
        } else {
            $fuori[$colonna] = $valore === null ? 0.0 : (float) $valore;
        }
    }
    $fuori['source'] = $fonte;
    return $fuori;
}

const TESTUALI = [
    'barcode', 'food_name', 'brand', 'categories', 'image_url', 'image_nutrition_url',
    'image_ingredients_url', 'nutriscore_grade', 'allergens', 'traces', 'labels',
    'serving_size', 'manufacturing_places', 'ingredients', 'quantity', 'packaging',
    'environmental_score_grade', 'pnns_group', 'stores', 'data_source', 'source_ref',
];

// ---------------------------------------------------------------------------
// 1. La libreria personale di chi chiede
// ---------------------------------------------------------------------------
if ($userMail !== '') {
    $stmt = $conn->prepare('SELECT * FROM na_custom_foods WHERE barcode = ? AND user_mail = ? LIMIT 1');
    $stmt->bind_param('ss', $barcode, $userMail);
    $stmt->execute();
    $riga = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if ($riga) {
        echo json_encode(['status' => 'success', 'product' => rigaProdotto($riga, TESTUALI, 'custom')]);
        exit;
    }
}

// ---------------------------------------------------------------------------
// 2. L'archivio OpenFoodFacts gia' importato
// ---------------------------------------------------------------------------
$stmt = $conn->prepare('SELECT * FROM na_off_products WHERE barcode = ? LIMIT 1');
$stmt->bind_param('s', $barcode);
$stmt->execute();
$riga = $stmt->get_result()->fetch_assoc();
$stmt->close();
if ($riga) {
    $prodotto = rigaProdotto($riga, TESTUALI, 'off_local_it');
    $prodotto['base_weight_g'] = 100.0;
    echo json_encode(['status' => 'success', 'product' => $prodotto]);
    exit;
}

// ---------------------------------------------------------------------------
// 3. OpenFoodFacts dal vivo
// ---------------------------------------------------------------------------
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, 'https://world.openfoodfacts.org/api/v2/product/' . urlencode($barcode) . '.json');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 8);
curl_setopt($ch, CURLOPT_USERAGENT, 'NutriApp - server - 1.2');
$risposta = curl_exec($ch);
$codiceHttp = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($codiceHttp !== 200 || !$risposta) {
    echo json_encode(['status' => 'error', 'message' => 'Prodotto non trovato o errore di connessione.', 'code' => 'not_found']);
    exit;
}

$dati = json_decode((string) $risposta, true);
if (!isset($dati['product'])) {
    echo json_encode(['status' => 'error', 'message' => 'Prodotto non trovato.', 'code' => 'not_found']);
    exit;
}

$prodottoOff = $dati['product'];
$nutrienti = $prodottoOff['nutriments'] ?? [];

/** Un valore per 100 g, moltiplicato per passare dai grammi di OFF all'unita' dell'app. */
function nutriente(array $nutrienti, string $chiave, float $fattore = 1.0): float
{
    foreach (["{$chiave}_100g", $chiave] as $campo) {
        if (isset($nutrienti[$campo]) && is_numeric($nutrienti[$campo])) {
            return ((float) $nutrienti[$campo]) * $fattore;
        }
    }
    return 0.0;
}

// OFF scrive tutto in grammi per 100 g. L'app vuole mg per minerali e alcune
// vitamine, µg per le altre: qui si converte una volta sola.
const IN_MG = 1000.0;
const IN_MCG = 1000000.0;

$calorie = nutriente($nutrienti, 'energy-kcal');
if ($calorie <= 0) {
    // Solo kJ dichiarati: 1 kcal = 4,184 kJ.
    $kj = nutriente($nutrienti, 'energy-kj');
    if ($kj <= 0) {
        $kj = nutriente($nutrienti, 'energy');
    }
    $calorie = $kj > 0 ? $kj / 4.184 : 0.0;
}

$mappato = [
    'food_name' => $prodottoOff['product_name_it'] ?? $prodottoOff['product_name'] ?? 'Prodotto sconosciuto',
    // Senza questi quattro il prodotto scansionato arrivava anonimo: niente
    // codice da salvare, niente marca, niente foto, niente porzione.
    'barcode' => (string) ($prodottoOff['code'] ?? $barcode),
    'brand' => (string) ($prodottoOff['brands'] ?? ''),
    'image_url' => (string) ($prodottoOff['image_url'] ?? ''),
    'image_nutrition_url' => (string) ($prodottoOff['image_nutrition_url'] ?? ''),
    'image_ingredients_url' => (string) ($prodottoOff['image_ingredients_url'] ?? ''),
    'categories' => (string) ($prodottoOff['categories'] ?? ''),
    'ingredients' => (string) ($prodottoOff['ingredients_text_it'] ?? $prodottoOff['ingredients_text'] ?? ''),
    'allergens' => (string) ($prodottoOff['allergens'] ?? ''),
    'traces' => (string) ($prodottoOff['traces'] ?? ''),
    'labels' => (string) ($prodottoOff['labels'] ?? ''),
    'quantity' => (string) ($prodottoOff['quantity'] ?? ''),
    'packaging' => (string) ($prodottoOff['packaging'] ?? ''),
    'manufacturing_places' => (string) ($prodottoOff['manufacturing_places'] ?? ''),
    'serving_size' => (string) ($prodottoOff['serving_size'] ?? ''),
    'serving_quantity' => (float) ($prodottoOff['serving_quantity'] ?? 0),
    'nutriscore_grade' => (string) ($prodottoOff['nutriscore_grade'] ?? ''),
    'nova_group' => (float) ($prodottoOff['nova_group'] ?? 0),
    'additives_n' => (float) ($prodottoOff['additives_n'] ?? 0),
    'base_weight_g' => 100.0,

    // --- Macronutrienti: OFF li da' gia' in grammi, come l'app ---
    'calories' => $calorie,
    'carbs' => nutriente($nutrienti, 'carbohydrates'),
    'proteins' => nutriente($nutrienti, 'proteins'),
    'fats' => nutriente($nutrienti, 'fat'),
    'fibers' => nutriente($nutrienti, 'fiber'),
    'sugars' => nutriente($nutrienti, 'sugars'),
    'added_sugars' => nutriente($nutrienti, 'added-sugars'),
    'starch' => nutriente($nutrienti, 'starch'),
    'polyols' => nutriente($nutrienti, 'polyols'),
    'lactose' => nutriente($nutrienti, 'lactose'),
    'water' => nutriente($nutrienti, 'water'),
    'alcohol_percent' => nutriente($nutrienti, 'alcohol'),
    'salt' => nutriente($nutrienti, 'salt'),

    // --- Grassi ---
    'saturated_fats' => nutriente($nutrienti, 'saturated-fat'),
    'monounsaturated_fats' => nutriente($nutrienti, 'monounsaturated-fat'),
    'polyunsaturated_fats' => nutriente($nutrienti, 'polyunsaturated-fat'),
    'trans_fats' => nutriente($nutrienti, 'trans-fat'),
    'cholesterol' => nutriente($nutrienti, 'cholesterol', IN_MG),

    // --- Vitamine ---
    'vit_a' => nutriente($nutrienti, 'vitamin-a', IN_MCG),
    'vit_b1' => nutriente($nutrienti, 'vitamin-b1', IN_MG),
    'vit_b2' => nutriente($nutrienti, 'vitamin-b2', IN_MG),
    'vit_b3' => nutriente($nutrienti, 'vitamin-pp', IN_MG),
    'vit_b5' => nutriente($nutrienti, 'pantothenic-acid', IN_MG),
    'vit_b6' => nutriente($nutrienti, 'vitamin-b6', IN_MG),
    'vit_b7' => nutriente($nutrienti, 'biotin', IN_MCG),
    'vit_b9' => nutriente($nutrienti, 'vitamin-b9', IN_MCG),
    'vit_b12' => nutriente($nutrienti, 'vitamin-b12', IN_MCG),
    'vit_c' => nutriente($nutrienti, 'vitamin-c', IN_MG),
    'vit_d' => nutriente($nutrienti, 'vitamin-d', IN_MCG),
    'vit_e' => nutriente($nutrienti, 'vitamin-e', IN_MG),
    'vit_k' => nutriente($nutrienti, 'vitamin-k', IN_MCG),
    'biotin' => nutriente($nutrienti, 'biotin', IN_MCG),
    'caffeine' => nutriente($nutrienti, 'caffeine', IN_MG),

    // --- Minerali ---
    'sodium' => nutriente($nutrienti, 'sodium', IN_MG),
    'calcium' => nutriente($nutrienti, 'calcium', IN_MG),
    'iron' => nutriente($nutrienti, 'iron', IN_MG),
    'potassium' => nutriente($nutrienti, 'potassium', IN_MG),
    'magnesium' => nutriente($nutrienti, 'magnesium', IN_MG),
    'phosphorus' => nutriente($nutrienti, 'phosphorus', IN_MG),
    'zinc' => nutriente($nutrienti, 'zinc', IN_MG),
    'copper' => nutriente($nutrienti, 'copper', IN_MG),
    'manganese' => nutriente($nutrienti, 'manganese', IN_MG),
    'chloride' => nutriente($nutrienti, 'chloride', IN_MG),
    'fluoride' => nutriente($nutrienti, 'fluoride', IN_MG),
    'iodine' => nutriente($nutrienti, 'iodine', IN_MCG),
    'selenium' => nutriente($nutrienti, 'selenium', IN_MCG),
    'chromium' => nutriente($nutrienti, 'chromium', IN_MCG),
    'molybdenum' => nutriente($nutrienti, 'molybdenum', IN_MCG),
    'choline' => nutriente($nutrienti, 'choline', IN_MG),
    'source' => 'off_live',
];

echo json_encode(['status' => 'success', 'product' => $mappato]);
