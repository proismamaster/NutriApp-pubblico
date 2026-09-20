<?php
// get_custom_foods.php
header('Content-Type: application/json');
require 'db_config.php';
require_once 'auth.php';
require 'custom_food_columns.php'; // Elenco colonne condiviso con save_custom_food.php

if (!isset($_GET['user_mail'])) {
    echo json_encode(["status" => "error", "message" => "user_mail mancante"]);
    exit;
}

// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$user_mail = $conn->real_escape_string(emailAutenticata($conn, (string) ($_GET['user_mail'] ?? '')));

// Senza gli alimenti che l'autore ha tolto dalla libreria dopo l'approvazione
// (15/09): sono rimasti nel database pubblico, non sono piu' suoi.
$colonna = $conn->query("SHOW COLUMNS FROM na_custom_foods LIKE 'author_removed_at'");
$soloMiei = ($colonna && $colonna->num_rows > 0) ? " AND author_removed_at IS NULL" : "";

$sql = "SELECT * FROM na_custom_foods WHERE user_mail = '$user_mail'$soloMiei ORDER BY food_name ASC";
$result = $conn->query($sql);

$foods = [];
if ($result->num_rows > 0) {
    while($row = $result->fetch_assoc()) {
        // Cast dei valori numerici in double/float per il frontend.
        // FIX 2026-07-24 (bug reale): prima la condizione era una lista di 4
        // esclusioni scritte a mano, quindi veniva castato a double anche il
        // `barcode` — che tornava al client come numero e diventava
        // "8032123456789.0" una volta riconvertito in stringa lato Dart,
        // rompendo il confronto col codice a barre scansionato — e qualunque
        // colonna testuale aggiunta in seguito sarebbe arrivata come 0.
        // Ora l'elenco delle colonne testuali è esplicito e condiviso.
        foreach ($row as $key => $value) {
            if (!in_array($key, NA_CUSTOM_FOOD_TEXT_COLUMNS, true)) {
                $row[$key] = (double)$value;
            }
        }
        $foods[] = $row;
    }
}

echo json_encode(["status" => "success", "foods" => $foods]);
?>