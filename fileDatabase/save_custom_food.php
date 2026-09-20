<?php
// save_custom_food.php
header('Content-Type: application/json');
require 'db_config.php';
require_once 'auth.php';
require 'custom_food_columns.php'; // Elenco colonne condiviso con get_custom_foods.php

$data = json_decode(file_get_contents('php://input'), true);

if (!$data || !isset($data['user_mail'])) {
    echo json_encode(["status" => "error", "message" => "user_mail mancante"]);
    exit;
}

// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$user_mail = $conn->real_escape_string(emailAutenticata($conn, (string) ($data['user_mail'] ?? '')));

// Valori che in 100 g di cibo non possono esistere non entrano nel database
// (decisione del 20/09): 40000 kcal per 100 g sono arrivate cosi' da un
// import, e da un utente arriverebbero allo stesso modo.
require_once 'limiti_nutrienti.php';
$impossibile = erroreNutrienti($data);
if ($impossibile !== null) {
    echo json_encode([
        'status' => 'error',
        'code' => 'valori_impossibili',
        'message' => 'Valori non plausibili: ' . $impossibile . '.',
    ]);
    exit;
}

if (isset($data['id'])) {
    // UPDATE - Se passiamo solo is_favorite, aggiorniamo solo quello
    $id = (int)$data['id'];
    $is_fav = (int)($data['is_favorite'] ?? 0);
    
    if (count($data) <= 4 && isset($data['is_favorite'])) {
        $sql = "UPDATE na_custom_foods SET is_favorite=$is_fav WHERE id=$id AND user_mail='$user_mail'";
    } else {
        // Un alimento approvato e' del database (15/09, decisione di Ismail):
        // l'autore non lo modifica piu'. Le correzioni passano dalle
        // segnalazioni e dal pannello. Il preferito (ramo sopra) resta suo.
        $colonnaStato = $conn->query("SHOW COLUMNS FROM na_custom_foods LIKE 'shared_status'");
        if ($colonnaStato && $colonnaStato->num_rows > 0) {
            $statoAttuale = $conn->query("SELECT shared_status FROM na_custom_foods WHERE id=$id AND user_mail='$user_mail' LIMIT 1");
            $rigaStato = $statoAttuale ? $statoAttuale->fetch_assoc() : null;
            if (($rigaStato['shared_status'] ?? '') === 'approved') {
                echo json_encode([
                    "status" => "error",
                    "message" => "Questo alimento e' pubblico e fa parte del database: non si modifica piu'. Se contiene un errore, segnalalo.",
                    "reason" => "locked",
                ]);
                exit;
            }
        }
        if (!isset($data['food_name'])) {
            echo json_encode(["status" => "error", "message" => "food_name mancante per update completo"]);
            exit;
        }
        $food_name = $conn->real_escape_string($data['food_name']);
        $barcode = isset($data['barcode']) ? $conn->real_escape_string($data['barcode']) : null;
        $base_weight = (double)($data['base_weight_g'] ?? 100.0);
        // Foto, descrizione e metadati OpenFoodFacts (2026-07-24): richiedono
        // le nuove colonne su na_custom_foods (ALTER in custom_food_columns.php).
        $offAssignments = buildCustomFoodOffAssignments($conn, $data);
        // ... (rest of macro/micro logic remains the same)
        $cal = (double)($data['calories'] ?? 0);
        $prot = (double)($data['proteins'] ?? 0);
        $carbs = (double)($data['carbs'] ?? 0);
        $fats = (double)($data['fats'] ?? 0);
        $water = (double)($data['water'] ?? 0);
        $fibers = (double)($data['fibers'] ?? 0);
        $sugars = (double)($data['sugars'] ?? 0);
        $sat = (double)($data['saturated_fats'] ?? 0);
        $mono = (double)($data['monounsaturated_fats'] ?? 0);
        $poly = (double)($data['polyunsaturated_fats'] ?? 0);
        $trans = (double)($data['trans_fats'] ?? 0);
        $chol = (double)($data['cholesterol'] ?? 0);
        $v_a = (double)($data['vit_a'] ?? 0); $v_b1 = (double)($data['vit_b1'] ?? 0); $v_b2 = (double)($data['vit_b2'] ?? 0);
        $v_b3 = (double)($data['vit_b3'] ?? 0); $v_b5 = (double)($data['vit_b5'] ?? 0); $v_b6 = (double)($data['vit_b6'] ?? 0);
        $v_b7 = (double)($data['vit_b7'] ?? 0); $v_b9 = (double)($data['vit_b9'] ?? 0); $v_b11 = (double)($data['vit_b11'] ?? 0);
        $v_b12 = (double)($data['vit_b12'] ?? 0); $v_c = (double)($data['vit_c'] ?? 0); $v_d = (double)($data['vit_d'] ?? 0);
        $v_e = (double)($data['vit_e'] ?? 0); $v_k = (double)($data['vit_k'] ?? 0); $v_biotin = (double)($data['biotin'] ?? 0);
        $m_sodium = (double)($data['sodium'] ?? 0); $m_arsenic = (double)($data['arsenic'] ?? 0); $m_boron = (double)($data['boron'] ?? 0);
        $m_calcium = (double)($data['calcium'] ?? 0); $m_chloride = (double)($data['chloride'] ?? 0); $m_choline = (double)($data['choline'] ?? 0);
        $m_chromium = (double)($data['chromium'] ?? 0); $m_cobalt = (double)($data['cobalt'] ?? 0); $m_copper = (double)($data['copper'] ?? 0);
        $m_fluoride = (double)($data['fluoride'] ?? 0); $m_fluorine = (double)($data['fluorine'] ?? 0); $m_iodine = (double)($data['iodine'] ?? 0);
        $m_iron = (double)($data['iron'] ?? 0); $m_magnesium = (double)($data['magnesium'] ?? 0); $m_manganese = (double)($data['manganese'] ?? 0);
        $m_molybdenum = (double)($data['molybdenum'] ?? 0); $m_phosphorus = (double)($data['phosphorus'] ?? 0); $m_potassium = (double)($data['potassium'] ?? 0);
        $m_selenium = (double)($data['selenium'] ?? 0); $m_silicon = (double)($data['silicon'] ?? 0); $m_sulfur = (double)($data['sulfur'] ?? 0);
        $m_tin = (double)($data['tin'] ?? 0); $m_vanadium = (double)($data['vanadium'] ?? 0); $m_zinc = (double)($data['zinc'] ?? 0);

        $sql = "UPDATE na_custom_foods SET
                food_name='$food_name', barcode=" . ($barcode ? "'$barcode'" : "NULL") . ", base_weight_g=$base_weight, is_favorite=$is_fav,
                $offAssignments,
                calories=$cal, proteins=$prot, carbs=$carbs, fats=$fats, water=$water, fibers=$fibers, sugars=$sugars,
                saturated_fats=$sat, monounsaturated_fats=$mono, polyunsaturated_fats=$poly, trans_fats=$trans, cholesterol=$chol,
                vit_a=$v_a, vit_b1=$v_b1, vit_b2=$v_b2, vit_b3=$v_b3, vit_b5=$v_b5, vit_b6=$v_b6, vit_b7=$v_b7, vit_b9=$v_b9, vit_b11=$v_b11, vit_b12=$v_b12, vit_c=$v_c, vit_d=$v_d, vit_e=$v_e, vit_k=$v_k, biotin=$v_biotin,
                sodium=$m_sodium, arsenic=$m_arsenic, boron=$m_boron, calcium=$m_calcium, chloride=$m_chloride, choline=$m_choline, chromium=$m_chromium, cobalt=$m_cobalt, copper=$m_copper, fluoride=$m_fluoride, fluorine=$m_fluorine, iodine=$m_iodine, iron=$m_iron, magnesium=$m_magnesium, manganese=$m_manganese, molybdenum=$m_molybdenum, phosphorus=$m_phosphorus, potassium=$m_potassium, selenium=$m_selenium, silicon=$m_silicon, sulfur=$m_sulfur, tin=$m_tin, vanadium=$m_vanadium, zinc=$m_zinc
                WHERE id=$id AND user_mail='$user_mail'";
    }
} else {
    // INSERT
    if (!isset($data['food_name'])) {
        echo json_encode(["status" => "error", "message" => "food_name mancante per inserimento"]);
        exit;
    }
    $food_name = $conn->real_escape_string($data['food_name']);
    $barcode = isset($data['barcode']) ? $conn->real_escape_string($data['barcode']) : null;
    $base_weight = (double)($data['base_weight_g'] ?? 100.0);
    $is_fav = (int)($data['is_favorite'] ?? 0);
    // Foto, descrizione e metadati OpenFoodFacts (2026-07-24): richiedono
    // le nuove colonne su na_custom_foods (ALTER in custom_food_columns.php).
    [$offCols, $offVals] = buildCustomFoodOffInsert($conn, $data);

    // ... (macro/micro logic)
    $cal = (double)($data['calories'] ?? 0);
    $prot = (double)($data['proteins'] ?? 0);
    $carbs = (double)($data['carbs'] ?? 0);
    $fats = (double)($data['fats'] ?? 0);
    $water = (double)($data['water'] ?? 0);
    $fibers = (double)($data['fibers'] ?? 0);
    $sugars = (double)($data['sugars'] ?? 0);
    $sat = (double)($data['saturated_fats'] ?? 0);
    $mono = (double)($data['monounsaturated_fats'] ?? 0);
    $poly = (double)($data['polyunsaturated_fats'] ?? 0);
    $trans = (double)($data['trans_fats'] ?? 0);
    $chol = (double)($data['cholesterol'] ?? 0);
    $v_a = (double)($data['vit_a'] ?? 0); $v_b1 = (double)($data['vit_b1'] ?? 0); $v_b2 = (double)($data['vit_b2'] ?? 0);
    $v_b3 = (double)($data['vit_b3'] ?? 0); $v_b5 = (double)($data['vit_b5'] ?? 0); $v_b6 = (double)($data['vit_b6'] ?? 0);
    $v_b7 = (double)($data['vit_b7'] ?? 0); $v_b9 = (double)($data['vit_b9'] ?? 0); $v_b11 = (double)($data['vit_b11'] ?? 0);
    $v_b12 = (double)($data['vit_b12'] ?? 0); $v_c = (double)($data['vit_c'] ?? 0); $v_d = (double)($data['vit_d'] ?? 0);
    $v_e = (double)($data['vit_e'] ?? 0); $v_k = (double)($data['vit_k'] ?? 0); $v_biotin = (double)($data['biotin'] ?? 0);
    $m_sodium = (double)($data['sodium'] ?? 0); $m_arsenic = (double)($data['arsenic'] ?? 0); $m_boron = (double)($data['boron'] ?? 0);
    $m_calcium = (double)($data['calcium'] ?? 0); $m_chloride = (double)($data['chloride'] ?? 0); $m_choline = (double)($data['choline'] ?? 0);
    $m_chromium = (double)($data['chromium'] ?? 0); $m_cobalt = (double)($data['cobalt'] ?? 0); $m_copper = (double)($data['copper'] ?? 0);
    $m_fluoride = (double)($data['fluoride'] ?? 0); $m_fluorine = (double)($data['fluorine'] ?? 0); $m_iodine = (double)($data['iodine'] ?? 0);
    $m_iron = (double)($data['iron'] ?? 0); $m_magnesium = (double)($data['magnesium'] ?? 0); $m_manganese = (double)($data['manganese'] ?? 0);
    $m_molybdenum = (double)($data['molybdenum'] ?? 0); $m_phosphorus = (double)($data['phosphorus'] ?? 0); $m_potassium = (double)($data['potassium'] ?? 0);
    $m_selenium = (double)($data['selenium'] ?? 0); $m_silicon = (double)($data['silicon'] ?? 0); $m_sulfur = (double)($data['sulfur'] ?? 0);
    $m_tin = (double)($data['tin'] ?? 0); $m_vanadium = (double)($data['vanadium'] ?? 0); $m_zinc = (double)($data['zinc'] ?? 0);

    $sql = "INSERT INTO na_custom_foods (
        user_mail, food_name, barcode, base_weight_g, is_favorite, $offCols,
        calories, proteins, carbs, fats, water, fibers, sugars,
        saturated_fats, monounsaturated_fats, polyunsaturated_fats, trans_fats, cholesterol,
        vit_a, vit_b1, vit_b2, vit_b3, vit_b5, vit_b6, vit_b7, vit_b9, vit_b11, vit_b12, vit_c, vit_d, vit_e, vit_k, biotin,
        sodium, arsenic, boron, calcium, chloride, choline, chromium, cobalt, copper, fluoride, fluorine, iodine, iron, magnesium, manganese, molybdenum, phosphorus, potassium, selenium, silicon, sulfur, tin, vanadium, zinc
    ) VALUES (
        '$user_mail', '$food_name', " . ($barcode ? "'$barcode'" : "NULL") . ", $base_weight, $is_fav, $offVals,
        $cal, $prot, $carbs, $fats, $water, $fibers, $sugars,
        $sat, $mono, $poly, $trans, $chol,
        $v_a, $v_b1, $v_b2, $v_b3, $v_b5, $v_b6, $v_b7, $v_b9, $v_b11, $v_b12, $v_c, $v_d, $v_e, $v_k, $v_biotin,
        $m_sodium, $m_arsenic, $m_boron, $m_calcium, $m_chloride, $m_choline, $m_chromium, $m_cobalt, $m_copper, $m_fluoride, $m_fluorine, $m_iodine, $m_iron, $m_magnesium, $m_manganese, $m_molybdenum, $m_phosphorus, $m_potassium, $m_selenium, $m_silicon, $m_sulfur, $m_tin, $m_vanadium, $m_zinc
    )";
}

if ($conn->query($sql) === TRUE) {
    echo json_encode(["status" => "success", "id" => isset($id) ? $id : $conn->insert_id]);
} else {
    echo json_encode(["status" => "error", "message" => $conn->error]);
}
?>