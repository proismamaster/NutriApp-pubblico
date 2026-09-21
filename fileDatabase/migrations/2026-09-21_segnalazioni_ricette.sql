-- NutriApp — segnalazione di una ricetta pubblica — 2026-09-21
--
-- PERCHE'
-- Richiesta di Ismail (21/09): chi trova una ricetta pubblica sbagliata,
-- copiata o inadatta deve poterla segnalare. Finora si poteva segnalare un
-- ALIMENTO del database (`na_food_reports`, 12/09) e un problema dell'APP
-- (`na_reports`), ma non una ricetta: l'unica strada era descriverla a parole
-- in un problema generico, e chi rivedeva doveva ritrovarla a mano.
--
-- PERCHE' UNA TABELLA SUA E NON `na_food_reports`
-- Le colonne non combaciano: li' il soggetto e' un prodotto identificato dal
-- barcode e la segnalazione puo' portare una proposta di valori campo per
-- campo; qui il soggetto e' una riga di `na_recipes` con un autore, e non si
-- propone niente — si dice che c'e' un problema. Infilarle nella stessa
-- tabella avrebbe lasciato meta' colonne sempre nulle da una parte e
-- dall'altra, e ogni query da interpretare a mano per capire di cosa parla.
--
-- STESSA FORMA delle altre due: lista chiusa di motivi (si raggruppa e si
-- conta), stato pending/accepted/rejected, chi ha rivisto e quando. Chi sa
-- gia' leggere le segnalazioni degli alimenti legge anche queste.
--
-- L'AUTORE SI SALVA QUI, non si cerca dopo: se la ricetta viene cancellata la
-- segnalazione resta leggibile (nessuna FOREIGN KEY, come le altre tabelle
-- delle segnalazioni).
--
-- RILANCIABILE IN SICUREZZA: IF NOT EXISTS, come le precedenti.

CREATE TABLE IF NOT EXISTS `na_recipe_reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_mail` varchar(255) NOT NULL COMMENT 'chi segnala',
  `recipe_id` int(11) NOT NULL COMMENT 'riga di na_recipes segnalata',
  `recipe_name` varchar(255) NOT NULL COMMENT 'com era quando e stata segnalata',
  `author_mail` varchar(255) DEFAULT NULL COMMENT 'autore della ricetta, copiato qui',
  `issue` varchar(30) NOT NULL COMMENT 'contenuto | valori | copia | pericolosa | spam | altro',
  `note` text DEFAULT NULL,
  `status` enum('pending','accepted','rejected') NOT NULL DEFAULT 'pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `reviewed_at` timestamp NULL DEFAULT NULL,
  `reviewed_by` varchar(255) DEFAULT NULL,
  `review_note` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  -- Lo stato e' il primo filtro di chi rivede ("fammi vedere le aperte"), la
  -- ricetta il secondo ("quante segnalazioni ha questa?").
  KEY `idx_recipe_reports_status` (`status`),
  KEY `idx_recipe_reports_recipe` (`recipe_id`),
  -- La stessa persona non apre due segnalazioni uguali sulla stessa ricetta:
  -- il controllo vero lo fa save_recipe_report.php (solo finche' la prima e'
  -- aperta), questo indice lo rende immediato.
  KEY `idx_recipe_reports_doppioni` (`user_mail`, `recipe_id`, `issue`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
