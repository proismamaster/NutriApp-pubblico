<?php
/**
 * save_food_report.php — un utente segnala che un alimento del database e'
 * sbagliato (punto 1 della collaborazione, ROADMAP).
 *
 * DIVERSO DA save_report.php, che raccoglie i problemi dell'APP. Qui il
 * soggetto e' un alimento preciso: il dato e' sbagliato, non il programma.
 * Mescolarli avrebbe reso ogni riga da interpretare a mano per capire di cosa
 * si stia parlando.
 *
 * DAL 13/09 PUO' PORTARE ANCHE LA CORREZIONE, NON SOLO LA LAMENTELA
 * `proposed` sono i valori che l'utente propone (solo i campi che ha toccato),
 * `photos` le foto dell'etichetta che li dimostrano. Nessuno dei due tocca il
 * database dei prodotti: finiscono nella segnalazione, che resta `pending`
 * finche' un revisore non la guarda nel pannello e accetta campo per campo.
 *
 * Le chiavi di `proposed` NON sono nomi di colonna fidati: qui vengono solo
 * ripulite e contate, e il confronto con le colonne vere lo fa il pannello
 * (`campiAmmessi()` in admin/_comune.php) al momento di scrivere. Il posto in
 * cui si decide cosa e' scrivibile deve essere uno solo, ed e' quello.
 *
 * Richiede: community_comune.php, db_config.php e le migrazioni
 * 2026-09-12_collaborazione_community.sql e 2026-09-12_pannello_admin.sql.
 */

/*
 * IL FILE COMUNE, CONTROLLATO PRIMA DI CHIEDERLO.
 *
 * `require` di un file assente e' un errore fatale: la risposta diventa un
 * avviso PHP piu' un 500, e dall'app si vede solo "errore" senza dire quale.
 * E' esattamente cio' che il 07/09 ha tenuto giu' il salvataggio ricette per
 * tre sessioni, con `recipe_ingredient_columns.php` rimasto a terra. Cinque
 * righe qui dentro — non in un altro file condiviso, che si romperebbe allo
 * stesso modo — e chi carica via FTP legge il nome di cio' che manca.
 */
if (!is_file(__DIR__ . '/community_comune.php')) {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'status'  => 'error',
        'message' => 'File mancante sul server: community_comune.php — va caricato via FTP nella stessa cartella di questo script.',
    ]);
    exit;
}

require_once __DIR__ . '/community_comune.php';
communityAvvia();
communitySoloPost();

require communityRichiediFile('db_config.php');
require_once __DIR__ . '/auth.php';

$dati = communityCorpo();

// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$userMail = emailAutenticata($conn, trim((string) ($dati['user_mail'] ?? '')));
$foodName = trim((string) ($dati['food_name'] ?? ''));
$issue    = trim((string) ($dati['issue'] ?? ''));

if ($userMail === '' || $foodName === '' || $issue === '') {
    communityErrore('Dati mancanti: servono user_mail, food_name e issue.');
}
if (!in_array($issue, NA_TIPI_SEGNALAZIONE, true)) {
    communityErrore('Tipo di problema non valido: ' . $issue . '. Ammessi: ' . implode(', ', NA_TIPI_SEGNALAZIONE) . '.');
}

communityRichiediMigrazione($conn, 'na_food_reports', 'status');

if (!communityUtenteEsiste($conn, $userMail)) {
    communityErrore('Utente non trovato: ' . $userMail);
}

// I facoltativi vuoti diventano NULL, non stringhe vuote: una colonna piena di
// '' non si distingue da una risposta data e cancellata.
$nulloSeVuoto = static function ($v) {
    $v = trim((string) ($v ?? ''));
    return $v === '' ? null : $v;
};

$barcode        = $nulloSeVuoto($dati['barcode'] ?? null);
$source         = $nulloSeVuoto($dati['source'] ?? null);
$fieldName      = $nulloSeVuoto($dati['field_name'] ?? null);
$suggestedValue = $nulloSeVuoto($dati['suggested_value'] ?? null);
$note           = $nulloSeVuoto($dati['note'] ?? null);

/*
 * DOPPIONI: la stessa persona che segnala due volte lo stesso problema sullo
 * stesso alimento non aggiunge informazione, aggiunge lavoro a chi rivede.
 * Vale solo finche' la prima e' aperta: se e' stata gestita e il problema si
 * ripresenta, va potuta segnalare di nuovo.
 *
 * Il confronto e' sul barcode quando c'e', altrimenti sul nome — gli alimenti
 * CREA/USDA e quelli personali non hanno barcode.
 */
if ($barcode !== null) {
    $sql = 'SELECT id FROM na_food_reports
             WHERE user_mail = ? AND barcode = ? AND issue = ? AND status = "pending" LIMIT 1';
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('sss', $userMail, $barcode, $issue);
} else {
    $sql = 'SELECT id FROM na_food_reports
             WHERE user_mail = ? AND barcode IS NULL AND food_name = ? AND issue = ? AND status = "pending" LIMIT 1';
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('sss', $userMail, $foodName, $issue);
}
$stmt->execute();
$giaAperta = $stmt->get_result()->fetch_assoc();
$stmt->close();

if ($giaAperta) {
    // `already` e' un esito positivo, non un errore: dal punto di vista di chi
    // usa l'app la segnalazione c'e'. Dirgli "errore" lo farebbe ritentare.
    communityOk([
        'already'   => true,
        'report_id' => (int) $giaAperta['id'],
        'message'   => 'Segnalazione gia\' aperta per questo alimento.',
    ]);
}

/*
 * LA PROPOSTA DI VALORI.
 *
 * Si accettano solo coppie nome->valore scalare: niente oggetti annidati,
 * niente liste. Il tetto di 80 campi e' due volte i nutrienti esistenti, e
 * serve solo a impedire che una richiesta malfatta riempia la colonna.
 * I nomi vengono ripuliti (lettere, numeri, trattino basso): non e' una
 * verifica di esistenza — quella tocca al pannello — ma evita di conservare
 * chiavi che nessuna colonna potra' mai avere.
 */
$proposta = null;
$grezza = $dati['proposed'] ?? null;
if (is_string($grezza) && $grezza !== '') {
    $grezza = json_decode($grezza, true);
}
if (is_array($grezza) && $grezza !== []) {
    $pulita = [];
    foreach ($grezza as $campo => $valore) {
        if (count($pulita) >= 80) {
            break;
        }
        $campo = (string) $campo;
        if (!preg_match('/^[a-z0-9_]{1,60}$/i', $campo) || is_array($valore) || is_object($valore)) {
            continue;
        }
        if ($valore === null || $valore === '') {
            continue;
        }
        $pulita[$campo] = is_numeric($valore) ? 0 + $valore : mb_substr((string) $valore, 0, 255);
    }
    if ($pulita !== []) {
        $proposta = json_encode($pulita, JSON_UNESCAPED_UNICODE);
    }
}

// `nuovo` = l'alimento non esiste e lo sta caricando l'utente; `correzione` =
// esiste ed e' sbagliato. Sono due letture diverse per chi rivede.
$kind = ($dati['kind'] ?? '') === 'nuovo' ? 'nuovo' : 'correzione';

$haColonneProposta = communityColonnaEsiste($conn, 'na_food_reports', 'proposed_json');

if ($haColonneProposta) {
    $sql = 'INSERT INTO na_food_reports
              (user_mail, barcode, food_name, source, issue, field_name, suggested_value, note,
               kind, proposed_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
    $stmt = $conn->prepare($sql);
    $stmt->bind_param(
        'ssssssssss',
        $userMail,
        $barcode,
        $foodName,
        $source,
        $issue,
        $fieldName,
        $suggestedValue,
        $note,
        $kind,
        $proposta
    );
} else {
    // Server con la prima migrazione ma non la seconda: la segnalazione si
    // salva lo stesso, senza la proposta. Meglio una segnalazione parziale che
    // un errore su una cosa che l'utente ha appena scritto.
    $sql = 'INSERT INTO na_food_reports
              (user_mail, barcode, food_name, source, issue, field_name, suggested_value, note)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)';
    $stmt = $conn->prepare($sql);
    $stmt->bind_param(
        'ssssssss',
        $userMail,
        $barcode,
        $foodName,
        $source,
        $issue,
        $fieldName,
        $suggestedValue,
        $note
    );
}

if (!$stmt->execute()) {
    $messaggio = $stmt->error;
    $stmt->close();
    communityErrore('Segnalazione non salvata: ' . $messaggio);
}

$id = $stmt->insert_id;
$stmt->close();

/*
 * LE FOTO DELLA PROVA.
 *
 * Arrivano gia' caricate da upload_image.php, che e' l'unico punto che tocca
 * i file: qui si conservano solo l'indirizzo e il ruolo.
 *
 * L'indirizzo DEVE puntare alla nostra cartella uploads/. Senza questo
 * controllo, un client potrebbe far salvare l'indirizzo di un'immagine
 * ospitata altrove, che poi il pannello caricherebbe: chi rivede finirebbe per
 * chiedere un file a un server sconosciuto, ogni volta che apre la
 * segnalazione. Il ruolo viene da una lista chiusa perche' e' un'etichetta,
 * non testo libero.
 */
$foto = $dati['photos'] ?? [];
if ($haColonneProposta && is_array($foto) && $foto !== []) {
    $ruoliAmmessi = ['fronte', 'tabella', 'ingredienti', 'altro'];
    $stmt = $conn->prepare(
        'INSERT INTO na_report_photos (report_id, url, role, sort_order) VALUES (?, ?, ?, ?)'
    );
    $ordine = 0;
    foreach ($foto as $f) {
        if ($ordine >= 4) {
            break;
        }
        $url = is_array($f) ? (string) ($f['url'] ?? '') : (string) $f;
        $ruolo = is_array($f) ? (string) ($f['role'] ?? 'altro') : 'altro';
        $url = trim($url);
        if ($url === '' || mb_strlen($url) > 500) {
            continue;
        }
        if (stripos($url, '/nutriapp/uploads/') === false) {
            continue;
        }
        if (!in_array($ruolo, $ruoliAmmessi, true)) {
            $ruolo = 'altro';
        }
        $stmt->bind_param('issi', $id, $url, $ruolo, $ordine);
        $stmt->execute();
        $ordine++;
    }
    $stmt->close();
}

$conn->close();

communityOk([
    'report_id' => (int) $id,
    'already'   => false,
    // Quanti campi e quante foto sono stati registrati davvero: se il server
    // e' indietro con la seconda migrazione, l'app lo scopre da qui invece di
    // credere di aver mandato una proposta che non c'e'.
    'proposed_fields' => $proposta === null ? 0 : count(json_decode($proposta, true) ?: []),
    'photos_saved'    => $haColonneProposta ? min(is_array($foto) ? count($foto) : 0, 4) : 0,
]);
