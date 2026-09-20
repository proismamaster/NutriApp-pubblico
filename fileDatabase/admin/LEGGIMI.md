# Pannello di revisione — come metterlo online

Cartella da caricare via FTP: **`nutriapp/admin/`** (accanto agli endpoint,
non dentro un'altra cartella: il pannello cerca `../db_config.php`).

## 1. Le due migrazioni, in quest'ordine

Su phpMyAdmin, database dell'app:

1. `migrations/2026-09-12_collaborazione_community.sql` — se non l'hai gia'
   eseguita (crea le code).
2. `migrations/2026-09-12_pannello_admin.sql` — account, registro, proposte
   con foto.

Entrambe si possono rilanciare senza danni: usano `IF NOT EXISTS` ovunque.

## 2. I file da caricare

Dentro `nutriapp/admin/`:

```
_comune.php  login.php  logout.php  index.php
segnalazioni.php  segnalazione.php  alimenti.php  alimento.php
ricette.php  registro.php  utenti.php  admins.php
primo_admin.php  stile.css  .htaccess
```

Nella cartella `nutriapp/` (endpoint dell'app, se non gia' aggiornati):

```
save_food_report.php  get_my_reports.php  search_community_foods.php
```

`alimento.php` (modifica di un alimento, anche gia' pubblicato) e `utenti.php`
(ricerca utenti e diario) sono del 14/09. Il diario di un utente lo vede solo
chi ha il ruolo di proprietario.

## 3. Il primo account

1. Apri `https://progetti.galileicrema.org/nutriapp/admin/primo_admin.php`
2. Nome, email, password di **almeno 12 caratteri**.
3. **Cancella `primo_admin.php` dall'hosting.** Si disattiva da solo quando un
   account esiste, ma un file che crea amministratori non deve restare
   raggiungibile comunque.
4. Entra da `admin/login.php`. Gli altri account si creano da "Account".

## 4. Controlla che sia in HTTPS

L'indirizzo deve iniziare per `https://`. Se apri in `http://` vieni
rimandato: la regola sta sia in `.htaccess` sia in `_comune.php`, perche' se
l'hosting non e' Apache la prima non vale.

## Se qualcosa non va

| Cosa vedi | Cosa significa |
| --- | --- |
| "db_config.php mancante" | hai caricato `admin/` nel posto sbagliato: deve stare dentro `nutriapp/` |
| Tabella `na_admins` sconosciuta | manca la migrazione del punto 1.2 |
| "Credenziali non valide" sempre | password sbagliata, oppure account disattivato |
| "Troppi tentativi" | cinque errori di fila: si sblocca da solo dopo 15 minuti |
| Pagina bianca | errore PHP non mostrato: guarda il log degli errori dell'hosting |

## Provarlo prima di caricarlo

```bash
bash fileDatabase/prova_pannello_admin.sh
```

Fa girare il pannello vero su un MySQL locale usa-e-getta: accesso, coda,
accettazione di un campo solo su due, scrittura verificata nel database,
annullamento e ripristino del valore precedente.
