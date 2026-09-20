<?php
require 'db_config.php';
require_once 'auth.php';

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

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Identita' dal gettone di sessione, non dal parametro: chiunque poteva
    // indicare l'email di un altro utente (test di release 19/09).
    $user_id = (int) utenteAutenticato($conn)['id'];
    $first_name = $_POST['first_name'] ?? null;
    $last_name = $_POST['last_name'] ?? null;
    $height = $_POST['height'] ?? null;
    $gender = $_POST['gender'] ?? null;
    $birth_date = $_POST['birth_date'] ?? null;
    $profile_image = $_POST['profile_image'] ?? null;

    if (!$user_id) {
        echo json_encode(["status" => "error", "message" => "ID utente mancante"]);
        exit;
    }

    $fuoriLimiti = nutriappFuoriLimiti(null, $height, $birth_date);
    if ($fuoriLimiti !== null) {
        echo json_encode(["status" => "error", "message" => $fuoriLimiti]);
        exit;
    }

    if ($profile_image !== null) {
        $sql = "UPDATE na_users SET first_name = ?, last_name = ?, height = ?, gender = ?, birth_date = ?, profile_image = ? WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("ssdsssi", $first_name, $last_name, $height, $gender, $birth_date, $profile_image, $user_id);
    } else {
        $sql = "UPDATE na_users SET first_name = ?, last_name = ?, height = ?, gender = ?, birth_date = ? WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("ssdssi", $first_name, $last_name, $height, $gender, $birth_date, $user_id);
    }

    if ($stmt->execute()) {
        echo json_encode(["status" => "success", "message" => "Profilo aggiornato con successo"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Errore durante l'aggiornamento: " . $conn->error]);
    }

    $stmt->close();
    $conn->close();
} else {
    echo json_encode(["status" => "error", "message" => "Metodo non consentito"]);
}
?>