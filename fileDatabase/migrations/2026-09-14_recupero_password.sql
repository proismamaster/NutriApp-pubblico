-- 2026-09-14_recupero_password.sql
--
-- Un contatore di tentativi sui codici di verifica, per reset_password.php.
--
-- PERCHE': un codice di 6 cifre vale 15 minuti, e fino a oggi si poteva
-- provare all'infinito: un milione di combinazioni si esauriscono ben prima
-- della scadenza. Con il contatore, al quinto errore il codice viene
-- cancellato e ne serve uno nuovo, che arriva solo a chi legge quella casella.
--
-- Senza questa colonna reset_password.php si rifiuta di cambiare la password
-- e lo dice (code "missing_migration"), invece di farlo senza protezione.
--
-- Si puo' rilanciare: IF NOT EXISTS.

ALTER TABLE `na_otp_codes`
  ADD COLUMN IF NOT EXISTS `attempts` TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER `code`;
