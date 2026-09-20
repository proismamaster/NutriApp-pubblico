<?php

require 'db_config.php';
require_once 'auth.php';

// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$user_mail = emailAutenticata($conn, (string) ($_GET['user_mail'] ?? ''));
$date = $_GET['date'] ?? date('Y-m-d');
$meal_type = $_GET['meal_type'] ?? 'day';

if(empty($user_mail)){
    die(json_encode(["status" => "error", "message" => "Email utente mancante"]));
}

$sql = "SELECT
    -- Macronutrienti
    IFNULL(SUM(calories), 0) as tot_cal,
    IFNULL(SUM(carbs), 0) as tot_carbs,
    IFNULL(SUM(proteins), 0) as tot_proteins,
    IFNULL(SUM(fats), 0) as tot_fats,
    IFNULL(SUM(water), 0) as tot_water,
    IFNULL(SUM(fibers), 0) as tot_fibers,
    IFNULL(SUM(sugars), 0) as tot_sugars,
    -- Grassi Dettagliati
    IFNULL(SUM(saturated_fats), 0) as tot_saturated,
    IFNULL(SUM(monounsaturated_fats), 0) as tot_monounsaturated,
    IFNULL(SUM(polyunsaturated_fats), 0) as tot_polyunsaturated,
    IFNULL(SUM(trans_fats), 0) as tot_trans,
    IFNULL(SUM(cholesterol), 0) as tot_cholesterol,
    -- Minerali
    IFNULL(SUM(sodium), 0) as tot_sodium,
    IFNULL(SUM(arsenic), 0) as tot_arsenic,
    IFNULL(SUM(boron), 0) as tot_boron,
    IFNULL(SUM(calcium), 0) as tot_calcium,
    IFNULL(SUM(chloride), 0) as tot_chloride,
    IFNULL(SUM(choline), 0) as tot_choline,
    IFNULL(SUM(chromium), 0) as tot_chromium,
    IFNULL(SUM(cobalt), 0) as tot_cobalt,
    IFNULL(SUM(copper), 0) as tot_copper,
    IFNULL(SUM(fluoride), 0) as tot_fluoride,
    IFNULL(SUM(fluorine), 0) as tot_fluorine,
    IFNULL(SUM(iodine), 0) as tot_iodine,
    IFNULL(SUM(iron), 0) as tot_iron,
    IFNULL(SUM(magnesium), 0) as tot_magnesium,
    IFNULL(SUM(manganese), 0) as tot_manganese,
    IFNULL(SUM(molybdenum), 0) as tot_molybdenum,
    IFNULL(SUM(phosphorus), 0) as tot_phosphorus,
    IFNULL(SUM(potassium), 0) as tot_potassium,
    IFNULL(SUM(selenium), 0) as tot_selenium,
    IFNULL(SUM(silicon), 0) as tot_silicon,
    IFNULL(SUM(sulfur), 0) as tot_sulfur,
    IFNULL(SUM(tin), 0) as tot_tin,
    IFNULL(SUM(vanadium), 0) as tot_vanadium,
    IFNULL(SUM(zinc), 0) as tot_zinc,
    -- Vitamine
    IFNULL(SUM(vit_a), 0) as tot_vit_a,
    IFNULL(SUM(vit_b1), 0) as tot_vit_b1,
    IFNULL(SUM(vit_b2), 0) as tot_vit_b2,
    IFNULL(SUM(vit_b3), 0) as tot_vit_b3,
    IFNULL(SUM(vit_b5), 0) as tot_vit_b5,
    IFNULL(SUM(vit_b6), 0) as tot_vit_b6,
    IFNULL(SUM(vit_b7), 0) as tot_vit_b7,
    IFNULL(SUM(vit_b9), 0) as tot_vit_b9,
    IFNULL(SUM(vit_b11), 0) as tot_vit_b11,
    IFNULL(SUM(vit_b12), 0) as tot_vit_b12,
    IFNULL(SUM(vit_c), 0) as tot_vit_c,
    IFNULL(SUM(vit_d), 0) as tot_vit_d,
    IFNULL(SUM(vit_e), 0) as tot_vit_e,
    IFNULL(SUM(vit_k), 0) as tot_vit_k,
    IFNULL(SUM(biotin), 0) as tot_biotin,

    COUNT(*) as intakeCount,

    -- Qualita' del giorno: media di Nutri-Score/NOVA/Eco-Score delle sole
    -- voci che li hanno (AVG() di SQL ignora i NULL da solo — un alimento
    -- CREA senza punteggio non abbassa la media, semplicemente non conta).
    -- Lettera->numero perche' AVG() non funziona su una colonna testuale.
    AVG(CASE nutriscore_grade
        WHEN 'a' THEN 1 WHEN 'b' THEN 2 WHEN 'c' THEN 3 WHEN 'd' THEN 4 WHEN 'e' THEN 5 END
    ) as avg_nutriscore_num,
    AVG(nova_group) as avg_nova,
    AVG(CASE environmental_score_grade
        WHEN 'a' THEN 1 WHEN 'b' THEN 2 WHEN 'c' THEN 3 WHEN 'd' THEN 4 WHEN 'e' THEN 5 END
    ) as avg_ecoscore_num

    FROM na_nutri_entries
    WHERE user_mail = ? AND entry_date = ?";

// Se è stato richiesto un pasto specifico, aggiungiamo il filtro alla query
if($meal_type !== 'day'){
    $sql .= " AND meal_type = ?";
}

$stmt = $conn->prepare($sql);

if ($meal_type !== 'day') {
    $stmt->bind_param("sss", $user_mail, $date, $meal_type);
} else {
    $stmt->bind_param("ss", $user_mail, $date);
}

$stmt->execute();
$result = $stmt->get_result();
$totals = $result->fetch_assoc();

// Invio della risposta in formato JSON
echo json_encode([
    "status" => "success",
    "request" => [
        "user_mail" => $user_mail,
        "date" => $date,
        "meal_type" => $meal_type
    ],
    "totals" => $totals
]);

$stmt->close();
$conn->close();
?>