-- NutriApp — storico delle pesate — 2026-09-20
--
-- Da eseguire su phpMyAdmin. Rilanciabile: IF NOT EXISTS.
--
-- PERCHE' ADESSO (test di release del 19/09)
-- L'app chiedeva da sempre `save_physical.php` e `get_physical.php`: il +/-
-- del peso in Home li usa a ogni pesata e la Home li interroga a ogni
-- aggiornamento. I due file non erano mai stati scritti e non esisteva la
-- tabella: ogni chiamata rispondeva 404, lo storico restava vuoto e il
-- confronto "rispetto a 7 giorni fa" non compariva mai.
--
-- UNA RIGA PER GIORNO
-- La chiave unica (utente, giorno) tiene una sola pesata al giorno: pesarsi
-- due volte aggiorna il valore invece di lasciare due verita' per lo stesso
-- giorno, che al grafico non si saprebbe quale mostrare.

CREATE TABLE IF NOT EXISTS `na_physical_measurements` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `user_mail` VARCHAR(255) NOT NULL,
  `measured_on` DATE NOT NULL,
  `weight` DECIMAL(6,2) NOT NULL,
  `height` DECIMAL(6,2) DEFAULT NULL,
  `body_fat` DECIMAL(5,2) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `utente_giorno` (`user_mail`, `measured_on`),
  KEY `utente_data` (`user_mail`, `measured_on`)
) ENGINE=InnoDB;
-- Niente CHARSET/COLLATE espliciti: la tabella prende quelli del
-- database, come le altre. Fissandoli a utf8mb4_unicode_ci il JOIN con
-- na_users (utf8mb4_general_ci) falliva con "Illegal mix of collations".

-- Il peso che il profilo ha gia' diventa la pesata di oggi, cosi' il grafico
-- parte da un punto vero invece che da zero. Solo per chi un peso ce l'ha.
INSERT IGNORE INTO `na_physical_measurements` (`user_mail`, `measured_on`, `weight`, `height`)
SELECT `email`, CURDATE(), `current_weight`, `height`
FROM `na_users`
WHERE `current_weight` > 0;
