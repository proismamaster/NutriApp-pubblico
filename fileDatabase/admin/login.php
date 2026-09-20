<?php
/**
 * login.php — accesso al pannello di revisione.
 *
 * Ricalcato sulla schermata 6A dei mockup: riquadro da 360px al centro, titolo,
 * due campi, pulsante a pillola. Due avvisi diversi: rosso per le credenziali
 * sbagliate, ambra per il blocco dopo troppi tentativi — il secondo non e' un
 * errore di chi scrive, e' un'attesa.
 *
 * Nessuna registrazione e nessun "password dimenticata": gli account li crea
 * il proprietario da admins.php. Un pannello con due o tre account non ha
 * bisogno di un giro di recupero, e ogni giro di recupero e' una porta in piu'.
 */

declare(strict_types=1);
require __DIR__ . '/_comune.php';

if (adminCorrente() !== null) {
    header('Location: index.php');
    exit;
}

$errore = null;
$email = '';
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    richiediToken();
    $email = trim((string) ($_POST['email'] ?? ''));
    $password = (string) ($_POST['password'] ?? '');
    if ($email === '' || $password === '') {
        $errore = 'Compila entrambi i campi.';
    } else {
        $errore = tentaAccesso($conn, $email, $password);
        if ($errore === null) {
            header('Location: index.php');
            exit;
        }
    }
}

// Il blocco a tempo e' ambra, tutto il resto rosso.
$classeAvviso = ($errore !== null && str_starts_with($errore, 'Troppi')) ? 'avviso' : 'errore';

echo '<!DOCTYPE html><html lang="it"><head><meta charset="utf-8">';
echo '<meta name="viewport" content="width=device-width, initial-scale=1">';
echo '<title>Accesso — NutriApp revisione</title><link rel="stylesheet" href="stile.css"></head><body>';
echo '<div class="pagina-accesso"><form method="post" class="accesso">'
    . campoToken()
    . '<h1>Revisione NutriApp</h1>'
    . ($errore ? '<div class="' . $classeAvviso . '">' . e($errore) . '</div>' : '')
    . '<label>Email<input type="email" name="email" value="' . e($email) . '" autocomplete="username" autofocus required></label>'
    . '<label>Password<input type="password" name="password" autocomplete="current-password" required></label>'
    . '<button class="principale" type="submit">Entra</button>'
    . '</form></div></body></html>';
