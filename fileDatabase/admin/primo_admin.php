<?php
/**
 * primo_admin.php — crea il PRIMO account del pannello, una volta sola.
 *
 * Stesso riquadro della pagina di accesso (schermata 6A dei mockup), perche' e'
 * la porta d'ingresso che si vede prima di quella.
 *
 * PERCHE' UN FILE A PARTE E NON UNA RIGA NELLA MIGRAZIONE
 * Una password dentro un file SQL finirebbe nel repo e nella storia di git.
 * Questo progetto ha gia' quattro segreti esposti per lo stesso motivo (vedi
 * PROBLEMS nel vault): non se ne aggiunge un quinto.
 *
 * COME FUNZIONA
 *  1. carica questo file via FTP insieme al resto del pannello;
 *  2. aprilo nel browser UNA volta e compila il modulo;
 *  3. **cancellalo dall'hosting**.
 *
 * Si disattiva da solo appena esiste un account: da quel momento risponde solo
 * "gia' fatto". Anche cosi', cancellarlo e' la cosa giusta — un file che crea
 * amministratori non deve restare raggiungibile, nemmeno se oggi si rifiuta.
 */

declare(strict_types=1);
require __DIR__ . '/_comune.php';

$res = $conn->query('SELECT COUNT(*) FROM na_admins');
$quanti = (int) ($res ? ($res->fetch_row()[0] ?? 0) : 0);

$messaggio = null;
$classe = 'errore';
$fatto = false;

if ($quanti > 0) {
    $messaggio = 'Esiste già almeno un account: questo file non serve più e va cancellato dall\'hosting.';
    $classe = 'avviso';
} elseif (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    richiediToken();
    $email = strtolower(trim((string) ($_POST['email'] ?? '')));
    $nome = trim((string) ($_POST['nome'] ?? ''));
    $password = (string) ($_POST['password'] ?? '');

    if (!filter_var($email, FILTER_VALIDATE_EMAIL) || $nome === '') {
        $messaggio = 'Email non valida o nome mancante.';
    } elseif (strlen($password) < 12) {
        $messaggio = 'La password deve avere almeno 12 caratteri.';
    } else {
        $hash = password_hash($password, PASSWORD_DEFAULT);
        $stmt = $conn->prepare(
            'INSERT INTO na_admins (email, password_hash, display_name, role) VALUES (?, ?, ?, "owner")'
        );
        $stmt->bind_param('sss', $email, $hash, $nome);
        if ($stmt->execute()) {
            $fatto = true;
            $classe = 'esito';
            $messaggio = 'Account proprietario creato. ORA CANCELLA QUESTO FILE dall\'hosting, poi entra dal pannello.';
        } else {
            $messaggio = 'Non creato: ' . $stmt->error;
        }
        $stmt->close();
    }
}

echo '<!DOCTYPE html><html lang="it"><head><meta charset="utf-8">';
echo '<meta name="viewport" content="width=device-width, initial-scale=1">';
echo '<title>Primo accesso — NutriApp revisione</title><link rel="stylesheet" href="stile.css"></head><body>';
echo '<div class="pagina-accesso"><form method="post" class="accesso">' . campoToken();
echo '<h1>Primo account</h1>';
if ($messaggio !== null) {
    echo '<div class="' . $classe . '">' . e($messaggio) . '</div>';
}
if ($quanti === 0 && !$fatto) {
    echo '<label>Nome<input type="text" name="nome" required></label>'
        . '<label>Email<input type="email" name="email" required></label>'
        . '<label>Password (almeno 12 caratteri)<input type="password" name="password" minlength="12" required></label>'
        . '<button class="principale" type="submit">Crea il proprietario</button>';
} else {
    echo '<a class="bottone principale" href="login.php" style="border-radius:100px">Vai all\'accesso</a>';
}
echo '</form></div></body></html>';
