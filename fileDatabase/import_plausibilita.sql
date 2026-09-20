-- NutriApp — scarto dei valori impossibili dopo un import — 2026-09-20
--
-- DA ESEGUIRE COME ULTIMO PASSO DI OGNI IMPORT DI MASSA in na_off_products
-- (i file di `tools/`). Applica in SQL le stesse soglie di
-- `limiti_nutrienti.php`, che valgono per gli alimenti scritti dagli utenti.
--
-- PERCHE' (decisione del 20/09, test di release)
-- Il prodotto `0810128370448` dichiara 40000 kcal per 100 g. Non e' un errore
-- dell'app: e' un dato sbagliato alla fonte, entrato senza che nessuno lo
-- guardasse. Da qui in poi non entra piu'.
--
-- COSA SCARTA
--  - oltre 900 kcal per 100 g (il grasso puro ne fa 900, l'olio si ferma a 884);
--  - un macro oltre 100 g su 100 g di prodotto, o la loro somma oltre 100;
--  - energia dichiarata piu' che doppia, o meno della meta', di quella che
--    danno i macro con 4/4/9. Tolleranza larga apposta: fibre, polioli e alcol
--    spostano il conto e non vogliamo buttare via dati buoni.
--
-- COSA NON FA
-- Non tocca le righe gia' presenti da prima. Ripulire lo storico e' una
-- decisione a parte (vedi ROADMAP): qui si chiude solo la porta.

-- 1. Guarda prima cosa verrebbe buttato via: se i numeri sono grossi, l'import
--    ha un problema suo e va guardato prima di cancellare.
SELECT COUNT(*) AS righe_impossibili
FROM `na_off_products`
WHERE `fetched_at` >= CURDATE()
  AND (
    `calories` > 900
    OR `calories` < 0
    OR `carbs` > 100 OR `proteins` > 100 OR `fats` > 100
    OR `fibers` > 100 OR `sugars` > 100 OR `saturated_fats` > 100
    OR (`carbs` + `proteins` + `fats`) > 100.5
    OR (
      `calories` > 0
      AND (`carbs` * 4 + `proteins` * 4 + `fats` * 9) > 50
      AND (
        `calories` > (`carbs` * 4 + `proteins` * 4 + `fats` * 9) * 2.2
        OR `calories` < (`carbs` * 4 + `proteins` * 4 + `fats` * 9) / 2.2
      )
    )
  );

-- 2. Via le righe impossibili importate oggi.
DELETE FROM `na_off_products`
WHERE `fetched_at` >= CURDATE()
  AND (
    `calories` > 900
    OR `calories` < 0
    OR `carbs` > 100 OR `proteins` > 100 OR `fats` > 100
    OR `fibers` > 100 OR `sugars` > 100 OR `saturated_fats` > 100
    OR (`carbs` + `proteins` + `fats`) > 100.5
    OR (
      `calories` > 0
      AND (`carbs` * 4 + `proteins` * 4 + `fats` * 9) > 50
      AND (
        `calories` > (`carbs` * 4 + `proteins` * 4 + `fats` * 9) * 2.2
        OR `calories` < (`carbs` * 4 + `proteins` * 4 + `fats` * 9) / 2.2
      )
    )
  );
