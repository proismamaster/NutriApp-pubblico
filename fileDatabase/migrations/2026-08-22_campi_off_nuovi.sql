-- ============================================================================
-- NutriApp — nuovi campi da OpenFoodFacts — 2026-08-22
--
-- Trovati riscaricando l'export fresco (22/08) e confrontando le 211 colonne
-- disponibili con quelle gia' importate. Cinque campi che l'export ha sempre
-- avuto ma che import_off_italy.py non mappava ancora:
--
--   stores                    -> dove i contributori OFF segnalano di aver
--                                trovato il prodotto. Possibile fonte IN PIU'
--                                per "chi lo vende" oltre alle nostre 40
--                                raccolte retailer (na_product_retailer).
--   completeness               -> punteggio 0-1 che OFF calcola per scheda
--                                prodotto: quanto e' completa. Utile per
--                                prioritizzare (gia' segnalato come utile in
--                                DATA-QUALITY-PLAN.md il 28/07, mai importato).
--   data_quality_errors_tags  -> le regole di qualita' che OFF STESSO applica
--                                e pubblica. "Incrociale, ti risparmiano
--                                lavoro" (DATA-QUALITY-PLAN.md).
--   states_tags                -> stato di completamento della scheda secondo
--                                OFF (es. "categorie completate",
--                                "nutrienti completati").
--   environmental_score_grade  -> Eco-Score (A-E come il Nutri-Score),
--                                mai importato finora.
--
-- ESEGUIRE DOPO 2026-07-28_provenienza_e_predizioni.sql.
-- ============================================================================

ALTER TABLE `na_off_products`
  ADD COLUMN IF NOT EXISTS `stores` VARCHAR(1000) NOT NULL DEFAULT ''
      COMMENT 'negozi segnalati dai contributori OFF (testo libero/tag)',
  ADD COLUMN IF NOT EXISTS `completeness` DECIMAL(5,4) NOT NULL DEFAULT 0
      COMMENT 'punteggio di completezza scheda calcolato da OFF, 0-1',
  ADD COLUMN IF NOT EXISTS `data_quality_errors_tags` VARCHAR(2000) NOT NULL DEFAULT ''
      COMMENT 'errori di qualita rilevati da OFF stesso',
  ADD COLUMN IF NOT EXISTS `states_tags` VARCHAR(2000) NOT NULL DEFAULT ''
      COMMENT 'stato di completamento scheda secondo OFF',
  ADD COLUMN IF NOT EXISTS `environmental_score_grade` VARCHAR(5) NOT NULL DEFAULT ''
      COMMENT 'Eco-Score A-E, come nutriscore_grade';
