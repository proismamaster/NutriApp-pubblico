<?php
// signup.php
require 'db_config.php';
require_once 'auth.php';

$email      = trim((string) ($_POST["email"] ?? ''));
$password   = (string) ($_POST["password"] ?? '');
$first_name = $_POST["first_name"] ?? '';
$last_name  = $_POST["last_name"] ?? '';

// Senza email o password l'INSERT falliva con un errore fatale e una risposta
// 500 vuota (visto il 14/09 con una semplice GET): meglio dirlo in JSON.
if ($email === '' || $password === '') {
    echo json_encode(["status" => "error", "message" => "Email e password obbligatorie."]);
    exit;
}
$weight     = $_POST["weight"] ?? null;
$height     = $_POST["height"] ?? null;
$gender     = $_POST["gender"] ?? null;
$birth_date = $_POST["birth_date"] ?? null;

// Limiti dei dati del corpo (2026-09-14), gli stessi di lib/logic/limiti_corpo.dart.
// L'app li controlla gia': qui servono contro un'app vecchia o una richiesta
// scritta a mano, perche' da peso, altezza ed eta' partono i calcoli degli
// obiettivi. Un campo vuoto o a zero vuol dire "non indicato" e passa.
// Ripetuta in update_profile.php invece di stare in un file condiviso: un file
// condiviso mai caricato via FTP ha gia' rotto il salvataggio delle ricette.
function nutriappFuoriLimiti($peso, $altezza, $nascita): ?string
{
    if ($peso !== null && $peso !== '' && (float) $peso != 0.0 && ((float) $peso < 30 || (float) $peso > 300)) {
        return 'Peso ammesso fra 30 e 300 kg.';
    }
    if ($altezza !== null && $altezza !== '' && (float) $altezza != 0.0 && ((float) $altezza < 100 || (float) $altezza > 230)) {
        return 'Altezza ammessa fra 100 e 230 cm.';
    }
    if ($nascita !== null && $nascita !== '') {
        $data = DateTime::createFromFormat('!Y-m-d', substr((string) $nascita, 0, 10));
        if (!$data) {
            return 'Data di nascita non valida.';
        }
        $oggi = new DateTime('today');
        $anni = $data->diff($oggi)->y;
        if ($data > $oggi || $anni < 14 || $anni > 100) {
            return 'Età ammessa fra 14 e 100 anni.';
        }
    }
    return null;
}

$fuoriLimiti = nutriappFuoriLimiti($weight, $height, $birth_date);
if ($fuoriLimiti !== null) {
    echo json_encode(["status" => "error", "message" => $fuoriLimiti]);
    exit;
}

// Controlla se email esiste già
$check = $conn->prepare("SELECT id FROM na_users WHERE email = ?");
$check->bind_param("s", $email);
$check->execute();
$check->store_result();

if ($check->num_rows > 0) {
    echo json_encode(["status" => "error", "message" => "Email già registrata"]);
    $check->close();
    $conn->close();
    exit;
}
$check->close();

$password_hash = password_hash($password, PASSWORD_BCRYPT);

$sql = "INSERT INTO na_users 
        (email, password_hash, first_name, last_name, weight, height, gender, birth_date) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
$stmt = $conn->prepare($sql);
$stmt->bind_param("ssssddss", $email, $password_hash, $first_name, $last_name, $weight, $height, $gender, $birth_date);

if ($stmt->execute()) {
    echo json_encode([
        "status"  => "success",
        "message" => "Registrazione completata",
        "user_id" => $stmt->insert_id,
        // Gettone di sessione: da qui in poi l'app parla come utente
        // riconosciuto, non come email scritta nella richiesta (19/09).
        "token"   => creaSessione($conn, $email)
    ]);
} else {
    echo json_encode(["status" => "error", "message" => "Errore SQL: " . $conn->error]);
}

$stmt->close();
$conn->close();
?>