<?php
// social_login.php
require 'db_config.php';
require_once 'auth.php';

// Leggi il body JSON
$input = json_decode(file_get_contents('php://input'), true);

$email       = $input['email'] ?? '';
$provider    = $input['provider'] ?? '';
$provider_id = $input['provider_id'] ?? '';
$first_name  = $input['first_name'] ?? '';
$last_name   = $input['last_name'] ?? '';

if (empty($email)) {
    echo json_encode(["status" => "error", "message" => "Email mancante"]);
    exit;
}

// Controlla se l'utente esiste già
$stmt = $conn->prepare("SELECT * FROM na_users WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($user = $result->fetch_assoc()) {
    // Utente esiste, lo restituiamo
    unset($user['password_hash']);
    echo json_encode([
        "status" => "success",
        "message" => "Login effettuato",
        "is_new" => false,
        "token" => creaSessione($conn, (string) $user['email']),
        "user_data" => $user
    ]);
} else {
    // Utente non esiste, lo creiamo
    // Generiamo una password casuale hashata (non verrà usata)
    $dummy_password = password_hash(bin2hex(random_bytes(16)), PASSWORD_BCRYPT);
    
    $stmt_ins = $conn->prepare("INSERT INTO na_users (email, password_hash, first_name, last_name) VALUES (?, ?, ?, ?)");
    $stmt_ins->bind_param("ssss", $email, $dummy_password, $first_name, $last_name);
    
    if ($stmt_ins->execute()) {
        $new_id = $stmt_ins->insert_id;
        
        // Recupera i dati appena inseriti
        $stmt_get = $conn->prepare("SELECT * FROM na_users WHERE id = ?");
        $stmt_get->bind_param("i", $new_id);
        $stmt_get->execute();
        $new_user = $stmt_get->get_result()->fetch_assoc();
        unset($new_user['password_hash']);
        
        echo json_encode([
            "status" => "success",
            "message" => "Account creato tramite $provider",
            "is_new" => true,
            "token" => creaSessione($conn, (string) $new_user['email']),
            "user_data" => $new_user
        ]);
        $stmt_get->close();
    } else {
        echo json_encode(["status" => "error", "message" => "Errore creazione utente: " . $conn->error]);
    }
    $stmt_ins->close();
}

$stmt->close();
$conn->close();
?>
