<?php
header('Content-Type: application/json');

// Le credenziali DB NON vanno mai hardcoded qui (vedi vault NutriApp,
// PROBLEMS.md: le vecchie credenziali erano in chiaro nel sorgente e sono
// da considerare compromesse). Ordine di risoluzione:
//   1) variabili d'ambiente DB_HOST / DB_USER / DB_PASSWORD / DB_NAME
//   2) fileDatabase/db_config.local.php (escluso da git), se presente
// Vedi db_config.example.php per il formato del file locale.

$servername = getenv('DB_HOST') ?: null;
$username   = getenv('DB_USER') ?: null;
$password   = getenv('DB_PASSWORD') ?: null;
$dbname     = getenv('DB_NAME') ?: null;

$localConfig = __DIR__ . '/db_config.local.php';
if ((!$servername || !$username || !$password || !$dbname) && file_exists($localConfig)) {
    require $localConfig; // deve definire $servername, $username, $password, $dbname
}

if (!$servername || !$username || !$password || !$dbname) {
    http_response_code(500);
    die(json_encode([
        "status" => "error",
        "message" => "Configurazione database mancante: impostare le variabili d'ambiente DB_HOST/DB_USER/DB_PASSWORD/DB_NAME sull'hosting, oppure creare fileDatabase/db_config.local.php a partire da db_config.example.php.",
    ]));
}

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "Connessione fallita: " . $conn->connect_error]));
}

// Senza set_charset esplicito, mysqli usa il charset di default del server
// MySQL/MariaDB (spesso latin1 su hosting condiviso datati), indipendente da
// quello delle singole tabelle: puo' causare confronti/LIKE sbagliati su
// caratteri accentati anche quando la tabella e' utf8mb4. Va dichiarato qui,
// una volta sola, per tutti gli script che includono questo file.
$conn->set_charset('utf8mb4');
?>