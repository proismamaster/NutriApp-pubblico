-- NutriApp — segnalazioni piu' ricche — 2026-09-05
--
-- PERCHE'
-- Il mockup "Report Problem" chiede di sapere CHE TIPO di problema e' e su
-- QUALE schermata succede, di poter lasciare un contatto diverso dall'account,
-- e di allegare (con consenso) qualche informazione tecnica. Oggi na_reports
-- ha solo email e testo libero: una segnalazione arriva come un paragrafo da
-- leggere e interpretare a mano, senza modo di raggrupparla o filtrarla.
--
-- CHARSET: la tabella e' rimasta latin1, unica in tutto il database — le altre
-- sono utf8mb4 dalla conversione del 28/07. Con latin1 una segnalazione
-- scritta con accenti o emoji arriva storpiata, ed e' proprio il testo che poi
-- va letto per capire il problema. La convertiamo qui.
--
-- DIAGNOSTICA: `diagnostics` e' facoltativa e nasce spenta lato server (NULL).
-- L'app la manda solo se l'utente lascia acceso l'interruttore, e contiene
-- versione dell'app e modello del dispositivo: niente che identifichi la
-- persona oltre a cio' che l'account gia' dice.
--
-- RILANCIABILE IN SICUREZZA: IF NOT EXISTS su ogni colonna.

-- LA TABELLA BASE (aggiunta il 20/09, dopo il test di release)
-- `na_reports` era nata a mano su phpMyAdmin e nel repo non c'era nessun
-- CREATE: su un database appena installato questa migrazione si fermava alla
-- prima riga. Qui c'e' la forma minima; le colonne nuove le aggiunge il
-- blocco sotto, che resta rilanciabile.
CREATE TABLE IF NOT EXISTS `na_reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_email` varchar(255) NOT NULL,
  `problem_description` text NOT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'open',
  `admin_reply` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `utente` (`user_email`)
) ENGINE=InnoDB;

ALTER TABLE `na_reports`
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `na_reports`
  ADD COLUMN IF NOT EXISTS `kind` varchar(20) DEFAULT NULL
      COMMENT 'bug | data | sync | idea | other',
  ADD COLUMN IF NOT EXISTS `screen` varchar(60) DEFAULT NULL
      COMMENT 'schermata su cui si verifica, se indicata',
  ADD COLUMN IF NOT EXISTS `contact_email` varchar(255) DEFAULT NULL
      COMMENT 'contatto alternativo, facoltativo',
  ADD COLUMN IF NOT EXISTS `diagnostics` varchar(500) DEFAULT NULL
      COMMENT 'versione app e dispositivo, solo se l utente acconsente';

-- Il tipo e' la prima cosa su cui si filtra guardando le segnalazioni: senza
-- indice, ogni filtro sarebbe una scansione completa della tabella.
ALTER TABLE `na_reports`
  ADD INDEX IF NOT EXISTS `idx_reports_kind` (`kind`);
