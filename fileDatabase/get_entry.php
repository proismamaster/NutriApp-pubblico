<?php
/**
 * get_entry.php — le voci del diario di un utente.
 *
 * FILTRO DI DATE (test di release 19/09)
 * Prima restituiva SEMPRE tutto lo storico, e la Home lo richiede a ogni
 * aggiornamento: dopo qualche mese di diario sono migliaia di righe da una
 * sessantina di colonne, a ogni cambio di giorno e a ogni ritorno da una
 * schermata. Ora chi sa quali giorni gli servono li chiede con `from` e `to`
 * (AAAA-MM-GG, estremi inclusi); senza parametri risponde come prima, cosi'
 * le versioni vecchie dell'app continuano a funzionare.
 */

require 'db_config.php';
require_once 'auth.php';

header('Content-Type: application/json; charset=utf-8');

// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$user_mail = emailAutenticata($conn, (string) ($_GET['user_mail'] ?? ''));
if ($conn->connect_error) {
    die(json_encode(["error" => "Connesione fallita"]));
}

$da = trim((string) ($_GET['from'] ?? ''));
$a = trim((string) ($_GET['to'] ?? ''));
$valida = static function (string $d) {
    return (bool) preg_match('/^\d{4}-\d{2}-\d{2}$/', $d);
};

$sql = "SELECT * FROM na_nutri_entries WHERE user_mail = ?";
$tipi = "s";
$parametri = [$user_mail];
if ($valida($da)) {
    $sql .= " AND DATE(entry_date) >= ?";
    $tipi .= "s";
    $parametri[] = $da;
}
if ($valida($a)) {
    $sql .= " AND DATE(entry_date) <= ?";
    $tipi .= "s";
    $parametri[] = $a;
}
$sql .= " ORDER BY entry_date DESC";

$stmt = $conn->prepare($sql);
$stmt->bind_param($tipi, ...$parametri);
$stmt->execute();
$result = $stmt->get_result();

//array vuoto
$entries = [];
//ciclo ogni riga
while ($row = $result->fetch_assoc()) {
    //aggiunge una riga (che è gia chiave-valore) all'array
    $entries[] = $row;
}

//trasformo in json
echo json_encode($entries);
$stmt->close();
$conn->close();
