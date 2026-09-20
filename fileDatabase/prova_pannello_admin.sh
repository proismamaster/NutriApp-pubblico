#!/usr/bin/env bash
# prova_pannello_admin.sh — fa girare il PANNELLO VERO su un MySQL locale
# usa-e-getta, con richieste HTTP e una sessione vera (cookie compresi).
#
# PERCHE' ESISTE: il pannello scrive su na_off_products. Un difetto qui non e'
# una schermata storta, e' un valore sbagliato su un prodotto che poi finisce
# nel diario di qualcuno. Ogni cosa che scrive va provata eseguendola, come per
# gli endpoint (lezione del 07-08/09).
#
# COSA PROVA:
#   1. senza accesso, ogni pagina rimanda al login
#   2. il primo account si crea una volta sola
#   3. password sbagliata: messaggio generico, nessuna sessione
#   4. accesso corretto
#   5. modulo senza token: rifiutato (protezione dai siti terzi)
#   6. la coda mostra la segnalazione con proposta e foto
#   7. si accetta UN campo su due: scrive solo quello
#   8. il valore non accettato resta com'era
#   9. il registro ha la riga, con i valori di prima
#  10. annulla: il prodotto torna indietro e la segnalazione si riapre
#  11. una chiave che non e' una colonna viene ignorata (niente SQL a sorpresa)
#  12. rifiuto senza motivazione: bloccato
#  13. un revisore non entra nella gestione account
#
# SERVE: XAMPP (PHP + MySQL) sui percorsi qui sotto, e MySQL avviato.
#
#   bash fileDatabase/prova_pannello_admin.sh
set -u

PHP=/c/xampp/php/php.exe
MYSQL=/c/xampp/mysql/bin/mysql.exe
REPO="$(cd "$(dirname "$0")" && pwd)"
DIR="${TMPDIR:-/tmp}/nutriapp_prova_admin"
DB=nutriapp_prova_admin
PORTA=8767
BISCOTTI="$DIR/biscotti.txt"

rm -rf "$DIR" && mkdir -p "$DIR/admin"

$MYSQL -u root -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB DEFAULT CHARACTER SET utf8mb4;"
$MYSQL -u root $DB < "$REPO/na_users.sql"
$MYSQL -u root $DB < "$REPO/na_custom_foods.sql"
$MYSQL -u root $DB < "$REPO/na_recipes.sql"
$MYSQL -u root $DB < "$REPO/na_recipe_ingredients.sql"
# Il diario serve alla pagina Utenti (14/09). Il dump vero porta con se' 26
# voci di prova: si tolgono, la prova ne semina una sua.
$MYSQL -u root $DB < "$REPO/na_nutri_entries.sql"
$MYSQL -u root $DB -e "DELETE FROM na_nutri_entries;"
# Le migrazioni nell'ordine in cui sono state eseguite sul server vero: il
# pannello legge colonne aggiunte nel tempo (image_url, brand), e provarlo su
# uno schema piu' povero di quello reale misurerebbe un'altra applicazione.
$MYSQL -u root $DB < "$REPO/migrations/2026-07-24_ricette_custom_foods_traduzioni.sql"
$MYSQL -u root $DB < "$REPO/migrations/2026-08-29_alimenti_personali_completi.sql"
$MYSQL -u root $DB < "$REPO/migrations/2026-08-30_ricette_immagine.sql"
$MYSQL -u root $DB < "$REPO/migrations/2026-09-12_collaborazione_community.sql"
$MYSQL -u root $DB < "$REPO/migrations/2026-09-12_pannello_admin.sql"
# 15/09: na_reports non ha un dump nel repo, si crea com'era prima del 05/09.
$MYSQL -u root $DB -e "CREATE TABLE na_reports (id int AUTO_INCREMENT PRIMARY KEY, user_email varchar(255) NOT NULL, problem_description text NOT NULL, created_at timestamp NOT NULL DEFAULT current_timestamp()) DEFAULT CHARSET=latin1;"
$MYSQL -u root $DB < "$REPO/migrations/2026-09-05_segnalazioni_e_unita.sql"
$MYSQL -u root $DB < "$REPO/migrations/2026-09-15_community_ricette_pannello.sql"

# na_off_products col minimo indispensabile: il dump vero ha 200+ colonne e non
# serve nessuna di quelle per provare la scrittura campo per campo.
# Le email hanno un dominio con il punto di proposito: `filter_var(...
# FILTER_VALIDATE_EMAIL)` rifiuta "nome@locale" perche' il dominio non ha TLD,
# e la prima versione di questo script falliva tutte le prove per quello — il
# primo account non veniva creato e da li' in poi ogni POST rispondeva un 302
# muto verso il login.
cat > "$DIR/semina.sql" <<'SQL'
CREATE TABLE na_off_products (
  barcode varchar(32) NOT NULL PRIMARY KEY,
  food_name varchar(255) DEFAULT NULL,
  brand varchar(255) DEFAULT NULL,
  image_url varchar(500) DEFAULT NULL,
  calories double DEFAULT 0,
  sugars double DEFAULT 0,
  proteins double DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO na_off_products (barcode, food_name, brand, calories, sugars, proteins)
VALUES ('8001234567890','Croissant alla crema','Forno',43,24.5,6);

INSERT INTO na_users (email, password_hash, first_name, last_name)
VALUES ('utente@prova.test','x','Ismail','Barakat');

INSERT INTO na_custom_foods (user_mail, food_name, base_weight_g, calories)
VALUES ('utente@prova.test','Pane di segale',100,250);
UPDATE na_custom_foods SET shared_status='pending', shared_at=NOW();

INSERT INTO na_recipes (user_mail, recipe_name, `portion`, notes, is_favorite, creation_date)
VALUES ('utente@prova.test','Pasta al pesto','2','buona',0,CURDATE());
UPDATE na_recipes SET shared_status='pending', shared_at=NOW();
INSERT INTO na_recipe_ingredients (recipe_id, food_name, unit, weight_g, calories)
SELECT id,'Pasta','g',100,350 FROM na_recipes LIMIT 1;

INSERT INTO na_nutri_entries (user_mail, food_name, meal_type, entry_date, weight_g, calories)
VALUES ('utente@prova.test','Risotto ai funghi','Pranzo',CURDATE(),250,420);

INSERT INTO na_reports (user_email, problem_description, kind, screen, diagnostics)
VALUES ('utente@prova.test','Il grafico delle calorie non si aggiorna dopo aver aggiunto un pasto','bug','Grafici','Android 14 · Pixel 7');
SQL
$MYSQL -u root $DB < "$DIR/semina.sql" || { echo "semina fallita: mi fermo"; exit 1; }

cat > "$DIR/db_config.php" <<PHP
<?php
\$conn = new mysqli('127.0.0.1', 'root', '', '$DB');
if (\$conn->connect_error) { die('connessione fallita: ' . \$conn->connect_error); }
\$conn->set_charset('utf8mb4');
PHP

cp "$REPO/community_comune.php" "$REPO/save_food_report.php" "$REPO/get_my_reports.php" "$DIR/"
cp "$REPO/admin/"*.php "$REPO/admin/stile.css" "$DIR/admin/"

# Il log del server NON si butta via: con display_errors spento un errore
# fatale risponde un corpo vuoto, e senza questo file si vedrebbe solo "avuto:
# (niente)" senza sapere perche'. (Successo davvero il 13/09 alla prima
# esecuzione: dodici prove rosse e nessun messaggio.)
"$PHP" -S 127.0.0.1:$PORTA -t "$DIR" > "$DIR/server.log" 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
for _ in $(seq 1 40); do
  curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$PORTA/admin/login.php" && break
  sleep 0.25
done

B="http://127.0.0.1:$PORTA"
prendi() { curl -s --max-time 20 -b "$BISCOTTI" -c "$BISCOTTI" "$B/$1"; }
posta() { curl -s --max-time 20 -b "$BISCOTTI" -c "$BISCOTTI" -X POST "$B/$1" "${@:2}"; }
codice() { curl -s -o /dev/null -w '%{http_code}' -b "$BISCOTTI" -c "$BISCOTTI" --max-time 20 "$B/$1"; }
sql() { $MYSQL -u root $DB -N -B -e "$1"; }
# Il token sta in una pagina: si legge da li', come farebbe un browser.
tokenDa() { prendi "$1" | grep -o 'name="token" value="[a-f0-9]*"' | head -1 | sed 's/.*value="//;s/"//'; }

VERDI=0
ROSSI=0
atteso() {
  if echo "$1" | grep -q -- "$2"; then echo "  OK     $3"; VERDI=$((VERDI+1));
  else echo "  ROTTO  $3"; echo "         atteso: $2"; echo "         avuto:  $(echo "$1" | head -c 200)"; ROSSI=$((ROSSI+1)); fi
}
ugualeA() {
  if [ "$1" = "$2" ]; then echo "  OK     $3"; VERDI=$((VERDI+1));
  else echo "  ROTTO  $3 (atteso '$2', avuto '$1')"; ROSSI=$((ROSSI+1)); fi
}

echo "=== 1. senza accesso si finisce al login ==="
R=$(curl -s -o /dev/null -w '%{redirect_url}' --max-time 20 "$B/admin/index.php")
atteso "$R" "login.php" "il cruscotto rimanda al login"
R=$(curl -s -o /dev/null -w '%{redirect_url}' --max-time 20 "$B/admin/segnalazioni.php")
atteso "$R" "login.php" "la coda rimanda al login"
# db_config.php manda application/json: il pannello deve sovrascriverlo, o il
# browser mostra l'HTML come testo (successo sull'hosting il 13/09).
R=$(curl -s -o /dev/null -w '%{content_type}' --max-time 20 "$B/admin/login.php")
atteso "$R" "text/html" "le pagine arrivano come HTML, non come JSON"

echo
echo "=== 2. primo account ==="
T=$(tokenDa admin/primo_admin.php)
R=$(posta admin/primo_admin.php -d "token=$T" -d "nome=Ismail" -d "email=ismail@prova.test" -d "password=parolalunghissima")
atteso "$R" "Account proprietario creato" "creato il proprietario"
ugualeA "$(sql "SELECT COUNT(*) FROM na_admins;")" "1" "un solo account nel database"
T=$(tokenDa admin/primo_admin.php)
R=$(posta admin/primo_admin.php -d "token=$T" -d "nome=Altro" -d "email=altro@prova.test" -d "password=parolalunghissima")
atteso "$R" "Esiste già" "il secondo tentativo viene rifiutato"
ugualeA "$(sql "SELECT COUNT(*) FROM na_admins;")" "1" "e non ha creato niente"

echo
echo "=== 3. password sbagliata ==="
rm -f "$BISCOTTI"
T=$(tokenDa admin/login.php)
R=$(posta admin/login.php -d "token=$T" -d "email=ismail@prova.test" -d "password=sbagliata")
atteso "$R" "Credenziali non valide" "messaggio generico"
R=$(curl -s -o /dev/null -w '%{redirect_url}' -b "$BISCOTTI" --max-time 20 "$B/admin/index.php")
atteso "$R" "login.php" "nessuna sessione aperta"

echo
echo "=== 4. accesso corretto ==="
T=$(tokenDa admin/login.php)
posta admin/login.php -d "token=$T" -d "email=ismail@prova.test" -d "password=parolalunghissima" >/dev/null
R=$(prendi admin/index.php)
atteso "$R" "Cruscotto" "il cruscotto si apre"
atteso "$R" "in attesa" "e mostra le code (singolare o plurale)"

echo
echo "=== 5. modulo senza token ==="
R=$(posta admin/alimenti.php -d "id=1" -d "azione=approva")
atteso "$R" "Modulo scaduto" "una POST senza token viene rifiutata"
ugualeA "$(sql "SELECT shared_status FROM na_custom_foods LIMIT 1;")" "pending" "e non ha approvato niente"

echo
echo "=== 6. la segnalazione con proposta e foto ==="
curl -s --max-time 20 -X POST -H "Content-Type: application/json" --data-binary '{
  "user_mail":"utente@prova.test","barcode":"8001234567890","food_name":"Croissant alla crema",
  "source":"off","issue":"valori","note":"Sull etichetta sono 430 kcal.",
  "proposed":{"calories":430,"sugars":2.45,"campo_inventato":99},
  "photos":[{"url":"http://127.0.0.1/nutriapp/uploads/finta.jpg","role":"tabella"},
            {"url":"http://sito-estraneo.example/x.jpg","role":"tabella"}]
}' "$B/save_food_report.php" >/dev/null
ID=$(sql "SELECT id FROM na_food_reports ORDER BY id DESC LIMIT 1;")
ugualeA "$(sql "SELECT COUNT(*) FROM na_report_photos WHERE report_id=$ID;")" "1" "solo la foto ospitata da noi viene salvata"
R=$(prendi admin/segnalazioni.php)
atteso "$R" "Croissant alla crema" "la coda mostra la segnalazione"
atteso "$R" "campi proposti" "con il segno della proposta"
R=$(prendi "admin/segnalazione.php?id=$ID")
atteso "$R" "calories" "il dettaglio elenca i campi proposti"
atteso "$R" "virgola spostata" "e segnala il valore sospetto (43 -> 430)"
if echo "$R" | grep -q "campo_inventato"; then
  echo "  ROTTO  una chiave che non e' una colonna non deve comparire"; ROSSI=$((ROSSI+1))
else
  echo "  OK     la chiave inventata viene scartata prima di arrivare a schermo"; VERDI=$((VERDI+1))
fi

echo
echo "=== 7-8. si accetta UN campo su due ==="
T=$(tokenDa "admin/segnalazione.php?id=$ID")
R=$(posta "admin/segnalazione.php?id=$ID" -d "token=$T" -d "id=$ID" -d "azione=accetta" -d "campi[]=calories")
atteso "$R" "1 valori scritti" "scritto un solo campo"
ugualeA "$(sql "SELECT calories FROM na_off_products WHERE barcode='8001234567890';")" "430" "le calorie sono cambiate"
ugualeA "$(sql "SELECT sugars FROM na_off_products WHERE barcode='8001234567890';")" "24.5" "gli zuccheri NON sono stati toccati"
ugualeA "$(sql "SELECT status FROM na_food_reports WHERE id=$ID;")" "accepted" "la segnalazione risulta accettata"

echo
echo "=== 9. il registro ==="
R=$(prendi admin/registro.php)
atteso "$R" "Croissant alla crema" "la decisione e' nel registro"
atteso "$(sql "SELECT before_json FROM na_review_log WHERE action='accept' LIMIT 1;")" "43" "col valore di prima, per poter tornare indietro"

echo
echo "=== 10. annulla ==="
IDLOG=$(sql "SELECT id FROM na_review_log WHERE action='accept' ORDER BY id DESC LIMIT 1;")
T=$(tokenDa admin/registro.php)
R=$(posta admin/registro.php -d "token=$T" -d "id=$IDLOG")
atteso "$R" "Decisione annullata" "l'annullamento risponde"
ugualeA "$(sql "SELECT calories FROM na_off_products WHERE barcode='8001234567890';")" "43" "le calorie sono tornate a 43"
ugualeA "$(sql "SELECT status FROM na_food_reports WHERE id=$ID;")" "pending" "la segnalazione e' di nuovo aperta"
ugualeA "$(sql "SELECT COUNT(*) FROM na_review_log WHERE undone_at IS NOT NULL;")" "1" "la riga vecchia risulta annullata, non cancellata"

echo
echo "=== 11. rifiuto senza motivazione ==="
T=$(tokenDa "admin/segnalazione.php?id=$ID")
R=$(posta "admin/segnalazione.php?id=$ID" -d "token=$T" -d "id=$ID" -d "azione=rifiuta" -d "nota=")
atteso "$R" "Scrivi una motivazione" "il rifiuto muto viene bloccato"
ugualeA "$(sql "SELECT status FROM na_food_reports WHERE id=$ID;")" "pending" "e la segnalazione resta aperta"

echo
echo "=== 11-bis. si propone anche nome, marca e foto (18/09) ==="
curl -s --max-time 20 -X POST -H "Content-Type: application/json" --data-binary '{
  "user_mail":"utente@prova.test","barcode":"8001234567890","food_name":"Croissant alla crema",
  "source":"off","issue":"nome","note":"Il nome e la foto sono di un altro prodotto.",
  "proposed":{"food_name":"Croissant alla crema Forno Buono","brand":"Forno Buono",
              "image_url":"http://127.0.0.1/nutriapp/uploads/proposta.jpg"}
}' "$B/save_food_report.php" >/dev/null
IDT=$(sql "SELECT id FROM na_food_reports ORDER BY id DESC LIMIT 1;")
R=$(prendi "admin/segnalazione.php?id=$IDT")
atteso "$R" "Croissant alla crema Forno Buono" "il nome proposto si legge nel pannello"
atteso "$R" "uploads/proposta.jpg" "e la foto proposta si vede come immagine"
T=$(tokenDa "admin/segnalazione.php?id=$IDT")
R=$(posta "admin/segnalazione.php?id=$IDT" -d "token=$T" -d "id=$IDT" -d "azione=accetta" \
     -d "campi[]=food_name" -d "campi[]=image_url")
atteso "$R" "2 valori scritti" "si accettano due campi su tre"
ugualeA "$(sql "SELECT food_name FROM na_off_products WHERE barcode='8001234567890';")" \
  "Croissant alla crema Forno Buono" "il nome e' cambiato"
ugualeA "$(sql "SELECT image_url FROM na_off_products WHERE barcode='8001234567890';")" \
  "http://127.0.0.1/nutriapp/uploads/proposta.jpg" "la foto e' cambiata"
if [ "$(sql "SELECT brand FROM na_off_products WHERE barcode='8001234567890';")" = "Forno Buono" ]; then
  echo "  ROTTO  la marca non era stata selezionata"; ROSSI=$((ROSSI+1))
else
  echo "  OK     la marca NON e' stata toccata"; VERDI=$((VERDI+1))
fi

echo
echo "=== 12. alimenti e ricette ==="
IDCIBO=$(sql "SELECT id FROM na_custom_foods LIMIT 1;")
T=$(tokenDa admin/alimenti.php)
R=$(posta admin/alimenti.php -d "token=$T" -d "id=$IDCIBO" -d "azione=approva")
atteso "$R" "Alimento pubblicato" "alimento approvato"
ugualeA "$(sql "SELECT shared_status FROM na_custom_foods WHERE id=$IDCIBO;")" "approved" "stato scritto"
IDRIC=$(sql "SELECT id FROM na_recipes LIMIT 1;")
T=$(tokenDa admin/ricette.php)
R=$(posta admin/ricette.php -d "token=$T" -d "id=$IDRIC" -d "azione=rifiuta" -d "nota=Manca il procedimento")
atteso "$R" "Ricetta rifiutata" "ricetta rifiutata con motivazione"
ugualeA "$(sql "SELECT review_note FROM na_recipes WHERE id=$IDRIC;")" "Manca il procedimento" "la motivazione arriva all'utente"

echo
echo "=== 12-bis. un alimento pubblicato resta modificabile (14/09) ==="
R=$(prendi "admin/alimento.php?id=$IDCIBO")
atteso "$R" "Salva modifiche" "la pagina di modifica si apre anche da pubblicato"
T=$(tokenDa "admin/alimento.php?id=$IDCIBO")
R=$(posta admin/alimento.php -d "token=$T" -d "id=$IDCIBO" -d "food_name=Pane di segale integrale" \
     -d "calories=260,5" -d "base_weight_g=100" -d "colonna_inventata=1")
atteso "$R" "2 campi modificati" "salva solo i due campi cambiati"
ugualeA "$(sql "SELECT CONCAT(food_name,'|',calories,'|',shared_status) FROM na_custom_foods WHERE id=$IDCIBO;")" \
  "Pane di segale integrale|260.5|approved" "scritti davvero, e l'alimento resta pubblico"
R=$(posta admin/alimento.php -d "token=$T" -d "id=$IDCIBO" -d "calories=-4")
atteso "$R" "Niente salvato" "un valore negativo non passa"
R=$(posta admin/alimento.php -d "token=$T" -d "id=$IDCIBO" -d "image_url=javascript:alert(1)")
atteso "$R" "deve iniziare con http" "e nemmeno una foto che non e' un indirizzo web"
ugualeA "$(sql "SELECT calories FROM na_custom_foods WHERE id=$IDCIBO;")" "260.5" "quindi niente e' cambiato"
IDLOG=$(sql "SELECT id FROM na_review_log WHERE action='edit' ORDER BY id DESC LIMIT 1;")
atteso "$IDLOG" "[0-9]" "la modifica e' nel registro"
T=$(tokenDa admin/registro.php)
R=$(posta admin/registro.php -d "token=$T" -d "id=$IDLOG")
atteso "$R" "2 valori ripristinati" "e si annulla dal registro"
ugualeA "$(sql "SELECT CONCAT(food_name,'|',calories,'|',shared_status) FROM na_custom_foods WHERE id=$IDCIBO;")" \
  "Pane di segale|250|approved" "tornando ai valori di prima, stato compreso"

echo
echo "=== 12-ter. ricerche e utenti (14/09) ==="
R=$(prendi "admin/alimenti.php?stato=approved&q=segale")
atteso "$R" "Pane di segale" "la ricerca negli alimenti trova per nome"
R=$(prendi "admin/alimenti.php?stato=approved&q=nessunrisultato")
atteso "$R" "Nessun alimento in questo stato" "e una ricerca a vuoto lo dice"
R=$(prendi "admin/segnalazioni.php?stato=tutti&q=utente@prova")
atteso "$R" "Croissant alla crema" "la coda delle segnalazioni cerca anche per email"
R=$(prendi "admin/utenti.php?q=Barakat")
atteso "$R" "utente@prova.test" "gli utenti si cercano per cognome"
IDUTENTE=$(sql "SELECT id FROM na_users WHERE email='utente@prova.test';")
R=$(prendi "admin/utenti.php?id=$IDUTENTE")
atteso "$R" "Risotto ai funghi" "il proprietario vede il diario"
atteso "$R" "Pane di segale" "e gli alimenti dell'utente"
R=$(prendi "admin/utenti.php?id=$IDUTENTE&pasto=Cena")
atteso "$R" "Nessuna voce con questi filtri" "il filtro per pasto funziona"
R=$(prendi "admin/utenti.php?q=%25")
atteso "$R" "Nessun utente con questa ricerca" "un % scritto nella ricerca vale come carattere, non come jolly"

echo
echo "=== 13. un revisore non gestisce gli account ==="
T=$(tokenDa admin/admins.php)
posta admin/admins.php -d "token=$T" -d "azione=crea" -d "nome=Christian" -d "email=christian@prova.test" \
     -d "ruolo=reviewer" -d "password=unapasswordlunga" >/dev/null
ugualeA "$(sql "SELECT COUNT(*) FROM na_admins;")" "2" "il proprietario ha creato il revisore"
rm -f "$BISCOTTI"
T=$(tokenDa admin/login.php)
posta admin/login.php -d "token=$T" -d "email=christian@prova.test" -d "password=unapasswordlunga" >/dev/null
R=$(prendi admin/index.php)
atteso "$R" "Cruscotto" "il revisore entra"
R=$(prendi admin/admins.php)
atteso "$R" "riservata al proprietario" "ma non apre la gestione account"
R=$(prendi "admin/utenti.php?id=$IDUTENTE")
atteso "$R" "visibile solo al proprietario" "e non vede il diario di un utente"
if echo "$R" | grep -q "Risotto ai funghi"; then
  echo "  ROTTO  il revisore legge le voci del diario"; ROSSI=$((ROSSI+1))
else
  echo "  OK     nessuna voce del diario nella pagina"; VERDI=$((VERDI+1))
fi

echo
echo "=== 14. le proprie segnalazioni tornano all'utente ==="
R=$(curl -s --max-time 20 "$B/get_my_reports.php?user_mail=utente@prova.test")
atteso "$R" '"status":"success"' "l'elenco risponde"
atteso "$R" "Croissant alla crema" "con la segnalazione mandata"
atteso "$R" '"proposed_fields":\["calories","sugars","campo_inventato"\]' "coi campi proposti, anche quelli che il pannello scartera'"

echo
echo "=== 15. problemi dell'app (15/09), col revisore ancora collegato ==="
R=$(prendi admin/problemi.php)
atteso "$R" "Il grafico delle calorie non si aggiorna" "la pagina elenca il problema aperto"
atteso "$R" "Pixel 7" "con il dispositivo"
R=$(prendi "admin/problemi.php?stato=tutti&q=Grafici")
atteso "$R" "Il grafico delle calorie" "si cerca anche per schermata"
IDPROB=$(sql "SELECT id FROM na_reports LIMIT 1;")
T=$(tokenDa admin/problemi.php)
R=$(posta admin/problemi.php -d "token=$T" -d "id=$IDPROB" -d "stato=closed" -d "nota=")
atteso "$R" "Scrivi perch" "chiudere senza dire perche' non passa"
R=$(posta admin/problemi.php -d "token=$T" -d "id=$IDPROB" -d "stato=resolved" -d "nota=Sistemato nella versione di domani")
atteso "$R" "segnato come risolto" "segnato come risolto"
ugualeA "$(sql "SELECT CONCAT(status,'|',admin_note) FROM na_reports WHERE id=$IDPROB;")" "resolved|Sistemato nella versione di domani" "stato e risposta scritti"
R=$(curl -s --max-time 20 "$B/get_my_reports.php?user_mail=utente@prova.test")
atteso "$R" '"app_reports":\[{' "chi ha segnalato lo ritrova fra i suoi"
atteso "$R" "Sistemato nella versione di domani" "con la risposta"
IDLOG=$(sql "SELECT id FROM na_review_log WHERE target_type='app_report' ORDER BY id DESC LIMIT 1;")
T=$(tokenDa admin/registro.php)
R=$(posta admin/registro.php -d "token=$T" -d "id=$IDLOG")
atteso "$R" "problema riportato a open" "si annulla dal registro"
ugualeA "$(sql "SELECT status FROM na_reports WHERE id=$IDPROB;")" "open" "e il problema torna aperto"

echo
echo "=== 16. ordinamento e ricerca su ogni pagina (15/09) ==="
for PAGINA in "segnalazioni.php?stato=tutti" "alimenti.php?stato=approved" "ricette.php?stato=rejected" "registro.php?q=Croissant" "utenti.php?q=" "problemi.php?stato=tutti" "admin.php?q="; do
  R=$(prendi "admin/$PAGINA&ordina=nome&verso=desc")
  atteso "$R" "Ordina per" "$PAGINA si ordina"
done
R=$(prendi "admin/utenti.php?ordina=u.email%3BDROP%20TABLE%20na_users&verso=desc")
atteso "$R" "utente@prova.test" "una colonna inventata nell'URL ricade sull'ordine di sempre"
ugualeA "$(sql "SELECT COUNT(*) FROM na_users;")" "1" "e non ha toccato niente"
R=$(prendi "admin/registro.php?q=Pane")
atteso "$R" "Pane di segale" "il registro si cerca per nome"

echo
echo "=== 17. un revisore ritira un alimento approvato dal proprietario (15/09) ==="
ugualeA "$(sql "SELECT CONCAT(shared_status,'|',reviewed_by) FROM na_custom_foods WHERE id=$IDCIBO;")" "approved|ismail@prova.test" "l'alimento l'ha pubblicato Ismail"
IDISMAIL=$(sql "SELECT id FROM na_admins WHERE email='ismail@prova.test';")
R=$(prendi "admin/admin.php?id=$IDISMAIL")
atteso "$R" "Pane di segale" "la pagina di Ismail mostra cosa ha pubblicato"
atteso "$R" "Ritira" "con il pulsante per ritirarlo"
# Il token si legge da una pagina che ha un modulo: la scheda "In attesa" e' vuota.
T=$(tokenDa "admin/alimenti.php?stato=approved")
R=$(posta "admin/alimenti.php?stato=approved" -d "token=$T" -d "id=$IDCIBO" -d "azione=ritira" -d "nota=")
atteso "$R" "Scrivi il motivo del ritiro" "senza motivo non si ritira"
R=$(posta "admin/admin.php?id=$IDISMAIL" -d "token=$T" -d "tipo=custom_food" -d "id=$IDCIBO" -d "nota=Valori copiati da un altro prodotto")
atteso "$R" "Alimento ritirato" "Christian lo ritira dalla pagina di Ismail"
ugualeA "$(sql "SELECT CONCAT(shared_status,'|',reviewed_by) FROM na_custom_foods WHERE id=$IDCIBO;")" "rejected|christian@prova.test" "non e' piu' pubblico, e il registro sa chi"
IDLOG=$(sql "SELECT id FROM na_review_log WHERE action='withdraw' ORDER BY id DESC LIMIT 1;")
T=$(tokenDa admin/registro.php)
R=$(posta admin/registro.php -d "token=$T" -d "id=$IDLOG")
atteso "$R" "stato riportato a approved" "il ritiro si annulla"
ugualeA "$(sql "SELECT CONCAT(shared_status,'|',reviewed_by) FROM na_custom_foods WHERE id=$IDCIBO;")" "approved|ismail@prova.test" "e torna pubblicato da Ismail"

echo
echo "=== 18. categorie delle ricette prima di pubblicare (15/09) ==="
sql "UPDATE na_recipes SET shared_status='pending' WHERE id=$IDRIC;" >/dev/null
T=$(tokenDa admin/ricette.php)
R=$(posta admin/ricette.php -d "token=$T" -d "id=$IDRIC" -d "azione=approva")
atteso "$R" "Scegli almeno un pasto" "senza categorie non si pubblica"
R=$(posta admin/ricette.php -d "token=$T" -d "id=$IDRIC" -d "azione=approva" -d "pasti[]=pranzo" -d "pasti[]=merenda" -d "portata=primo" -d "diete[]=vegetariana")
atteso "$R" "Ricetta pubblicata" "con le categorie si pubblica"
ugualeA "$(sql "SELECT CONCAT(shared_status,'|',meal_types,'|',course,'|',diet_tags) FROM na_recipes WHERE id=$IDRIC;")" "approved|pranzo|primo|vegetariana" "scritte, e il pasto inventato scartato"
R=$(prendi "admin/ricette.php?stato=approved&q=Pasta")
atteso "$R" "Primo" "la ricetta pubblicata mostra la sua portata"

if [ "$ROSSI" -gt 0 ]; then
  echo
  echo "=== ultime righe del log del server (errori PHP) ==="
  grep -iE "error|warning|fatal" "$DIR/server.log" | tail -15
fi

echo
echo "verdi: $VERDI   rossi: $ROSSI"
$MYSQL -u root -e "DROP DATABASE $DB;"
rm -rf "$DIR"
echo "database e cartella di prova rimossi."
[ "$ROSSI" -eq 0 ]
