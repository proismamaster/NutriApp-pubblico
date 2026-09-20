#!/usr/bin/env bash
# prova_endpoint_ricette.sh — prova end-to-end di save_recipe.php e
# update_recipe.php contro un MySQL locale usa-e-getta, con VERE richieste HTTP.
#
# PERCHE' ESISTE (2026-09-08): questi due endpoint sono stati spediti rotti due
# volte di fila. La prima per un file condiviso mai caricato sul server, la
# seconda per un `require` finito dentro una funzione — in PHP le variabili di
# un file incluso restano nello scope di dove sta il require, quindi $conn era
# null. Nessuno dei due difetti era visibile leggendo il codice, e nessuno dei
# due sarebbe sopravvissuto a questo script.
#
# COSA PROVA:
#   1. salvataggio di una ricetta nuova
#   2. modifica della stessa
#   3. che nel database ci sia davvero quello che ci si aspetta
#   4. il ramo "solo preferito", senza ingredienti
#   5. che con db_config.php mancante risponda un messaggio, non un 500 muto
#
# La tabella degli ingredienti viene creata DI PROPOSITO senza le colonne
# aggiunte dalla migrazione del 24/07: il caso interessante e' proprio
# "server indietro rispetto all'app", che deve funzionare lo stesso saltando
# le colonne che non ci sono.
#
# SERVE: XAMPP (PHP + MySQL) sul percorso qui sotto, e MySQL avviato.
# Non tocca nulla al di fuori del database di prova, che cancella alla fine.
#
#   bash fileDatabase/prova_endpoint_ricette.sh
set -u

PHP=/c/xampp/php/php.exe
MYSQL=/c/xampp/mysql/bin/mysql.exe
REPO="$(cd "$(dirname "$0")" && pwd)"
DIR="${TMPDIR:-/tmp}/nutriapp_prova_endpoint"
DB=nutriapp_prova_locale
PORTA=8765

rm -rf "$DIR" && mkdir -p "$DIR"

$MYSQL -u root -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB DEFAULT CHARACTER SET utf8mb4;"
$MYSQL -u root $DB < "$REPO/na_recipes.sql"
$MYSQL -u root $DB < "$REPO/na_recipe_ingredients.sql"
# Il dump di na_recipes nel repo e' anteriore alla migrazione della foto: la
# applichiamo, cosi' la fixture combacia col server vero (che image_url ce
# l'ha, verificato via get_recipes.php).
$MYSQL -u root $DB < "$REPO/migrations/2026-08-30_ricette_immagine.sql"
# NON applichiamo la migrazione delle colonne ingrediente di proposito: il
# caso da provare e' proprio "server indietro rispetto all'app".

cat > "$DIR/db_config.php" <<'PHP'
<?php
$conn = new mysqli('127.0.0.1', 'root', '', 'nutriapp_prova_locale');
if ($conn->connect_error) { die('connessione fallita: ' . $conn->connect_error); }
$conn->set_charset('utf8mb4');
PHP

cp "$REPO/save_recipe.php" "$REPO/update_recipe.php" "$DIR/"

# Server web integrato di PHP: cosi' php://input si comporta come sull'hosting
# (con il SAPI a riga di comando non lo fa).
"$PHP" -S 127.0.0.1:$PORTA -t "$DIR" >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
for _ in $(seq 1 40); do
  curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$PORTA/save_recipe.php" && break
  sleep 0.25
done

posta() {
  curl -s --max-time 20 -X POST -H "Content-Type: application/json" \
       --data-binary "$2" "http://127.0.0.1:$PORTA/$1"
}

ING='{"food_name":"Croissant crema","unit":"g","weight_g":100,"calories":430,"carbs":54,"proteins":6,"fats":21,"sugars":24.5,"fibers":2,"calcium":30,"nova_group":4,"nutriscore_grade":"d","barcode":"8001234567890","campo_inventato":"ignorami"}'

esito() { # esito "<risposta>" "<descrizione>"
  if echo "$1" | grep -q '"status":"success"'; then echo "  OK     $2"; else echo "  ROTTO  $2"; fi
}

echo "=== 1. salvataggio di una ricetta nuova ==="
R1=$(posta save_recipe.php "{\"user_mail\":\"prova@locale\",\"recipe_name\":\"abed\",\"portion\":\"3\",\"notes\":\"buongiorno\",\"is_favorite\":0,\"image_url\":\"http://esempio/foto.jpg\",\"ingredients\":[$ING]}")
echo "$R1"; esito "$R1" "salvataggio"

ID=$($MYSQL -u root $DB -N -B -e "SELECT id FROM na_recipes ORDER BY id DESC LIMIT 1")
echo "  id ricetta: $ID"

echo
echo "=== 2. modifica della stessa ricetta ==="
R2=$(posta update_recipe.php "{\"id\":$ID,\"user_mail\":\"prova@locale\",\"recipe_name\":\"abed modificata\",\"portion\":\"4\",\"notes\":\"aggiornata\",\"is_favorite\":1,\"image_url\":\"http://esempio/foto2.jpg\",\"ingredients\":[$ING]}")
echo "$R2"; esito "$R2" "modifica"

echo
echo "=== 3. cosa c'e' davvero nel database ==="
$MYSQL -u root $DB -e "SELECT recipe_name, is_favorite, image_url FROM na_recipes WHERE id=$ID;"
$MYSQL -u root $DB -e "SELECT food_name, weight_g, calories, sugars, calcium FROM na_recipe_ingredients WHERE recipe_id=$ID;"
$MYSQL -u root $DB -e "SELECT COUNT(*) AS righe_ingredienti FROM na_recipe_ingredients WHERE recipe_id=$ID;"

echo "=== 4. solo il preferito (ramo senza ingredienti) ==="
R3=$(posta update_recipe.php "{\"id\":$ID,\"user_mail\":\"prova@locale\",\"is_favorite\":0}")
echo "$R3"; esito "$R3" "toggle preferito"
$MYSQL -u root $DB -e "SELECT is_favorite FROM na_recipes WHERE id=$ID;"

echo "=== 5. db_config.php mancante: deve dirlo, non morire di 500 ==="
mv "$DIR/db_config.php" "$DIR/db_config.php.via"
posta save_recipe.php '{}'; echo
mv "$DIR/db_config.php.via" "$DIR/db_config.php"

echo
$MYSQL -u root -e "DROP DATABASE $DB;"
rm -rf "$DIR"
echo "database e cartella di prova rimossi."
