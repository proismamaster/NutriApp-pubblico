<?php
require 'db_config.php';
require_once 'auth.php';

$id = (int) ($_GET["id"] ?? 0);
// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$user_mail = emailAutenticata($conn, (string) ($_GET["user_mail"] ?? ''));

/*
 * UNA RICETTA APPROVATA E' DEL DATABASE (2026-09-15): stessa regola degli
 * alimenti, vedi delete_custom_food.php. Se l'autore la cancella sparisce dalle
 * sue ricette e resta in "Consigliate"; se non era approvata si cancella.
 */
$colonna = $conn->query("SHOW COLUMNS FROM na_recipes LIKE 'author_removed_at'");
$haRimozione = $colonna && $colonna->num_rows > 0;

if ($haRimozione) {
    $stmt = $conn->prepare(
        'UPDATE na_recipes SET author_removed_at = NOW()
          WHERE id = ? AND user_mail = ? AND shared_status = "approved" AND author_removed_at IS NULL'
    );
    $stmt->bind_param("is", $id, $user_mail);
    $stmt->execute();
    $tolta = $stmt->affected_rows > 0;
    $stmt->close();
    if ($tolta) {
        echo json_encode([
            "status" => "success",
            "message" => "Ricetta tolta dalle tue. Resta pubblica in Consigliate.",
            "kept_public" => true,
        ]);
        $conn->close();
        exit;
    }
}

$sql = "DELETE FROM na_recipes WHERE id = ? AND user_mail = ?" . ($haRimozione ? " AND author_removed_at IS NULL" : "");

$stmt = $conn->prepare($sql);
$stmt->bind_param("is", $id, $user_mail);

if($stmt->execute()){
    // MODIFICA QUI: usiamo affected_rows invece di num_rows
    if($stmt->affected_rows > 0){
        echo json_encode(["status" => "success", "message" => "Ricetta eliminata", "kept_public" => false]);
    } else {
        echo json_encode(["status" => "error", "message" => "Ricetta non trovata o non autorizzato"]);
    }
} else{
    echo json_encode(["status" => "error", "message" => "Errore SQL: " . $conn->error]);
}
$stmt->close();
$conn->close();
?>
