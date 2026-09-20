<?php
/**
 * custom_food_columns.php — elenco condiviso delle colonne NON numeriche e
 * dei metadati OpenFoodFacts di na_custom_foods.
 *
 * Usato da get_custom_foods.php e save_custom_food.php per non poter
 * divergere fra loro (stessa scelta già fatta per le ricette in
 * recipe_ingredient_columns.php).
 *
 * CONTESTO (vedi vault: 03 Projects/NutriApp/PROBLEMS.md):
 *  - get_custom_foods.php castava a (double) TUTTE le colonne tranne
 *    id/user_mail/food_name/created_at. Effetto: il `barcode` tornava al
 *    client come numero (e quindi come "8032123456789.0" una volta
 *    ri-convertito in stringa lato Dart), e qualunque nuova colonna
 *    testuale sarebbe arrivata come 0. Ora la lista delle colonne testuali
 *    è esplicita e vive qui.
 *  - I metadati OpenFoodFacts (Nutri-Score, NOVA, allergeni, ecc.) non
 *    venivano salvati affatto in libreria: salvando un prodotto trovato
 *    dalla ricerca si perdevano tutti. Stesso bug già corretto per gli
 *    ingredienti delle ricette, qui era rimasto aperto.
 *
 * Richiede DUE migrazioni su na_custom_foods, entrambe in fileDatabase/migrations/:
 *   - 2026-07-24_ricette_custom_foods_traduzioni.sql (eseguita il 29/08)
 *   - 2026-08-29_alimenti_personali_completi.sql (le 15 colonne nuove)
 * La ALTER qui sotto e' la prima delle due, tenuta come riferimento storico:
 *
 *   ALTER TABLE `na_custom_foods`
 *     ADD COLUMN `image_url` varchar(500) DEFAULT '' AFTER `barcode`,
 *     ADD COLUMN `description` text DEFAULT NULL AFTER `image_url`,
 *     ADD COLUMN `nutriscore_grade` varchar(20) DEFAULT '' AFTER `description`,
 *     ADD COLUMN `nova_group` tinyint UNSIGNED DEFAULT 0 AFTER `nutriscore_grade`,
 *     ADD COLUMN `additives_n` tinyint UNSIGNED DEFAULT 0 AFTER `nova_group`,
 *     ADD COLUMN `allergens` varchar(500) DEFAULT '' AFTER `additives_n`,
 *     ADD COLUMN `labels` varchar(500) DEFAULT '' AFTER `allergens`,
 *     ADD COLUMN `palm_oil_n` tinyint UNSIGNED DEFAULT 0 AFTER `labels`,
 *     ADD COLUMN `palm_oil_maybe_n` tinyint UNSIGNED DEFAULT 0 AFTER `palm_oil_n`,
 *     ADD COLUMN `serving_size` varchar(100) DEFAULT '' AFTER `palm_oil_maybe_n`,
 *     ADD COLUMN `categories` varchar(500) DEFAULT '' AFTER `serving_size`,
 *     ADD COLUMN `manufacturing_places` varchar(255) DEFAULT '' AFTER `categories`,
 *     ADD COLUMN `ingredients` text DEFAULT NULL AFTER `manufacturing_places`,
 *     ADD COLUMN `alcohol_percent` double DEFAULT 0 AFTER `ingredients`,
 *     ADD COLUMN `caffeine` double DEFAULT 0 AFTER `alcohol_percent`;
 */

/** Colonne che NON devono mai essere convertite in numero verso il client. */
const NA_CUSTOM_FOOD_TEXT_COLUMNS = [
    'id', 'user_mail', 'food_name', 'created_at',
    'barcode', 'image_url', 'description',
    'nutriscore_grade', 'allergens', 'labels', 'serving_size',
    'categories', 'manufacturing_places', 'ingredients',
    // Aggiunte 2026-08-30 con la migrazione 2026-08-29_alimenti_personali_completi.
    'brand', 'environmental_score_grade', 'nutrient_levels_tags', 'quantity',
    'packaging', 'additives_tags', 'best_before', 'updated_at',
    // Aggiunte 2026-09-12 con la migrazione 2026-09-12_collaborazione_community:
    // la visibilita' di un alimento e le tracce della revisione. Senza questa
    // riga get_custom_foods.php le convertirebbe in numero — `shared_status`
    // arriverebbe all'app come 0 invece di "private", ed e' esattamente il
    // bug del barcode diventato "8032123456789.0" che ha fatto nascere questo
    // elenco: una colonna testuale nuova va aggiunta QUI, sempre.
    'shared_status', 'shared_at', 'reviewed_at', 'reviewed_by', 'review_note',
];

/** Metadati OpenFoodFacts testuali. */
const NA_CUSTOM_FOOD_OFF_STRING = [
    'image_url', 'description', 'nutriscore_grade', 'allergens', 'labels',
    'serving_size', 'categories', 'manufacturing_places', 'ingredients',
    // 2026-08-30: un alimento creato a mano deve poter contenere tutto cio'
    // che la ricerca restituisce (search_off_products.php fa SELECT * su
    // na_off_products), piu' i campi di confezione del mockup "New product".
    'brand', 'environmental_score_grade', 'nutrient_levels_tags', 'quantity',
    'packaging', 'additives_tags',
];

/** Metadati OpenFoodFacts interi. */
const NA_CUSTOM_FOOD_OFF_INT = [
    'nova_group', 'additives_n', 'palm_oil_n', 'palm_oil_maybe_n',
];

/** Metadati OpenFoodFacts numerici con decimali. */
const NA_CUSTOM_FOOD_OFF_DOUBLE = [
    'alcohol_percent', 'caffeine',
    'added_sugars', 'starch', 'polyols', 'lactose',
];

/**
 * Colonne che devono poter restare NULL invece di diventare 0.
 *
 * PERCHE' SEPARATE: `servings` a 0 non vuol dire "zero porzioni", vuol dire
 * "non lo so" — e con 0 il calcolo "una porzione e' netto/porzioni" darebbe
 * una divisione per zero. Stesso discorso per `nutriscore_score`, dove 0 e'
 * un punteggio legittimo e non puo' fare da segnaposto per "assente".
 */
const NA_CUSTOM_FOOD_OFF_NULLABLE = [
    'net_quantity_g' => 'double',
    'servings' => 'int',
    'nutriscore_score' => 'int',
    'best_before' => 'date',
];

/** Frammento `col=valore` per una colonna nullable, con NULL se vuota. */
function customFoodNullableValue(mysqli $conn, array $data, string $col, string $tipo): string {
    $raw = $data[$col] ?? null;
    if ($raw === null || $raw === '' || $raw === false) {
        return 'NULL';
    }
    if ($tipo === 'int') {
        return (string)(int)$raw;
    }
    if ($tipo === 'double') {
        return (string)(double)$raw;
    }
    return "'" . $conn->real_escape_string((string)$raw) . "'";
}

/**
 * Costruisce il frammento SQL "col='val', col2=N, ..." per i metadati OFF,
 * con i valori già messi in sicurezza. Ritorna stringa vuota se non c'è
 * nulla da scrivere, così il chiamante può concatenarlo senza preoccuparsi.
 */
function buildCustomFoodOffAssignments(mysqli $conn, array $data): string {
    $parts = [];
    foreach (NA_CUSTOM_FOOD_OFF_STRING as $col) {
        $val = $conn->real_escape_string((string)($data[$col] ?? ''));
        $parts[] = "`$col`='$val'";
    }
    foreach (NA_CUSTOM_FOOD_OFF_INT as $col) {
        $parts[] = "`$col`=" . (int)($data[$col] ?? 0);
    }
    foreach (NA_CUSTOM_FOOD_OFF_DOUBLE as $col) {
        $parts[] = "`$col`=" . (double)($data[$col] ?? 0);
    }
    foreach (NA_CUSTOM_FOOD_OFF_NULLABLE as $col => $tipo) {
        $parts[] = "`$col`=" . customFoodNullableValue($conn, $data, $col, $tipo);
    }
    return implode(', ', $parts);
}

/**
 * Come sopra ma per l'INSERT: ritorna [listaColonne, listaValori] già
 * formattate e nello stesso ordine.
 */
function buildCustomFoodOffInsert(mysqli $conn, array $data): array {
    $cols = [];
    $vals = [];
    foreach (NA_CUSTOM_FOOD_OFF_STRING as $col) {
        $cols[] = "`$col`";
        $vals[] = "'" . $conn->real_escape_string((string)($data[$col] ?? '')) . "'";
    }
    foreach (NA_CUSTOM_FOOD_OFF_INT as $col) {
        $cols[] = "`$col`";
        $vals[] = (string)(int)($data[$col] ?? 0);
    }
    foreach (NA_CUSTOM_FOOD_OFF_DOUBLE as $col) {
        $cols[] = "`$col`";
        $vals[] = (string)(double)($data[$col] ?? 0);
    }
    foreach (NA_CUSTOM_FOOD_OFF_NULLABLE as $col => $tipo) {
        $cols[] = "`$col`";
        $vals[] = customFoodNullableValue($conn, $data, $col, $tipo);
    }
    return [implode(', ', $cols), implode(', ', $vals)];
}
