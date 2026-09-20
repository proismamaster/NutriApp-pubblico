-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Creato il: Apr 15, 2026 alle 07:55
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
-- Struttura della tabella `na_users`
--

CREATE TABLE `na_users` (
  `id` int(11) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `first_name` varchar(100) DEFAULT NULL,
  `last_name` varchar(100) DEFAULT NULL,
  `weight` decimal(5,2) DEFAULT NULL,
  `height` decimal(5,2) DEFAULT NULL,
  `gender` enum('male','female') DEFAULT NULL,
  `birth_date` date DEFAULT NULL,
  `current_weight` decimal(5,2) DEFAULT 0.00,
  `target_weight` decimal(5,2) DEFAULT 0.00,
  `calorie_goal` decimal(10,2) DEFAULT 0.00,
  `protein_goal` decimal(10,2) DEFAULT 0.00,
  `fat_goal` decimal(10,2) DEFAULT 0.00,
  `carb_goal` decimal(10,2) DEFAULT 0.00,
  `water_goal` decimal(10,2) DEFAULT 0.00,
  `fiber_goal` decimal(10,2) DEFAULT 0.00,
  `sugar_max` decimal(10,2) DEFAULT 0.00,
  `saturated_fats_goal` decimal(10,2) DEFAULT 0.00,
  `monounsaturated_fats_goal` decimal(10,2) DEFAULT 0.00,
  `polyunsaturated_fats_goal` decimal(10,2) DEFAULT 0.00,
  `trans_fats_max` decimal(10,2) DEFAULT 0.00,
  `cholesterol_max` decimal(10,2) DEFAULT 0.00,
  `sodium_max` decimal(10,3) DEFAULT 0.000,
  `vit_a_goal` decimal(10,3) DEFAULT 0.000,
  `vit_b1_goal` decimal(10,3) DEFAULT 0.000,
  `vit_b2_goal` decimal(10,3) DEFAULT 0.000,
  `vit_b3_goal` decimal(10,3) DEFAULT 0.000,
  `vit_b5_goal` decimal(10,3) DEFAULT 0.000,
  `vit_b6_goal` decimal(10,3) DEFAULT 0.000,
  `vit_b7_goal` decimal(10,3) DEFAULT 0.000,
  `vit_b9_goal` decimal(10,3) DEFAULT 0.000,
  `vit_b11_goal` decimal(10,3) DEFAULT 0.000,
  `vit_b12_goal` decimal(10,3) DEFAULT 0.000,
  `vit_c_goal` decimal(10,3) DEFAULT 0.000,
  `vit_d_goal` decimal(10,3) DEFAULT 0.000,
  `vit_e_goal` decimal(10,3) DEFAULT 0.000,
  `vit_k_goal` decimal(10,3) DEFAULT 0.000,
  `arsenic_goal` decimal(10,3) DEFAULT 0.000,
  `biotin_goal` decimal(10,3) DEFAULT 0.000,
  `boron_goal` decimal(10,3) DEFAULT 0.000,
  `calcium_goal` decimal(10,3) DEFAULT 0.000,
  `chloride_goal` decimal(10,3) DEFAULT 0.000,
  `choline_goal` decimal(10,3) DEFAULT 0.000,
  `chromium_goal` decimal(10,3) DEFAULT 0.000,
  `cobalt_goal` decimal(10,3) DEFAULT 0.000,
  `copper_goal` decimal(10,3) DEFAULT 0.000,
  `fluoride_goal` decimal(10,3) DEFAULT 0.000,
  `fluorine_goal` decimal(10,3) DEFAULT 0.000,
  `iodine_goal` decimal(10,3) DEFAULT 0.000,
  `iron_goal` decimal(10,3) DEFAULT 0.000,
  `magnesium_goal` decimal(10,3) DEFAULT 0.000,
  `manganese_goal` decimal(10,3) DEFAULT 0.000,
  `molybdenum_goal` decimal(10,3) DEFAULT 0.000,
  `phosphorus_goal` decimal(10,3) DEFAULT 0.000,
  `potassium_goal` decimal(10,3) DEFAULT 0.000,
  `selenium_goal` decimal(10,3) DEFAULT 0.000,
  `silicon_goal` decimal(10,3) DEFAULT 0.000,
  `sulfur_goal` decimal(10,3) DEFAULT 0.000,
  `tin_goal` decimal(10,3) DEFAULT 0.000,
  `vanadium_goal` decimal(10,3) DEFAULT 0.000,
  `zinc_goal` decimal(10,3) DEFAULT 0.000,
  `language` varchar(50) DEFAULT 'Italiano',
  `profile_image` longtext DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Indici per le tabelle scaricate
--

--
-- Indici per le tabelle `na_users`
--
ALTER TABLE `na_users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`);

--
-- AUTO_INCREMENT per le tabelle scaricate
--

--
-- AUTO_INCREMENT per la tabella `na_users`
--
ALTER TABLE `na_users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
