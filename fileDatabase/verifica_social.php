<?php
// verifica_social.php
//
// Controlla che un accesso "con Google" venga davvero da Google.
//
// Perche' esiste (21/09): social_login.php si fidava dell'email mandata dal
// client. Una POST con l'email di un altro bastava per farsi dare un gettone
// di sessione valido, cioe' per entrare come quella persona. Il gettone
// introdotto il 20/09 non serviva a niente, perche' da qui si entrava senza
// dimostrare nulla.
//
// Ora l'app manda l'id_token firmato da Google e qui si verifica con Google
// stesso. L'email autorevole e' quella scritta nel token, non quella mandata
// dal client: cosi' non c'e' modo di chiedere la sessione di un altro.

/// Gli id delle applicazioni a cui Google puo' aver rilasciato il token: sono
/// quelli di google-services.json (Android e "web"). Non sono segreti, stanno
/// dentro l'app installata; segreta e' solo la firma, che la fa Google.
const GOOGLE_CLIENT_ID_AMMESSI = [
    '416008927739-3hddbl7jokpf2rdcvs67c2jnb21qn573.apps.googleusercontent.com',
    '416008927739-2ih8ompg1kib7e7bi0skbdkusdjjnrka.apps.googleusercontent.com',
];

/// Verifica un id_token di Google.
///
/// Torna ['email' => ..., 'sub' => ..., 'nome' => ..., 'cognome' => ...]
/// quando il token e' valido, altrimenti una stringa con il motivo del
/// rifiuto: chi chiama decide cosa dire all'utente.
///
/// La verifica la fa Google (endpoint tokeninfo): non ci si accontenta di
/// leggere il contenuto del token, che chiunque puo' scrivere.
function verificaTokenGoogle(string $idToken): array|string
{
    if ($idToken === '') {
        return 'token_mancante';
    }

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL => 'https://oauth2.googleapis.com/tokeninfo?id_token=' . urlencode($idToken),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 10,
        CURLOPT_SSL_VERIFYPEER => true,
    ]);
    $risposta = curl_exec($ch);
    $codice   = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $erroreRete = curl_error($ch);
    curl_close($ch);

    // Google non raggiungibile: e' un guasto, non un tentativo di imbroglio, e
    // va distinto — chi chiama non deve dire "accesso rifiutato" per un
    // problema di rete del server.
    if ($risposta === false || $erroreRete !== '') {
        return 'verifica_non_disponibile';
    }
    if ($codice !== 200) {
        return 'token_rifiutato';
    }

    $dati = json_decode($risposta, true);
    if (!is_array($dati)) {
        return 'token_illeggibile';
    }
    if (!in_array($dati['aud'] ?? '', GOOGLE_CLIENT_ID_AMMESSI, true)) {
        return 'token_di_altra_app';
    }
    // Google scrive email_verified come stringa "true", non come booleano.
    $verificata = $dati['email_verified'] ?? 'false';
    if ($verificata !== true && $verificata !== 'true') {
        return 'email_non_verificata';
    }
    $email = trim(strtolower((string) ($dati['email'] ?? '')));
    if ($email === '' || ($dati['sub'] ?? '') === '') {
        return 'token_incompleto';
    }

    return [
        'email'   => $email,
        'sub'     => (string) $dati['sub'],
        'nome'    => (string) ($dati['given_name'] ?? ''),
        'cognome' => (string) ($dati['family_name'] ?? ''),
    ];
}
