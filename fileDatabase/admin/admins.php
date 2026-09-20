<?php
/**
 * admins.php — gli account del pannello. Solo il proprietario.
 *
 * Non c'era una schermata di mockup per questa pagina: usa la stessa
 * grammatica del registro (tabella a griglia, pulsanti a pillola) perche' sta
 * nella stessa barra e deve sembrare parte dello stesso pannello.
 *
 * SI DISATTIVA, NON SI CANCELLA. Le decisioni nel registro portano l'email di
 * chi le ha prese: cancellare l'account lascerebbe righe senza autore proprio
 * nel posto dove l'autore serve. Un account disattivato non entra piu' e resta
 * leggibile nel registro.
 *
 * La password non si vede e non si recupera: se qualcuno la perde, il
 * proprietario ne imposta una nuova. Con due o tre account, un giro di
 * recupero via email sarebbe una porta in piu' da difendere in cambio di
 * niente.
 */

declare(strict_types=1);
require __DIR__ . '/_comune.php';
richiediProprietario();

$messaggio = null;
$tipoMessaggio = 'esito';

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    richiediToken();
    $azione = (string) ($_POST['azione'] ?? '');

    if ($azione === 'crea') {
        $email = strtolower(trim((string) ($_POST['email'] ?? '')));
        $nome = trim((string) ($_POST['nome'] ?? ''));
        $ruolo = (string) ($_POST['ruolo'] ?? 'reviewer');
        $password = (string) ($_POST['password'] ?? '');

        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || $nome === '') {
            $messaggio = 'Email non valida o nome mancante.';
            $tipoMessaggio = 'avviso';
        } elseif (strlen($password) < 12) {
            // Dodici caratteri e non otto: questa password apre la scrittura su
            // un database di 214.000 prodotti, e non c'e' nessun secondo
            // fattore dietro.
            $messaggio = 'La password deve avere almeno 12 caratteri.';
            $tipoMessaggio = 'avviso';
        } elseif (!in_array($ruolo, ['reviewer', 'owner'], true)) {
            $messaggio = 'Ruolo non valido.';
            $tipoMessaggio = 'avviso';
        } else {
            $hash = password_hash($password, PASSWORD_DEFAULT);
            $stmt = $conn->prepare(
                'INSERT INTO na_admins (email, password_hash, display_name, role) VALUES (?, ?, ?, ?)'
            );
            $stmt->bind_param('ssss', $email, $hash, $nome, $ruolo);
            try {
                $stmt->execute();
                $messaggio = 'Account creato: ' . $email;
            } catch (mysqli_sql_exception $ex) {
                $messaggio = 'Non creato: esiste già un account con questa email.';
                $tipoMessaggio = 'avviso';
            }
            $stmt->close();
        }
    } elseif ($azione === 'stato') {
        $id = (int) ($_POST['id'] ?? 0);
        $attivo = ((string) ($_POST['attivo'] ?? '1')) === '1' ? 1 : 0;
        $io = (int) (adminCorrente()['id'] ?? 0);
        if ($id === $io && $attivo === 0) {
            // Disattivare se stessi chiuderebbe fuori l'unico proprietario, e
            // non ci sarebbe nessuno a riaprire.
            $messaggio = 'Non puoi disattivare il tuo stesso account.';
            $tipoMessaggio = 'avviso';
        } else {
            $stmt = $conn->prepare('UPDATE na_admins SET active = ? WHERE id = ?');
            $stmt->bind_param('ii', $attivo, $id);
            $stmt->execute();
            $stmt->close();
            $messaggio = $attivo === 1 ? 'Account riattivato.' : 'Account disattivato.';
        }
    } elseif ($azione === 'password') {
        $id = (int) ($_POST['id'] ?? 0);
        $password = (string) ($_POST['password'] ?? '');
        if (strlen($password) < 12) {
            $messaggio = 'La password deve avere almeno 12 caratteri.';
            $tipoMessaggio = 'avviso';
        } else {
            $hash = password_hash($password, PASSWORD_DEFAULT);
            $stmt = $conn->prepare(
                'UPDATE na_admins SET password_hash = ?, failed_logins = 0, locked_until = NULL WHERE id = ?'
            );
            $stmt->bind_param('si', $hash, $id);
            $stmt->execute();
            $stmt->close();
            $messaggio = 'Password aggiornata.';
        }
    }
}

// Ricerca e ordinamento (15/09).
$cerca = testoCercato();
$colonneOrdine = [
    'nome' => ['Nome', 'display_name'],
    'email' => ['Email', 'email'],
    'ruolo' => ['Ruolo', 'role'],
    'accesso' => ['Ultimo accesso', 'last_login_at'],
    'attivo' => ['Attivo', 'active'],
];
[$ordine, $ordinaPer, $verso] = ordinamento($colonneOrdine, 'nome');
$stmt = $conn->prepare(
    'SELECT id, email, display_name, role, active, last_login_at FROM na_admins'
    . ($cerca !== '' ? ' WHERE (display_name LIKE ? OR email LIKE ? OR role LIKE ?)' : '')
    . " ORDER BY $ordine, id"
);
if ($cerca !== '') {
    $like = comeLike($cerca);
    $stmt->bind_param('sss', $like, $like, $like);
}
$stmt->execute();
$res = $stmt->get_result();
$righe = '';
while ($res && ($a = $res->fetch_assoc())) {
    $attivo = (int) $a['active'] === 1;
    $righe .= '<div class="riga">'
        . '<a class="nome-link taglia' . ($attivo ? '' : ' barrato') . '" href="admin.php?id=' . (int) $a['id'] . '">' . e((string) $a['display_name']) . '</a>'
        . '<span class="taglia' . ($attivo ? '' : ' barrato') . '">' . e((string) $a['email']) . '</span>'
        . '<span><span class="pastiglia ' . ($a['role'] === 'owner' ? 'ok' : 'neutro') . '">'
        . e($a['role'] === 'owner' ? 'Proprietario' : 'Revisore') . '</span></span>'
        . '<span class="secondario" style="font-size:12px">'
        . e($a['last_login_at'] ? date('d/m H:i', strtotime((string) $a['last_login_at'])) : 'mai') . '</span>'
        . '<form method="post" style="margin:0">' . campoToken()
        . '<input type="hidden" name="id" value="' . (int) $a['id'] . '">'
        . '<input type="hidden" name="attivo" value="' . ($attivo ? '0' : '1') . '">'
        . '<button class="piccolo" name="azione" value="stato">' . ($attivo ? 'Disattiva' : 'Riattiva') . '</button>'
        . '</form>'
        . '<form method="post" style="margin:0;display:flex;gap:6px">' . campoToken()
        . '<input type="hidden" name="id" value="' . (int) $a['id'] . '">'
        . '<input type="password" name="password" placeholder="nuova password" style="flex:1;min-width:0">'
        . '<button class="piccolo" name="azione" value="password">Imposta</button>'
        . '</form>'
        . '</div>';
}

$modulo = '<form method="post" class="modulo-nuovo">' . campoToken()
    . '<h2 style="margin:0">Nuovo account</h2>'
    . '<label>Nome<input type="text" name="nome" required></label>'
    . '<label>Email<input type="email" name="email" required></label>'
    . '<label>Ruolo<select name="ruolo">'
    . '<option value="reviewer">Revisore — vede le code e decide</option>'
    . '<option value="owner">Proprietario — anche gli account</option>'
    . '</select></label>'
    . '<label>Password (almeno 12 caratteri)<input type="password" name="password" minlength="12" required></label>'
    . '<button class="principale" name="azione" value="crea">Crea</button>'
    . '</form>';

$html = ($messaggio !== null ? '<div class="' . $tipoMessaggio . '">' . e($messaggio) . '</div>' : '')
    . '<form class="filtri" method="get">'
    . campoCerca($cerca, 'nome, email o ruolo')
    . sceltaOrdinamento($colonneOrdine, $ordinaPer, $verso)
    . '<button class="principale" type="submit">Cerca</button></form>'
    . '<div class="riquadro account">'
    . testaOrdinabile([
        ['Nome', 'nome'], ['Email', 'email'], ['Ruolo', 'ruolo'], ['Ultimo accesso', 'accesso'], ['', 'attivo'], ['Password', null],
    ], $ordinaPer, $verso)
    . ($righe === '' ? '<div class="vuoto">Nessun account con questa ricerca</div>' : $righe) . '</div>'
    . $modulo;

pagina('Account del pannello', $html, 'admins.php');
