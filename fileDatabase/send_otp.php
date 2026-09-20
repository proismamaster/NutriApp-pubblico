<?php
// send_otp.php
//
// La mail parte dall'API REST di Brevo con curl (fix 2026-08-29): PHPMailer non
// si usa piu'. I suoi `require` erano rimasti qui in cima e sono stati tolti il
// 2026-09-14: la cartella phpmailer/ non e' nel repo, e su un server che non ce
// l'ha questo file si fermava con un errore fatale prima ancora di leggere
// l'email.
require 'db_config.php';

$email = $_POST['email'] ?? '';

if (empty($email)) {
    echo json_encode(["status" => "error", "message" => "Email mancante"]);
    exit;
}

// Genera un codice a 6 cifre. random_int e non rand (2026-09-14): rand non e'
// fatto per la sicurezza, e questo codice e' cio' che permette di cambiare la
// password di un account.
$otp = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

// Elimina eventuali codici precedenti per la stessa email
$stmt = $conn->prepare("DELETE FROM na_otp_codes WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
$stmt->close();

// Inserisce il nuovo codice nel Database
$stmt = $conn->prepare("INSERT INTO na_otp_codes (email, code) VALUES (?, ?)");
$stmt->bind_param("ss", $email, $otp);

if ($stmt->execute()) {
    // La chiave NON sta piu' qui dentro (fix 2026-08-29). Questo file e'
    // tracciato da git e il repo e' stato pubblico fino al 22/07: la chiave
    // precedente era leggibile da chiunque, e Brevo revoca le chiavi che
    // trova pubbliche — probabile causa del "l'OTP non arriva mai".
    // Ora arriva da BREVO_API_KEY (variabile d'ambiente) oppure da
    // db_config.local.php, che e' in .gitignore. Stesso schema gia' usato
    // per le credenziali del database.
    // ATTENZIONE: serve una API key (`xkeysib-...`), non una chiave SMTP
    // (`xsmtpsib-...`): quest'endpoint REST accetta solo la prima.
    $apiKey = getenv('BREVO_API_KEY');
    if ($apiKey === false || $apiKey === '') {
        $apiKey = isset($brevo_api_key) ? $brevo_api_key : '';
    }
    if ($apiKey === '') {
        echo json_encode([
            "status"  => "error",
            "message" => "Chiave Brevo non configurata sul server: impostare BREVO_API_KEY o \$brevo_api_key in db_config.local.php"
        ]);
        $stmt->close();
        $conn->close();
        exit;
    }

    $emailData = [
        // FIX 2026-08-29: il mittente era 'ismail.barakat@galileo.galileicrema.it',
        // che su Brevo non e' MAI stato registrato — verificato interrogando
        // GET /v3/senders, che restituisce solo 'ismail@ismailbarakat.dev'.
        // Brevo rifiuta gli invii da mittenti non verificati, quindi questa era
        // la seconda causa del "l'OTP non arriva", indipendente dal filtro IP:
        // anche sbloccando l'IP, l'invio sarebbe fallito lo stesso.
        // ismailbarakat.dev e' autenticato via DNS sull'account (record SPF/DKIM
        // in regola), quindi e' anche la scelta migliore per non finire in spam.
        'sender' => ['name' => 'NutriApp', 'email' => 'ismail@ismailbarakat.dev'],
        'to' => [['email' => $email]],
        'subject' => 'Codice di verifica NutriApp',
        'htmlContent' => '<h2>Il tuo codice e: <strong>' . $otp . '</strong></h2><p>Scade tra 15 minuti.</p>'
    ];

    $jsonPayload = json_encode($emailData, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => 'https://api.brevo.com/v3/smtp/email',
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => $jsonPayload,
        CURLOPT_HTTPHEADER     => [
            'Accept: application/json',
            'Content-Type: application/json',
            'Content-Length: ' . strlen($jsonPayload),
            'api-key: ' . $apiKey
        ]
    ]);

    $result   = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode == 201) {
        echo json_encode(["status" => "success", "message" => "Codice inviato"]);
    } else {
        // `otp_debug` rimosso il 2026-08-29: rimandava il codice di verifica in
        // chiaro nella risposta. Chiunque conoscesse l'endpoint poteva chiedere
        // un OTP per l'email di un altro, leggerlo qui e completare la
        // registrazione al posto suo. Il corpo dell'errore Brevo resta, perche'
        // serve a diagnosticare: non contiene segreti.
        echo json_encode(["status" => "error", "message" => "Errore API: $result"]);
    }
}else {
    echo json_encode(["status" => "error", "message" => "Errore nel salvataggio del codice: " . $conn->error]);
}

$stmt->close();
$conn->close();
?>
