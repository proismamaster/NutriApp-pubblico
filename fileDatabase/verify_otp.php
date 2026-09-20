<?php
// verify_otp.php
require 'db_config.php';

$email = $_POST['email'] ?? '';
$otp   = $_POST['otp'] ?? '';

if (empty($email) || empty($otp)) {
    echo json_encode(["status" => "error", "message" => "Dati mancanti"]);
    exit;
}

// Verifica se il codice esiste ed è valido (non scaduto)
$stmt = $conn->prepare("SELECT id FROM na_otp_codes WHERE email = ? AND code = ? AND expires_at > CURRENT_TIMESTAMP");
$stmt->bind_param("ss", $email, $otp);
$stmt->execute();
$stmt->store_result();

if ($stmt->num_rows > 0) {
    // Codice valido, lo eliminiamo per evitare riutilizzi
    $del = $conn->prepare("DELETE FROM na_otp_codes WHERE email = ?");
    $del->bind_param("s", $email);
    $del->execute();
    $del->close();

    echo json_encode(["status" => "success", "message" => "Codice verificato correttamente"]);
} else {
    echo json_encode(["status" => "error", "message" => "Codice non valido o scaduto"]);
}

$stmt->close();
$conn->close();
?>
