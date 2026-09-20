<?php
//leggo tutti gli input
$json_data = file_get_contents('php://input');
//decodifco input
$data = json_decode($json_data, true);
require_once __DIR__ . '/auth.php';

//se non ci saono dati non "moriremo qua" ma lo lasceremo gestire al codice padre
if($data){

// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$user_mail = emailAutenticata($conn, (string) ($data['user_mail'] ?? ''));
    $food_name = $data['food_name'] ?? '';
    $meal_type = $data['meal_type'] ?? '';
    $entry_date = $data['entry_date'] ?? '';
    $weight_g = (double)($data['weight_g'] ?? 0);
    // ID (utile per l'update)
    $id = isset($data['id']) ? (int)$data['id'] : null;
    // Macronutrienti
    $calories = (double)($data['calories'] ?? 0);
    $carbs = (double)($data['carbs'] ?? 0);
    $proteins = (double)($data['proteins'] ?? 0);
    $fats = (double)($data['fats'] ?? 0);
    $water = (double)($data['water'] ?? 0);
    $fibers = (double)($data['fibers'] ?? 0);
    $sugars = (double)($data['sugars'] ?? 0);
    // Grassi
    $saturated_fats = (double)($data['saturated_fats'] ?? 0);
    $monounsaturated_fats = (double)($data['monounsaturated_fats'] ?? 0);
    $polyunsaturated_fats = (double)($data['polyunsaturated_fats'] ?? 0);
    $trans_fats = (double)($data['trans_fats'] ?? 0);
    $cholesterol = (double)($data['cholesterol'] ?? 0);
    // Minerali
    $sodium = (double)($data['sodium'] ?? 0);
    $arsenic = (double)($data['arsenic'] ?? 0);
    $boron = (double)($data['boron'] ?? 0);
    $calcium = (double)($data['calcium'] ?? 0);
    $chloride = (double)($data['chloride'] ?? 0);
    $choline = (double)($data['choline'] ?? 0);
    $chromium = (double)($data['chromium'] ?? 0);
    $cobalt = (double)($data['cobalt'] ?? 0);
    $copper = (double)($data['copper'] ?? 0);
    $fluoride = (double)($data['fluoride'] ?? 0);
    $fluorine = (double)($data['fluorine'] ?? 0);
    $iodine = (double)($data['iodine'] ?? 0);
    $iron = (double)($data['iron'] ?? 0);
    $magnesium = (double)($data['magnesium'] ?? 0);
    $manganese = (double)($data['manganese'] ?? 0);
    $molybdenum = (double)($data['molybdenum'] ?? 0);
    $phosphorus = (double)($data['phosphorus'] ?? 0);
    $potassium = (double)($data['potassium'] ?? 0);
    $selenium = (double)($data['selenium'] ?? 0);
    $silicon = (double)($data['silicon'] ?? 0);
    $sulfur = (double)($data['sulfur'] ?? 0);
    $tin = (double)($data['tin'] ?? 0);
    $vanadium = (double)($data['vanadium'] ?? 0);
    $zinc = (double)($data['zinc'] ?? 0);
    // Vitamine
    $vit_a = (double)($data['vit_a'] ?? 0);
    $vit_b1 = (double)($data['vit_b1'] ?? 0);
    $vit_b2 = (double)($data['vit_b2'] ?? 0);
    $vit_b3 = (double)($data['vit_b3'] ?? 0);
    $vit_b5 = (double)($data['vit_b5'] ?? 0);
    $vit_b6 = (double)($data['vit_b6'] ?? 0);
    $vit_b7 = (double)($data['vit_b7'] ?? 0);
    $vit_b9 = (double)($data['vit_b9'] ?? 0);
    $vit_b11 = (double)($data['vit_b11'] ?? 0);
    $vit_b12 = (double)($data['vit_b12'] ?? 0);
    $vit_c = (double)($data['vit_c'] ?? 0);
    $vit_d = (double)($data['vit_d'] ?? 0);
    $vit_e = (double)($data['vit_e'] ?? 0);
    $vit_k = (double)($data['vit_k'] ?? 0);
    $biotin = (double)($data['biotin'] ?? 0);
    // Qualita' (snapshot al momento del log, vedi
    // migrations/2026-08-23_qualita_giorno.sql): NULL se il prodotto non
    // ha il punteggio (es. alimento CREA), mai 0/stringa vuota, cosi' AVG()
    // in get_daily_summary.php lo ignora invece di farlo pesare come "il
    // peggiore possibile".
    $nutriscore_grade = isset($data['nutriscore_grade']) && $data['nutriscore_grade'] !== ''
        ? strtolower((string)$data['nutriscore_grade']) : null;
    $nova_group = isset($data['nova_group']) && (int)$data['nova_group'] > 0
        ? (int)$data['nova_group'] : null;
    $environmental_score_grade = isset($data['environmental_score_grade']) && $data['environmental_score_grade'] !== ''
        ? strtolower((string)$data['environmental_score_grade']) : null;
}
?>