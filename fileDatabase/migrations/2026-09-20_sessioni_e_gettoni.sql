-- NutriApp — sessioni con gettone — 2026-09-20
--
-- Da eseguire su phpMyAdmin. Rilanciabile: IF NOT EXISTS.
--
-- PERCHE' (test di release del 19/09)
-- Gli endpoint si fidavano dell'email o dell'id scritti nella richiesta.
-- Bastava cambiare quel parametro per leggere il profilo di un altro utente
-- (`get_user_data.php?email=...`), modificarlo (`update_profile.php` con
-- `user_id` altrui) o mettere like a nome suo. Con una sessione vera il
-- server non chiede piu' "chi dici di essere": lo legge dal gettone.
--
-- COME FUNZIONA
-- Al login (o alla registrazione, o dopo il recupero password) il server
-- genera un gettone casuale da 64 caratteri, lo salva qui e lo manda all'app,
-- che lo rimanda in ogni richiesta nell'intestazione `X-Auth-Token`. Una riga
-- per dispositivo: uscire da un telefono non butta fuori gli altri.
--
-- SCADENZA
-- Novanta giorni dall'ultimo uso. Un'app aperta ogni tanto resta dentro; un
-- gettone dimenticato in un telefono perso smette di valere da solo.

CREATE TABLE IF NOT EXISTS `na_sessions` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `token` CHAR(64) NOT NULL,
  `user_mail` VARCHAR(255) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_seen_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `token` (`token`),
  KEY `utente` (`user_mail`)
) ENGINE=InnoDB;
-- Niente CHARSET/COLLATE espliciti: la tabella prende quelli del
-- database, come le altre. Fissandoli a utf8mb4_unicode_ci il JOIN con
-- na_users (utf8mb4_general_ci) falliva con "Illegal mix of collations".

-- Pulizia delle sessioni vecchie: si puo' rilanciare quando si vuole.
DELETE FROM `na_sessions` WHERE `last_seen_at` < DATE_SUB(NOW(), INTERVAL 90 DAY);
