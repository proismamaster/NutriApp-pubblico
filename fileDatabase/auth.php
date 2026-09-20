<?php
/**
 * auth.php — chi sta chiamando.
 *
 * PERCHE' ESISTE (test di release 19/09)
 * Prima ogni endpoint si fidava dell'email o dell'id scritti nella richiesta:
 * `get_user_data.php?email=<altro>` restituiva il profilo di un altro utente,
 * `update_profile.php` con lo `user_id` di un altro glielo modificava, e
 * `toggle_recipe_like.php` metteva like a nome suo. Nessuno di questi e' un
 * bug del singolo file: manca(va) il gradino prima, cioe' sapere chi chiede.
 *
 * COME SI USA
 *   require_once 'auth.php';
 *   $email = emailAutenticata($conn);   // 401 e stop se il gettone non c'e'
 * oppure, dove il vecchio parametro serve ancora per compatibilita':
 *   $email = emailAutenticata($conn, $_GET['user_mail'] ?? '');
 * che confronta i due e rifiuta se non combaciano.
 *
 * IL GETTONE
 * Arriva nell'intestazione `X-Auth-Token` (o, per i pochi posti dove non si
 * possono mandare intestazioni, nel parametro `token`). Lo crea
 * `creaSessione()` al login, alla registrazione e dopo il recupero password.
 */

declare(strict_types=1);

/** Il gettone della richiesta, '' se non c'e'. */
function gettoneRichiesta(): string
{
    $intestazioni = function_exists('getallheaders') ? getallheaders() : [];
    foreach ($intestazioni as $nome => $valore) {
        if (strtolower((string) $nome) === 'x-auth-token') {
            return trim((string) $valore);
        }
    }
    // Alcuni server non passano le intestazioni custom a PHP-CGI.
    if (!empty($_SERVER['HTTP_X_AUTH_TOKEN'])) {
        return trim((string) $_SERVER['HTTP_X_AUTH_TOKEN']);
    }
    return trim((string) ($_GET['token'] ?? $_POST['token'] ?? ''));
}

/**
 * L'utente della sessione, o null se il gettone manca o non vale piu'.
 * Aggiorna l'ultimo accesso: e' quello che tiene viva la sessione.
 */
function utenteDelGettone(mysqli $conn): ?array
{
    $token = gettoneRichiesta();
    if (strlen($token) !== 64) {
        return null;
    }
    $sql = 'SELECT u.* FROM na_sessions s
            JOIN na_users u ON u.email = s.user_mail
            WHERE s.token = ? AND s.last_seen_at >= DATE_SUB(NOW(), INTERVAL 90 DAY)
            LIMIT 1';
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return null;
    }
    $stmt->bind_param('s', $token);
    $stmt->execute();
    $riga = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$riga) {
        return null;
    }

    $tocca = $conn->prepare('UPDATE na_sessions SET last_seen_at = NOW() WHERE token = ?');
    $tocca->bind_param('s', $token);
    $tocca->execute();
    $tocca->close();
    return $riga;
}

/**
 * L'email di chi chiama. Senza gettone valido la richiesta si ferma qui con
 * 401: e' il punto in cui prima passava chiunque.
 *
 * Se [$dichiarata] non e' vuota deve combaciare con l'utente del gettone:
 * cosi' una richiesta che parla di un altro utente viene rifiutata invece di
 * essere eseguita sull'utente sbagliato.
 */
function emailAutenticata(mysqli $conn, string $dichiarata = ''): string
{
    $utente = utenteDelGettone($conn);
    if ($utente === null) {
        http_response_code(401);
        echo json_encode([
            'status' => 'error',
            'code' => 'auth_required',
            'message' => 'Sessione scaduta: accedi di nuovo.',
        ]);
        exit;
    }
    $email = (string) $utente['email'];
    if ($dichiarata !== '' && strcasecmp($dichiarata, $email) !== 0) {
        http_response_code(403);
        echo json_encode([
            'status' => 'error',
            'code' => 'auth_mismatch',
            'message' => 'Operazione non consentita su un altro account.',
        ]);
        exit;
    }
    return $email;
}

/** Come emailAutenticata, ma restituisce tutta la riga dell'utente. */
function utenteAutenticato(mysqli $conn): array
{
    $utente = utenteDelGettone($conn);
    if ($utente === null) {
        http_response_code(401);
        echo json_encode([
            'status' => 'error',
            'code' => 'auth_required',
            'message' => 'Sessione scaduta: accedi di nuovo.',
        ]);
        exit;
    }
    return $utente;
}

/** Nuovo gettone per un utente appena riconosciuto. */
function creaSessione(mysqli $conn, string $email): string
{
    $token = bin2hex(random_bytes(32));
    $stmt = $conn->prepare('INSERT INTO na_sessions (token, user_mail) VALUES (?, ?)');
    $stmt->bind_param('ss', $token, $email);
    $stmt->execute();
    $stmt->close();
    return $token;
}

/** Chiude la sessione di questo dispositivo (le altre restano). */
function chiudiSessione(mysqli $conn): void
{
    $token = gettoneRichiesta();
    if (strlen($token) !== 64) {
        return;
    }
    $stmt = $conn->prepare('DELETE FROM na_sessions WHERE token = ?');
    $stmt->bind_param('s', $token);
    $stmt->execute();
    $stmt->close();
}
