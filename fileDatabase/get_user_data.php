<?php
require 'db_config.php';
require_once 'auth.php';

if (!isset($_GET['email'])) {
    die(json_encode(["status" => "error", "message" => "Email mancante."]));
}

// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$email = emailAutenticata($conn, (string) ($_GET['email'] ?? ''));

$sql = "SELECT * FROM na_users WHERE email = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($row = $result->fetch_assoc()) {
    unset($row['password_hash']); // Non inviamo mai la password
    echo json_encode(["status" => "success", "data" => $row]);
} else {
    echo json_encode(["status" => "error", "message" => "Utente non trovato."]);
}

$stmt->close();
$conn->close();
?>