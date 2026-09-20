-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Creato il: Mag 11, 2026 alle 18:02
-- Versione del server: 10.6.25-MariaDB-cll-lve-log
-- Versione PHP: 8.3.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `uulbrauy_5ib`
--

-- --------------------------------------------------------

--
-- Struttura della tabella `na_off_products`
--

-- Struttura aggiornata il 2026-09-20 (test di release): la versione
-- precedente era il dump di aprile e non aveva categories, image_url,
-- nutriscore e gli altri campi che le migrazioni di luglio usano come
-- riferimento, quindi su un database nuovo si fermavano con
-- "Unknown column".
CREATE TABLE `na_off_products` (
  `barcode` varchar(50) NOT NULL,
  `food_name` varchar(255) DEFAULT NULL,
  `brand` varchar(255) DEFAULT NULL,
  `calories` double DEFAULT 0,
  `carbs` double DEFAULT 0,
  `proteins` double DEFAULT 0,
  `fats` double DEFAULT 0,
  `water` double DEFAULT 0,
  `fibers` double DEFAULT 0,
  `sugars` double DEFAULT 0,
  `saturated_fats` double DEFAULT 0,
  `monounsaturated_fats` double DEFAULT 0,
  `polyunsaturated_fats` double DEFAULT 0,
  `trans_fats` double DEFAULT 0,
  `cholesterol` double DEFAULT 0,
  `sodium` double DEFAULT 0,
  `arsenic` double DEFAULT 0,
  `boron` double DEFAULT 0,
  `calcium` double DEFAULT 0,
  `chloride` double DEFAULT 0,
  `choline` double DEFAULT 0,
  `chromium` double DEFAULT 0,
  `cobalt` double DEFAULT 0,
  `copper` double DEFAULT 0,
  `fluoride` double DEFAULT 0,
  `fluorine` double DEFAULT 0,
  `iodine` double DEFAULT 0,
  `iron` double DEFAULT 0,
  `magnesium` double DEFAULT 0,
  `manganese` double DEFAULT 0,
  `molybdenum` double DEFAULT 0,
  `phosphorus` double DEFAULT 0,
  `potassium` double DEFAULT 0,
  `selenium` double DEFAULT 0,
  `silicon` double DEFAULT 0,
  `sulfur` double DEFAULT 0,
  `tin` double DEFAULT 0,
  `vanadium` double DEFAULT 0,
  `zinc` double DEFAULT 0,
  `vit_a` double DEFAULT 0,
  `vit_b1` double DEFAULT 0,
  `vit_b2` double DEFAULT 0,
  `vit_b3` double DEFAULT 0,
  `vit_b5` double DEFAULT 0,
  `vit_b6` double DEFAULT 0,
  `vit_b7` double DEFAULT 0,
  `vit_b9` double DEFAULT 0,
  `vit_b11` double DEFAULT 0,
  `vit_b12` double DEFAULT 0,
  `vit_c` double DEFAULT 0,
  `vit_d` double DEFAULT 0,
  `vit_e` double DEFAULT 0,
  `vit_k` double DEFAULT 0,
  `biotin` double DEFAULT 0,
  `last_update` timestamp NOT NULL DEFAULT current_timestamp(),
  `unique_scans_n` int(10) unsigned NOT NULL DEFAULT 0,
  `categories` varchar(500) NOT NULL DEFAULT '',
  `pnns_group` varchar(100) NOT NULL DEFAULT '',
  `image_url` varchar(500) NOT NULL DEFAULT '',
  `image_nutrition_url` varchar(500) NOT NULL DEFAULT '',
  `image_ingredients_url` varchar(500) NOT NULL DEFAULT '',
  `nutriscore_grade` varchar(20) NOT NULL DEFAULT '',
  `nova_group` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `additives_n` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `allergens` varchar(500) NOT NULL DEFAULT '',
  `traces` varchar(500) NOT NULL DEFAULT '',
  `labels` varchar(500) NOT NULL DEFAULT '',
  `palm_oil_n` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `palm_oil_maybe_n` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `serving_size` varchar(100) NOT NULL DEFAULT '',
  `serving_quantity` double NOT NULL DEFAULT 0,
  `has_nutrition` tinyint(1) NOT NULL DEFAULT 1,
  `manufacturing_places` varchar(255) NOT NULL DEFAULT '',
  `ingredients` text DEFAULT NULL,
  `alcohol_percent` double NOT NULL DEFAULT 0,
  `caffeine` double NOT NULL DEFAULT 0,
  `quantity` varchar(100) NOT NULL DEFAULT '',
  `packaging` varchar(255) NOT NULL DEFAULT '',
  `environmental_score_grade` varchar(20) NOT NULL DEFAULT '',
  `salt` double NOT NULL DEFAULT 0,
  `added_sugars` double NOT NULL DEFAULT 0,
  `starch` double NOT NULL DEFAULT 0,
  `polyols` double NOT NULL DEFAULT 0,
  `lactose` double NOT NULL DEFAULT 0,
  `stores` varchar(500) NOT NULL DEFAULT '',
  `completeness` double NOT NULL DEFAULT 0,
  `data_quality_errors_tags` varchar(500) NOT NULL DEFAULT '',
  `states_tags` varchar(500) NOT NULL DEFAULT '',
  `nutrient_levels_tags` varchar(255) NOT NULL DEFAULT '',
  `nutriscore_score` int(11) DEFAULT NULL,
  `data_source` varchar(32) NOT NULL DEFAULT 'off_dump' COMMENT 'off_dump | off_api | robotoff | web_agent | manual | crea | usda',
  `source_ref` varchar(255) DEFAULT NULL COMMENT 'URL o identificativo esatto della fonte',
  `fetched_at` datetime DEFAULT NULL COMMENT 'quando il dato e stato prelevato dalla fonte',
  `verified_by` varchar(64) DEFAULT NULL COMMENT 'chi ha verificato a mano (NULL = mai verificato da una persona)',
  `verified_at` datetime DEFAULT NULL,
  `quality_flags` varchar(255) NOT NULL DEFAULT '' COMMENT 'violazioni dei validatori, separate da virgola',
  PRIMARY KEY (`barcode`),
  KEY `idx_has_nutrition` (`has_nutrition`),
  KEY `idx_popolarita` (`unique_scans_n`),
  FULLTEXT KEY `food_name` (`food_name`,`brand`),
  FULLTEXT KEY `ft_nome_marca` (`food_name`,`brand`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dump dei dati per la tabella `na_off_products`
--

INSERT INTO `na_off_products` (`barcode`, `food_name`, `brand`, `calories`, `carbs`, `proteins`, `fats`, `water`, `fibers`, `sugars`, `saturated_fats`, `monounsaturated_fats`, `polyunsaturated_fats`, `trans_fats`, `cholesterol`, `sodium`, `arsenic`, `boron`, `calcium`, `chloride`, `choline`, `chromium`, `cobalt`, `copper`, `fluoride`, `fluorine`, `iodine`, `iron`, `magnesium`, `manganese`, `molybdenum`, `phosphorus`, `potassium`, `selenium`, `silicon`, `sulfur`, `tin`, `vanadium`, `zinc`, `vit_a`, `vit_b1`, `vit_b2`, `vit_b3`, `vit_b5`, `vit_b6`, `vit_b7`, `vit_b9`, `vit_b11`, `vit_b12`, `vit_c`, `vit_d`, `vit_e`, `vit_k`, `biotin`, `last_update`) VALUES
('00000108', 'BP-ER', 'Edelbrand, Wellgard', 360, 0, 90, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000143', 'Vegan mix - zuppa toscana', '', 210, 17.6, 13.35, 7.73, 0, 7.35, 3.024, 1.2, 0, 0, 0, 0, 0.95, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000145', 'MK Gold Bread Mix', 'MK Nutrition', 386, 5.1, 53, 13, 0, 0.5, 1, 1.5, 0, 0, 0, 0, 0.66, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000215', 'Riso rosso', 'Scotti', 173, 26.2, 8.8, 1.9, 0, 0, 3.2, 0.3, 0, 0, 0, 0, 0.488, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000230', 'Greens', 'Pure GPS, lack', 20, 2, 1, 13, 0, 1, 34, 5.7, 0, 0, 0, 0, 0.352, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000242', 'Protein powder', 'Herbalife', 367, 61.7, 83.3, 71.7, 0, 0, 15, 25, 0, 0, 0, 0, 0.287, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000273', 'Superfruit Organic Freezie Pops', 'DeeBee\'s Organics', 58.1, 14, 0, 0, 0, 0, 11.6, 0, 2.33, 1.16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000274', 'Protine', 'Redcon1', 413, 12.7, 76.2, 6.35, 0, 0, 6.35, 3.17, 0, 0, 0, 0, 0.302, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000279', 'Choco break', '', 524, 46.9, 5.4, 35, 0, 0, 0.1, 21.1, 0, 0, 0, 0, 0.12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000306', 'Crockis', '', 361, 51.5, 23.6, 6.8, 0, 6.5, 1.7, 0.7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000331', 'Start- sport eleven', '', 373, 4, 31, 7.3, 0, 0, 1.9, 1.6, 0, 0, 0, 0, 0.04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000351', 'Vegan plus-z', '', 204.43, 18.94, 16.34, 6.79, 0, 0, 12.75, 3.67, 0, 0, 0, 0, 0.2376, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000352', 'Plus vaniglia senza zucchero', '', 206.89999389648, 19.209999084473, 16.180000305176, 6.75, 0, 0, 13.119999885559, 3.4900000095367, 0, 0, 0, 0, 0.2456, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000353', 'Vegan Plus-Z Cocco', '', 220.27, 12, 10, 7.29, 0, 3.9, 10, 1.27, 0, 0, 0, 0, 0.8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000409', 'Ingwer Wurzel', 'Biotiva, Grappa', 303, 60, 7, 3, 0, 6, 59.4, 1, 0, 0, 0, 0, 0.04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000420', 'Tramezzino', '', 236.3, 15.2, 14.2, 13, 0, 0, 0.7, 4.1, 0, 0, 0, 0, 0.64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000424', 'Ashwagandha Extra Strength', 'futurebiotics', 552, 49, 4.8, 37, 0, 1.9, 49, 1.1, 0, 0, 0, 0, 0.004, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000466', 'Wellness Noci sgusciate', '', 721, 5, 0.06, 69, 0, 5.9, 1.5, 6.1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000600', 'Crema di nocciola al Gianduia', '', 504, 50.7, 10.5, 29.6, 0, 3.6, 49.3, 2.2, 0, 0, 0, 0, 1.28, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000666', 'Biscuits avoine choco', '', 420, 60, 6, 18, 0, 4, 28, 8, 0, 0, 0, 0, 0.25, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('00000671', 'TI ‘ Nutre', '', 385, 3, 88.4, 2.1, 0, 0, 0.8, 1.1, 0, 0, 0, 0, 0.44, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('3560071357474', 'Cornflakes', 'Carrefour', 384, 85, 7.4, 1.1, 0, 2.7, 2, 0.2, 0, 0, 0, 0, 0.18, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('8002924312636', 'Testaroli', 'Arconatura', 226, 46, 6.9, 0.9, 0, 3.1, 1.4, 0.2, 0, 0, 0, 0, 0.24, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('8008082903405', 'Melanzane alla parmigiana', 'Cucina nostrana', 149, 5.5, 3.8, 12, 0, 2.6, 2.3, 2.8, 0, 0, 0, 0, 0.392, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('8008660163600', 'Ciliegie confettura extra', 'Buongiorno Natura,In\'s,Menz&Gassner', 243, 59, 0.5, 0.2, 0, 0.6, 51, 0, 0, 0, 0, 0, 0.04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('8020053501622', 'Yogurt mirtillo', 'Mondo Natura', 100, 14, 3.5, 3.2, 0, 0, 13, 2.3, 0, 0, 0, 0, 0.04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('8024370110994', 'Farina di mandorle', 'Amonatura', 612, 11, 23, 51, 0, 8.5, 2.5, 3.9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('8026380707232', 'SLIM METABOL', '', 36, 7.1, 0.8, 0.3, 0, 1, 0.34, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('80695776', 'Fiocchi di tonno naturale in gelée con orata', '', 122, 5, 11.9, 2, 0, 0, 1.5, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16'),
('8722700628927', 'Gelato alla panna', 'Carte d\'Or,Unilever', 190, 22, 4, 9, 0, 0, 22, 6, 0, 0, 0, 0, 0.076, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '2026-04-29 16:36:16');

--
-- Indici per le tabelle scaricate
--

--
-- Indici per le tabelle `na_off_products`
--
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
