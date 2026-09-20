<?php

require 'db_config.php';
require 'extract_data.php';

if (!$id || !$data) {
    die(json_encode(["status" => "error", "message" => "Dati o ID mancanti"]));
}

$sql = "UPDATE na_nutri_entries SET 
    food_name = ?, meal_type = ?, entry_date = ?, weight_g = ?, 
    calories = ?, carbs = ?, proteins = ?, fats = ?, water = ?, fibers = ?, sugars = ?,
    saturated_fats = ?, monounsaturated_fats = ?, polyunsaturated_fats = ?, trans_fats = ?, cholesterol = ?, sodium = ?,
    vit_a = ?, vit_b1 = ?, vit_b2 = ?, vit_b3 = ?, vit_b5 = ?, vit_b6 = ?, vit_b7 = ?, vit_b9 = ?, vit_b11 = ?, vit_b12 = ?,
    vit_c = ?, vit_d = ?, vit_e = ?, vit_k = ?, biotin = ?,
    arsenic = ?, boron = ?, calcium = ?, chloride = ?, choline = ?, chromium = ?, cobalt = ?, copper = ?, fluoride = ?,
    fluorine = ?, iodine = ?, iron = ?, magnesium = ?, manganese = ?, molybdenum = ?, phosphorus = ?, potassium = ?, 
    selenium = ?, silicon = ?, sulfur = ?, tin = ?, vanadium = ?, zinc = ?,
    nutriscore_grade = ?, nova_group = ?, environmental_score_grade = ?
    WHERE id = ? AND user_mail = ?";

$stmt = $conn->prepare($sql);

if (!$stmt) {
    die(json_encode(["status" => "error", "message" => "Errore SQL: " . $conn->error]));
}

$types = "sssd" . str_repeat("d", 51) . "sisis";

$stmt->bind_param($types,
    $food_name, $meal_type, $entry_date, $weight_g,
    $calories, $carbs, $proteins, $fats, $water, $fibers, $sugars,
    $saturated_fats, $monounsaturated_fats, $polyunsaturated_fats, $trans_fats, $cholesterol,
    $sodium, $vit_a, $vit_b1, $vit_b2, $vit_b3, $vit_b5, $vit_b6, $vit_b7, $vit_b9, $vit_b11, $vit_b12,
    // FIX 2026-08-29: qui c'era `$vit_k, $arsenic, $biotin`, ma la SQL sopra
    // elenca le colonne come `vit_k, biotin, arsenic` — ogni modifica di una
    // voce scriveva la biotina nella colonna arsenico e viceversa, in silenzio.
    // save_entry.php ha sempre avuto l'ordine giusto: ora i due file coincidono.
    $vit_c, $vit_d, $vit_e, $vit_k, $biotin, $arsenic, $boron, $calcium, $chloride, $choline, $chromium, $cobalt, $copper, $fluoride,
    $fluorine, $iodine, $iron, $magnesium, $manganese, $molybdenum, $phosphorus, $potassium,
    $selenium, $silicon, $sulfur, $tin, $vanadium, $zinc,
    $nutriscore_grade, $nova_group, $environmental_score_grade, $id, $user_mail
);

if ($stmt->execute()) {
    echo json_encode(["status" => "success", "message" => "Pasto aggiornato con successo"]);
} else {
    echo json_encode(["status" => "error", "message" => "Errore durante l'aggiornamento: " . $stmt->error]);
}

$stmt->close();
$conn->close();

?>