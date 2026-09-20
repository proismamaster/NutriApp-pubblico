<?php
/**
 * alimento.php — modificare un alimento personale dal pannello (2026-09-14).
 *
 * PERCHE' ESISTE: "quando l'admin approva un alimento, questo deve rimanere
 * modificabile" (Ismail). Prima approvare era l'ultima parola: un alimento
 * pubblicato con le calorie sbagliate restava sbagliato per tutti, e l'unica
 * strada era rifiutarlo o correggerlo a mano su phpMyAdmin.
 *
 * Si modifica in ogni stato (in attesa, pubblico, rifiutato). La modifica
 * scrive sulla riga dell'autore, non su una copia: e' la stessa scelta del
 * 12/09 ("la coda e' uno stato, non una copia"), e l'autore ritrova i valori
 * corretti nella sua libreria.
 *
 * Ogni salvataggio passa dal registro con i valori di prima, quindi si annulla
 * da registro.php come una decisione. Solo i campi cambiati finiscono nel
 * registro, cosi' la riga dice cosa e' stato toccato davvero.
 *
 * I nomi di colonna vengono da campiAlimentoPersonale(), mai dal modulo.
 */

declare(strict_types=1);
require __DIR__ . '/_comune.php';
richiediAccesso();

$id = (int) ($_GET['id'] ?? $_POST['id'] ?? 0);
$campi = campiAlimentoPersonale($conn);
$tipi = $campi['tipi'];

/** La riga dell'alimento con l'autore, o null. */
function leggiAlimento(mysqli $conn, int $id, array $tipi): ?array
{
    $lista = implode(', ', array_map(static fn($c) => 'f.`' . $c . '`', array_keys($tipi)));
    $stmt = $conn->prepare(
        "SELECT f.id, f.user_mail, f.shared_status, u.first_name, $lista
           FROM na_custom_foods f
           LEFT JOIN na_users u ON u.email = f.user_mail
          WHERE f.id = ? LIMIT 1"
    );
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $riga = $stmt->get_result()->fetch_assoc() ?: null;
    $stmt->close();
    return $riga;
}

$alimento = leggiAlimento($conn, $id, $tipi);
if ($alimento === null) {
    http_response_code(404);
    pagina('Alimento non trovato', '<a class="torna" href="alimenti.php">&larr; alimenti proposti</a>'
        . '<div class="vuoto">Nessun alimento con questo numero.</div>', 'alimento.php');
    exit;
}

$messaggio = null;
$tipoMessaggio = 'esito';
$errori = [];
$scritti = [];

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    richiediToken();
    $nuovi = [];

    foreach ($tipi as $campo => $tipo) {
        if (!array_key_exists($campo, $_POST)) {
            continue;
        }
        $grezzo = trim((string) $_POST[$campo]);
        $scritti[$campo] = $grezzo;

        if ($tipo === 'd') {
            $testo = str_replace(',', '.', $grezzo);
            // Un campo svuotato vale zero: le colonne numeriche di
            // na_custom_foods non ammettono "non indicato".
            if ($testo === '') {
                $valore = 0.0;
            } elseif (!is_numeric($testo) || (float) $testo < 0) {
                $errori[$campo] = 'serve un numero non negativo';
                continue;
            } else {
                $valore = (float) $testo;
            }
            if ($campo === 'base_weight_g' && $valore <= 0) {
                $errori[$campo] = 'deve essere maggiore di zero';
                continue;
            }
            if (abs($valore - (float) $alimento[$campo]) > 1e-9) {
                $nuovi[$campo] = $valore;
            }
            continue;
        }

        if ($campo === 'food_name' && $grezzo === '') {
            $errori[$campo] = 'il nome non può restare vuoto';
            continue;
        }
        // Solo indirizzi web: un "javascript:" nella foto non deve arrivare
        // agli <img> del pannello e dell'app.
        if ($campo === 'image_url' && $grezzo !== '' && !preg_match('#^https?://#i', $grezzo)) {
            $errori[$campo] = 'deve iniziare con http:// o https://';
            continue;
        }
        $grezzo = mb_substr($grezzo, 0, $campo === 'ingredients' ? 5000 : 500);
        if ($grezzo !== (string) ($alimento[$campo] ?? '')) {
            $nuovi[$campo] = $grezzo;
        }
    }

    if ($errori !== []) {
        $messaggio = 'Niente salvato: controlla i campi segnati in rosso.';
        $tipoMessaggio = 'errore';
    } elseif ($nuovi === []) {
        $messaggio = 'Nessuna modifica da salvare.';
        $tipoMessaggio = 'avviso';
        $scritti = [];
    } else {
        [$prima, $dopo] = applicaValori($conn, 'na_custom_foods', 'id', (string) $id, $tipi, $nuovi);
        $nome = (string) ($nuovi['food_name'] ?? $alimento['food_name']);
        registra($conn, 'edit', 'custom_food', $id, $nome, $prima, $dopo);
        $n = count($dopo);
        $messaggio = 'Salvato: ' . $n . ($n === 1 ? ' campo modificato' : ' campi modificati')
            . '. Si può annullare dal registro.';
        $alimento = leggiAlimento($conn, $id, $tipi);
        $scritti = [];
    }
}

/** Il valore da mostrare in una casella: quello appena scritto se c'e' un errore, se no quello salvato. */
$valoreCampo = static function (string $campo) use ($scritti, $alimento, $tipi): string {
    if (array_key_exists($campo, $scritti)) {
        return $scritti[$campo];
    }
    $v = $alimento[$campo] ?? '';
    if ($tipi[$campo] === 'd') {
        $n = (float) $v;
        return $n == 0.0 ? '0' : rtrim(rtrim(number_format($n, 3, '.', ''), '0'), '.');
    }
    return (string) $v;
};

$stati = [
    'private' => ['neutro', 'Privato'], 'pending' => ['attesa', 'In attesa'],
    'approved' => ['ok', 'Pubblico'], 'rejected' => ['no', 'Rifiutato'],
];
[$classeStato, $testoStato] = $stati[(string) $alimento['shared_status']] ?? ['neutro', (string) $alimento['shared_status']];
$tornaStato = in_array($alimento['shared_status'], ['pending', 'approved', 'rejected'], true)
    ? (string) $alimento['shared_status'] : 'pending';

$foto = trim((string) ($alimento['image_url'] ?? ''));
$html = '<a class="torna" href="alimenti.php?stato=' . e($tornaStato) . '">&larr; alimenti proposti</a>'
    . ($messaggio !== null ? '<div class="' . $tipoMessaggio . '">' . e($messaggio) . '</div>' : '')
    . '<div class="testata-alimento">'
    . ($foto !== '' ? '<img src="' . e($foto) . '" alt="">' : '<div class="senza"></div>')
    . '<div><span class="pastiglia ' . $classeStato . '">' . e($testoStato) . '</span>'
    . '<div class="chi-propone">Di ' . e((string) ($alimento['first_name'] ?: 'Anonimo'))
    . ' · ' . e((string) $alimento['user_mail']) . '</div></div></div>'
    . '<p class="nota-modifica">Le modifiche valgono per tutti quelli che trovano l\'alimento, e anche nella libreria di chi l\'ha creato.</p>'
    . '<form method="post" class="modulo-alimento">' . campoToken()
    . '<input type="hidden" name="id" value="' . $id . '">';

foreach ($campi['gruppi'] as $titolo => $gruppo) {
    $html .= '<fieldset><legend>' . e($titolo) . '</legend><div class="campi-alimento">';
    foreach ($gruppo as $campo => [$etichetta, $unita, $lungo]) {
        $errore = $errori[$campo] ?? null;
        $classi = 'campo' . ($lungo || $campo === 'food_name' || $campo === 'image_url' ? ' largo' : '')
            . ($errore !== null ? ' sbagliato' : '');
        $html .= '<label class="' . $classi . '"><span class="etichetta-campo">' . e($etichetta)
            . ($unita !== '' ? ' <span class="unita">(' . e($unita) . ')</span>' : '') . '</span>';
        if ($lungo) {
            $html .= '<textarea name="' . e($campo) . '" rows="4">' . e($valoreCampo($campo)) . '</textarea>';
        } else {
            $numerico = $tipi[$campo] === 'd';
            $html .= '<input type="text" name="' . e($campo) . '" value="' . e($valoreCampo($campo)) . '"'
                . ($numerico ? ' inputmode="decimal"' : '')
                . ($campo === 'food_name' ? ' required maxlength="255"' : '') . '>';
        }
        if ($errore !== null) {
            $html .= '<small>' . e($errore) . '</small>';
        }
        $html .= '</label>';
    }
    $html .= '</div></fieldset>';
}

$html .= '<div class="azioni"><button class="principale" type="submit">Salva modifiche</button>'
    . '<a class="bottone" href="alimenti.php?stato=' . e($tornaStato) . '">Annulla</a></div>'
    . '</form>';

pagina((string) $alimento['food_name'], $html, 'alimento.php');
