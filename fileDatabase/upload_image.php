<?php
/**
 * upload_image.php — riceve una foto dall'app e la salva sul server,
 * restituendo l'indirizzo pubblico da mettere in `image_url`.
 *
 * PERCHE' ESISTE (2026-09-05)
 * Le foto scelte dalla galleria venivano codificate in base64 e infilate
 * dentro la colonna `image_url`. Sembrava la strada piu' corta perche' l'app
 * gia' fa cosi' con la foto profilo, ma su una ricetta si e' rotta subito:
 * "Error saving recipe". Le ragioni sono strutturali, non un dettaglio da
 * aggiustare:
 *   - una foto anche compressa supera di molto i 500 caratteri della colonna;
 *   - allargare la colonna sposta solo il problema: ogni lettura dell'elenco
 *     ricette si sarebbe portata dietro tutte le immagini, in ogni richiesta;
 *   - il corpo POST supera facilmente i limiti PHP di default
 *     (post_max_size), e l'errore che ne esce non dice cosa e' successo.
 * Con un file vero sul disco, `image_url` torna a contenere un indirizzo
 * corto, l'elenco resta leggero e le immagini le serve il web server.
 *
 * SICUREZZA
 *  - accetta solo immagini vere: il tipo viene dedotto dal CONTENUTO con
 *    getimagesize(), non dal nome del file ne' dal Content-Type dichiarato;
 *  - il nome del file lo decide il server (casuale + estensione dedotta):
 *    niente path scelti dal client, quindi niente scritture fuori cartella;
 *  - estensione da una lista chiusa: nessun .php puo' finire nella cartella
 *    servita, che e' il modo classico di trasformare un upload in esecuzione
 *    di codice.
 *
 * RICHIEDE una cartella `uploads/` scrivibile accanto a questo file. Se non
 * esiste prova a crearla; se non ci riesce lo dice invece di fallire a meta'.
 */

require 'db_config.php';
require_once 'auth.php';

header('Content-Type: application/json');

/** Estensione ammessa per ogni tipo riconosciuto da getimagesize(). */
const NA_TIPI_IMMAGINE = [
    IMAGETYPE_JPEG => 'jpg',
    IMAGETYPE_PNG  => 'png',
    IMAGETYPE_WEBP => 'webp',
];

/** Dimensione massima accettata: oltre, e' quasi certamente un errore. */
const NA_MAX_BYTE = 8 * 1024 * 1024;

function na_errore(string $messaggio, int $codice = 400): void {
    http_response_code($codice);
    echo json_encode(['status' => 'error', 'message' => $messaggio]);
    exit;
}

// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$user_mail = emailAutenticata($conn, (string) ($_POST['user_mail'] ?? ''));
if ($user_mail === '') {
    na_errore('Utente mancante');
}

if (!isset($_FILES['image']) || !is_uploaded_file($_FILES['image']['tmp_name'])) {
    na_errore('Nessun file ricevuto');
}

$file = $_FILES['image'];
if ($file['error'] !== UPLOAD_ERR_OK) {
    // I codici di PHP da soli non dicono niente a chi legge la risposta.
    $spiegazione = [
        UPLOAD_ERR_INI_SIZE => 'File troppo grande per la configurazione del server (upload_max_filesize)',
        UPLOAD_ERR_FORM_SIZE => 'File troppo grande',
        UPLOAD_ERR_PARTIAL => 'Caricamento interrotto a meta\'',
        UPLOAD_ERR_NO_TMP_DIR => 'Manca la cartella temporanea sul server',
        UPLOAD_ERR_CANT_WRITE => 'Il server non riesce a scrivere il file temporaneo',
    ];
    na_errore($spiegazione[$file['error']] ?? 'Errore di caricamento (' . $file['error'] . ')');
}

if ($file['size'] > NA_MAX_BYTE) {
    na_errore('Immagine troppo grande: massimo 8 MB');
}

// Il tipo si deduce dal contenuto, non da cio' che dichiara il client.
$info = @getimagesize($file['tmp_name']);
if ($info === false || !isset(NA_TIPI_IMMAGINE[$info[2]])) {
    na_errore('Il file non e\' un\'immagine valida (ammessi JPEG, PNG, WebP)');
}
$estensione = NA_TIPI_IMMAGINE[$info[2]];

$cartella = __DIR__ . '/uploads';
if (!is_dir($cartella) && !@mkdir($cartella, 0755, true)) {
    na_errore('Cartella uploads/ mancante e non creabile sul server', 500);
}
if (!is_writable($cartella)) {
    na_errore('Cartella uploads/ non scrivibile: servono i permessi di scrittura', 500);
}

// Nome deciso dal server: casuale, piu' un pezzo di hash dell'utente per
// tenere insieme le foto di una stessa persona senza esporne l'email.
$nome = bin2hex(random_bytes(16)) . '_' . substr(sha1($user_mail), 0, 8) . '.' . $estensione;
$destinazione = $cartella . '/' . $nome;

if (!move_uploaded_file($file['tmp_name'], $destinazione)) {
    na_errore('Impossibile salvare il file sul server', 500);
}
@chmod($destinazione, 0644);

// Indirizzo pubblico, ricavato da dove sta questo script: cosi' continua a
// funzionare se un giorno la cartella nutriapp/ cambia posizione.
$schema = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$base = $schema . '://' . ($_SERVER['HTTP_HOST'] ?? 'progetti.galileicrema.org');
$percorso = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? '/nutriapp/upload_image.php'), '/');

echo json_encode([
    'status' => 'success',
    'url' => $base . $percorso . '/uploads/' . $nome,
]);
