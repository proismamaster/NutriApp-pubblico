-- NutriApp — immagine della ricetta — 2026-08-30
--
-- PERCHE'
-- Richiesta di Ismail (punti 13 e 9 del backlog UI): poter aggiungere una foto
-- alla ricetta quando la si crea, modifica e salva, e vederla nella lista.
-- `na_recipes` non ha nessuna colonna per un'immagine: gli ingredienti ce
-- l'hanno (`na_recipe_ingredients.image_url`, dalla migrazione del 24/07) ma
-- la ricetta nel suo insieme no.
--
-- STESSO NOME E STESSO TIPO delle altre tabelle (`image_url varchar(500)`),
-- cosi' il codice che gia' sa leggere un'immagine da un prodotto o da un
-- ingrediente funziona identico anche qui, senza casi speciali.
--
-- COSA CI FINISCE DENTRO: per ora un indirizzo web, come per gli alimenti.
-- Il caricamento di un file dalla galleria richiede un endpoint di upload e
-- una cartella sul server che non esistono ancora (punto 7 dei prossimi passi
-- in ROADMAP): quando ci saranno, questa colonna conterra' il percorso del
-- file caricato senza bisogno di altre migrazioni.
--
-- RILANCIABILE IN SICUREZZA: IF NOT EXISTS, come le precedenti.

ALTER TABLE `na_recipes`
  ADD COLUMN IF NOT EXISTS `image_url` varchar(500) DEFAULT ''
      COMMENT 'foto della ricetta; indirizzo web finche non esiste l upload';
