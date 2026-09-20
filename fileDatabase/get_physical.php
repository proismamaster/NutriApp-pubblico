<?php
/**
 * get_physical.php — lo storico delle pesate di un utente, dalla piu' vecchia
 * alla piu' recente.
 *
 * Serve al grafico del peso e al confronto con sette giorni fa in Home. Come
 * save_physical.php, mancava del tutto: l'app riceveva 404 a ogni
 * aggiornamento della Home (test di release 19/09).
 *
 * Restituisce una lista semplice, nella forma che PhysicalMeasurement.fromJson
 * si aspetta: date, weight, height, body_fat.
 */

declare(strict_types=1);
require 'db_config.php';
require_once 'auth.php';

header('Content-Type: application/json; charset=utf-8');

// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$email = emailAutenticata($conn, trim((string) ($_GET['user_email'] ?? $_GET['user_mail'] ?? '')));
if ($email === '') {
    echo json_encode([]);
    exit;
}

// Un anno di pesate basta a ogni grafico dell'app: senza limite lo storico
// cresce all'infinito e viaggia intero a ogni apertura della Home.
$sql = 'SELECT measured_on, weight, height, body_fat
        FROM na_physical_measurements
        WHERE user_mail = ? AND measured_on >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
        ORDER BY measured_on ASC';
$stmt = $conn->prepare($sql);
if (!$stmt) {
    echo json_encode([]);
    exit;
}
$stmt->bind_param('s', $email);
$stmt->execute();
$res = $stmt->get_result();

$misure = [];
while ($riga = $res->fetch_assoc()) {
    $misure[] = [
        'date' => $riga['measured_on'],
        'weight' => (float) $riga['weight'],
        'height' => $riga['height'] === null ? null : (float) $riga['height'],
        'body_fat' => $riga['body_fat'] === null ? null : (float) $riga['body_fat'],
    ];
}

echo json_encode($misure);
$stmt->close();
$conn->close();
