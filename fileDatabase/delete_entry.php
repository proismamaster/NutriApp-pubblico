<?php
require 'db_config.php';
require_once 'auth.php';

$id = $_GET["id"];
// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$user_mail = emailAutenticata($conn, (string) ($_GET["user_mail"] ?? ''));
$sql = "DELETE FROM na_nutri_entries WHERE id = ? AND user_mail = ?";

$stmt = $conn->prepare($sql);
$stmt->bind_param("is", $id, $user_mail);

if($stmt->execute()){
    if($stmt->affected_rows > 0){
        echo json_encode(["status" => "success", "message" => "Alimento eliminato"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Alimento non trovato o già eliminato"]);
    }
} else{
    echo json_encode(["status" => "error", "message" => "Errore SQL: " . $conn->error]);
} 
$stmt->close();
$conn->close();
?>