<?php
/**
 * list_insegne.php — elenco insegne disponibili per il filtro di ricerca
 * (vedi migrations/2026-08-22_ricerca_per_insegna.sql), con quanti prodotti
 * ciascuna copre. Serve al client per popolare il menu a tendina senza tenere
 * l'elenco hardcoded — se un domani si aggiunge una nuova insegna raccolta,
 * compare qui da sola.
 */
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

require_once 'db_config.php';

$response = array("status" => "error", "message" => "Errore sconosciuto", "insegne" => array());

if (!isset($conn) || $conn->connect_error) {
    $response["message"] = "Errore di connessione al database MySQLi";
    echo json_encode($response);
    exit;
}

try {
    $sql = "SELECT insegna, COUNT(DISTINCT barcode) AS n_prodotti
            FROM na_product_retailer
            GROUP BY insegna
            ORDER BY insegna ASC";
    $result = $conn->query($sql);
    $insegne = [];
    while ($row = $result->fetch_assoc()) {
        $insegne[] = ["insegna" => $row["insegna"], "n_prodotti" => (int) $row["n_prodotti"]];
    }
    $response["status"] = "success";
    $response["message"] = count($insegne) . " insegne";
    $response["insegne"] = $insegne;
} catch (Throwable $e) {
    // Tabella non ancora importata: nessuna insegna disponibile, non un errore
    // che deve bloccare il resto dell'app (stessa logica di attachPredictedCategories
    // in search_off_products.php).
    $response["status"] = "success";
    $response["message"] = "na_product_retailer non disponibile";
    $response["insegne"] = [];
}

echo json_encode($response);
