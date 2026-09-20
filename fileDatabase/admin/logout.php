<?php
/**
 * logout.php — chiude la sessione del pannello.
 *
 * Distrugge la sessione E cancella il cookie: senza la seconda riga il browser
 * continuerebbe a mandare un identificatore che non vale piu', e ogni pagina
 * aperta ne creerebbe una nuova vuota.
 */

declare(strict_types=1);
require __DIR__ . '/_comune.php';

$_SESSION = [];
if (ini_get('session.use_cookies')) {
    $p = session_get_cookie_params();
    setcookie(session_name(), '', time() - 42000, $p['path'], $p['domain'], $p['secure'], $p['httponly']);
}
session_destroy();

header('Location: login.php');
