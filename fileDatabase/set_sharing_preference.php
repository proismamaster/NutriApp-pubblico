<?php
/**
 * set_sharing_preference.php — consenso generale a proporre i propri alimenti
 * personali al database pubblico (punto 2 della collaborazione, ROADMAP).
 *
 * COSA FA IL CONSENSO, ESATTAMENTE
 * Accendendolo, gli alimenti personali ancora `private` passano a `pending`:
 * sono PROPOSTI, non pubblicati. Nessuno li vede finche' non li approva una
 * revisione. Spegnendolo, i `pending` tornano `private` e sparisce la proposta.
 *
 * COSA NON FA: non tocca gli `approved`. Un alimento gia' entrato nel database
 * pubblico non si ritira spegnendo un interruttore generale — per quello c'e'
 * share_custom_food.php, che agisce su UNO, cosi' il ritiro e' una scelta
 * deliberata su una cosa precisa e non l'effetto collaterale di un consenso
 * revocato. La risposta dice quanti restano pubblici, perche' l'utente deve
 * poterlo sapere senza doverlo scoprire da solo.
 *
 * Richiede: community_comune.php, db_config.php e la migrazione
 * 2026-09-12_collaborazione_community.sql.
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

if ($userMail === '' || !array_key_exists('share_custom_foods', $dati)) {
    communityErrore('Dati mancanti: servono user_mail e share_custom_foods.');
}

// "1", 1, true e "true" valgono tutti si': il valore arriva da un interruttore,
// e a seconda di come viene serializzato cambia forma.
$condividi = filter_var($dati['share_custom_foods'], FILTER_VALIDATE_BOOLEAN) ? 1 : 0;

communityRichiediMigrazione($conn, 'na_users', 'share_custom_foods');
communityRichiediMigrazione($conn, 'na_custom_foods', 'shared_status');

if (!communityUtenteEsiste($conn, $userMail)) {
    communityErrore('Utente non trovato: ' . $userMail);
}

$conn->begin_transaction();
try {
    $stmt = $conn->prepare(
        'UPDATE na_users SET share_custom_foods = ?, share_asked_at = NOW() WHERE email = ?'
    );
    $stmt->bind_param('is', $condividi, $userMail);
    $stmt->execute();
    $stmt->close();

    if ($condividi === 1) {
        $stmt = $conn->prepare(
            'UPDATE na_custom_foods SET shared_status = "pending", shared_at = NOW()
              WHERE user_mail = ? AND shared_status = "private"'
        );
    } else {
        // `shared_at` torna NULL: la data serve a ordinare la coda di revisione,
        // e una riga non piu' in coda con una data addosso sembrerebbe in attesa.
        $stmt = $conn->prepare(
            'UPDATE na_custom_foods SET shared_status = "private", shared_at = NULL
              WHERE user_mail = ? AND shared_status = "pending"'
        );
    }
    $stmt->bind_param('s', $userMail);
    $stmt->execute();
    $toccati = $stmt->affected_rows;
    $stmt->close();

    $stmt = $conn->prepare(
        'SELECT COUNT(*) AS n FROM na_custom_foods WHERE user_mail = ? AND shared_status = "approved"'
    );
    $stmt->bind_param('s', $userMail);
    $stmt->execute();
    $pubblici = (int) ($stmt->get_result()->fetch_assoc()['n'] ?? 0);
    $stmt->close();

    $conn->commit();
} catch (Throwable $e) {
    $conn->rollback();
    communityErrore('Preferenza non salvata: ' . $e->getMessage());
}

$conn->close();

communityOk([
    'share_custom_foods' => $condividi,
    'foods_changed'      => (int) $toccati,
    'foods_public'       => $pubblici,
]);
