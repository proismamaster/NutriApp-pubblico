<?php
/**
 * community_comune.php — pezzi condivisi dai quattro endpoint della
 * collaborazione fra utenti (segnalazioni, condivisione alimenti, ricette
 * pubbliche).
 *
 * ATTENZIONE A CHI CARICA I FILE VIA FTP: questo file e' un `require` di
 * save_food_report.php, set_sharing_preference.php, share_custom_food.php,
 * share_recipe.php e get_public_recipes.php. Se non viene caricato, quei
 * cinque endpoint rispondono un messaggio che lo dice (vedi
 * `communityRichiediFile`), non un HTTP 500 muto — e' la lezione del 07/09,
 * quando `recipe_ingredient_columns.php` rimasto a terra ha fatto perdere tre
 * sessioni a cercare colonne che c'erano.
 *
 * Richiede la migrazione fileDatabase/migrations/2026-09-12_collaborazione_community.sql.
 */

/** Stati ammessi per la visibilita' di un contenuto dell'utente. */
const NA_STATI_CONDIVISIONE = ['private', 'pending', 'approved', 'rejected'];

/** Tipi di problema segnalabili su un alimento (lista chiusa: si contano). */
const NA_TIPI_SEGNALAZIONE = ['valori', 'nome', 'categoria', 'immagine', 'duplicato', 'altro'];

/**
 * Intestazione JSON + rete di sicurezza sugli errori fatali.
 *
 * Perche' 200 e non 500: il client legge il messaggio dal corpo, e con un 500
 * lo scarterebbe mostrando "errore" senza dire quale. Stessa scelta di
 * save_recipe.php, da cui questo blocco e' preso.
 */
function communityAvvia(): void {
    header('Content-Type: application/json; charset=utf-8');
    register_shutdown_function(function () {
        $e = error_get_last();
        if ($e === null || !in_array($e['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR], true)) {
            return;
        }
        http_response_code(200);
        echo json_encode([
            'status'  => 'error',
            'message' => 'Errore fatale PHP: ' . $e['message'] . ' (' . basename($e['file']) . ':' . $e['line'] . ')',
        ]);
    });
}

/**
 * Percorso di un file obbligatorio, o messaggio chiaro se non c'e'.
 *
 * NON fa il require: restituisce il percorso. Il `require` deve stare al
 * livello principale di chi chiama, altrimenti le variabili del file incluso
 * (cioe' $conn) nascono e muoiono dentro questa funzione — errore vero fatto
 * il 07/09 e costato un'altra sessione.
 */
function communityRichiediFile(string $nome): string {
    $percorso = __DIR__ . '/' . $nome;
    if (!is_file($percorso)) {
        http_response_code(200);
        echo json_encode([
            'status'  => 'error',
            'message' => "File mancante sul server: $nome — va caricato via FTP nella stessa cartella di questo script.",
        ]);
        exit;
    }
    return $percorso;
}

/** Chiude la risposta con un esito negativo e ferma lo script. */
function communityErrore(string $messaggio, array $extra = []): void {
    echo json_encode(array_merge(['status' => 'error', 'message' => $messaggio], $extra));
    exit;
}

/** Chiude la risposta con un esito positivo e ferma lo script. */
function communityOk(array $dati = []): void {
    echo json_encode(array_merge(['status' => 'success'], $dati));
    exit;
}

/**
 * Corpo della richiesta come array.
 *
 * Accetta sia JSON (quello che manda l'app) sia un POST di form, perche'
 * provare un endpoint a mano con curl -d e' la prima cosa che si fa quando
 * qualcosa non va.
 */
function communityCorpo(): array {
    $grezzo = file_get_contents('php://input');
    $dati = json_decode($grezzo ?: '', true);
    if (is_array($dati)) {
        return $dati;
    }
    return $_POST ?: [];
}

/** Solo POST: una scrittura non si fa con una GET, che i browser rifanno da soli. */
function communitySoloPost(): void {
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
        communityErrore('Metodo non consentito: serve POST.');
    }
}

/**
 * Verifica che l'utente esista davvero.
 *
 * PERCHE' NON BASTA L'EMAIL NEL CORPO: questi endpoint scrivono righe a nome
 * di qualcuno. Senza questo controllo una email inventata creerebbe
 * segnalazioni che nessuno potra' mai ricondurre a un account (e la colonna e'
 * un varchar, non una chiave esterna, quindi il database non lo impedisce).
 * Non e' autenticazione — quella manca in tutto il progetto, vedi PROBLEMS —
 * ma e' il minimo perche' i dati restino collegabili.
 */
function communityUtenteEsiste(mysqli $conn, string $email): bool {
    $stmt = $conn->prepare('SELECT 1 FROM na_users WHERE email = ? LIMIT 1');
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $esiste = (bool) $stmt->get_result()->fetch_row();
    $stmt->close();
    return $esiste;
}

/**
 * Vero se la tabella/colonna esiste: gli endpoint devono funzionare anche su
 * un server ancora indietro con le migrazioni, dicendolo invece di morire.
 * Stessa idea del "server indietro rispetto all'app" gia' provata per le
 * ricette l'08/09.
 */
function communityColonnaEsiste(mysqli $conn, string $tabella, string $colonna): bool {
    $stmt = $conn->prepare(
        'SELECT 1 FROM information_schema.COLUMNS
          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ? LIMIT 1'
    );
    $stmt->bind_param('ss', $tabella, $colonna);
    $stmt->execute();
    $esiste = (bool) $stmt->get_result()->fetch_row();
    $stmt->close();
    return $esiste;
}

/** Ferma lo script con un messaggio utile se la migrazione non e' stata eseguita. */
function communityRichiediMigrazione(mysqli $conn, string $tabella, string $colonna): void {
    if (!communityColonnaEsiste($conn, $tabella, $colonna)) {
        communityErrore(
            "Migrazione mancante: $tabella non ha la colonna $colonna. " .
            'Eseguire fileDatabase/migrations/2026-09-12_collaborazione_community.sql su phpMyAdmin.'
        );
    }
}
