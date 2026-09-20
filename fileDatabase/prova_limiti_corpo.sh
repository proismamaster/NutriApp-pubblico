#!/usr/bin/env bash
# prova_limiti_corpo.sh — i limiti dei dati del corpo negli endpoint (2026-09-14):
# signup.php, update_profile.php, update_goals.php, con VERE richieste HTTP
# contro un MySQL locale usa-e-getta.
#
# PERCHE' ESISTE: fino al 13/09 il server accettava un peso di 2 kg e un'eta'
# di 3 anni. L'app ora li blocca, ma un'app vecchia o una richiesta scritta a
# mano arrivano direttamente qui. Si prova anche il caso opposto: i campi
# vuoti (o a zero) di un'app vecchia devono continuare a passare.
#
# SERVE: XAMPP (PHP + MySQL) sul percorso qui sotto, e MySQL avviato.
#
#   bash fileDatabase/prova_limiti_corpo.sh
set -u

PHP=/c/xampp/php/php.exe
MYSQL=/c/xampp/mysql/bin/mysql.exe
REPO="$(cd "$(dirname "$0")" && pwd)"
DIR="${TMPDIR:-/tmp}/nutriapp_prova_limiti"
DB=nutriapp_prova_limiti
PORTA=8768

rm -rf "$DIR" && mkdir -p "$DIR"
$MYSQL -u root -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB DEFAULT CHARACTER SET utf8mb4;"
$MYSQL -u root $DB < "$REPO/na_users.sql"

cat > "$DIR/db_config.php" <<PHP
<?php
\$conn = new mysqli('127.0.0.1', 'root', '', '$DB');
if (\$conn->connect_error) { die('connessione fallita: ' . \$conn->connect_error); }
\$conn->set_charset('utf8mb4');
PHP
cp "$REPO/signup.php" "$REPO/update_profile.php" "$REPO/update_goals.php" "$DIR/"

"$PHP" -S 127.0.0.1:$PORTA -t "$DIR" >"$DIR/server.log" 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
for _ in $(seq 1 40); do
  curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$PORTA/signup.php" && break
  sleep 0.25
done

posta() { curl -s --max-time 20 -X POST "http://127.0.0.1:$PORTA/$1" "${@:2}"; }
sql() { $MYSQL -u root $DB -N -B -e "$1"; }
anni_fa() { date -d "-$1 years" +%Y-%m-%d; }

VERDI=0
ROSSI=0
atteso() {
  if echo "$1" | grep -q -- "$2"; then echo "  OK     $3"; VERDI=$((VERDI+1));
  else echo "  ROTTO  $3"; echo "         atteso: $2"; echo "         avuto:  $(echo "$1" | head -c 300)"; ROSSI=$((ROSSI+1)); fi
}
ugualeA() {
  if [ "$1" = "$2" ]; then echo "  OK     $3"; VERDI=$((VERDI+1));
  else echo "  ROTTO  $3 (atteso '$2', avuto '$1')"; ROSSI=$((ROSSI+1)); fi
}
iscrivi() { # iscrivi <email> <peso> <altezza> <nascita>
  posta signup.php -d "email=$1" -d "password=parolalunga1" -d "first_name=Prova" -d "last_name=Limiti" \
    -d "weight=$2" -d "height=$3" -d "gender=male" -d "birth_date=$4"
}

echo "=== 1. registrazione ==="
atteso "$(iscrivi peso@prova.test 5 175 2000-01-01)" "Peso ammesso" "un peso di 5 kg viene rifiutato"
atteso "$(iscrivi alto@prova.test 70 90 2000-01-01)" "Altezza ammessa" "un'altezza di 90 cm viene rifiutata"
atteso "$(iscrivi bimbo@prova.test 40 140 "$(anni_fa 10)")" "ammessa fra 14 e 100" "10 anni vengono rifiutati"
atteso "$(iscrivi anziano@prova.test 70 170 1900-01-01)" "ammessa fra 14 e 100" "126 anni vengono rifiutati"
ugualeA "$(sql "SELECT COUNT(*) FROM na_users WHERE email LIKE '%@prova.test';")" "0" "e nessuno di questi e' stato creato"
atteso "$(iscrivi giusto@prova.test 70,5 175 2000-01-01)" '"status":"success"' "valori giusti: account creato"
atteso "$(iscrivi vecchia.app@prova.test "" "" "")" '"status":"success"' "campi vuoti di un'app vecchia: passano"

ID=$(sql "SELECT id FROM na_users WHERE email='giusto@prova.test';")

echo
echo "=== 2. profilo ==="
R=$(posta update_profile.php -d "user_id=$ID" -d "first_name=Prova" -d "last_name=Limiti" -d "height=250" -d "gender=male" -d "birth_date=2000-01-01")
atteso "$R" "Altezza ammessa" "un'altezza di 250 cm viene rifiutata"
ugualeA "$(sql "SELECT height FROM na_users WHERE id=$ID;")" "175.00" "e l'altezza resta quella di prima"
R=$(posta update_profile.php -d "user_id=$ID" -d "first_name=Prova" -d "last_name=Limiti" -d "height=180" -d "gender=male" -d "birth_date=$(anni_fa 5)")
atteso "$R" "ammessa fra 14 e 100" "una data di nascita di 5 anni fa viene rifiutata"
R=$(posta update_profile.php -d "user_id=$ID" -d "first_name=Prova" -d "last_name=Limiti" -d "height=180" -d "gender=male" -d "birth_date=1990-05-03")
atteso "$R" '"status":"success"' "valori giusti: profilo aggiornato"

echo
echo "=== 3. obiettivi ==="
R=$(posta update_goals.php -d "user_id=$ID" -d "current_weight=72" -d "target_weight=10" -d "calorie_goal=2000")
atteso "$R" "Peso obiettivo ammesso" "un obiettivo di 10 kg viene rifiutato"
R=$(posta update_goals.php -d "user_id=$ID" -d "current_weight=900" -d "target_weight=70" -d "calorie_goal=2000")
atteso "$R" "Peso ammesso" "un peso di 900 kg viene rifiutato"
R=$(posta update_goals.php -d "user_id=$ID" -d "current_weight=72" -d "target_weight=70" -d "calorie_goal=99999")
atteso "$R" "Obiettivo calorico non valido" "99999 kcal vengono rifiutate"
R=$(posta update_goals.php -d "user_id=$ID" -d "current_weight=72" -d "target_weight=68" -d "calorie_goal=2000")
atteso "$R" '"status":"success"' "valori giusti: obiettivi salvati"
ugualeA "$(sql "SELECT target_weight FROM na_users WHERE id=$ID;")" "68.00" "e scritti davvero"
R=$(posta update_goals.php -d "user_id=$ID" -d "current_weight=0" -d "target_weight=0" -d "calorie_goal=700")
atteso "$R" '"status":"success"' "pesi a zero (non indicati) e calorie automatiche basse: passano"
# 15/09: dalla Home e dal profilo si manda SOLO il peso. Un obiettivo salvato
# prima dei limiti del 14/09 non deve bloccarlo ("Errore nel salvataggio degli
# obiettivi" sul telefono di Ismail), e i campi non mandati non si azzerano.
sql "UPDATE na_users SET target_weight=545, calorie_goal=1800 WHERE id=$ID;"
R=$(posta update_goals.php -d "user_id=$ID" -d "current_weight=54.2")
atteso "$R" '"status":"success"' "solo il peso, con un obiettivo vecchio fuori limite: salvato"
ugualeA "$(sql "SELECT CONCAT(ROUND(current_weight,1),'|',ROUND(weight,1),'|',ROUND(target_weight),'|',ROUND(calorie_goal)) FROM na_users WHERE id=$ID;")" "54.2|54.2|545|1800" "scritto solo il peso, il resto intatto"
R=$(posta update_goals.php -d "user_id=$ID" -d "current_weight=545")
atteso "$R" "Peso ammesso" "solo il peso, fuori limite: rifiutato"

echo
if grep -q -i "fatal\|parse error" "$DIR/server.log"; then
  echo "  ROTTO  il server di prova ha scritto errori PHP:"; grep -i "fatal\|parse error" "$DIR/server.log" | head -5
  ROSSI=$((ROSSI+1))
else
  echo "  OK     nessun errore fatale nel log del server"; VERDI=$((VERDI+1))
fi

echo
echo "verdi: $VERDI   rossi: $ROSSI"
kill $SERVER 2>/dev/null
$MYSQL -u root -e "DROP DATABASE $DB;"
rm -rf "$DIR"
echo "database e cartella di prova rimossi."
[ "$ROSSI" -eq 0 ]
