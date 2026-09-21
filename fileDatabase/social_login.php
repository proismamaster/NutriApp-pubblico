<?php
// social_login.php
require 'db_config.php';
require_once 'auth.php';
require_once 'verifica_social.php';

// Leggi il body JSON
$input = json_decode(file_get_contents('php://input'), true);

$provider    = $input['provider'] ?? '';
$id_token    = $input['id_token'] ?? '';
$first_name  = $input['first_name'] ?? '';
$last_name   = $input['last_name'] ?? '';

// Apple: l'accesso resta chiuso finche' non c'e' l'account sviluppatore,
// perche' senza quello il suo token non e' verificabile. Aperto senza
// verifica sarebbe una porta di servizio per entrare come chiunque.
if ($provider !== 'google') {
    http_response_code(400);
    echo json_encode([
        "status"  => "error",
        "code"    => $provider === 'apple' ? 'apple_non_configurato' : 'provider_non_valido',
        "message" => "Accesso con $provider non disponibile.",
    ]);
    exit;
}

// L'identita' esce dal token firmato da Google, non da cio' che manda il
// client: e' tutta la differenza fra un accesso e una dichiarazione.
$verifica = verificaTokenGoogle((string) $id_token);
if (is_string($verifica)) {
    http_response_code($verifica === 'verifica_non_disponibile' ? 503 : 401);
    echo json_encode([
        "status"  => "error",
        "code"    => $verifica,
        "message" => $verifica === 'verifica_non_disponibile'
            ? "Non riesco a verificare l'accesso con Google. Riprova."
            : "Accesso con Google rifiutato.",
    ]);
    exit;
}

$email       = $verifica['email'];
$provider_id = $verifica['sub'];
// Nome e cognome: quelli del token valgono piu' di quelli del client, ma
// Google non li manda sempre.
if ($verifica['nome'] !== '') {
    $first_name = $verifica['nome'];
}
if ($verifica['cognome'] !== '') {
    $last_name = $verifica['cognome'];
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
