<?php
/**
 * recipe_ingredient_columns.php — NON PIU' RICHIESTO DAGLI ENDPOINT (2026-09-07).
 *
 * ⚠️ Questo file NON va piu' caricato sul server, e nessuno script lo include
 * piu'. save_recipe.php e update_recipe.php leggono ora le colonne
 * direttamente da `SHOW COLUMNS FROM na_recipe_ingredients`.
 *
 * PERCHE' e' cambiato: questo file non e' mai arrivato sull'hosting, e
 * `require` di un file assente e' un errore fatale — il salvataggio delle
 * ricette e' rimasto rotto per settimane rispondendo HTTP 500 senza corpo,
 * quindi senza alcun indizio su cosa mancasse. Un elenco di colonne scritto a
 * mano ha due modi di sbagliare (divergere dallo schema, non arrivare a
 * destinazione); chiederlo al database non ne ha nessuno.
 *
 * RESTA UTILE COME DOCUMENTAZIONE: la ALTER TABLE qui sotto e' ancora
 * l'elenco di riferimento delle colonne che na_recipe_ingredients deve avere
 * perche' i campi OpenFoodFacts vengano salvati. Se sul server mancano, oggi
 * gli endpoint non falliscono piu' — semplicemente saltano quelle colonne.
 *
 * CONTESTO (vedi vault: 03 Projects/NutriApp/PROBLEMS.md): prima queste due
 * pagine salvavano SOLO recipe_id/food_name/unit/weight_g/calories/carbs/
 * proteins/fats, anche se na_recipe_ingredients ha 51 colonne nutrizionali —
 * ogni ingrediente aggiunto o modificato in una ricetta perdeva
 * silenziosamente acqua/fibre/zuccheri/grassi dettagliati/tutte le vitamine
 * e i minerali. Bug reale, non solo mancanza dei nuovi campi OpenFoodFacts.
 *
 * Le colonne NA_RECIPE_ING_INT/STRING (14 campi OFF + barcode) richiedono
 * questa ALTER TABLE su na_recipe_ingredients per essere salvate:
 *
 *   ALTER TABLE `na_recipe_ingredients`
 *     ADD COLUMN `nutriscore_grade` varchar(20) DEFAULT '' AFTER `unit`,
 *     ADD COLUMN `nova_group` tinyint UNSIGNED DEFAULT 0 AFTER `nutriscore_grade`,
 *     ADD COLUMN `additives_n` tinyint UNSIGNED DEFAULT 0 AFTER `nova_group`,
 *     ADD COLUMN `allergens` varchar(500) DEFAULT '' AFTER `additives_n`,
 *     ADD COLUMN `labels` varchar(500) DEFAULT '' AFTER `allergens`,
 *     ADD COLUMN `palm_oil_n` tinyint UNSIGNED DEFAULT 0 AFTER `labels`,
 *     ADD COLUMN `palm_oil_maybe_n` tinyint UNSIGNED DEFAULT 0 AFTER `palm_oil_n`,
 *     ADD COLUMN `image_url` varchar(500) DEFAULT '' AFTER `palm_oil_maybe_n`,
 *     ADD COLUMN `serving_size` varchar(100) DEFAULT '' AFTER `image_url`,
 *     ADD COLUMN `categories` varchar(500) DEFAULT '' AFTER `serving_size`,
 *     ADD COLUMN `manufacturing_places` varchar(255) DEFAULT '' AFTER `categories`,
 *     ADD COLUMN `ingredients` text DEFAULT NULL AFTER `manufacturing_places`,
 *     ADD COLUMN `alcohol_percent` double DEFAULT 0 AFTER `zinc`,
 *     ADD COLUMN `caffeine` double DEFAULT 0 AFTER `alcohol_percent`,
 *     ADD COLUMN `barcode` varchar(50) DEFAULT '' AFTER `caffeine`;
 */

// Colonne double/decimal già esistenti in na_recipe_ingredients, più
// alcohol_percent/caffeine (nuove, ma numeriche come le altre).
const NA_RECIPE_ING_NUMERIC = [
    'calories', 'carbs', 'proteins', 'fats', 'water', 'fibers', 'sugars',
    'saturated_fats', 'monounsaturated_fats', 'polyunsaturated_fats', 'trans_fats', 'cholesterol',
    'sodium', 'vit_a', 'vit_b1', 'vit_b2', 'vit_b3', 'vit_b5', 'vit_b6', 'vit_b7', 'vit_b9',
    'vit_b11', 'vit_b12', 'vit_c', 'vit_d', 'vit_e', 'vit_k', 'arsenic', 'biotin', 'boron',
    'calcium', 'chloride', 'choline', 'chromium', 'cobalt', 'copper', 'fluoride', 'fluorine',
    'iodine', 'iron', 'magnesium', 'manganese', 'molybdenum', 'phosphorus', 'potassium',
    'selenium', 'silicon', 'sulfur', 'tin', 'vanadium', 'zinc',
    'alcohol_percent', 'caffeine',
];

// Colonne intere OpenFoodFacts (nuove, richiedono la ALTER TABLE sopra).
const NA_RECIPE_ING_INT = ['nova_group', 'additives_n', 'palm_oil_n', 'palm_oil_maybe_n'];

// Colonne testuali OpenFoodFacts + barcode (nuove, richiedono la ALTER TABLE sopra).
const NA_RECIPE_ING_STRING = [
    'nutriscore_grade', 'allergens', 'labels', 'image_url', 'serving_size',
    'categories', 'manufacturing_places', 'ingredients', 'barcode',
];

/**
 * Costruisce la stringa dei tipi e l'array dei valori per bind_param, nello
 * stesso ordine di food_name/unit/weight_g + NA_RECIPE_ING_NUMERIC +
 * NA_RECIPE_ING_INT + NA_RECIPE_ING_STRING (l'ordine DEVE combaciare con
 * come viene costruita $columnList in save_recipe.php/update_recipe.php).
 */
function buildRecipeIngredientParams(int $recipe_id, array $ing): array {
    $types = "issd"; // recipe_id (i), food_name (s), unit (s), weight_g (d)
    $values = [
        $recipe_id,
        (string)($ing['food_name'] ?? ''),
        (string)($ing['unit'] ?? 'g'),
        floatval($ing['weight_g'] ?? 0),
    ];

    foreach (NA_RECIPE_ING_NUMERIC as $col) {
        $types .= "d";
        $values[] = floatval($ing[$col] ?? 0);
    }
    foreach (NA_RECIPE_ING_INT as $col) {
        $types .= "i";
        $values[] = intval($ing[$col] ?? 0);
    }
    foreach (NA_RECIPE_ING_STRING as $col) {
        $types .= "s";
        $values[] = (string)($ing[$col] ?? '');
    }

    return [$types, $values];
}
