-- ============================================================================
-- NutriApp — ricerca per insegna — 2026-08-22
--
-- Tabella di collegamento barcode<->insegna, per poter filtrare/mostrare "chi
-- vende questo prodotto". Il dato grezzo esiste gia' nei 40 raccolta_*.csv
-- (raccolti da luglio ad agosto dalle chat retailer, gia' deduplicati nella
-- fusione del 13/08) — questa tabella non raccoglie niente di nuovo, riusa
-- quel lavoro con uno scopo in piu'.
--
-- Non e' un dato completo per insegna: e' "questa insegna e' stata VISTA
-- vendere questo prodotto durante la raccolta", non un catalogo vivo — se
-- un'insegna smette di vendere un prodotto la riga resta finche' non si
-- rifa' una raccolta. Va bene per "dove lo trovo di solito", non per la
-- disponibilita' in tempo reale.
--
-- ESEGUIRE DOPO merge_retailer_in_off.sql: barcode FK su na_off_products.
-- ============================================================================

CREATE TABLE IF NOT EXISTS `na_product_retailer` (
  `barcode`     VARCHAR(50)  NOT NULL,
  `insegna`     VARCHAR(50)  NOT NULL,
  `url_scheda`  VARCHAR(500) NULL COMMENT 'pagina del negozio da cui e stato letto',
  `raccolto_il` DATE         NULL,
  PRIMARY KEY (`barcode`, `insegna`),
  KEY `idx_insegna` (`insegna`),
  CONSTRAINT `fk_retailer_prodotto` FOREIGN KEY (`barcode`)
      REFERENCES `na_off_products` (`barcode`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
