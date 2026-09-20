-- NutriApp — alimenti personali completi — 2026-08-29
--
-- PERCHE'
-- La schermata "New product" del mockup Claude Design permette all'utente di
-- creare o modificare un alimento con TUTTI i campi, non solo i macro. Il
-- criterio di completezza deciso con Ismail e' preciso: `search_off_products.php`
-- fa `SELECT *` su `na_off_products`, quindi un alimento creato a mano deve
-- poter contenere tutto cio' che la ricerca restituisce — altrimenti un
-- prodotto personale resta di serie B rispetto a uno di OpenFoodFacts.
--
-- COSA C'E' GIA' (verificato il 29/08 con SHOW COLUMNS sul server vero, non
-- sul dump locale): na_custom_foods ha gia' barcode, image_url, description,
-- nutriscore_grade, nova_group, additives_n, allergens, labels, palm_oil_n,
-- palm_oil_maybe_n, serving_size, categories, manufacturing_places,
-- ingredients, alcohol_percent, caffeine, tutti i macro, tutti i grassi,
-- tutte le vitamine, tutti i minerali, is_favorite e created_at.
-- Questa migrazione aggiunge SOLO cio' che manca davvero.
--
-- COSA NON VIENE AGGIUNTO, DI PROPOSITO
-- `stores`, `completeness`, `data_quality_errors_tags`, `states_tags`,
-- `unique_scans_n`: sono metadati che OpenFoodFacts calcola sul proprio
-- catalogo (in quali negozi e' stato visto, quanto e' completa la scheda,
-- quante volte e' stato scansionato nel mondo). Su un alimento scritto a mano
-- da un singolo utente non vogliono dire niente, e riempirli a caso li
-- renderebbe indistinguibili da quelli veri.
--
-- RILANCIABILE IN SICUREZZA: `IF NOT EXISTS` su ogni colonna, come la
-- migrazione del 24/07 — che proprio oggi si e' rivelata gia' applicata sul
-- server mentre il dump locale diceva il contrario.

ALTER TABLE `na_custom_foods`
  -- 1) Parita' con i campi che la ricerca restituisce e che mancavano.
  --    `brand` e' il piu' importante: la ricerca ordina e mostra per marca,
  --    e senza di essa un alimento personale non e' distinguibile fra
  --    varianti dello stesso nome.
  ADD COLUMN IF NOT EXISTS `brand` varchar(255) DEFAULT '' AFTER `food_name`,
  ADD COLUMN IF NOT EXISTS `environmental_score_grade` varchar(2) DEFAULT NULL
      COMMENT 'Eco-Score a..e, NULL quando non dichiarato',
  ADD COLUMN IF NOT EXISTS `nutriscore_score` int(11) DEFAULT NULL
      COMMENT 'punteggio numerico dietro la lettera, NULL se non calcolato',
  ADD COLUMN IF NOT EXISTS `nutrient_levels_tags` varchar(255) DEFAULT ''
      COMMENT 'semaforo nutrienti nel formato OFF (es. en:fat-in-high-quantity)',
  ADD COLUMN IF NOT EXISTS `quantity` varchar(100) DEFAULT ''
      COMMENT 'quantita\' come stampata sulla confezione, es. "500 g"',
  -- 2) Nutrienti che na_off_products ha dal reimport del 22/08 e qui no.
  ADD COLUMN IF NOT EXISTS `added_sugars` double DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `starch` double DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `polyols` double DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `lactose` double DEFAULT 0,
  -- 3) Campi nuovi della schermata, che non esistono in nessuna tabella.
  --    `net_quantity_g` e `servings` sono numerici (non basta `quantity`,
  --    che e' testo libero) perche' servono al calcolo mostrato a schermo:
  --    "una porzione e' X g, circa Y kcal".
  ADD COLUMN IF NOT EXISTS `net_quantity_g` double DEFAULT NULL
      COMMENT 'contenuto netto in grammi, per il calcolo della porzione',
  ADD COLUMN IF NOT EXISTS `servings` int(11) DEFAULT NULL
      COMMENT 'porzioni per confezione, per il calcolo della porzione',
  ADD COLUMN IF NOT EXISTS `packaging` varchar(100) DEFAULT ''
      COMMENT 'tipo di confezione: plastica, vetro, metallo, cartone, ...',
  ADD COLUMN IF NOT EXISTS `best_before` date DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `additives_tags` varchar(500) DEFAULT ''
      COMMENT 'famiglie di additivi dichiarate; additives_n resta il conteggio',
  -- 4) Tracciabilita' della modifica. created_at c'e' gia', ma senza questa
  --    non si sa se un alimento e' stato corretto dopo essere stato creato —
  --    e la schermata ora permette di modificarlo, non solo di crearlo.
  ADD COLUMN IF NOT EXISTS `updated_at` timestamp NULL DEFAULT NULL
      ON UPDATE CURRENT_TIMESTAMP;

-- Indice sulla marca: la ricerca locale sugli alimenti personali filtra per
-- nome e marca insieme (ApiServices.normalizeForSearch), e senza indice ogni
-- ricerca e' una scansione completa della tabella dell'utente.
ALTER TABLE `na_custom_foods`
  ADD INDEX IF NOT EXISTS `idx_custom_brand` (`brand`);
