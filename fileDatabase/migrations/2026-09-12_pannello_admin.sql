-- NutriApp — pannello di revisione e proposte con foto — 2026-09-12
--
-- Seconda migrazione della giornata: la prima
-- (2026-09-12_collaborazione_community.sql) ha creato le code, questa crea
-- CHI le guarda e cosa puo' contenere una segnalazione.
--
-- Da eseguire su phpMyAdmin DOPO quella della community.
-- Rilanciabile in sicurezza: IF NOT EXISTS su tutto.

-- ---------------------------------------------------------------------------
-- 1. Gli account del pannello, SEPARATI da na_users
-- ---------------------------------------------------------------------------
-- PERCHE' UNA TABELLA A PARTE E NON UN CAMPO `is_admin` SU na_users
-- Gli endpoint dell'app non sono autenticati: login.php, social_login.php e
-- update_profile.php accettano un'email e agiscono. Un campo `is_admin` dentro
-- na_users significa che un difetto in uno di quei file diventa una scalata ai
-- privilegi. Due tabelle separate, due percorsi di accesso separati: rompere il
-- lato utente non consegna il pannello.
--
-- Nessun collegamento fra le due: un admin NON e' un utente dell'app, e non
-- deve poter usare la sua password dell'app per entrare qui.
CREATE TABLE IF NOT EXISTS `na_admins` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `email` varchar(255) NOT NULL,
  -- password_hash() di PHP, algoritmo di default (oggi bcrypt). MAI md5/sha1.
  `password_hash` varchar(255) NOT NULL,
  `display_name` varchar(100) NOT NULL,
  `role` enum('reviewer','owner') NOT NULL DEFAULT 'reviewer',
  -- Si disattiva, non si cancella: un admin cancellato lascerebbe le sue
  -- decisioni passate senza autore nel registro.
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `last_login_at` timestamp NULL DEFAULT NULL,
  -- Freno sui tentativi: dopo 5 errori l'account aspetta 15 minuti. Non e' una
  -- difesa completa, e' cio' che rende inutile provare le password a mano.
  `failed_logins` int(11) NOT NULL DEFAULT 0,
  `locked_until` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_admins_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ---------------------------------------------------------------------------
-- 2. Il registro delle decisioni
-- ---------------------------------------------------------------------------
-- Accettare una correzione e' una scrittura su un database da 214.000
-- prodotti. Senza il valore di prima, e' irreversibile: da qui la colonna
-- `before_json`, che e' cio' che rende possibile il pulsante "Annulla".
CREATE TABLE IF NOT EXISTS `na_review_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `admin_email` varchar(255) NOT NULL,
  `action` varchar(30) NOT NULL COMMENT 'accept | reject | approve | withdraw | undo',
  `target_type` varchar(20) NOT NULL COMMENT 'food_report | custom_food | recipe',
  `target_id` int(11) NOT NULL,
  -- Copia del nome al momento della decisione: se l'oggetto viene poi
  -- rinominato o cancellato, il registro resta leggibile.
  `target_label` varchar(255) DEFAULT NULL,
  `before_json` text DEFAULT NULL COMMENT 'valori precedenti, per annullare',
  `after_json` text DEFAULT NULL COMMENT 'valori scritti',
  `note` varchar(500) DEFAULT NULL COMMENT 'motivazione del rifiuto',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `undone_at` timestamp NULL DEFAULT NULL,
  `undone_by` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_review_log_target` (`target_type`,`target_id`),
  KEY `idx_review_log_admin` (`admin_email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ---------------------------------------------------------------------------
-- 3. Una segnalazione puo' portare una proposta di valori
-- ---------------------------------------------------------------------------
-- PERCHE' JSON E NON SESSANTA COLONNE
-- La proposta puo' riguardare qualunque campo nutrizionale (~60). Sessanta
-- colonne nullable su questa tabella resterebbero vuote nel 95% delle righe e
-- raddoppierebbero lo schema per un caso raro. In JSON c'e' SOLO cio' che
-- l'utente ha toccato, che e' anche esattamente cio' che il pannello mostra.
--
-- ATTENZIONE (lato codice, non lato schema): le chiavi di questo JSON arrivano
-- dall'app e NON sono nomi di colonna fidati. Il pannello le confronta con le
-- colonne vere della tabella di destinazione prima di scrivere: vedi
-- `campiAmmessi()` in admin/_comune.php.
ALTER TABLE `na_food_reports`
  ADD COLUMN IF NOT EXISTS `kind` varchar(20) NOT NULL DEFAULT 'correzione'
      COMMENT 'correzione (esiste ed e sbagliato) | nuovo (non esiste)',
  ADD COLUMN IF NOT EXISTS `proposed_json` text DEFAULT NULL
      COMMENT 'solo i campi proposti dall utente',
  ADD COLUMN IF NOT EXISTS `accepted_json` text DEFAULT NULL
      COMMENT 'i campi effettivamente accettati dal revisore';

-- ---------------------------------------------------------------------------
-- 4. Le foto della prova
-- ---------------------------------------------------------------------------
-- I file passano da upload_image.php, che esiste dal 05/09 e fa la parte
-- delicata: riconosce il tipo dal CONTENUTO (non dal nome ne' dal
-- Content-Type), decide lui il nome del file, ammette solo jpg/png/webp, si
-- ferma a 8 MB. Qui si conservano solo l'indirizzo e il RUOLO della foto.
--
-- Il ruolo conta: "tabella nutrizionale" e' la foto che permette di accettare
-- una correzione, "fronte confezione" no. Chi rivede deve saperlo prima di
-- aprirla.
CREATE TABLE IF NOT EXISTS `na_report_photos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `report_id` int(11) NOT NULL,
  `url` varchar(500) NOT NULL,
  `role` varchar(20) NOT NULL DEFAULT 'altro' COMMENT 'fronte | tabella | ingredienti | altro',
  `sort_order` tinyint(4) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_report_photos_report` (`report_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ---------------------------------------------------------------------------
-- 5. Correzione: stessa collation delle tabelle vecchie
-- ---------------------------------------------------------------------------
-- TROVATO PROVANDO IL PANNELLO (13/09), non leggendo il codice.
--
-- La migrazione di ieri creava `na_food_reports` e `na_report_photos` con
-- `utf8mb4_unicode_ci`, mentre `na_users`, `na_recipes` e `na_custom_foods`
-- (i dump storici) sono `utf8mb4_general_ci`. Finche' nessuno mette insieme
-- le due famiglie non succede niente — ed e' per questo che la prova degli
-- endpoint era tutta verde. Al primo JOIN fra una tabella nuova e na_users,
-- pero', MySQL rifiuta:
--
--   Illegal mix of collations (utf8mb4_general_ci,IMPLICIT)
--   and (utf8mb4_unicode_ci,IMPLICIT) for operation '='
--
-- Il pannello fa esattamente quel JOIN per mostrare chi ha mandato una
-- segnalazione, quindi senza queste due righe ogni pagina dell'elenco
-- risponderebbe un errore fatale. Le CREATE TABLE qui sopra sono gia'
-- corrette; queste ALTER servono ai database dove la migrazione di ieri e'
-- gia' stata eseguita (fra cui quello vero).
ALTER TABLE `na_food_reports`
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
ALTER TABLE `na_report_photos`
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- ---------------------------------------------------------------------------
-- Il primo account admin NON si crea qui
-- ---------------------------------------------------------------------------
-- Una password scritta dentro un file SQL finirebbe nel repo e nella storia di
-- git, che e' il quarto segreto esposto di questo progetto (vedi PROBLEMS).
-- Si crea aprendo una volta `admin/primo_admin.php`, che funziona SOLO finche'
-- questa tabella e' vuota e va cancellato subito dopo.
