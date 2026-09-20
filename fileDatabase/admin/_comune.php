<?php
/**
 * _comune.php — fondamenta del pannello di revisione: sessione, accesso,
 * protezione dei moduli, impaginazione, registro delle decisioni.
 *
 * Ogni pagina del pannello inizia con:
 *     require __DIR__ . '/_comune.php';
 *     richiediAccesso();
 *
 * SCELTE, E PERCHE'
 *  - Sessione PHP e non token: il pannello e' un sito che si apre col browser,
 *    non un'API. Il cookie di sessione e' il meccanismo che i browser sanno
 *    gia' proteggere (HttpOnly, SameSite).
 *  - HTTPS obbligatorio: il dominio ha un certificato valido (verificato il
 *    12/09), quindi non c'e' nessun motivo per far viaggiare in chiaro la
 *    password di chi puo' riscrivere il database.
 *  - Un token in ogni modulo: senza, una pagina qualunque aperta in un'altra
 *    scheda potrebbe far accettare una correzione a nostro nome.
 *  - Niente framework: la stessa ragione per cui il revisore delle categorie
 *    e' un file HTML. Questo pannello deve poter essere caricato via FTP e
 *    funzionare, senza composer e senza build.
 *
 * Richiede: ../db_config.php e le migrazioni 2026-09-12_collaborazione_community
 * e 2026-09-12_pannello_admin.
 */

declare(strict_types=1);

// ---------------------------------------------------------------------------
// HTTPS o niente
// ---------------------------------------------------------------------------
// Su `php -S` (le prove in locale) non c'e' TLS: la verifica si applica solo
// quando il server dichiara un host vero, altrimenti lo script di prova non
// potrebbe girare. In produzione la condizione e' sempre vera.
$inLocale = in_array($_SERVER['SERVER_NAME'] ?? '', ['127.0.0.1', 'localhost'], true);
$inHttps = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
    || ($_SERVER['SERVER_PORT'] ?? '') === '443'
    || ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https';
if (!$inLocale && !$inHttps) {
    $destinazione = 'https://' . ($_SERVER['HTTP_HOST'] ?? '') . ($_SERVER['REQUEST_URI'] ?? '');
    header('Location: ' . $destinazione, true, 301);
    exit;
}

// ---------------------------------------------------------------------------
// Sessione
// ---------------------------------------------------------------------------
if (session_status() !== PHP_SESSION_ACTIVE) {
    session_set_cookie_params([
        'httponly' => true,          // niente JavaScript sul cookie
        'samesite' => 'Lax',         // niente invio da altri siti
        'secure'   => !$inLocale,    // solo su HTTPS, tranne nelle prove locali
    ]);
    session_name('nutriadmin');
    session_start();
}

$percorsoConfig = __DIR__ . '/../db_config.php';
if (!is_file($percorsoConfig)) {
    http_response_code(500);
    exit('db_config.php mancante: va caricato via FTP nella cartella nutriapp/, accanto agli endpoint.');
}
require $percorsoConfig;
// db_config.php e' fatto per gli endpoint dell'app e manda
// "Content-Type: application/json": senza questa riga il browser mostra le
// pagine del pannello come testo (visto sull'hosting il 13/09). Va dopo il
// require, perche' l'ultimo header scritto vince.
header('Content-Type: text/html; charset=utf-8');
/** @var mysqli $conn */
$conn->set_charset('utf8mb4');

// ---------------------------------------------------------------------------
// Accesso
// ---------------------------------------------------------------------------

/** Admin collegato, o null. */
function adminCorrente(): ?array
{
    return $_SESSION['admin'] ?? null;
}

/** Ferma la pagina se non c'e' nessuno collegato. */
function richiediAccesso(): void
{
    if (adminCorrente() === null) {
        header('Location: login.php');
        exit;
    }
}

/** Ferma la pagina se chi e' collegato non e' il proprietario. */
function richiediProprietario(): void
{
    richiediAccesso();
    if ((adminCorrente()['role'] ?? '') !== 'owner') {
        http_response_code(403);
        pagina('Non permesso', '<p class="vuoto">Questa sezione e\' riservata al proprietario.</p>');
        exit;
    }
}

/**
 * Verifica email e password.
 *
 * Restituisce SEMPRE lo stesso messaggio d'errore, qualunque sia la causa:
 * dire "questa email non esiste" e' un modo gentile di consegnare l'elenco
 * degli account a chi prova.
 */
function tentaAccesso(mysqli $conn, string $email, string $password): ?string
{
    $stmt = $conn->prepare(
        'SELECT id, email, password_hash, display_name, role, active, failed_logins, locked_until
           FROM na_admins WHERE email = ? LIMIT 1'
    );
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $riga = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    $generico = 'Credenziali non valide.';

    if (!$riga || (int) $riga['active'] !== 1) {
        // Tempo speso comunque, cosi' un'email inesistente non risponde piu'
        // in fretta di una esistente (e non si distinguono a cronometro).
        password_verify($password, '$2y$10$usurpatoreusurpatoreusurpatoreusurpatoreusurpat');
        return $generico;
    }

    if ($riga['locked_until'] !== null && strtotime($riga['locked_until']) > time()) {
        return 'Troppi tentativi: riprova piu\' tardi.';
    }

    if (!password_verify($password, $riga['password_hash'])) {
        $tentativi = (int) $riga['failed_logins'] + 1;
        $bloccoFino = $tentativi >= 5 ? date('Y-m-d H:i:s', time() + 900) : null;
        $stmt = $conn->prepare('UPDATE na_admins SET failed_logins = ?, locked_until = ? WHERE id = ?');
        $stmt->bind_param('isi', $tentativi, $bloccoFino, $riga['id']);
        $stmt->execute();
        $stmt->close();
        return $generico;
    }

    // Identificatore nuovo dopo l'accesso: un identificatore di sessione
    // ottenuto prima del login non deve valere dopo.
    session_regenerate_id(true);
    $_SESSION['admin'] = [
        'id' => (int) $riga['id'],
        'email' => $riga['email'],
        'name' => $riga['display_name'],
        'role' => $riga['role'],
    ];

    $stmt = $conn->prepare(
        'UPDATE na_admins SET failed_logins = 0, locked_until = NULL, last_login_at = NOW() WHERE id = ?'
    );
    $stmt->bind_param('i', $riga['id']);
    $stmt->execute();
    $stmt->close();
    return null;
}

// ---------------------------------------------------------------------------
// Token dei moduli
// ---------------------------------------------------------------------------

function token(): string
{
    if (empty($_SESSION['token'])) {
        $_SESSION['token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['token'];
}

function campoToken(): string
{
    return '<input type="hidden" name="token" value="' . e(token()) . '">';
}

/** Da chiamare all'inizio di OGNI ramo che scrive. */
function richiediToken(): void
{
    $inviato = $_POST['token'] ?? '';
    if (!is_string($inviato) || !hash_equals(token(), $inviato)) {
        http_response_code(400);
        exit('Modulo scaduto: torna indietro, ricarica la pagina e riprova.');
    }
}

// ---------------------------------------------------------------------------
// Uscita verso l'HTML
// ---------------------------------------------------------------------------

/** Tutto cio' che arriva dal database o dagli utenti passa da qui. */
function e(?string $s): string
{
    return htmlspecialchars((string) $s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/** Numero leggibile: 1234.5 -> "1.234,5" (separatori italiani). */
function num($v, int $decimali = 1): string
{
    if ($v === null || $v === '') {
        return '—';
    }
    $f = (float) $v;
    return number_format($f, ($f == (int) $f) ? 0 : $decimali, ',', '.');
}

/** "3 giorni" / "oggi": quanto e' ferma una cosa in coda. */
function attesa(?string $data): string
{
    if (!$data) {
        return '—';
    }
    $giorni = (int) floor((time() - strtotime($data)) / 86400);
    if ($giorni <= 0) {
        return 'oggi';
    }
    return $giorni === 1 ? '1 giorno' : "$giorni giorni";
}

/**
 * Pastiglia di stato con la stessa grammatica di colori dell'app.
 *
 * "Aperta" e' neutra (bianca col filo) e non ambra, come nel mockup della coda:
 * in una coda di segnalazioni quasi tutte sono aperte, e una colonna intera di
 * ambra smetterebbe di segnalare qualcosa. L'ambra resta agli alimenti e alle
 * ricette in attesa, dove l'attesa e' l'eccezione da notare.
 */
function pastiglia(string $stato): string
{
    $mappa = [
        'pending'  => ['neutro', 'Aperta'],
        'approved' => ['ok', 'Pubblico'],
        'accepted' => ['ok', 'Accettata'],
        'rejected' => ['no', 'Rifiutata'],
        'private'  => ['neutro', 'Privato'],
        // Problemi dell'app (15/09)
        'open'     => ['neutro', 'Aperto'],
        'resolved' => ['ok', 'Risolto'],
        'closed'   => ['no', 'Chiuso'],
    ];
    [$classe, $testo] = $mappa[$stato] ?? ['neutro', $stato];
    return '<span class="pastiglia stato ' . $classe . '">' . e($testo) . '</span>';
}

/**
 * Colore dei giorni di attesa: nero fino a 6, ambra da 7, rosso da 14.
 *
 * Soglie del mockup del cruscotto. Servono a far notare cio' che e' stato
 * dimenticato: un totale non distingue dieci segnalazioni di oggi da dieci
 * ferme da un mese.
 */
function classeAttesa(?string $data): string
{
    if (!$data) {
        return 'attesa-ok';
    }
    $giorni = (int) floor((time() - strtotime($data)) / 86400);
    if ($giorni >= 14) {
        return 'attesa-lungo';
    }
    return $giorni >= 7 ? 'attesa-medio' : 'attesa-ok';
}

/**
 * Nome leggibile di una colonna nutrizionale.
 *
 * Il revisore giudica "Zuccheri", non `sugars`; ma il nome vero della colonna
 * resta scritto piccolo sotto, perche' e' quello che finira' nel registro e
 * quello che serve se qualcosa va controllato su phpMyAdmin.
 */
function etichettaCampo(string $campo): string
{
    static $nomi = [
        'food_name' => 'Nome', 'brand' => 'Marca', 'categories' => 'Categorie',
        'ingredients' => 'Ingredienti', 'image_url' => 'Foto', 'quantity' => 'Quantità',
        'serving_size' => 'Porzione', 'packaging' => 'Confezione',
        'nutriscore_grade' => 'Nutri-Score', 'environmental_score_grade' => 'Eco-Score',
        'allergens' => 'Allergeni', 'labels' => 'Etichette',
        'calories' => 'Calorie', 'carbs' => 'Carboidrati', 'proteins' => 'Proteine',
        'fats' => 'Grassi', 'fibers' => 'Fibre', 'sugars' => 'Zuccheri', 'water' => 'Acqua',
        'saturated_fats' => 'Grassi saturi', 'monounsaturated_fats' => 'Grassi monoinsaturi',
        'polyunsaturated_fats' => 'Grassi polinsaturi', 'trans_fats' => 'Grassi trans',
        'cholesterol' => 'Colesterolo', 'sodium' => 'Sodio', 'salt' => 'Sale',
        'added_sugars' => 'Zuccheri aggiunti', 'starch' => 'Amido', 'polyols' => 'Polioli',
        'lactose' => 'Lattosio', 'alcohol_percent' => 'Alcol', 'caffeine' => 'Caffeina',
        'nova_group' => 'NOVA', 'additives_n' => 'Additivi',
        'vit_a' => 'Vitamina A', 'vit_b1' => 'Vitamina B1', 'vit_b2' => 'Vitamina B2',
        'vit_b3' => 'Vitamina B3', 'vit_b5' => 'Vitamina B5', 'vit_b6' => 'Vitamina B6',
        'vit_b7' => 'Vitamina B7', 'vit_b9' => 'Vitamina B9', 'vit_b11' => 'Vitamina B11',
        'vit_b12' => 'Vitamina B12', 'vit_c' => 'Vitamina C', 'vit_d' => 'Vitamina D',
        'vit_e' => 'Vitamina E', 'vit_k' => 'Vitamina K', 'biotin' => 'Biotina',
        'calcium' => 'Calcio', 'iron' => 'Ferro', 'magnesium' => 'Magnesio',
        'phosphorus' => 'Fosforo', 'potassium' => 'Potassio', 'zinc' => 'Zinco',
        'copper' => 'Rame', 'manganese' => 'Manganese', 'selenium' => 'Selenio',
        'iodine' => 'Iodio', 'chloride' => 'Cloruro', 'fluoride' => 'Fluoruro',
        'chromium' => 'Cromo', 'molybdenum' => 'Molibdeno',
    ];
    return $nomi[$campo] ?? $campo;
}

/**
 * Scheletro della pagina.
 *
 * Un solo posto per intestazione, menu e chiusura: il pannello ha nove pagine,
 * e nove copie della stessa barra sarebbero nove barre che divergono.
 */
function pagina(string $titolo, string $contenuto, string $attiva = ''): void
{
    $admin = adminCorrente();
    // Stesso ordine della barra nei mockup: la coda viene prima del cruscotto,
    // perche' e' li' che si lavora; il cruscotto e' dove si guarda.
    $voci = [
        'segnalazioni.php' => 'Segnalazioni',
        'problemi.php' => 'Problemi app',
        'index.php' => 'Cruscotto',
        'alimenti.php' => 'Alimenti',
        'ricette.php' => 'Ricette',
        'registro.php' => 'Registro',
        'utenti.php' => 'Utenti',
        'admin.php' => 'Admin',
    ];
    if (($admin['role'] ?? '') === 'owner') {
        $voci['admins.php'] = 'Account';
    }
    // Una pagina di dettaglio accende la voce dell'elenco da cui si arriva:
    // una barra senza voce attiva fa perdere l'orientamento.
    $accesa = match ($attiva) {
        'segnalazione.php' => 'segnalazioni.php',
        'alimento.php' => 'alimenti.php',
        default => $attiva,
    };

    echo '<!DOCTYPE html><html lang="it"><head><meta charset="utf-8">';
    echo '<meta name="viewport" content="width=device-width, initial-scale=1">';
    echo '<title>' . e($titolo) . ' — NutriApp revisione</title>';
    echo '<link rel="stylesheet" href="stile.css"></head><body>';

    if ($admin !== null) {
        echo '<header class="barra"><div class="marchio">NutriApp <span>· revisione</span></div><nav>';
        foreach ($voci as $file => $etichetta) {
            $classe = $file === $accesa ? ' class="attiva"' : '';
            echo '<a href="' . e($file) . '"' . $classe . '>' . e($etichetta) . '</a>';
        }
        echo '</nav><div class="chi"><span>' . e($admin['name']) . '</span><a href="logout.php">esci</a></div></header>';
    }

    echo '<main><h1>' . e($titolo) . '</h1>' . $contenuto . '</main>';
    echo '</body></html>';
}

/**
 * Accende "Rifiuta" solo quando la motivazione non e' vuota, in ogni modulo
 * `.decidi` della pagina (schede di alimenti e ricette).
 *
 * E' una comodita', non la regola: il server rifiuta comunque un rifiuto senza
 * motivazione. Qui serve solo a non far premere un pulsante che non puo'
 * funzionare — come nei mockup, dove Rifiuta resta grigio finche' non si scrive.
 */
function scriptRifiutoConMotivazione(): string
{
    return <<<'JS'
<script>
document.querySelectorAll('form.decidi').forEach(function (f) {
  var nota = f.querySelector('input[name="nota"]');
  var rifiuta = f.querySelector('button[value="rifiuta"]');
  if (!nota || !rifiuta) return;
  var aggiorna = function () { rifiuta.disabled = nota.value.trim() === ''; };
  nota.addEventListener('input', aggiorna);
  aggiorna();
});
</script>
JS;
}

// ---------------------------------------------------------------------------
// Scrittura dei dati accettati
// ---------------------------------------------------------------------------

/**
 * Campi che si possono scrivere su una tabella, con il loro tipo.
 *
 * QUESTA FUNZIONE E' LA DIFESA PRINCIPALE DEL PANNELLO.
 *
 * Le chiavi di `proposed_json` arrivano dall'app, cioe' da fuori: non sono
 * nomi di colonna fidati. Qui si chiede al database quali colonne esistono
 * davvero e di che tipo sono, e si incrocia con una lista chiusa di campi
 * modificabili. Tutto cio' che non e' in entrambe le liste viene ignorato: una
 * chiave inventata non diventa mai un pezzo di SQL, e nemmeno una colonna
 * legittima ma che non deve essere toccata (id, barcode, chi l'ha creato).
 */
function campiAmmessi(mysqli $conn, string $tabella): array
{
    static $cache = [];
    if (isset($cache[$tabella])) {
        return $cache[$tabella];
    }

    // Lista chiusa: cio' che una segnalazione puo' correggere.
    static $modificabili = [
        // testuali
        'food_name' => 's', 'brand' => 's', 'categories' => 's', 'ingredients' => 's',
        'image_url' => 's', 'quantity' => 's', 'serving_size' => 's', 'packaging' => 's',
        'nutriscore_grade' => 's', 'environmental_score_grade' => 's', 'allergens' => 's',
        'labels' => 's',
        // numerici: energia, macro, grassi, zuccheri, fibre, sale
        'calories' => 'd', 'carbs' => 'd', 'proteins' => 'd', 'fats' => 'd',
        'fibers' => 'd', 'sugars' => 'd', 'water' => 'd', 'saturated_fats' => 'd',
        'monounsaturated_fats' => 'd', 'polyunsaturated_fats' => 'd', 'trans_fats' => 'd',
        'cholesterol' => 'd', 'sodium' => 'd', 'salt' => 'd', 'added_sugars' => 'd',
        'starch' => 'd', 'polyols' => 'd', 'lactose' => 'd', 'alcohol_percent' => 'd',
        'caffeine' => 'd', 'nova_group' => 'i', 'additives_n' => 'i',
        // vitamine e minerali: tutti i nomi usati in na_off_products
        'vit_a' => 'd', 'vit_b1' => 'd', 'vit_b2' => 'd', 'vit_b3' => 'd', 'vit_b5' => 'd',
        'vit_b6' => 'd', 'vit_b7' => 'd', 'vit_b9' => 'd', 'vit_b11' => 'd', 'vit_b12' => 'd',
        'vit_c' => 'd', 'vit_d' => 'd', 'vit_e' => 'd', 'vit_k' => 'd',
        'biotin' => 'd', 'arsenic' => 'd', 'boron' => 'd', 'calcium' => 'd',
        'chloride' => 'd', 'choline' => 'd', 'chromium' => 'd', 'cobalt' => 'd',
        'copper' => 'd', 'fluoride' => 'd', 'iodine' => 'd', 'iron' => 'd',
        'magnesium' => 'd', 'manganese' => 'd', 'molybdenum' => 'd', 'nickel' => 'd',
        'phosphorus' => 'd', 'potassium' => 'd', 'selenium' => 'd', 'silicon' => 'd',
        'sulfur' => 'd', 'tin' => 'd', 'vanadium' => 'd', 'zinc' => 'd',
    ];

    $esistenti = [];
    $res = $conn->query('SHOW COLUMNS FROM `' . str_replace('`', '', $tabella) . '`');
    if ($res) {
        while ($r = $res->fetch_assoc()) {
            $esistenti[$r['Field']] = true;
        }
    }

    $ammessi = [];
    foreach ($modificabili as $campo => $tipo) {
        if (isset($esistenti[$campo])) {
            $ammessi[$campo] = $tipo;
        }
    }
    $cache[$tabella] = $ammessi;
    return $ammessi;
}

/**
 * Valori attuali dei campi proposti, per il confronto e per poter annullare.
 */
function valoriAttuali(mysqli $conn, string $tabella, string $chiave, string $valoreChiave, array $campi): array
{
    if ($campi === []) {
        return [];
    }
    $lista = implode(', ', array_map(static fn($c) => '`' . $c . '`', array_keys($campi)));
    $stmt = $conn->prepare("SELECT $lista FROM `$tabella` WHERE `$chiave` = ? LIMIT 1");
    $stmt->bind_param('s', $valoreChiave);
    $stmt->execute();
    $riga = $stmt->get_result()->fetch_assoc() ?: [];
    $stmt->close();
    return $riga;
}

/**
 * Scrive i campi accettati e restituisce [prima, dopo].
 *
 * Nomi di colonna interpolati nella query, valori SEMPRE come segnaposto: i
 * nomi hanno superato `campiAmmessi()` (quindi esistono nel database e sono
 * nella lista chiusa), i valori no e non lo faranno mai.
 */
function applicaValori(
    mysqli $conn,
    string $tabella,
    string $chiave,
    string $valoreChiave,
    array $campiTipo,
    array $valori
): array {
    if ($valori === []) {
        return [[], []];
    }
    $prima = valoriAttuali($conn, $tabella, $chiave, $valoreChiave, $valori);

    $pezzi = [];
    $tipi = '';
    $parametri = [];
    foreach ($valori as $campo => $valore) {
        $tipo = $campiTipo[$campo];
        $pezzi[] = '`' . $campo . '` = ?';
        $tipi .= $tipo;
        $parametri[] = $tipo === 's' ? (string) $valore : ($tipo === 'i' ? (int) $valore : (float) $valore);
    }
    $tipi .= 's';
    $parametri[] = $valoreChiave;

    $sql = "UPDATE `$tabella` SET " . implode(', ', $pezzi) . " WHERE `$chiave` = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($tipi, ...$parametri);
    $stmt->execute();
    $stmt->close();

    return [$prima, $valori];
}

/**
 * I campi di un alimento personale che il pannello puo' modificare (14/09).
 *
 * Restituisce `tipi` (colonna => 's' o 'd', il formato di applicaValori) e
 * `gruppi` (titolo => colonna => [etichetta, unita', testo lungo]), solo per le
 * colonne che esistono davvero in na_custom_foods. Lista chiusa per la stessa
 * ragione di campiAmmessi(): cio' che arriva dal modulo non diventa mai un nome
 * di colonna. Le unita' sono quelle della schermata "Proponi i valori corretti"
 * dell'app.
 *
 * Usata da alimento.php per scrivere e da registro.php per annullare.
 */
function campiAlimentoPersonale(mysqli $conn): array
{
    static $cache = null;
    if ($cache !== null) {
        return $cache;
    }
    $gruppi = [
        'Prodotto' => [
            'food_name' => ['Nome', '', false], 'brand' => ['Marca', '', false],
            'barcode' => ['Codice a barre', '', false], 'image_url' => ['Indirizzo della foto', '', false],
            'base_weight_g' => ['Valori riferiti a', 'g', false],
        ],
        'Energia e macro' => [
            'calories' => ['Calorie', 'kcal', false], 'carbs' => ['Carboidrati', 'g', false],
            'sugars' => ['Zuccheri', 'g', false], 'fibers' => ['Fibre', 'g', false],
            'proteins' => ['Proteine', 'g', false], 'sodium' => ['Sodio', 'mg', false],
        ],
        'Grassi' => [
            'fats' => ['Grassi', 'g', false], 'saturated_fats' => ['Saturi', 'g', false],
            'monounsaturated_fats' => ['Monoinsaturi', 'g', false],
            'polyunsaturated_fats' => ['Polinsaturi', 'g', false], 'trans_fats' => ['Trans', 'g', false],
            'cholesterol' => ['Colesterolo', 'mg', false],
        ],
        'Vitamine' => [
            'vit_a' => ['Vitamina A', 'µg', false], 'vit_c' => ['Vitamina C', 'mg', false],
            'vit_d' => ['Vitamina D', 'µg', false], 'vit_e' => ['Vitamina E', 'mg', false],
            'vit_b12' => ['Vitamina B12', 'µg', false],
        ],
        'Minerali' => [
            'calcium' => ['Calcio', 'mg', false], 'iron' => ['Ferro', 'mg', false],
            'potassium' => ['Potassio', 'mg', false], 'magnesium' => ['Magnesio', 'mg', false],
            'phosphorus' => ['Fosforo', 'mg', false], 'zinc' => ['Zinco', 'mg', false],
        ],
        'Etichetta' => [
            'allergens' => ['Allergeni', '', false], 'ingredients' => ['Ingredienti', '', true],
        ],
    ];
    $testuali = ['food_name', 'brand', 'barcode', 'image_url', 'allergens', 'ingredients'];

    $esistenti = [];
    $res = $conn->query('SHOW COLUMNS FROM na_custom_foods');
    while ($res && ($r = $res->fetch_assoc())) {
        $esistenti[$r['Field']] = true;
    }

    $cache = ['tipi' => [], 'gruppi' => []];
    foreach ($gruppi as $titolo => $campi) {
        foreach ($campi as $campo => $descrizione) {
            if (!isset($esistenti[$campo])) {
                continue;
            }
            $cache['tipi'][$campo] = in_array($campo, $testuali, true) ? 's' : 'd';
            $cache['gruppi'][$titolo][$campo] = $descrizione;
        }
    }
    return $cache;
}

/**
 * Casella di ricerca per i moduli `.filtri` (14/09): un campo solo che cerca
 * in piu' colonne, perche' chi rivede di solito ricorda un pezzo di nome o
 * un'email, non in quale colonna stia.
 */
function campoCerca(string $valore, string $suggerimento): string
{
    return '<label class="cerca"><span>Cerca</span><input type="search" name="q" maxlength="100" value="'
        . e($valore) . '" placeholder="' . e($suggerimento) . '"></label>';
}

/** Il testo cercato, pulito e con un tetto: non finisce mai nella query se non come `LIKE ?`. */
function testoCercato(): string
{
    return mb_substr(trim((string) ($_GET['q'] ?? '')), 0, 100);
}

/** `%testo%` per un LIKE, con `%` e `_` scritti dall'utente presi alla lettera. */
function comeLike(string $testo): string
{
    return '%' . addcslashes($testo, '%_\\') . '%';
}

/**
 * Ordinamento delle liste (15/09): "si possa ordinare in base a nome ecc".
 *
 * $colonne: chiave => [etichetta, espressione SQL]. Dall'URL arriva solo la
 * CHIAVE; l'espressione si sceglie fra quelle scritte dalle pagine, come i nomi
 * di colonna in campiAmmessi(). Il verso e' asc o desc, nient'altro.
 *
 * @return array{0:string,1:string,2:string} [clausola per ORDER BY, chiave, verso]
 */
function ordinamento(array $colonne, string $predefinita, string $versoPredefinito = 'asc'): array
{
    $chiave = (string) ($_GET['ordina'] ?? '');
    if (!isset($colonne[$chiave])) {
        $chiave = $predefinita;
    }
    $verso = (string) ($_GET['verso'] ?? '');
    if (!in_array($verso, ['asc', 'desc'], true)) {
        $verso = $chiave === $predefinita ? $versoPredefinito : 'asc';
    }
    return [$colonne[$chiave][1] . ' ' . strtoupper($verso), $chiave, $verso];
}

/** L'indirizzo della pagina con alcuni parametri cambiati: filtri e ricerca restano. */
function conParametri(array $cambi): string
{
    $par = array_filter(
        array_merge($_GET, $cambi),
        static fn($v) => is_string($v) ? $v !== '' : $v !== null
    );
    return '?' . http_build_query($par);
}

/**
 * Intestazione di una tabella a griglia con le colonne cliccabili.
 * $intestazioni: lista di [etichetta, chiave di ordinamento oppure null, classe].
 * Un clic ordina per quella colonna; un secondo clic inverte il verso.
 */
function testaOrdinabile(array $intestazioni, string $attiva, string $verso): string
{
    $html = '<div class="riga testa">';
    foreach ($intestazioni as $voce) {
        $etichetta = (string) $voce[0];
        $chiave = $voce[1] ?? null;
        $classe = (string) ($voce[2] ?? '');
        if ($chiave === null) {
            $html .= '<span class="' . e($classe) . '">' . e($etichetta) . '</span>';
            continue;
        }
        $accesa = $chiave === $attiva;
        $nuovo = $accesa && $verso === 'asc' ? 'desc' : 'asc';
        $freccia = $accesa ? ($verso === 'asc' ? ' ▲' : ' ▼') : '';
        $html .= '<span class="' . e($classe) . '"><a class="ordina' . ($accesa ? ' attiva' : '') . '" href="'
            . e(conParametri(['ordina' => $chiave, 'verso' => $nuovo])) . '">' . e($etichetta . $freccia) . '</a></span>';
    }
    return $html . '</div>';
}

/** "Ordina per" nei moduli di filtro: sul telefono le intestazioni non si vedono. */
function sceltaOrdinamento(array $colonne, string $attiva, string $verso): string
{
    $opzioni = '';
    foreach ($colonne as $chiave => $colonna) {
        $opzioni .= '<option value="' . e((string) $chiave) . '"' . ($chiave === $attiva ? ' selected' : '') . '>'
            . e((string) $colonna[0]) . '</option>';
    }
    return '<label><span>Ordina per</span><select name="ordina">' . $opzioni . '</select></label>'
        . '<label><span>Verso</span><select name="verso">'
        . '<option value="asc"' . ($verso === 'asc' ? ' selected' : '') . '>crescente</option>'
        . '<option value="desc"' . ($verso === 'desc' ? ' selected' : '') . '>decrescente</option>'
        . '</select></label>';
}

/** La colonna c'e'? Per le pagine che leggono colonne di migrazioni recenti. */
function colonnaEsiste(mysqli $conn, string $tabella, string $colonna): bool
{
    static $visto = [];
    $chiave = $tabella . '.' . $colonna;
    if (!isset($visto[$chiave])) {
        $stmt = $conn->prepare(
            'SELECT 1 FROM information_schema.COLUMNS
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ? LIMIT 1'
        );
        $stmt->bind_param('ss', $tabella, $colonna);
        $stmt->execute();
        $visto[$chiave] = $stmt->get_result()->num_rows > 0;
        $stmt->close();
    }
    return $visto[$chiave];
}

/** Nome da mostrare di un admin, dall'email scritta in reviewed_by o nel registro. */
function nomeAdmin(mysqli $conn, ?string $email): string
{
    static $nomi = null;
    if ($nomi === null) {
        $nomi = [];
        $res = $conn->query('SELECT email, display_name FROM na_admins');
        while ($res && ($a = $res->fetch_assoc())) {
            $nomi[strtolower((string) $a['email'])] = (string) $a['display_name'];
        }
    }
    $email = (string) $email;
    return $nomi[strtolower($email)] ?? ($email !== '' ? $email : '—');
}

/**
 * Ritira dalla pubblicazione un alimento o una ricetta approvati (15/09).
 *
 * Lo puo' fare QUALSIASI admin, anche se l'ha approvato un altro: e' la
 * richiesta di Ismail, ed e' cio' che serve quando un revisore sbaglia. Non
 * cancella niente: lo stato torna `rejected` col motivo, e il registro scrive
 * stato, revisore e data di prima, cosi' il ritiro si annulla come ogni altra
 * decisione.
 *
 * @return array{0:string,1:string} [messaggio, classe del messaggio]
 */
function ritiraPubblicazione(mysqli $conn, string $tipo, int $id, string $nota): array
{
    // Tabella e colonna del nome scelte fra due costanti, mai dall'input.
    $tabella = $tipo === 'recipe' ? 'na_recipes' : 'na_custom_foods';
    $colonnaNome = $tipo === 'recipe' ? 'recipe_name' : 'food_name';
    $tipo = $tipo === 'recipe' ? 'recipe' : 'custom_food';

    if ($nota === '') {
        return ['Scrivi il motivo del ritiro: la vede chi l\'aveva proposto e resta nel registro.', 'avviso'];
    }
    $stmt = $conn->prepare("SELECT `$colonnaNome` AS nome, shared_status, reviewed_by, reviewed_at FROM `$tabella` WHERE id = ? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $riga = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$riga || $riga['shared_status'] !== 'approved') {
        return ['Non e\' pubblicato: non c\'e\' niente da ritirare.', 'avviso'];
    }

    $chi = adminCorrente()['email'];
    $stmt = $conn->prepare(
        "UPDATE `$tabella` SET shared_status = 'rejected', reviewed_at = NOW(), reviewed_by = ?, review_note = ? WHERE id = ?"
    );
    $stmt->bind_param('ssi', $chi, $nota, $id);
    $stmt->execute();
    $stmt->close();

    registra(
        $conn, 'withdraw', $tipo, $id, (string) $riga['nome'],
        ['shared_status' => 'approved', 'reviewed_by' => $riga['reviewed_by'], 'reviewed_at' => $riga['reviewed_at']],
        ['shared_status' => 'rejected'],
        $nota
    );
    return [($tipo === 'recipe' ? 'Ricetta ritirata: ' : 'Alimento ritirato: ') . $riga['nome'], 'esito'];
}

/** Una riga nel registro. Ogni decisione ci passa, senza eccezioni. */
function registra(
    mysqli $conn,
    string $azione,
    string $tipoOggetto,
    int $idOggetto,
    ?string $etichetta,
    ?array $prima,
    ?array $dopo,
    ?string $nota = null
): void {
    $admin = adminCorrente()['email'] ?? 'sconosciuto';
    $primaJson = $prima === null || $prima === [] ? null : json_encode($prima, JSON_UNESCAPED_UNICODE);
    $dopoJson = $dopo === null || $dopo === [] ? null : json_encode($dopo, JSON_UNESCAPED_UNICODE);
    $stmt = $conn->prepare(
        'INSERT INTO na_review_log
           (admin_email, action, target_type, target_id, target_label, before_json, after_json, note)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->bind_param('sssissss', $admin, $azione, $tipoOggetto, $idOggetto, $etichetta, $primaJson, $dopoJson, $nota);
    $stmt->execute();
    $stmt->close();
}

/**
 * Valori sospetti: evidenziati e NON spuntati per difetto.
 *
 * Tre controlli, tutti nati da errori reali di chi copia un'etichetta:
 *  - un fattore 10, 100 o 1000 rispetto al valore attuale (virgola spostata);
 *  - un valore negativo;
 *  - piu' di 100 g di un nutriente su 100 g di prodotto, che non e' possibile.
 *
 * Cio' che NON prende: "per porzione" scambiato con "per 100 g", che di solito
 * e' un fattore fra 2 e 4 e non si distingue da una correzione legittima. Quel
 * caso lo prende l'occhio guardando la foto della tabella — ed e' il motivo
 * per cui la foto sta accanto ai numeri e non in un'altra schermata.
 */
function sospetto(string $campo, $attuale, $proposto): ?string
{
    $p = (float) $proposto;
    if ($p < 0) {
        return 'valore negativo';
    }

    // Campi espressi in grammi su 100 g: oltre 100 non esistono.
    static $inGrammi = [
        'carbs', 'proteins', 'fats', 'fibers', 'sugars', 'water', 'saturated_fats',
        'monounsaturated_fats', 'polyunsaturated_fats', 'trans_fats', 'added_sugars',
        'starch', 'polyols', 'lactose', 'salt',
    ];
    if (in_array($campo, $inGrammi, true) && $p > 100) {
        return 'oltre 100 g su 100 g di prodotto';
    }

    $a = (float) $attuale;
    if ($a > 0 && $p > 0) {
        $rapporto = $p > $a ? $p / $a : $a / $p;
        foreach ([1000, 100, 10] as $fattore) {
            if (abs($rapporto - $fattore) < $fattore * 0.02) {
                return 'differenza di ' . $fattore . ' volte: virgola spostata?';
            }
        }
    }
    return null;
}
