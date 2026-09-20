#!/usr/bin/env bash
# prova_endpoint_community.sh — prova end-to-end dei cinque endpoint della
# collaborazione fra utenti, con VERE richieste HTTP contro un MySQL locale
# usa-e-getta.
#
# PERCHE' ESISTE: stessa ragione di prova_endpoint_ricette.sh. Gli endpoint di
# questo progetto sono stati spediti rotti due volte per difetti invisibili
# leggendo il codice (un file condiviso mai caricato, un `require` dentro una
# funzione). Qui i file vengono ESEGUITI dal server web integrato di PHP, con
# POST vere, contro il database creato dai dump del repo piu' la migrazione.
#
# COSA PROVA:
#   1. segnalazione di un alimento sbagliato
#   2. doppione della stessa segnalazione (deve dire "gia' aperta", non creare)
#   3. tipo di problema inventato (deve rifiutare)
#   4. utente inesistente (deve rifiutare)
#   5. consenso generale acceso: gli alimenti privati passano in attesa
#   6. consenso spento: tornano privati, l'approvato resta pubblico
#   7. un singolo alimento proposto e poi ritirato, anche se era approvato
#   8. ricetta proposta, ritirata, e il rifiuto di una ricetta senza ingredienti
#   9. le ricette pubbliche: solo approvate, senza le proprie, senza email
#  10. migrazione mancante: deve dirlo, non morire di 500 muto
#  11. community_comune.php mancante: stesso trattamento
#  12. get_recipes.php porta lo stato di condivisione, e regge un server
#      ancora senza quella colonna (l'elenco delle proprie ricette resta)
#
# SERVE: XAMPP (PHP + MySQL) sul percorso qui sotto, e MySQL avviato.
# Non tocca nulla al di fuori del database di prova, che cancella alla fine.
#
#   bash fileDatabase/prova_endpoint_community.sh
set -u

PHP=/c/xampp/php/php.exe
MYSQL=/c/xampp/mysql/bin/mysql.exe
REPO="$(cd "$(dirname "$0")" && pwd)"
DIR="${TMPDIR:-/tmp}/nutriapp_prova_community"
DB=nutriapp_prova_community
PORTA=8766

rm -rf "$DIR" && mkdir -p "$DIR"

$MYSQL -u root -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB DEFAULT CHARACTER SET utf8mb4;"
$MYSQL -u root $DB < "$REPO/na_users.sql"
$MYSQL -u root $DB < "$REPO/na_custom_foods.sql"
$MYSQL -u root $DB < "$REPO/na_recipes.sql"
$MYSQL -u root $DB < "$REPO/na_recipe_ingredients.sql"
$MYSQL -u root $DB < "$REPO/migrations/2026-08-30_ricette_immagine.sql"

# Due utenti: uno che condivide e uno che guarda. Serve il secondo per provare
# che in "Consigliate" non ci si vedano le proprie ricette.
#
# La semina passa da un file e non da `mysql -e "..."`: `portion` e' una parola
# riservata di MariaDB e va fra backtick, che in una stringa di shell fra doppi
# apici diventerebbero una sostituzione di comando. Con l'heredoc quotato il
# testo arriva al database come e' scritto. (Trovato provando: la prima
# versione di questo script seminava zero ricette in silenzio, perche' l'errore
# 1064 finiva in /dev/null insieme agli avvisi.)
cat > "$DIR/semina.sql" <<'SQL'
INSERT INTO na_users (email, password_hash, first_name, last_name)
VALUES ('chi.condivide@locale','x','Ismail','Barakat'),
       ('chi.guarda@locale','x','Serena','Yu');
INSERT INTO na_custom_foods (user_mail, food_name, base_weight_g, calories)
VALUES ('chi.condivide@locale','Pane di segale',100,250),
       ('chi.condivide@locale','Hummus fatto in casa',100,180),
       ('chi.condivide@locale','Gia pubblico',100,90);
INSERT INTO na_recipes (user_mail, recipe_name, `portion`, notes, is_favorite, creation_date)
VALUES ('chi.condivide@locale','Pasta al pesto','2','buona',0,CURDATE()),
       ('chi.condivide@locale','Ricetta vuota','1','senza ingredienti',0,CURDATE()),
       ('chi.guarda@locale','Ricetta di Serena','1','mia',0,CURDATE());
SQL
$MYSQL -u root $DB < "$DIR/semina.sql" || { echo "semina fallita: mi fermo"; exit 1; }

cat > "$DIR/db_config.php" <<PHP
<?php
\$conn = new mysqli('127.0.0.1', 'root', '', '$DB');
if (\$conn->connect_error) { die('connessione fallita: ' . \$conn->connect_error); }
\$conn->set_charset('utf8mb4');
PHP

cp "$REPO/community_comune.php" "$REPO/save_food_report.php" \
   "$REPO/set_sharing_preference.php" "$REPO/share_custom_food.php" \
   "$REPO/share_recipe.php" "$REPO/get_public_recipes.php" \n   "$REPO/get_recipes.php" "$DIR/"

cp "$REPO/search_community_foods.php" "$DIR/"
# 15/09: proprieta' del database, like, categorie e contributi dell'utente.
cp "$REPO/delete_custom_food.php" "$REPO/delete_recipe.php" "$REPO/get_custom_foods.php" \
   "$REPO/custom_food_columns.php" "$REPO/save_custom_food.php" "$REPO/update_recipe.php" \
   "$REPO/recipe_ingredient_columns.php" "$REPO/toggle_recipe_like.php" "$DIR/"
"$PHP" -S 127.0.0.1:$PORTA -t "$DIR" >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
for _ in $(seq 1 40); do
  curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$PORTA/get_public_recipes.php" && break
  sleep 0.25
done

posta() { curl -s --max-time 20 -X POST -H "Content-Type: application/json" --data-binary "$2" "http://127.0.0.1:$PORTA/$1"; }
prendi() { curl -s --max-time 20 "http://127.0.0.1:$PORTA/$1"; }
sql() { $MYSQL -u root $DB -N -B -e "$1"; }

VERDI=0
ROSSI=0
atteso() { # atteso "<risposta>" "<pezzo che deve comparire>" "<descrizione>"
  if echo "$1" | grep -q -- "$2"; then echo "  OK     $3"; VERDI=$((VERDI+1));
  else echo "  ROTTO  $3"; echo "         atteso: $2"; echo "         avuto:  $1"; ROSSI=$((ROSSI+1)); fi
}

echo "=== 0. migrazione NON ancora eseguita: gli endpoint devono dirlo ==="
R=$(posta save_food_report.php '{"user_mail":"chi.condivide@locale","food_name":"Pane","issue":"valori"}')
atteso "$R" "Migrazione mancante" "segnalazione senza migrazione"
R=$(prendi get_public_recipes.php)
atteso "$R" '"migration_missing":true' "ricette pubbliche senza migrazione (elenco vuoto, non errore)"

echo
echo "=== ora applichiamo la migrazione ==="
$MYSQL -u root $DB < "$REPO/migrations/2026-09-12_collaborazione_community.sql"
sql "UPDATE na_custom_foods SET shared_status='approved', shared_at=NOW() WHERE food_name='Gia pubblico';" >/dev/null

echo
echo "=== 1. segnalazione di un alimento sbagliato ==="
R=$(posta save_food_report.php '{"user_mail":"chi.condivide@locale","barcode":"8001234567890","food_name":"Croissant","source":"off","issue":"valori","field_name":"calories","suggested_value":"430","note":"Sull etichetta sono 430, non 43."}')
atteso "$R" '"status":"success"' "segnalazione salvata"
atteso "$R" '"already":false' "non e' un doppione"

echo "=== 2. lo stesso problema segnalato due volte ==="
R=$(posta save_food_report.php '{"user_mail":"chi.condivide@locale","barcode":"8001234567890","food_name":"Croissant","issue":"valori"}')
atteso "$R" '"already":true' "seconda segnalazione riconosciuta come gia' aperta"
atteso "$(sql "SELECT COUNT(*) FROM na_food_reports;")" "^1$" "nel database c'e' una riga sola"

echo "=== 3. tipo di problema inventato ==="
R=$(posta save_food_report.php '{"user_mail":"chi.condivide@locale","food_name":"X","issue":"qualsiasi"}')
atteso "$R" "non valido" "tipo rifiutato"

echo "=== 4. utente che non esiste ==="
R=$(posta save_food_report.php '{"user_mail":"nessuno@locale","food_name":"X","issue":"nome"}')
atteso "$R" "Utente non trovato" "utente rifiutato"

echo
echo "=== 5. consenso generale acceso ==="
R=$(posta set_sharing_preference.php '{"user_mail":"chi.condivide@locale","share_custom_foods":true}')
atteso "$R" '"foods_changed":2' "i due alimenti privati passano in attesa"
atteso "$R" '"foods_public":1' "l'alimento gia' pubblico resta pubblico"
atteso "$(sql "SELECT share_custom_foods FROM na_users WHERE email='chi.condivide@locale';")" "^1$" "consenso scritto sull'utente"
atteso "$(sql "SELECT COUNT(*) FROM na_custom_foods WHERE shared_status='pending';")" "^2$" "due righe in attesa"

echo "=== 6. consenso spento ==="
R=$(posta set_sharing_preference.php '{"user_mail":"chi.condivide@locale","share_custom_foods":false}')
atteso "$R" '"foods_changed":2' "le proposte rientrano"
atteso "$(sql "SELECT COUNT(*) FROM na_custom_foods WHERE shared_status='approved';")" "^1$" "l'approvato non e' stato toccato"
atteso "$(sql "SELECT COUNT(*) FROM na_custom_foods WHERE shared_at IS NOT NULL AND shared_status='private';")" "^0$" "niente date orfane sulle righe rientrate"

echo
echo "=== 7. un alimento alla volta ==="
ID_PANE=$(sql "SELECT id FROM na_custom_foods WHERE food_name='Pane di segale';")
R=$(posta share_custom_food.php "{\"user_mail\":\"chi.condivide@locale\",\"id\":$ID_PANE,\"share\":true}")
atteso "$R" '"shared_status":"pending"' "proposto"
R=$(posta share_custom_food.php "{\"user_mail\":\"chi.condivide@locale\",\"id\":$ID_PANE,\"share\":true}")
atteso "$R" '"changed":false' "riproporlo non cambia niente"
ID_PUB=$(sql "SELECT id FROM na_custom_foods WHERE food_name='Gia pubblico';")
R=$(posta share_custom_food.php "{\"user_mail\":\"chi.condivide@locale\",\"id\":$ID_PUB,\"share\":false}")
atteso "$R" '"reason":"locked"' "un approvato e' del database: l'autore non lo ritira (15/09)"
atteso "$(sql "SELECT shared_status FROM na_custom_foods WHERE id=$ID_PUB;")" "^approved$" "e resta pubblico"
R=$(posta share_custom_food.php "{\"user_mail\":\"chi.guarda@locale\",\"id\":$ID_PANE,\"share\":false}")
atteso "$R" "non trovato fra i tuoi" "non si tocca l'alimento di un altro"

echo
echo "=== 8. ricette ==="
ID_PESTO=$(sql "SELECT id FROM na_recipes WHERE recipe_name='Pasta al pesto';")
ID_VUOTA=$(sql "SELECT id FROM na_recipes WHERE recipe_name='Ricetta vuota';")
$MYSQL -u root $DB -e "INSERT INTO na_recipe_ingredients (recipe_id, food_name, unit, weight_g, calories) VALUES ($ID_PESTO,'Pasta','g',100,350);"
R=$(posta share_recipe.php "{\"user_mail\":\"chi.condivide@locale\",\"id\":$ID_PESTO,\"share\":true}")
atteso "$R" '"shared_status":"pending"' "ricetta proposta"
R=$(posta share_recipe.php "{\"user_mail\":\"chi.condivide@locale\",\"id\":$ID_VUOTA,\"share\":true}")
atteso "$R" '"reason":"no_ingredients"' "ricetta senza ingredienti rifiutata"
R=$(posta share_recipe.php "{\"user_mail\":\"chi.guarda@locale\",\"id\":$ID_PESTO,\"share\":true}")
atteso "$R" "non trovata fra le tue" "non si propone la ricetta di un altro"

echo
echo "=== 9. ricette pubbliche ==="
R=$(prendi "get_public_recipes.php?user_mail=chi.guarda@locale")
atteso "$R" '"recipes":\[\]' "in attesa non si vede"
sql "UPDATE na_recipes SET shared_status='approved', reviewed_at=NOW(), reviewed_by='prova' WHERE id=$ID_PESTO;" >/dev/null
sql "UPDATE na_recipes SET shared_status='approved' WHERE recipe_name='Ricetta di Serena';" >/dev/null
R=$(prendi "get_public_recipes.php?user_mail=chi.guarda@locale")
atteso "$R" "Pasta al pesto" "approvata: si vede"
atteso "$R" '"author_name":"Ismail"' "compare il nome dell'autore"
atteso "$R" '"food_name":"Pasta"' "con i suoi ingredienti"
# 17/09: le proprie ricette approvate si vedono anche in Consigliate, segnate.
atteso "$R" "Ricetta di Serena" "le proprie approvate compaiono anche a chi le ha scritte"
atteso "$R" '"is_mine":true' "segnate come proprie"
if echo "$R" | grep -q "@locale"; then
  echo "  ROTTO  nessuna email deve uscire dall'endpoint"; ROSSI=$((ROSSI+1))
else
  echo "  OK     nessuna email nella risposta"; VERDI=$((VERDI+1))
fi
R=$(prendi "get_public_recipes.php")
atteso "$R" "Ricetta di Serena" "senza user_mail si vedono tutte"

echo
echo "=== 10. db_config.php mancante: deve dirlo, non morire di 500 ==="
mv "$DIR/db_config.php" "$DIR/db_config.php.via"
R=$(posta share_recipe.php '{}')
atteso "$R" "File mancante sul server: db_config.php" "messaggio chiaro invece di 500 muto"
mv "$DIR/db_config.php.via" "$DIR/db_config.php"

echo "=== 11. community_comune.php mancante: il caso del 07/09 ==="
mv "$DIR/community_comune.php" "$DIR/community_comune.php.via"
R=$(posta share_recipe.php '{}')
atteso "$R" "File mancante sul server: community_comune.php" "nomina il file da caricare"
if echo "$R" | grep -qi "warning\|fatal"; then
  echo "  ROTTO  la risposta contiene un avviso PHP: non e' JSON valido"; ROSSI=$((ROSSI+1))
else
  echo "  OK     risposta JSON pulita, nessun avviso PHP"; VERDI=$((VERDI+1))
fi
mv "$DIR/community_comune.php.via" "$DIR/community_comune.php"

echo
echo "=== 12. get_recipes.php: lo stato c'e', e sopravvive a un server indietro ==="
R=$(prendi "get_recipes.php?user_mail=chi.condivide@locale")
atteso "$R" '"shared_status":"approved"' "le proprie ricette portano il loro stato"
# Ora togliamo la colonna: e' il caso "app aggiornata, server ancora indietro",
# in cui una SELECT che la chiede farebbe perdere all'utente l'elenco delle
# PROPRIE ricette per una funzione che non ha nemmeno usato.
sql "ALTER TABLE na_recipes DROP COLUMN shared_status;" >/dev/null
R=$(prendi "get_recipes.php?user_mail=chi.condivide@locale")
atteso "$R" "Pasta al pesto" "senza la colonna l'elenco arriva comunque"
atteso "$R" '"shared_status":"private"' "e lo stato torna privato, non vuoto"
# Rimettiamo la colonna: il riepilogo qui sotto la legge.
sql "ALTER TABLE na_recipes ADD COLUMN shared_status enum('private','pending','approved','rejected') NOT NULL DEFAULT 'private';" >/dev/null
sql "UPDATE na_recipes SET shared_status='approved' WHERE recipe_name IN ('Pasta al pesto','Ricetta di Serena');" >/dev/null

echo
echo "=== 12-bis. gli alimenti approvati si trovano nella ricerca di tutti (14/09) ==="
# Stati rimessi a mano: il punto 7 ritira proprio l'alimento approvato. Hummus
# in attesa, perche' la prova sotto deve dimostrare che "proposto" non basta.
sql "UPDATE na_custom_foods SET shared_status='approved' WHERE food_name='Gia pubblico';" >/dev/null
sql "UPDATE na_custom_foods SET shared_status='pending' WHERE food_name='Hummus fatto in casa';" >/dev/null
R=$(prendi "search_community_foods.php?query=pubblico")
atteso "$R" '"status":"success"' "la ricerca della comunita' risponde"
atteso "$R" "Gia pubblico" "e trova l'alimento approvato"
if echo "$R" | grep -q "chi.condivide@locale"; then
  echo "  ROTTO  non deve dire di chi e' l'alimento"; ROSSI=$((ROSSI+1))
else
  echo "  OK     e non dice di chi e'"; VERDI=$((VERDI+1))
fi
R=$(prendi "search_community_foods.php?query=hummus")
if echo "$R" | grep -q "Hummus"; then
  echo "  ROTTO  un alimento non approvato non deve comparire"; ROSSI=$((ROSSI+1))
else
  echo "  OK     un alimento non approvato non compare"; VERDI=$((VERDI+1))
fi
echo

echo "=== 14. migrazione del 15/09: un contenuto approvato e' del database ==="
# na_reports non ha un dump nel repo: la si crea com'era prima del 05/09.
sql "CREATE TABLE IF NOT EXISTS na_reports (id int AUTO_INCREMENT PRIMARY KEY, user_email varchar(255) NOT NULL, problem_description text NOT NULL, created_at timestamp NOT NULL DEFAULT current_timestamp()) DEFAULT CHARSET=latin1;" >/dev/null
$MYSQL -u root $DB < "$REPO/migrations/2026-09-05_segnalazioni_e_unita.sql"
$MYSQL -u root $DB < "$REPO/migrations/2026-09-15_community_ricette_pannello.sql" || { echo "  ROTTO  migrazione del 15/09"; ROSSI=$((ROSSI+1)); }
$MYSQL -u root $DB < "$REPO/migrations/2026-09-15_community_ricette_pannello.sql" && { echo "  OK     migrazione rilanciabile"; VERDI=$((VERDI+1)); }

ID_PUB=$(sql "SELECT id FROM na_custom_foods WHERE food_name='Gia pubblico';")
R=$(posta delete_custom_food.php "{\"user_mail\":\"chi.condivide@locale\",\"id\":$ID_PUB}")
atteso "$R" '"kept_public":true' "l'autore cancella un approvato: tolto dalla sua libreria"
atteso "$(sql "SELECT COUNT(*) FROM na_custom_foods WHERE id=$ID_PUB AND author_removed_at IS NOT NULL;")" "^1$" "la riga resta, segnata come rimossa dall'autore"
R=$(prendi "get_custom_foods.php?user_mail=chi.condivide@locale")
if echo "$R" | grep -q "Gia pubblico"; then
  echo "  ROTTO  nella libreria dell'autore non deve piu' comparire"; ROSSI=$((ROSSI+1))
else
  echo "  OK     nella libreria dell'autore non compare piu'"; VERDI=$((VERDI+1))
fi
R=$(prendi "search_community_foods.php?query=pubblico")
atteso "$R" "Gia pubblico" "ma la ricerca di tutti lo trova ancora"
R=$(posta delete_custom_food.php "{\"user_mail\":\"chi.condivide@locale\",\"id\":$ID_PUB}")
atteso "$R" "non trovato" "cancellarlo di nuovo non tocca niente"

ID_PANE=$(sql "SELECT id FROM na_custom_foods WHERE food_name='Pane di segale';")
R=$(posta delete_custom_food.php "{\"user_mail\":\"chi.condivide@locale\",\"id\":$ID_PANE}")
atteso "$R" '"kept_public":false' "un alimento non approvato si cancella davvero"
atteso "$(sql "SELECT COUNT(*) FROM na_custom_foods WHERE id=$ID_PANE;")" "^0$" "e la riga non c'e' piu'"

ID_HUMMUS=$(sql "SELECT id FROM na_custom_foods WHERE food_name='Hummus fatto in casa';")
sql "UPDATE na_custom_foods SET shared_status='approved' WHERE id=$ID_HUMMUS;" >/dev/null
R=$(posta save_custom_food.php "{\"user_mail\":\"chi.condivide@locale\",\"id\":$ID_HUMMUS,\"food_name\":\"Hummus cambiato\",\"calories\":1,\"proteins\":1,\"carbs\":1}")
atteso "$R" '"reason":"locked"' "l'autore non modifica un alimento approvato"
atteso "$(sql "SELECT food_name FROM na_custom_foods WHERE id=$ID_HUMMUS;")" "^Hummus fatto in casa$" "e il nome resta quello"
R=$(posta save_custom_food.php "{\"user_mail\":\"chi.condivide@locale\",\"id\":$ID_HUMMUS,\"is_favorite\":1}")
atteso "$R" '"status":"success"' "il preferito resta suo"

ID_PESTO=$(sql "SELECT id FROM na_recipes WHERE recipe_name='Pasta al pesto';")
R=$(posta update_recipe.php "{\"user_mail\":\"chi.condivide@locale\",\"id\":$ID_PESTO,\"recipe_name\":\"Pesto cambiato\",\"portion\":\"2\",\"notes\":\"\",\"ingredients\":[{\"food_name\":\"Pasta\",\"weight_g\":100,\"calories\":350}]}")
atteso "$R" '"reason":"locked"' "l'autore non modifica una ricetta approvata"
R=$(posta share_recipe.php "{\"user_mail\":\"chi.condivide@locale\",\"id\":$ID_PESTO,\"share\":false}")
atteso "$R" '"reason":"locked"' "ne' la ritira"
R=$(curl -s "http://127.0.0.1:$PORTA/delete_recipe.php?id=$ID_PESTO&user_mail=chi.condivide@locale")
atteso "$R" '"kept_public":true' "cancellata dall'autore: tolta dalle sue"
R=$(prendi "get_recipes.php?user_mail=chi.condivide@locale")
if echo "$R" | grep -q "Pasta al pesto"; then
  echo "  ROTTO  fra le ricette dell'autore non deve piu' comparire"; ROSSI=$((ROSSI+1))
else
  echo "  OK     fra le ricette dell'autore non compare piu'"; VERDI=$((VERDI+1))
fi
R=$(prendi "get_public_recipes.php?user_mail=chi.guarda@locale")
atteso "$R" "Pasta al pesto" "ma in Consigliate c'e' ancora"

echo "=== 15. categorie obbligatorie per proporre una ricetta ==="
sql "INSERT INTO na_recipes (user_mail, recipe_name, \`portion\`, notes, is_favorite, creation_date) VALUES ('chi.condivide@locale','Insalata di farro','1','',0,CURDATE());" >/dev/null
ID_FARRO=$(sql "SELECT id FROM na_recipes WHERE recipe_name='Insalata di farro';")
sql "INSERT INTO na_recipe_ingredients (recipe_id, food_name, unit, weight_g, calories) VALUES ($ID_FARRO,'Farro','g',80,270);" >/dev/null
R=$(posta share_recipe.php "{\"user_mail\":\"chi.condivide@locale\",\"id\":$ID_FARRO,\"share\":true}")
atteso "$R" '"reason":"categories_missing"' "senza pasto e portata non si propone"
R=$(posta share_recipe.php "{\"user_mail\":\"chi.condivide@locale\",\"id\":$ID_FARRO,\"share\":true,\"meal_types\":[\"pranzo\",\"inventato\",\"cena\"],\"course\":\"piatto_unico\",\"diet_tags\":[\"vegana\"]}")
atteso "$R" '"shared_status":"pending"' "con le categorie si propone"
atteso "$(sql "SELECT CONCAT(meal_types,'|',course,'|',diet_tags) FROM na_recipes WHERE id=$ID_FARRO;")" "^pranzo,cena|piatto_unico|vegana$" "scritte, e il pasto inventato scartato"
R=$(posta share_recipe.php "{\"user_mail\":\"chi.condivide@locale\",\"id\":$ID_FARRO,\"share\":true,\"meal_types\":[\"cena\"],\"course\":\"primo\"}")
atteso "$(sql "SELECT CONCAT(meal_types,'|',course) FROM na_recipes WHERE id=$ID_FARRO;")" "^cena|primo$" "gia' in attesa: le categorie si aggiornano"
echo

echo "=== 16. like e modalita' di Consigliate (15/09) ==="
ID_PESTO=$(sql "SELECT id FROM na_recipes WHERE recipe_name='Pasta al pesto';")
ID_SERENA=$(sql "SELECT id FROM na_recipes WHERE recipe_name='Ricetta di Serena';")
R=$(posta toggle_recipe_like.php "{\"user_mail\":\"chi.guarda@locale\",\"recipe_id\":$ID_FARRO,\"like\":true}")
atteso "$R" '"reason":"not_public"' "una ricetta in attesa non si puo' votare"
# 18/09: la propria si puo' votare (senza cuore sembrava rotta), ma il voto
# dell'autore non deve contare nel punteggio di "Per te" (controllo piu' sotto).
R=$(posta toggle_recipe_like.php "{\"user_mail\":\"chi.guarda@locale\",\"recipe_id\":$ID_SERENA,\"like\":true}")
atteso "$R" '"likes_count":1' "anche le proprie si possono votare"
R=$(posta toggle_recipe_like.php "{\"user_mail\":\"nessuno@locale\",\"recipe_id\":$ID_PESTO,\"like\":true}")
atteso "$R" "Utente non trovato" "un utente inventato no"
R=$(posta toggle_recipe_like.php "{\"user_mail\":\"chi.guarda@locale\",\"recipe_id\":$ID_PESTO,\"like\":true}")
atteso "$R" '"likes_count":1' "like messo"
R=$(posta toggle_recipe_like.php "{\"user_mail\":\"chi.guarda@locale\",\"recipe_id\":$ID_PESTO,\"like\":true}")
atteso "$R" '"likes_count":1' "rimetterlo non lo conta due volte"

# Farro pubblicata oggi e adatta alla cena; il pesto pubblicato 60 giorni fa e
# adatto al pranzo, ma con un like.
sql "UPDATE na_recipes SET shared_status='approved', reviewed_at=NOW() WHERE id=$ID_FARRO;" >/dev/null
sql "UPDATE na_recipes SET meal_types='pranzo', course='secondo', reviewed_at=NOW() - INTERVAL 60 DAY, shared_at=NOW() - INTERVAL 60 DAY WHERE id=$ID_PESTO;" >/dev/null
sql "UPDATE na_recipes SET reviewed_at=NOW() - INTERVAL 90 DAY, shared_at=NOW() - INTERVAL 90 DAY WHERE id=$ID_SERENA;" >/dev/null
prima() { echo "$1" | grep -o '"recipe_name":"[^"]*"' | head -1; }
punteggio() { echo "$1" | tr '{' '\n' | grep "$2" | grep -o '"score":[0-9.]*' | head -1; }

# Il like dell'autore sulla propria ricetta (messo sopra) non deve spostare il
# punteggio: si toglie e si rimette, e il punteggio resta quello.
R=$(prendi "get_public_recipes.php?mode=per_te&now_meal=cena")
PUNTI_CON=$(punteggio "$R" "Ricetta di Serena")
posta toggle_recipe_like.php "{\"user_mail\":\"chi.guarda@locale\",\"recipe_id\":$ID_SERENA,\"like\":false}" >/dev/null
R=$(prendi "get_public_recipes.php?mode=per_te&now_meal=cena")
atteso "$(punteggio "$R" "Ricetta di Serena")" "^$PUNTI_CON$" "il voto dell'autore non alza il punteggio di Per te"
posta toggle_recipe_like.php "{\"user_mail\":\"chi.guarda@locale\",\"recipe_id\":$ID_SERENA,\"like\":true}" >/dev/null
R=$(prendi "get_public_recipes.php?mode=per_te&now_meal=cena")
atteso "$(prima "$R")" "Insalata di farro" "per te a cena: prima la ricetta da cena"
R=$(prendi "get_public_recipes.php?mode=per_te&now_meal=pranzo")
atteso "$(prima "$R")" "Pasta al pesto" "per te a pranzo: prima quella da pranzo"
R=$(prendi "get_public_recipes.php?mode=piaciute")
atteso "$(prima "$R")" "Pasta al pesto" "piu' piaciute: prima quella col like"
R=$(prendi "get_public_recipes.php?mode=nuove")
atteso "$(prima "$R")" "Insalata di farro" "piu' nuove: prima l'ultima pubblicata"
R=$(prendi "get_public_recipes.php?meal=pranzo")
if echo "$R" | grep -q "Insalata di farro"; then
  echo "  ROTTO  il filtro pranzo non deve dare la ricetta da cena"; ROSSI=$((ROSSI+1))
else
  echo "  OK     il filtro per pasto esclude le altre"; VERDI=$((VERDI+1))
fi
R=$(prendi "get_public_recipes.php?q=farro")
atteso "$R" "Insalata di farro" "la ricerca trova per ingrediente"
R=$(prendi "get_public_recipes.php?user_mail=chi.guarda@locale&mode=piaciute")
atteso "$R" '"liked_by_me":true' "chi ha messo like lo ritrova"
if echo "$R" | grep -q "@locale"; then
  echo "  ROTTO  nessuna email deve uscire dall'endpoint"; ROSSI=$((ROSSI+1))
else
  echo "  OK     ancora nessuna email nella risposta"; VERDI=$((VERDI+1))
fi
R=$(posta toggle_recipe_like.php "{\"user_mail\":\"chi.guarda@locale\",\"recipe_id\":$ID_PESTO,\"like\":false}")
atteso "$R" '"likes_count":0' "like tolto"
echo

echo "=== 13. cosa c'e' davvero nel database ==="
$MYSQL -u root $DB -e "SELECT issue, field_name, suggested_value, status FROM na_food_reports;"
$MYSQL -u root $DB -e "SELECT food_name, shared_status FROM na_custom_foods;"
$MYSQL -u root $DB -e "SELECT recipe_name, shared_status FROM na_recipes;"

echo
echo "verdi: $VERDI   rossi: $ROSSI"
$MYSQL -u root -e "DROP DATABASE $DB;"
rm -rf "$DIR"
echo "database e cartella di prova rimossi."
[ "$ROSSI" -eq 0 ]
