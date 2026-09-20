<?php
// update_goals.php
require 'db_config.php';
require_once 'auth.php';

// Disabilita la visualizzazione degli errori per non sporcare il JSON, ma loggali
error_reporting(E_ALL);
ini_set('display_errors', 0);

header('Content-Type: application/json');

// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$user_id = (int) utenteAutenticato($conn)['id'];
if ($user_id <= 0) {
    echo json_encode(["status" => "error", "message" => "ID utente mancante o non valido"]);
    exit;
}

// Limiti dei pesi (2026-09-14), gli stessi di lib/logic/limiti_corpo.dart. Zero
// vuol dire "non indicato" (lo manda chi non ha ancora un peso) e passa. Le
// calorie hanno solo un tetto di sicurezza: il minimo di 800 lo chiede l'app
// quando si modificano a mano, ma il calcolo automatico per una persona molto
// minuta puo' scendere sotto, e rifiutarlo qui bloccherebbe la registrazione.
foreach (["current_weight" => "Peso", "target_weight" => "Peso obiettivo"] as $campoPeso => $nomePeso) {
    $v = isset($_POST[$campoPeso]) ? (float) $_POST[$campoPeso] : 0.0;
    if ($v != 0.0 && ($v < 30 || $v > 300)) {
        echo json_encode(["status" => "error", "message" => "$nomePeso ammesso fra 30 e 300 kg."]);
        exit;
    }
}
$kcalObiettivo = isset($_POST["calorie_goal"]) ? (float) $_POST["calorie_goal"] : 0.0;
if ($kcalObiettivo < 0 || $kcalObiettivo > 10000) {
    echo json_encode(["status" => "error", "message" => "Obiettivo calorico non valido."]);
    exit;
}

// Lista chiusa delle colonne scrivibili: i nomi finiscono nella query, quindi
// arrivano solo da qui, mai dalla richiesta.
$fields = [
    "current_weight", "target_weight", "calorie_goal", "protein_goal", "fat_goal", "carb_goal",
    "water_goal", "fiber_goal", "sugar_max", "saturated_fats_goal", "monounsaturated_fats_goal",
    "polyunsaturated_fats_goal", "trans_fats_max", "cholesterol_max", "sodium_max",
    "vit_a_goal", "vit_b1_goal", "vit_b2_goal", "vit_b3_goal", "vit_b5_goal", "vit_b6_goal",
    "vit_b7_goal", "vit_b9_goal", "vit_b11_goal", "vit_b12_goal", "vit_c_goal", "vit_d_goal",
    "vit_e_goal", "vit_k_goal", "arsenic_goal", "biotin_goal", "boron_goal", "calcium_goal",
    "chloride_goal", "choline_goal", "chromium_goal", "cobalt_goal", "copper_goal",
    "fluoride_goal", "fluorine_goal", "iodine_goal", "iron_goal", "magnesium_goal",
    "manganese_goal", "molybdenum_goal", "phosphorus_goal", "potassium_goal", "selenium_goal",
    "silicon_goal", "sulfur_goal", "tin_goal", "vanadium_goal", "zinc_goal"
];

// SOLO I CAMPI ARRIVATI (2026-09-15). Prima si scrivevano sempre tutte le 53
// colonne, con zero per quelle mancanti. Dalla Home si cambia solo il peso, ma
// la richiesta portava con se' anche il peso obiettivo: un obiettivo salvato
// prima dei limiti del 14/09 (545 kg) faceva rifiutare il peso nuovo, e
// sul telefono usciva "Errore nel salvataggio degli obiettivi". Ora una
// richiesta con il solo peso tocca solo il peso; l'app di prima, che manda
// tutto, continua a scrivere tutto.
$sets = [];
$bind_values = [];
foreach ($fields as $campo) {
    if (!isset($_POST[$campo])) {
        continue;
    }
    $sets[] = "$campo = ?";
    $bind_values[] = (float) $_POST[$campo];
    // 'weight' (anagrafico) segue sempre 'current_weight'.
    if ($campo === "current_weight") {
        $sets[] = "weight = ?";
        $bind_values[] = (float) $_POST[$campo];
    }
}

if ($sets === []) {
    echo json_encode(["status" => "error", "message" => "Nessun obiettivo da salvare."]);
    exit;
}

$stmt = $conn->prepare("UPDATE na_users SET " . implode(", ", $sets) . " WHERE id = ?");
if (!$stmt) {
    echo json_encode(["status" => "error", "message" => "Errore Prepare: " . $conn->error]);
    exit;
}

$types = str_repeat("d", count($bind_values)) . "i";
$bind_values[] = $user_id;
$stmt->bind_param($types, ...$bind_values);

if ($stmt->execute()) {
    echo json_encode(["status" => "success", "message" => "Obiettivi salvati"]);
} else {
    echo json_encode(["status" => "error", "message" => "Errore SQL: " . $stmt->error]);
}

$stmt->close();
$conn->close();
?>
