<?php
// delete_custom_food.php
header('Content-Type: application/json');
require 'db_config.php';
require_once 'auth.php';

// Supporto sia per POST JSON che per parametri query
$data = json_decode(file_get_contents('php://input'), true);
$id = isset($data['id']) ? (int)$data['id'] : (isset($_REQUEST['id']) ? (int)$_REQUEST['id'] : null);
// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$user_mail = emailAutenticata($conn);

if (!$id || !$user_mail) {
    echo json_encode(["status" => "error", "message" => "ID o Email mancanti"]);
    exit;
}

/*
 * UN ALIMENTO APPROVATO E' DEL DATABASE (2026-09-15, decisione di Ismail).
 *
 * Una volta approvato, l'alimento sta nella ricerca di tutti e magari nelle
 * ricette di altri. Se l'autore lo cancella, sparisce solo dalla SUA libreria
 * (`author_removed_at`): la riga resta, pubblica. Un alimento non approvato
 * invece si cancella davvero, perche' non e' di nessun altro.
 *
 * La colonna si controlla prima di usarla: su un server senza la migrazione
 * del 15/09 la cancellazione resta quella di sempre.
 */
$colonna = $conn->query("SHOW COLUMNS FROM na_custom_foods LIKE 'author_removed_at'");
$haRimozione = $colonna && $colonna->num_rows > 0;

if ($haRimozione) {
    $stmt = $conn->prepare(
        'UPDATE na_custom_foods SET author_removed_at = NOW()
          WHERE id = ? AND user_mail = ? AND shared_status = "approved" AND author_removed_at IS NULL'
    );
    $stmt->bind_param('is', $id, $user_mail);
    $stmt->execute();
    $tolto = $stmt->affected_rows > 0;
    $stmt->close();
    if ($tolto) {
        echo json_encode([
            "status" => "success",
            "message" => "Alimento tolto dalla tua libreria. Resta nel database pubblico.",
            "kept_public" => true,
        ]);
        exit;
    }
}

$stmt = $conn->prepare(
    'DELETE FROM na_custom_foods WHERE id = ? AND user_mail = ?' . ($haRimozione ? ' AND author_removed_at IS NULL' : '')
);
$stmt->bind_param('is', $id, $user_mail);

if ($stmt->execute()) {
    if ($stmt->affected_rows > 0) {
        echo json_encode(["status" => "success", "message" => "Alimento eliminato", "kept_public" => false]);
    } else {
        echo json_encode(["status" => "error", "message" => "Alimento non trovato o non autorizzato"]);
    }
} else {
    echo json_encode(["status" => "error", "message" => $stmt->error]);
}
$stmt->close();
?>
