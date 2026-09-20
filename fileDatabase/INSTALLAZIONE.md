# Installare il database da zero

Scritto il 20/09 dopo il test di release: fino a ieri l'ordine dei file stava
solo nella testa di chi li aveva scritti, e una installazione nuova si fermava
a meta' (una tabella creata da una migrazione successiva a quella che la
modifica, e `na_reports` che nel repo non esisteva affatto).

Tutti i file sono rilanciabili: eseguirli due volte non rompe niente.

## 1. Database e utente

```sql
CREATE DATABASE nutriapp CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
```

Poi copia `db_config.example.php` in `db_config.local.php` con le credenziali
(oppure imposta le variabili d'ambiente `DB_HOST`, `DB_USER`, `DB_PASSWORD`,
`DB_NAME` sull'hosting). `db_config.local.php` non va mai nel repo.

## 2. Tabelle di base, in quest'ordine

1. `na_users.sql`
2. `na_nutri_entries.sql`
3. `na_custom_foods.sql`
4. `na_recipes.sql`
5. `na_recipe_ingredients.sql`
6. `na_otp_codes.sql`
7. `na_local_db.sql` — alimenti CREA
8. `na_off_products.sql` — prodotti OpenFoodFacts (solo la struttura piu'
   qualche riga di esempio; il contenuto vero sta in `tools/`)

## 3. Migrazioni, in ordine di data

Il nome dice la data: si eseguono dalla piu' vecchia alla piu' recente.

```
migrations/2026-07-24_ricette_custom_foods_traduzioni.sql
migrations/2026-07-28_livello0.sql
migrations/2026-07-28_provenienza_e_predizioni.sql
migrations/2026-08-22_campi_off_nuovi.sql
migrations/2026-08-22_campi_off_nutrizionali.sql
migrations/2026-08-22_insegne_fonte.sql
migrations/2026-08-22_ricerca_per_insegna.sql
migrations/2026-08-23_qualita_giorno.sql
migrations/2026-08-29_alimenti_personali_completi.sql
migrations/2026-08-30_ricette_immagine.sql
migrations/2026-09-01_ricetta_foto_dalla_galleria.sql
migrations/2026-09-05_segnalazioni_e_unita.sql
migrations/2026-09-12_collaborazione_community.sql
migrations/2026-09-12_pannello_admin.sql
migrations/2026-09-14_recupero_password.sql
migrations/2026-09-15_community_ricette_pannello.sql
migrations/2026-09-20_misure_fisiche.sql
migrations/2026-09-20_sessioni_e_gettoni.sql
```

Le due del 22/08 sullo stesso giorno si possono eseguire in qualunque ordine:
entrambe creano `na_product_retailer` se manca.

## 4. Dati facoltativi

`tools/` contiene gli import grossi (prodotti OpenFoodFacts, insegne). Non
servono per far partire l'app: senza, la ricerca per nome trova solo gli
alimenti CREA e quelli inseriti dagli utenti.

## 4-bis. Dopo ogni import di massa

Esegui `import_plausibilita.sql`: scarta dalle righe appena importate quelle
che non possono esistere (oltre 900 kcal per 100 g, un macro oltre 100 g su
100 g, energia che non torna con i macro). Le stesse soglie valgono per gli
alimenti scritti dagli utenti e per le correzioni accettate dal pannello:
stanno in `limiti_nutrienti.php`, un posto solo.

Il primo comando del file conta cosa verrebbe buttato via: se il numero e'
grosso, il problema e' nell'import e va guardato prima di cancellare.

## 5. Pannello di revisione

Carica `admin/` sull'hosting, apri **una volta** `admin/primo_admin.php` per
creare l'account proprietario, poi **cancella quel file**.

## Nota sulle sessioni

Dal 20/09 gli endpoint vogliono il gettone di sessione (`X-Auth-Token`), che
l'app riceve all'accesso: una versione dell'app precedente a quella data
riceve 401 e va aggiornata.
