-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Creato il: Mag 11, 2026 alle 17:57
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
-- Struttura della tabella `na_reports`
--

CREATE TABLE `na_reports` (
  `id` int(11) NOT NULL,
  `user_email` varchar(255) NOT NULL,
  `problem_description` text NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dump dei dati per la tabella `na_reports`
--

INSERT INTO `na_reports` (`id`, `user_email`, `problem_description`, `created_at`) VALUES
(2, 'chenboxuanandrea@gmail.com', 'ciao', '2026-05-04 11:39:38');

--
-- Indici per le tabelle scaricate
--

--
-- Indici per le tabelle `na_reports`
--
ALTER TABLE `na_reports`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT per le tabelle scaricate
--

--
-- AUTO_INCREMENT per la tabella `na_reports`
--
ALTER TABLE `na_reports`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
