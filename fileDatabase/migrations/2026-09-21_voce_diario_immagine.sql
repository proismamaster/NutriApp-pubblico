-- NutriApp — foto della voce di diario — 2026-09-21
--
-- PERCHE'
-- Segnalazione di Ismail (21/09): cambiando la foto di un alimento aperto dal
-- diario, la foto finiva nella LIBRERIA personale senza che nessuno avesse
-- chiesto "salva nella libreria"; e riaprendo la stessa voce del diario la
-- foto nuova non c'era.
--
-- CAUSA: `na_nutri_entries` non aveva nessuna colonna per l'immagine. La foto
-- di un alimento viveva SOLO su `na_custom_foods` (la libreria), quindi:
--   - per non buttare via il file appena caricato, l'app accendeva da sola
--     l'interruttore "salva nella mia libreria" (manual_entry_page.dart), che
--     e' esattamente il "senza chiedere" segnalato;
--   - modificando una voce gia' registrata quel ramo non partiva nemmeno, e
--     l'indirizzo della foto veniva scartato in silenzio: da qui la foto che
--     "non si aggiorna" quando si riapre la voce.
--
-- SCELTA: la voce di diario tiene la SUA foto. Le due cose diventano
-- indipendenti — correggere la foto di quello che si e' mangiato ieri non
-- tocca l'alimento in libreria, e aggiornare la libreria resta una scelta
-- esplicita dell'utente.
--
-- COSTO: un indirizzo corto (non il file) ripetuto sulle righe che ne hanno
-- uno. Il file sta in `uploads/` e viene caricato una volta sola da
-- upload_image.php: qui si duplica una stringa, non un'immagine.
--
-- STESSO NOME E STESSO TIPO delle altre tabelle (`image_url varchar(500)`),
-- cosi' il codice che gia' sa leggere un'immagine da un prodotto, da un
-- ingrediente o da una ricetta funziona identico anche qui.
--
-- RILANCIABILE IN SICUREZZA: IF NOT EXISTS, come le precedenti.

ALTER TABLE `na_nutri_entries`
  ADD COLUMN IF NOT EXISTS `image_url` varchar(500) NOT NULL DEFAULT ''
      COMMENT 'foto di QUESTA voce di diario; indipendente da na_custom_foods';
