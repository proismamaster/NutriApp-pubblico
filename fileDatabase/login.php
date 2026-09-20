<?php
/**
 * login.php — accesso con email e password.
 *
 * DUE COSE CAMBIATE DOPO IL TEST DI RELEASE DEL 19/09
 *  - risponde con un GETTONE di sessione (vedi auth.php): da qui in poi gli
 *    altri endpoint sanno chi chiede invece di fidarsi dell'email scritta
 *    nella richiesta;
 *  - un solo messaggio per email sconosciuta e password sbagliata. Prima
 *    erano due ("Nessun account trovato con questa email." e "Password
 *    errata.") e bastavano a sapere quali email sono registrate.
 */

require 'db_config.php';
require_once 'auth.php';

header('Content-Type: application/json; charset=utf-8');

$jsonData = file_get_contents('php://input');
$data = json_decode($jsonData, true);

if (!isset($data['email']) || !isset($data['password'])) {
    die(json_encode(["status" => "error", "code" => "missing_fields", "message" => "Email e password mancanti."]));
}

$email = $data['email'];
$password = $data['password'];
$generico = ["status" => "error", "code" => "bad_credentials", "message" => "Email o password non validi."];

$sql = "SELECT * FROM na_users WHERE email = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($row = $result->fetch_assoc()) {
    if (password_verify($password, $row['password_hash'])) {
        // Rimuoviamo la password hash prima di inviare i dati all'app per sicurezza
        unset($row['password_hash']);

        echo json_encode([
            "status" => "success",
            "message" => "Login effettuato",
            "token" => creaSessione($conn, (string) $row['email']),
            "user_data" => $row
        ]);
    } else {
        echo json_encode($generico);
    }
} else {
    // Stesso tempo speso anche senza account, cosi' non si distingue a
    // cronometro un'email registrata da una che non lo e'.
    password_verify($password, '$2y$10$usurpatoreusurpatoreusurpatoreusurpatoreusurpat');
    echo json_encode($generico);
}

$stmt->close();
$conn->close();
