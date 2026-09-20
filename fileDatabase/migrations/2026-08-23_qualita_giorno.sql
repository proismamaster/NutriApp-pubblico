-- NutriApp — punteggi qualita' sull'alimento loggato — 2026-08-23
--
-- PERCHE'
-- La home vuole mostrare la media di Nutri-Score/NOVA/Eco-Score dei cibi
-- mangiati oggi ("qualita' del giorno"), ma na_nutri_entries non ha mai
-- salvato questi 3 campi: solo macro/grassi/minerali/vitamine.
--
-- SNAPSHOT, NON RICALCOLO
-- Il punteggio va scritto al momento del log, preso dal prodotto (OFF/CREA/
-- libreria personale) in quel momento — MAI ricalcolato dopo a partire dal
-- prodotto attuale. Se il prodotto viene corretto in na_off_products un mese
-- dopo, la voce gia' loggata deve restare quella che l'utente ha davvero
-- mangiato quel giorno, non cambiare a posteriori (stesso principio ALCOA+
-- gia' applicato a na_off_products/na_product_predictions, vedi
-- 2026-07-28_provenienza_e_predizioni.sql). Per questo sono colonne dirette
-- sulla entry, non una JOIN verso na_off_products.
--
-- NULLABLE: un alimento CREA o una ricetta personale spesso non ha questi
-- punteggi. NULL (non 0/vuoto) cosi' la media in get_daily_summary.php li
-- ignora correttamente (AVG() di SQL salta i NULL da solo).

ALTER TABLE `na_nutri_entries`
  ADD COLUMN IF NOT EXISTS `nutriscore_grade` VARCHAR(2) DEFAULT NULL
      COMMENT 'a..e, snapshot al momento del log',
  ADD COLUMN IF NOT EXISTS `nova_group` TINYINT UNSIGNED DEFAULT NULL
      COMMENT '1..4, snapshot al momento del log',
  ADD COLUMN IF NOT EXISTS `environmental_score_grade` VARCHAR(2) DEFAULT NULL
      COMMENT 'a..e, snapshot al momento del log';
