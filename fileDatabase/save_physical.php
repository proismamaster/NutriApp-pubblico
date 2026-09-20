<?php
/**
 * save_physical.php — registra il peso (e, se ci sono, altezza e massa grassa)
 * di un giorno.
 *
 * PERCHE' ESISTE (test di release 19/09): l'app lo chiamava da sempre — il +/-
 * del peso in Home e il grafico dell'andamento a sette giorni — ma il file non
 * era mai stato scritto. Ogni pesata rispondeva 404, lo storico restava vuoto
 * e il trend non compariva mai.
 *
 * Una riga per utente e per giorno: pesarsi due volte nello stesso giorno
 * aggiorna la riga, non ne aggiunge una seconda.
 */

declare(strict_types=1);
require 'db_config.php';
require_once 'auth.php';

header('Content-Type: application/json; charset=utf-8');

$dati = json_decode(file_get_contents('php://input'), true);
if (!is_array($dati)) {
    $dati = $_POST;
}

// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$email = emailAutenticata($conn, trim((string) ($dati['user_email'] ?? $dati['user_mail'] ?? '')));
$data = trim((string) ($dati['date'] ?? ''));
$peso = (float) ($dati['weight'] ?? 0);

if ($email === '' || $peso <= 0) {
    echo json_encode(['status' => 'error', 'message' => 'Dati mancanti.', 'code' => 'missing_data']);
    exit;
}
// Data assente o scritta male: si registra oggi, non una riga senza data.
if ($data === '' || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $data)) {
    $data = date('Y-m-d');
}

$altezza = isset($dati['height']) && $dati['height'] !== null ? (float) $dati['height'] : null;
$grasso = isset($dati['body_fat']) && $dati['body_fat'] !== null ? (float) $dati['body_fat'] : null;

$sql = 'INSERT INTO na_physical_measurements (user_mail, measured_on, weight, height, body_fat)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE weight = VALUES(weight), height = VALUES(height), body_fat = VALUES(body_fat)';
$stmt = $conn->prepare($sql);
if (!$stmt) {
    echo json_encode(['status' => 'error', 'message' => $conn->error, 'code' => 'sql_error']);
    exit;
}
$stmt->bind_param('ssddd', $email, $data, $peso, $altezza, $grasso);

if ($stmt->execute()) {
    echo json_encode(['status' => 'success', 'message' => 'Misurazione salvata.']);
} else {
    echo json_encode(['status' => 'error', 'message' => $stmt->error, 'code' => 'sql_error']);
}
$stmt->close();
$conn->close();
