<?php
// Copia questo file in db_config.local.php (stessa cartella, escluso da
// git) e inserisci le credenziali reali del database MySQL/MariaDB
// dell'hosting. In alternativa, imposta le variabili d'ambiente
// DB_HOST / DB_USER / DB_PASSWORD / DB_NAME sul server, che hanno
// priorità su questo file (vedi db_config.php).

$servername = "localhost";
$username   = "il-tuo-utente-db";
$password   = "la-tua-password-db";
$dbname     = "il-nome-del-tuo-db";

// Chiave dell'API di Brevo per le mail con il codice di verifica (registrazione
// e recupero password), letta da send_otp.php. Serve una API key (inizia con
// "xkeysib-"), non una chiave SMTP ("xsmtpsib-"). La variabile d'ambiente
// BREVO_API_KEY, se presente, ha la priorita'. Senza chiave send_otp.php
// risponde "Chiave Brevo non configurata" e nessuna mail parte.
$brevo_api_key = "la-tua-api-key-brevo";
