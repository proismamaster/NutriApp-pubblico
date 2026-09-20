#!/usr/bin/env bash
# prova_recupero_password.sh — prova end-to-end del recupero password
# (send_otp.php + reset_password.php), con VERE richieste HTTP contro un MySQL
# locale usa-e-getta.
#
# PERCHE' ESISTE (14/09): l'app chiamava reset_password.php da mesi, ma il file
# non era mai esistito, ne' nel repo ne' sul server (GET: 404). Il dialogo
# rispondeva "email non trovata o codice errato" e nessuno poteva accorgersi
# che l'ultimo passo semplicemente mancava.
#
# COSA PROVA:
#   1. send_otp.php gira senza la cartella phpmailer/ e salva un codice di 6 cifre
#   2. reset_password.php senza migrazione: lo dice, non muore
#   3. richieste sbagliate (GET, dati mancanti, email non valida)
#   4. controllo del codice che NON lo consuma
#   5. codice sbagliato: conta il tentativo e dice quanti ne restano
#   6. password troppo corta: rifiutata senza bruciare un tentativo
#   7. cambio riuscito: il login entra con la nuova e non con la vecchia
#   8. il codice usato non vale una seconda volta
#   9. cinque tentativi sbagliati bruciano il codice, anche quello giusto
#  10. codice scaduto
#  11. email senza account
#
# SERVE: XAMPP (PHP + MySQL) sul percorso qui sotto, e MySQL avviato.
# Non manda mail: BREVO_API_KEY viene tolta dall'ambiente del server di prova,
# e il db_config.php di prova non definisce la chiave.
#
#   bash fileDatabase/prova_recupero_password.sh
set -u
unset BREVO_API_KEY

PHP=/c/xampp/php/php.exe
MYSQL=/c/xampp/mysql/bin/mysql.exe
REPO="$(cd "$(dirname "$0")" && pwd)"
DIR="${TMPDIR:-/tmp}/nutriapp_prova_recupero"
DB=nutriapp_prova_recupero
PORTA=8767
EMAIL=chi.dimentica@prova.test

rm -rf "$DIR" && mkdir -p "$DIR"

$MYSQL -u root -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB DEFAULT CHARACTER SET utf8mb4;"
$MYSQL -u root $DB < "$REPO/na_users.sql"
$MYSQL -u root $DB < "$REPO/na_otp_codes.sql"

# Un utente con una password conosciuta. L'hash lo calcola PHP e passa da
# printf: dentro c'e' "$2y$10$...", che scritto in una stringa di shell
# diventerebbe una sostituzione di variabili e arriverebbe al database mozzato.
VECCHIO_HASH=$("$PHP" -r 'echo password_hash("vecchia-password", PASSWORD_BCRYPT);')
printf "INSERT INTO na_users (email, password_hash, first_name) VALUES ('%s', '%s', 'Ismail');\n" \
  "$EMAIL" "$VECCHIO_HASH" > "$DIR/semina.sql"
$MYSQL -u root $DB < "$DIR/semina.sql" || { echo "semina fallita: mi fermo"; exit 1; }

cat > "$DIR/db_config.php" <<PHP
<?php
\$conn = new mysqli('127.0.0.1', 'root', '', '$DB');
if (\$conn->connect_error) { die('connessione fallita: ' . \$conn->connect_error); }
\$conn->set_charset('utf8mb4');
PHP

cp "$REPO/send_otp.php" "$REPO/reset_password.php" "$REPO/login.php" "$DIR/"

"$PHP" -S 127.0.0.1:$PORTA -t "$DIR" >"$DIR/server.log" 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
for _ in $(seq 1 40); do
  curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$PORTA/reset_password.php" && break
  sleep 0.25
done

posta() { curl -s --max-time 20 -X POST "http://127.0.0.1:$PORTA/$1" "${@:2}"; }
recupero() { posta reset_password.php --data-urlencode "email=$1" --data-urlencode "otp=$2" "${@:3}"; }
accedi() {
  curl -s --max-time 20 -X POST -H "Content-Type: application/json" \
    --data-binary "{\"email\":\"$EMAIL\",\"password\":\"$1\"}" "http://127.0.0.1:$PORTA/login.php"
}
sql() { $MYSQL -u root $DB -N -B -e "$1"; }

VERDI=0
ROSSI=0
atteso() { # atteso "<risposta>" "<pezzo che deve comparire>" "<descrizione>"
  if echo "$1" | grep -q -- "$2"; then echo "  OK     $3"; VERDI=$((VERDI+1));
  else echo "  ROTTO  $3"; echo "         atteso: $2"; echo "         avuto:  $(echo "$1" | head -c 300)"; ROSSI=$((ROSSI+1)); fi
}
assente() { # assente "<risposta>" "<pezzo che NON deve comparire>" "<descrizione>"
  if echo "$1" | grep -q -- "$2"; then echo "  ROTTO  $3"; echo "         non doveva esserci: $2"; ROSSI=$((ROSSI+1));
  else echo "  OK     $3"; VERDI=$((VERDI+1)); fi
}
ugualeA() {
  if [ "$1" = "$2" ]; then echo "  OK     $3"; VERDI=$((VERDI+1));
  else echo "  ROTTO  $3 (atteso '$2', avuto '$1')"; ROSSI=$((ROSSI+1)); fi
}

echo "=== 1. send_otp.php senza phpmailer/ ==="
R=$(posta send_otp.php --data-urlencode "email=$EMAIL")
atteso "$R" "Chiave Brevo non configurata" "risponde in JSON invece di fermarsi sui require"
ugualeA "$(sql "SELECT COUNT(*) FROM na_otp_codes WHERE email='$EMAIL' AND code REGEXP '^[0-9]{6}\$';")" "1" \
  "e ha salvato un codice di 6 cifre"

echo
echo "=== 2. senza migrazione ==="
R=$(recupero "$EMAIL" 123456 --data-urlencode "check_only=1")
atteso "$R" '"code":"missing_migration"' "dice che manca la migrazione"
$MYSQL -u root $DB < "$REPO/migrations/2026-09-14_recupero_password.sql"
if $MYSQL -u root $DB < "$REPO/migrations/2026-09-14_recupero_password.sql"; then
  echo "  OK     la migrazione si puo' rilanciare"; VERDI=$((VERDI+1))
else
  echo "  ROTTO  la migrazione rilanciata fallisce"; ROSSI=$((ROSSI+1))
fi

echo
echo "=== 3. richieste sbagliate ==="
R=$(curl -s --max-time 20 "http://127.0.0.1:$PORTA/reset_password.php")
atteso "$R" '"code":"bad_request"' "GET rifiutata"
T=$(curl -s -o /dev/null -w '%{content_type}' --max-time 20 "http://127.0.0.1:$PORTA/reset_password.php")
atteso "$T" "application/json" "risponde come JSON"
R=$(posta reset_password.php --data-urlencode "email=$EMAIL")
atteso "$R" '"code":"bad_request"' "senza codice"
R=$(recupero "non-una-email" 123456 --data-urlencode "check_only=1")
atteso "$R" '"code":"bad_request"' "email non valida"
R=$(recupero "$EMAIL" 12ab56 --data-urlencode "check_only=1")
atteso "$R" '"code":"bad_request"' "codice che non e' di 6 cifre"

# Da qui un codice conosciuto al posto di quello casuale di send_otp.
sql "DELETE FROM na_otp_codes; INSERT INTO na_otp_codes (email, code) VALUES ('$EMAIL', '123456');"

echo
echo "=== 4. controllo del codice che non lo consuma ==="
R=$(recupero "$EMAIL" 123456 --data-urlencode "check_only=1")
atteso "$R" '"status":"success"' "codice giusto riconosciuto"
ugualeA "$(sql "SELECT COUNT(*) FROM na_otp_codes;")" "1" "e ancora li' per il passo dopo"
ugualeA "$(sql "SELECT attempts FROM na_otp_codes;")" "0" "senza aver usato tentativi"

echo
echo "=== 5. codice sbagliato ==="
R=$(recupero "$EMAIL" 000000 --data-urlencode "check_only=1")
atteso "$R" '"code":"wrong_code"' "rifiutato"
atteso "$R" '"remaining":4' "e dice quanti tentativi restano"

echo
echo "=== 6. password troppo corta ==="
R=$(recupero "$EMAIL" 123456 --data-urlencode "new_password=corta")
atteso "$R" '"code":"invalid_password"' "rifiutata"
ugualeA "$(sql "SELECT attempts FROM na_otp_codes;")" "1" "senza bruciare un tentativo (resta quello del punto 5)"

echo
echo "=== 7. cambio riuscito ==="
R=$(recupero "$EMAIL" 123456 --data-urlencode "new_password=nuova-password-lunga")
atteso "$R" '"status":"success"' "password cambiata"
ugualeA "$(sql "SELECT COUNT(*) FROM na_otp_codes;")" "0" "e il codice non esiste piu'"
atteso "$(accedi nuova-password-lunga)" "Login effettuato" "il login entra con la nuova"
assente "$(accedi vecchia-password)" "Login effettuato" "e non con la vecchia"

echo
echo "=== 8. lo stesso codice una seconda volta ==="
R=$(recupero "$EMAIL" 123456 --data-urlencode "new_password=un-altra-password")
atteso "$R" '"code":"expired"' "il codice usato non vale piu'"
atteso "$(accedi nuova-password-lunga)" "Login effettuato" "e la password resta quella di prima"

echo
echo "=== 9. cinque tentativi sbagliati ==="
sql "INSERT INTO na_otp_codes (email, code) VALUES ('$EMAIL', '654321');"
for _ in 1 2 3 4; do recupero "$EMAIL" 111111 --data-urlencode "check_only=1" >/dev/null; done
R=$(recupero "$EMAIL" 111111 --data-urlencode "check_only=1")
atteso "$R" '"code":"too_many"' "il quinto errore brucia il codice"
R=$(recupero "$EMAIL" 654321 --data-urlencode "check_only=1")
atteso "$R" '"code":"expired"' "e dopo non vale nemmeno quello giusto"

echo
echo "=== 10. codice scaduto ==="
sql "INSERT INTO na_otp_codes (email, code, expires_at) VALUES ('$EMAIL', '222222', CURRENT_TIMESTAMP - INTERVAL 1 MINUTE);"
R=$(recupero "$EMAIL" 222222 --data-urlencode "check_only=1")
atteso "$R" '"code":"expired"' "un codice scaduto non vale"

echo
echo "=== 11. email senza account ==="
sql "INSERT INTO na_otp_codes (email, code) VALUES ('nessuno@prova.test', '333333');"
R=$(recupero nessuno@prova.test 333333 --data-urlencode "new_password=nuova-password-lunga")
atteso "$R" '"code":"no_account"' "lo dice, invece di rispondere 'fatto' senza aver cambiato niente"

echo
if grep -q -i "fatal\|warning" "$DIR/server.log"; then
  echo "  ROTTO  il server di prova ha scritto errori PHP:"; grep -i "fatal\|warning" "$DIR/server.log" | head -5
  ROSSI=$((ROSSI+1))
else
  echo "  OK     nessun errore o avviso PHP nel log del server"; VERDI=$((VERDI+1))
fi

echo
echo "verdi: $VERDI   rossi: $ROSSI"
kill $SERVER 2>/dev/null
$MYSQL -u root -e "DROP DATABASE $DB;"
rm -rf "$DIR"
echo "database e cartella di prova rimossi."
[ "$ROSSI" -eq 0 ]
