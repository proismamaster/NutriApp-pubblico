-- NutriApp — collaborazione della comunita' — 2026-09-12
--
-- Copre i tre punti che in ROADMAP stavano fermi sotto "Piu' avanti":
--   1. segnalare un alimento sbagliato del database;
--   2. rendere pubblici i propri alimenti personali, con consenso esplicito
--      e possibilita' di escluderne uno;
--   3. sezione "ricette consigliate" con le ricette pubbliche degli utenti.
--
-- PERCHE' UNO STATO SULLA RIGA E NON UNA TABELLA "IN ATTESA"
-- La zona d'attesa e' lo stato `pending`, non una copia della riga in un'altra
-- tabella. Copiare significherebbe tenere lo stesso alimento in due posti che
-- divergono appena uno dei due viene modificato: e' il difetto che in questo
-- progetto e' tornato piu' volte (due pagine ricetta, due palette, due elenchi
-- di colonne). Con lo stato sulla riga l'alimento e' uno, e cambia solo la sua
-- visibilita'.
--
-- NIENTE RUOLO ADMIN, PER ORA (scelta di Ismail del 12/09)
-- Le colonne di revisione (`reviewed_at`, `reviewed_by`, `review_note`) ci sono
-- perche' la revisione e' parte del modello dei dati, ma nessuna schermata le
-- scrive: finche' non esiste il pannello admin, l'approvazione si fa a mano su
-- phpMyAdmin (`UPDATE ... SET shared_status='approved'`). Niente nell'app puo'
-- pubblicare da solo: senza approvazione una ricetta resta invisibile agli
-- altri. Questo e' il punto: la coda esiste e si riempie da subito, cosi' il
-- pannello, quando arrivera', trovera' dati veri su cui lavorare.
--
-- RILANCIABILE IN SICUREZZA: IF NOT EXISTS su ogni colonna, indice e tabella.

-- ---------------------------------------------------------------------------
-- 1. Segnalazioni su un alimento del database
-- ---------------------------------------------------------------------------
-- Diversa da `na_reports`, che raccoglie i problemi sull'APP (bug, idee,
-- sincronizzazione). Qui si parla di un alimento preciso: il dato e' sbagliato,
-- non il programma. Tenerle separate evita di dover indovinare, leggendo una
-- riga, se "le calorie sono sbagliate" sia un bug o una correzione di dato.
-- COLLATION: `utf8mb4_general_ci`, la stessa di na_users/na_recipes/
-- na_custom_foods. Corretta il 13/09: era `unicode_ci`, e al primo JOIN con
-- na_users MySQL rispondeva "Illegal mix of collations". I database dove
-- questa migrazione e' gia' stata eseguita si sistemano con le due ALTER in
-- fondo a 2026-09-12_pannello_admin.sql.
CREATE TABLE IF NOT EXISTS `na_food_reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_mail` varchar(255) NOT NULL,
  -- Il barcode identifica l'alimento in na_off_products / na_product_retailer.
  -- Manca per gli alimenti CREA/USDA e per quelli personali: per quelli resta
  -- il nome, che e' comunque cio' che l'utente ha visto a schermo.
  `barcode` varchar(32) DEFAULT NULL,
  `food_name` varchar(255) NOT NULL,
  `source` varchar(20) DEFAULT NULL COMMENT 'off | retailer | crea | usda | custom',
  -- Che cosa non torna. Lista chiusa: una segnalazione va raggruppata e
  -- contata, e con il solo testo libero non si puo' fare (lezione di
  -- na_reports, che per mesi ha avuto solo un paragrafo da interpretare).
  `issue` varchar(30) NOT NULL COMMENT 'valori | nome | categoria | immagine | duplicato | altro',
  `field_name` varchar(60) DEFAULT NULL COMMENT 'campo contestato, se indicato',
  `suggested_value` varchar(255) DEFAULT NULL COMMENT 'valore proposto dall utente',
  `note` text DEFAULT NULL,
  `status` enum('pending','accepted','rejected') NOT NULL DEFAULT 'pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `reviewed_at` timestamp NULL DEFAULT NULL,
  `reviewed_by` varchar(255) DEFAULT NULL,
  `review_note` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  -- Lo stato e' il primo filtro di chi rivede ("fammi vedere le aperte"), il
  -- barcode il secondo ("quante segnalazioni ha questo prodotto?").
  KEY `idx_food_reports_status` (`status`),
  KEY `idx_food_reports_barcode` (`barcode`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ---------------------------------------------------------------------------
-- 2. Condivisione degli alimenti personali
-- ---------------------------------------------------------------------------
-- Il consenso vive sull'utente, non sul singolo alimento: e' una risposta alla
-- domanda "vuoi condividere?", e va data una volta. `share_asked_at` serve a
-- non richiederlo ad ogni avvio — una domanda ripetuta e' una domanda a cui si
-- risponde di si' per sbaglio.
ALTER TABLE `na_users`
  ADD COLUMN IF NOT EXISTS `share_custom_foods` tinyint(1) NOT NULL DEFAULT 0
      COMMENT 'consenso a proporre i propri alimenti al database pubblico',
  ADD COLUMN IF NOT EXISTS `share_asked_at` timestamp NULL DEFAULT NULL
      COMMENT 'quando gli e stato chiesto: non si richiede piu';

-- `private` e' il default, ed e' l'unico stato che l'app assegna da sola.
-- Il passaggio a `pending` lo decide l'utente (consenso generale o singolo
-- alimento); ad `approved` ci arriva solo una revisione.
ALTER TABLE `na_custom_foods`
  ADD COLUMN IF NOT EXISTS `shared_status` enum('private','pending','approved','rejected')
      NOT NULL DEFAULT 'private' COMMENT 'visibilita agli altri utenti',
  ADD COLUMN IF NOT EXISTS `shared_at` timestamp NULL DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `reviewed_at` timestamp NULL DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `reviewed_by` varchar(255) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `review_note` varchar(255) DEFAULT NULL;

ALTER TABLE `na_custom_foods`
  ADD INDEX IF NOT EXISTS `idx_custom_foods_shared` (`shared_status`);

-- ---------------------------------------------------------------------------
-- 3. Ricette pubbliche
-- ---------------------------------------------------------------------------
-- Stesse colonne, stesso significato: una ricetta e' pubblica solo dopo la
-- revisione. Nessun consenso generale qui — una ricetta la si propone una per
-- una, perche' e' un contenuto scritto dall'utente e non un dato di fatto come
-- i valori di un alimento.
ALTER TABLE `na_recipes`
  ADD COLUMN IF NOT EXISTS `shared_status` enum('private','pending','approved','rejected')
      NOT NULL DEFAULT 'private' COMMENT 'visibilita agli altri utenti',
  ADD COLUMN IF NOT EXISTS `shared_at` timestamp NULL DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `reviewed_at` timestamp NULL DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `reviewed_by` varchar(255) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `review_note` varchar(255) DEFAULT NULL;

ALTER TABLE `na_recipes`
  ADD INDEX IF NOT EXISTS `idx_recipes_shared` (`shared_status`);

-- ---------------------------------------------------------------------------
-- Come approvare a mano, finche' non esiste il pannello admin
-- ---------------------------------------------------------------------------
--   SELECT id, user_mail, recipe_name, shared_at FROM na_recipes
--    WHERE shared_status='pending' ORDER BY shared_at;
--
--   UPDATE na_recipes SET shared_status='approved', reviewed_at=NOW(),
--          reviewed_by='ismail' WHERE id=<id>;
--
--   UPDATE na_custom_foods SET shared_status='approved', reviewed_at=NOW(),
--          reviewed_by='ismail' WHERE id=<id>;
--
--   SELECT issue, COUNT(*) FROM na_food_reports WHERE status='pending'
--    GROUP BY issue;
