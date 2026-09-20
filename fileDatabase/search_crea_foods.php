<?php
// search_crea_foods.php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

// Includi il file di configurazione ESATTO usato dagli altri script
require_once 'db_config.php'; 

$response = array("status" => "error", "message" => "Errore sconosciuto", "foods" => array());

if (!isset($_GET['query']) || empty(trim($_GET['query']))) {
    $response["message"] = "Query mancante";
    echo json_encode($response);
    exit;
}

$query = trim($_GET['query']);

// Usiamo $conn che proviene da db_config.php (MySQLi)
if (!isset($conn) || $conn->connect_error) {
    $response["message"] = "Errore di connessione al database MySQLi";
    echo json_encode($response);
    exit;
}

// Esegue una ricerca su na_local_db in modalità AND (tutte le parole devono
// comparire nel nome) o OR (basta una parola), ordinando per rilevanza invece
// di affidarsi all'ordine di inserimento della tabella. Nessun indice FULLTEXT
// richiesto: funziona anche senza modifiche allo schema del DB.
function runFoodSearch($conn, array $words, string $fullQuery, string $mode) {
    if (empty($words)) {
        $words = [$fullQuery];
    }

    $conditions = [];
    $types = "";
    $params = [];
    foreach ($words as $word) {
        $conditions[] = "food_name LIKE ?";
        $types .= "s";
        $params[] = "%" . $word . "%";
    }
    $glue = ($mode === 'OR') ? ' OR ' : ' AND ';
    $whereClause = implode($glue, $conditions);

    // Ordinamento per rilevanza: match esatto prima, poi nomi che iniziano
    // con la query, poi nomi più corti (di solito più generici/pertinenti).
    // Tetto di sicurezza alto invece di un numero basso arbitrario (richiesta
    // 2026-07-24: "niente limite ma tutto ordinato"), stesso ragionamento di
    // search_off_products.php.
    $sql = "SELECT * FROM na_local_db
            WHERE ($whereClause)
            ORDER BY
                (food_name = ?) DESC,
                (food_name LIKE ?) DESC,
                LENGTH(food_name) ASC
            LIMIT 300";
    $types .= "ss";
    $params[] = $fullQuery;
    $params[] = $fullQuery . "%";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return ["error" => $conn->error, "foods" => []];
    }

    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();

    $foods = [];
    while ($row = $result->fetch_assoc()) {
        $foods[] = $row;
    }
    $stmt->close();
    return ["error" => null, "foods" => $foods];
}

try {
    // Solo le parole "significative" (>2 caratteri) partecipano al match,
    // come nella versione precedente.
    $searchWords = array_values(array_filter(
        array_map('trim', explode(" ", $query)),
        fn($w) => strlen($w) > 2
    ));

    // 1. Tentativo con match AND rigido (tutte le parole devono comparire)
    $resultAnd = runFoodSearch($conn, $searchWords, $query, 'AND');

    if ($resultAnd["error"] !== null) {
        $response["message"] = "Errore preparazione query: " . $resultAnd["error"];
    } elseif (!empty($resultAnd["foods"])) {
        $response["status"] = "success";
        $response["message"] = count($resultAnd["foods"]) . " risultati trovati";
        $response["foods"] = $resultAnd["foods"];
    } else {
        // 2. Fallback: l'AND rigido non ha trovato nulla, riprova in OR
        // (basta che una parola compaia) prima di arrenderci.
        $resultOr = runFoodSearch($conn, $searchWords, $query, 'OR');
        if ($resultOr["error"] !== null) {
            $response["message"] = "Errore preparazione query: " . $resultOr["error"];
        } else {
            $response["status"] = "success";
            $response["message"] = count($resultOr["foods"]) . " risultati trovati (fallback OR)";
            $response["foods"] = $resultOr["foods"];
        }
    }

} catch (Exception $e) {
    $response["message"] = "Errore: " . $e->getMessage();
}

echo json_encode($response);
?>
