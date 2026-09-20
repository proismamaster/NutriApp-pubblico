-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Creato il: Mar 01, 2026 alle 13:58
-- Versione del server: 10.6.24-MariaDB-cll-lve-log
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
-- Struttura della tabella `na_recipe_ingredients`
--

CREATE TABLE `na_recipe_ingredients` (
  `id` int(11) NOT NULL,
  `recipe_id` int(11) NOT NULL,
  `food_name` varchar(255) NOT NULL,
  `unit` varchar(50) DEFAULT NULL,
  `weight_g` decimal(10,2) DEFAULT 0.00,
  `calories` double(10,2) DEFAULT 0.00,
  `carbs` decimal(10,2) DEFAULT 0.00,
  `proteins` decimal(10,2) DEFAULT 0.00,
  `fats` decimal(10,2) DEFAULT 0.00,
  `water` decimal(10,2) DEFAULT 0.00,
  `fibers` decimal(10,2) DEFAULT 0.00,
  `sugars` decimal(10,2) DEFAULT 0.00,
  `saturated_fats` decimal(10,2) DEFAULT 0.00,
  `monounsaturated_fats` decimal(10,2) DEFAULT 0.00,
  `polyunsaturated_fats` decimal(10,2) DEFAULT 0.00,
  `trans_fats` decimal(10,2) DEFAULT 0.00,
  `cholesterol` decimal(10,2) DEFAULT 0.00,
  `sodium` decimal(10,3) DEFAULT 0.000,
  `vit_a` decimal(10,3) DEFAULT 0.000,
  `vit_b1` decimal(10,3) DEFAULT 0.000,
  `vit_b2` decimal(10,3) DEFAULT 0.000,
  `vit_b3` decimal(10,3) DEFAULT 0.000,
  `vit_b5` decimal(10,3) DEFAULT 0.000,
  `vit_b6` decimal(10,3) DEFAULT 0.000,
  `vit_b7` decimal(10,3) DEFAULT 0.000,
  `vit_b9` decimal(10,3) DEFAULT 0.000,
  `vit_b11` decimal(10,3) DEFAULT 0.000,
  `vit_b12` decimal(10,3) DEFAULT 0.000,
  `vit_c` decimal(10,3) DEFAULT 0.000,
  `vit_d` decimal(10,3) DEFAULT 0.000,
  `vit_e` decimal(10,3) DEFAULT 0.000,
  `vit_k` decimal(10,3) DEFAULT 0.000,
  `arsenic` decimal(10,3) DEFAULT 0.000,
  `biotin` decimal(10,3) DEFAULT 0.000,
  `boron` decimal(10,3) DEFAULT 0.000,
  `calcium` decimal(10,3) DEFAULT 0.000,
  `chloride` decimal(10,3) DEFAULT 0.000,
  `choline` decimal(10,3) DEFAULT 0.000,
  `chromium` decimal(10,3) DEFAULT 0.000,
  `cobalt` decimal(10,3) DEFAULT 0.000,
  `copper` decimal(10,3) DEFAULT 0.000,
  `fluoride` decimal(10,3) DEFAULT 0.000,
  `fluorine` decimal(10,3) DEFAULT 0.000,
  `iodine` decimal(10,3) DEFAULT 0.000,
  `iron` decimal(10,3) DEFAULT 0.000,
  `magnesium` decimal(10,3) DEFAULT 0.000,
  `manganese` decimal(10,3) DEFAULT 0.000,
  `molybdenum` decimal(10,3) DEFAULT 0.000,
  `phosphorus` decimal(10,3) DEFAULT 0.000,
  `potassium` decimal(10,3) DEFAULT 0.000,
  `selenium` decimal(10,3) DEFAULT 0.000,
  `silicon` decimal(10,3) DEFAULT 0.000,
  `sulfur` decimal(10,3) DEFAULT 0.000,
  `tin` decimal(10,3) DEFAULT 0.000,
  `vanadium` decimal(10,3) DEFAULT 0.000,
  `zinc` decimal(10,3) DEFAULT 0.000
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Indici per le tabelle scaricate
--

--
-- Indici per le tabelle `na_recipe_ingredients`
--
ALTER TABLE `na_recipe_ingredients`
  ADD PRIMARY KEY (`id`),
  ADD KEY `recipe_id` (`recipe_id`);

--
-- AUTO_INCREMENT per le tabelle scaricate
--

--
-- AUTO_INCREMENT per la tabella `na_recipe_ingredients`
--
ALTER TABLE `na_recipe_ingredients`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- Limiti per le tabelle scaricate
--

--
-- Limiti per la tabella `na_recipe_ingredients`
--
ALTER TABLE `na_recipe_ingredients`
  ADD CONSTRAINT `na_recipe_ingredients_ibfk_1` FOREIGN KEY (`recipe_id`) REFERENCES `na_recipes` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
