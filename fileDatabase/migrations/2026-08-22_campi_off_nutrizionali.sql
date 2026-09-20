-- ============================================================================
-- NutriApp — campi nutrizionali OFF mai importati — 2026-08-22
--
-- Trovati con l'audit sistematico del 22/08 (confronto fra le 211 colonne
-- dell'export e quelle davvero mappate). Non sono campi nuovi di OFF: ci sono
-- sempre stati, semplicemente non li leggevamo. Scelti per copertura reale
-- misurata sui 256.921 prodotti italiani, non a intuito.
--
--   nutrient_levels_tags  41,6%  il "semaforo" di OFF (grassi/saturi/zuccheri/
--                                sale in quantita' bassa/media/alta). E' la cosa
--                                piu' immediatamente leggibile per un utente
--                                che non sa interpretare i numeri.
--   nutriscore_score      33,1%  il punteggio numerico dietro la lettera A-E.
--                                ATTENZIONE: puo' essere NEGATIVO (da -15 a 40),
--                                quindi SMALLINT con segno, non UNSIGNED.
--   quantity              27,9%  peso/volume della confezione ("300 g", "1,5 L").
--                                Diverso da serving_size (la porzione): questa e'
--                                quanto pesa il pacco intero.
--   added_sugars          13,8%  zuccheri aggiunti, distinti dagli zuccheri
--                                totali gia' importati.
--   starch                 5,0%  amido.
--   polyols                5,0%  polioli (dolcificanti tipo maltitolo/sorbitolo):
--                                contano nel conteggio dei carboidrati per chi
--                                ha il diabete.
--   lactose                4,6%  lattosio. Copertura bassa ma e' il campo che
--                                per un intollerante fa la differenza fra
--                                "posso mangiarlo" e "non lo so".
--
-- NOTA sulle unita': added_sugars/starch/polyols/lactose sono in GRAMMI per
-- 100 g, come sugars/carbs gia' presenti — nessuna conversione, coerenti con
-- le colonne macro esistenti.
--
-- ESEGUIRE DOPO 2026-08-22_campi_off_nuovi.sql.
-- ============================================================================

ALTER TABLE `na_off_products`
  ADD COLUMN IF NOT EXISTS `nutrient_levels_tags` VARCHAR(500) NOT NULL DEFAULT ''
      COMMENT 'semaforo OFF: grassi/saturi/zuccheri/sale in quantita bassa-media-alta',
  -- SMALLINT con segno (non UNSIGNED): il punteggio va da -15 a 40.
  -- DEFAULT 0 come il resto dello schema, ma attenzione: 0 e' anche un
  -- punteggio VALIDO, quindi "nessun dato" e "punteggio 0" non si
  -- distinguono. Si legge solo quando `nutriscore_grade` e' A-E.
  ADD COLUMN IF NOT EXISTS `nutriscore_score` SMALLINT NOT NULL DEFAULT 0
      COMMENT 'punteggio numerico Nutri-Score -15..40; valido solo se nutriscore_grade e A-E',
  ADD COLUMN IF NOT EXISTS `quantity` VARCHAR(100) NOT NULL DEFAULT ''
      COMMENT 'peso/volume della confezione intera, NON la porzione',
  ADD COLUMN IF NOT EXISTS `added_sugars` DOUBLE NOT NULL DEFAULT 0
      COMMENT 'zuccheri aggiunti, g/100g',
  ADD COLUMN IF NOT EXISTS `starch` DOUBLE NOT NULL DEFAULT 0
      COMMENT 'amido, g/100g',
  ADD COLUMN IF NOT EXISTS `polyols` DOUBLE NOT NULL DEFAULT 0
      COMMENT 'polioli, g/100g — rilevanti per il conteggio carboidrati',
  ADD COLUMN IF NOT EXISTS `lactose` DOUBLE NOT NULL DEFAULT 0
      COMMENT 'lattosio, g/100g';
