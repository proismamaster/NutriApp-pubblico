-- ============================================================================
-- NutriApp — provenienza delle insegne + consolidamento Famila — 2026-08-22
--
-- PERCHE' LA COLONNA `fonte`
-- na_product_retailer nasceva da una fonte sola (le nostre 40 raccolte). Da
-- oggi ne ha tre, con affidabilita' diversa, e senza saperlo non si potrebbe
-- piu' rispondere a "da dove viene questa riga?" — che e' il principio
-- "Attribuibile" di ALCOA+ gia' applicato a na_off_products e
-- na_product_predictions (vedi 2026-07-28_provenienza_e_predizioni.sql).
--
--   raccolta   = letto dal sito del negozio dai nostri collector. Il piu'
--                affidabile: e' il negozio stesso a dire che lo vende.
--   off_stores = campo `stores` di OpenFoodFacts, auto-dichiarato da chi
--                carica il prodotto. Copre prodotti che non abbiamo raccolto.
--   off_brand  = il MARCHIO del prodotto e' un'insegna (marchio del
--                distributore: "Croissant al burro - Lidl"). Inferenza, non
--                dichiarazione — ma per un marchio proprio e' quasi sempre
--                vera, ed e' l'unico modo di agganciare i prodotti che nessuna
--                delle altre due fonti copre.
--
-- CONSOLIDAMENTO FAMILA (deciso da Ismail il 22/08)
-- Le 4 Famila regionali (adriatica/nord/nordest/sud) diventano una sola
-- insegna "famila": OpenFoodFacts dice solo "Famila" senza specificare la
-- regione, e distinguerle impediva di agganciare quei prodotti. Al massimo
-- due prodotti si incrociano, che e' esattamente il comportamento voluto.
--
-- ESEGUIRE DOPO 2026-08-22_ricerca_per_insegna.sql.
-- ============================================================================

-- ORDINE (sistemato il 20/09, test di release)
-- Il nome di questo file viene PRIMA di 2026-08-22_ricerca_per_insegna.sql in
-- ordine alfabetico, ma e' quell'altro a creare la tabella: chi eseguiva le
-- migrazioni in ordine si fermava qui con "Table doesn't exist". La tabella
-- nasce anche qui, identica, cosi' l'ordine non conta piu'.
CREATE TABLE IF NOT EXISTS `na_product_retailer` (
  `barcode`     VARCHAR(50)  NOT NULL,
  `insegna`     VARCHAR(50)  NOT NULL,
  `url_scheda`  VARCHAR(500) NULL COMMENT 'pagina del negozio da cui e stato letto',
  `raccolto_il` DATE         NULL,
  PRIMARY KEY (`barcode`, `insegna`),
  KEY `idx_insegna` (`insegna`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `na_product_retailer`
  ADD COLUMN IF NOT EXISTS `fonte` VARCHAR(20) NOT NULL DEFAULT 'raccolta'
      COMMENT 'raccolta | off_stores | off_brand — vedi commento in questa migrazione';

-- Consolidamento Famila. IGNORE perche' un barcode potrebbe stare in due
-- regionali diverse: dopo il merge sarebbe una chiave duplicata, e in quel
-- caso va semplicemente tenuta una riga sola.
UPDATE IGNORE `na_product_retailer`
   SET `insegna` = 'famila'
 WHERE `insegna` IN ('familaadriatica', 'familanord', 'familanordest', 'familasud');

-- Le righe che l'UPDATE IGNORE ha saltato (duplicate dopo il merge) restano
-- col vecchio nome: si cancellano, il loro barcode e' gia' su 'famila'.
DELETE FROM `na_product_retailer`
 WHERE `insegna` IN ('familaadriatica', 'familanord', 'familanordest', 'familasud');
