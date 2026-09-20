<?php
require 'db_config.php';    // Configura database
require 'extract_data.php'; // Carica i dati nutrizionali

// Query per salvare il nuovo pasto nel database
$sql = "INSERT INTO na_nutri_entries (
    user_mail, food_name, meal_type, entry_date, weight_g,
    calories, carbs, proteins, fats, water, fibers, sugars,
    saturated_fats, monounsaturated_fats, polyunsaturated_fats, trans_fats, cholesterol, sodium,
    vit_a, vit_b1, vit_b2, vit_b3, vit_b5, vit_b6, vit_b7, vit_b9, vit_b11, vit_b12,
    vit_c, vit_d, vit_e, vit_k,
    arsenic, biotin, boron, calcium, chloride, choline, chromium, cobalt, copper, fluoride,
    fluorine, iodine, iron, magnesium, manganese, molybdenum, phosphorus, potassium,
    selenium, silicon, sulfur, tin, vanadium, zinc,
    nutriscore_grade, nova_group, environmental_score_grade
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
// Prepara la query
$stmt = $conn->prepare($sql);
if (!$stmt) {
    die(json_encode(["status" => "error", "message" => "Errore SQL: " . $conn->error]));
}

// Definiamo i tipi di dati (s = string, d = double, i = int)
$types = "ssssd".str_repeat("d", 51)."sis";

// Associa i valori ai parametri
$stmt->bind_param($types, $user_mail,
    $food_name, $meal_type, $entry_date, $weight_g,
    $calories, $carbs, $proteins, $fats, $water, $fibers, $sugars,
    $saturated_fats, $monounsaturated_fats, $polyunsaturated_fats, $trans_fats, $cholesterol,
    $sodium, $vit_a, $vit_b1, $vit_b2, $vit_b3, $vit_b5, $vit_b6, $vit_b7, $vit_b9, $vit_b11, $vit_b12,
    $vit_c, $vit_d, $vit_e, $vit_k, $arsenic, $biotin, $boron, $calcium, $chloride, $choline, $chromium, $cobalt, $copper, $fluoride,
    $fluorine, $iodine, $iron, $magnesium, $manganese, $molybdenum, $phosphorus, $potassium,
    $selenium, $silicon, $sulfur, $tin, $vanadium, $zinc,
    $nutriscore_grade, $nova_group, $environmental_score_grade
);

// Invio della risposta in formato JSON
if ($stmt->execute()) {
    echo json_encode(["status" => "success", "message" => "Inserimento completato con successo"]);
} else {
    echo json_encode(["status" => "error", "message" => "Errore durante l'inserimento: " . $stmt->error]);
}

$stmt->close();
$conn->close();
?>