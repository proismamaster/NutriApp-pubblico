-- NutriApp — contenuti del database, problemi dell'app, like e categorie — 2026-09-15
--
-- Da eseguire su phpMyAdmin DOPO 2026-09-12_collaborazione_community.sql e
-- 2026-09-12_pannello_admin.sql. Rilanciabile: IF NOT EXISTS su tutto.
--
-- Copre quattro richieste di Ismail del 15/09:
--   1. un alimento o una ricetta APPROVATI diventano del database: l'autore
--      non li ritira piu', e se li cancella dalla sua libreria restano pubblici;
--   2. le segnalazioni dei problemi dell'app si gestiscono dal pannello;
--   3. like alle ricette pubbliche;
--   4. categorie delle ricette a lista chiusa, per filtrare e consigliare.

-- ---------------------------------------------------------------------------
-- 1. "Rimosso dall'autore": sparisce dalla sua libreria, non dal database
-- ---------------------------------------------------------------------------
-- PERCHE' UNA DATA E NON LA CANCELLAZIONE
-- Cancellare la riga di un alimento approvato lo toglieva anche a chi lo
-- trovava nella ricerca e a chi l'aveva gia' messo nelle sue ricette. Con la
-- data la riga resta una sola (la regola "uno stato, non una copia" del 12/09):
-- l'autore non la vede piu', gli altri si'. Per un contenuto non approvato la
-- cancellazione resta vera, perche' non e' di nessun altro.
ALTER TABLE `na_custom_foods`
  ADD COLUMN IF NOT EXISTS `author_removed_at` timestamp NULL DEFAULT NULL
      COMMENT 'l autore l ha tolto dalla libreria; resta pubblico se approvato';

ALTER TABLE `na_recipes`
  ADD COLUMN IF NOT EXISTS `author_removed_at` timestamp NULL DEFAULT NULL
      COMMENT 'l autore l ha tolta dalle sue ricette; resta pubblica se approvata';

-- ---------------------------------------------------------------------------
-- 2. Problemi dell'app: uno stato e chi li ha presi in carico
-- ---------------------------------------------------------------------------
-- `na_reports` e' in utf8mb4_unicode_ci dal 05/09, na_users in general_ci: chi
-- le unisce deve dichiarare la collation nel JOIN (vedi admin/problemi.php).
ALTER TABLE `na_reports`
  ADD COLUMN IF NOT EXISTS `status` enum('open','resolved','closed') NOT NULL DEFAULT 'open'
      COMMENT 'open = da guardare, resolved = sistemato, closed = non si fa',
  ADD COLUMN IF NOT EXISTS `admin_note` varchar(500) DEFAULT NULL
      COMMENT 'risposta di chi l ha gestito, la vede l utente',
  ADD COLUMN IF NOT EXISTS `handled_by` varchar(255) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `handled_at` timestamp NULL DEFAULT NULL;

ALTER TABLE `na_reports`
  ADD INDEX IF NOT EXISTS `idx_reports_status` (`status`);

-- ---------------------------------------------------------------------------
-- 3. Like alle ricette
-- ---------------------------------------------------------------------------
-- Chiave doppia: un like per persona per ricetta, garantito dal database e non
-- da un controllo nell'endpoint che due richieste insieme scavalcherebbero.
CREATE TABLE IF NOT EXISTS `na_recipe_likes` (
  `recipe_id` int(11) NOT NULL,
  `user_mail` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`recipe_id`, `user_mail`),
  KEY `idx_recipe_likes_user` (`user_mail`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ---------------------------------------------------------------------------
-- 4. Categorie delle ricette, a lista chiusa
-- ---------------------------------------------------------------------------
-- SET e non tag liberi: una categoria serve a filtrare e a contare, e "Primo",
-- "primo piatto" e "primi" sarebbero tre filtri per la stessa cosa.
--   meal_types  in quali pasti ha senso (piu' d'uno): e' cio' che usa "Per te"
--   course      che portata e'
--   diet_tags   etichette di dieta, facoltative
ALTER TABLE `na_recipes`
  ADD COLUMN IF NOT EXISTS `meal_types` set('colazione','pranzo','cena','spuntino') DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `course` enum('primo','secondo','piatto_unico','contorno','dolce','bevanda','altro') DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `diet_tags` set('vegetariana','vegana','senza_glutine') DEFAULT NULL;
