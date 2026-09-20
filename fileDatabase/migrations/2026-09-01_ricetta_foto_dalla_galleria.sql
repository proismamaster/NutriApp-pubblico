-- NutriApp — foto ricetta scelta dalla galleria — 2026-09-01
--
-- PERCHE'
-- Ismail ha provato l'APK e ha segnalato che "non ti fa mettere foto ricette":
-- il campo chiedeva un indirizzo web, ma nessuno ha una foto della propria
-- ricetta gia' pubblicata su internet. La foto va presa dal telefono.
--
-- COME, E PERCHE' COSI'
-- L'app ha gia' un precedente per le immagini scelte dall'utente: la foto
-- profilo, salvata come base64 dentro `na_users.profile_image longtext` e
-- riletta con base64Decode. La stessa strada qui evita di introdurre un
-- secondo meccanismo (endpoint di upload + cartella sul server + permessi)
-- solo per le ricette.
--
-- `varchar(500)` bastava per un indirizzo ma non per un'immagine codificata:
-- serve MEDIUMTEXT (16 MB). Le foto vengono comunque ridotte a 800px e
-- qualita' 70 prima della codifica, quindi restano decine di KB, non MB.
--
-- LIMITE NOTO, DICHIARATO: tenere immagini nel database appesantisce ogni
-- lettura dell'elenco ricette. Va bene con poche decine di ricette per utente;
-- se un giorno diventeranno molte, la strada giusta e' l'endpoint di upload
-- gia' previsto al punto 7 dei prossimi passi in ROADMAP, e allora questa
-- colonna tornera' a contenere un percorso invece del contenuto.
--
-- Il tipo cambia ma il nome no: il codice che legge `image_url` continua a
-- funzionare, e accetta sia un indirizzo sia un'immagine codificata.

ALTER TABLE `na_recipes`
  MODIFY COLUMN `image_url` MEDIUMTEXT DEFAULT NULL
      COMMENT 'foto della ricetta: indirizzo web oppure immagine base64';
