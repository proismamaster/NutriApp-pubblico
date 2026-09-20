# NutriApp

**NutriApp** è un'app mobile cross-platform pensata per aiutare l'utente a monitorare l'alimentazione quotidiana in modo semplice, completo e personalizzato.

L'obiettivo del progetto è trasformare il classico diario alimentare in uno strumento più intelligente: l'utente registra ciò che mangia e l'app restituisce dati nutrizionali, grafici, obiettivi personalizzati e avvisi automatici.

---

## Indice

- [Descrizione del progetto](#descrizione-del-progetto)
- [Obiettivi](#obiettivi)
- [Funzionalità principali](#funzionalità-principali)
- [Funzionalità aggiuntive](#funzionalità-aggiuntive)
- [Tecnologie utilizzate](#tecnologie-utilizzate)
- [Architettura del progetto](#architettura-del-progetto)
- [Flusso dei dati](#flusso-dei-dati)
- [Struttura indicativa delle cartelle](#struttura-indicativa-delle-cartelle)
- [Database](#database)
- [Installazione e avvio](#installazione-e-avvio)
- [Team](#team)
- [Metodo di lavoro](#metodo-di-lavoro)
- [Sviluppi futuri](#sviluppi-futuri)
- [Licenza](#licenza)

---

## Descrizione del progetto

NutriApp è un'applicazione mobile per il monitoraggio completo dell'alimentazione quotidiana.

L'app permette all'utente di:

- registrare alimenti e pasti;
- consultare valori nutrizionali;
- monitorare macronutrienti e micronutrienti;
- visualizzare grafici dei progressi;
- impostare obiettivi personalizzati;
- ricevere avvisi quando vengono superate determinate soglie nutrizionali.

Il progetto nasce da requisiti definiti da una committente e sviluppati attraverso un percorso di analisi, progettazione, sviluppo e rifinitura.

---

## Obiettivi

Gli obiettivi principali di NutriApp sono:

- offrire un diario alimentare semplice e completo;
- aiutare l'utente a controllare calorie, macronutrienti e micronutrienti;
- rendere più immediata la consultazione dei dati tramite grafici;
- permettere la personalizzazione degli obiettivi nutrizionali;
- salvare lo storico alimentare dell'utente;
- supportare l'utilizzo su più piattaforme tramite Flutter;
- progettare l'app con attenzione alla privacy e alla sicurezza dei dati.

---

## Funzionalità principali

Le funzionalità core dell'app includono:

- **Monitoraggio alimentare giornaliero**
  - registrazione degli alimenti per pasto;
  - calcolo automatico dei totali giornalieri;
  - visualizzazione di calorie e nutrienti.

- **Gestione dei nutrienti**
  - tracciamento di carboidrati, proteine e grassi;
  - consultazione di micronutrienti come vitamine, sali minerali, fibre, zuccheri e sodio.

- **Obiettivi personalizzati**
  - impostazione di soglie nutrizionali;
  - personalizzazione in base al profilo dell'utente.

- **Grafici e progressi**
  - visualizzazione dei dati nutrizionali;
  - confronto dei progressi su base giornaliera, settimanale e mensile.

- **Avvisi e notifiche**
  - avvisi automatici quando un valore si avvicina o supera una soglia;
  - notifiche locali pianificate.

- **Gestione profilo utente**
  - salvataggio delle informazioni personali;
  - storico dei pasti e delle preferenze.

- **Ricerca alimentare**
  - ricerca testuale degli alimenti;
  - consultazione di fonti alimentari interne ed esterne.

---

## Funzionalità aggiuntive

Oltre ai requisiti principali, il progetto include o prevede diverse funzioni avanzate:

- scansione del codice a barre dei prodotti;
- integrazione con fonti esterne come OpenFoodFacts, CREA e USDA;
- ricette personalizzate;
- backend dedicato in PHP;
- database MySQL/MariaDB;
- esportazione di report in PDF;
- modalità scura;
- guide utente e tutorial in-app;
- privacy policy integrata;
- supporto multilingua;
- social login;
- autenticazione tramite OTP.

---

## Tecnologie utilizzate

### Frontend

- **Flutter**
  - framework cross-platform per creare app mobile;
  - permette di sviluppare con un'unica base di codice per Android e iOS.

- **Dart**
  - linguaggio utilizzato da Flutter;
  - supporta null safety, programmazione a oggetti, `Future`, `async/await` e `Stream`.

- **Riverpod**
  - gestione dello stato dell'app;
  - separa la logica dai widget dell'interfaccia;
  - permette l'aggiornamento automatico delle schermate quando cambiano i dati.

### Backend

- **PHP**
  - gestione delle richieste provenienti dall'app;
  - logica applicativa;
  - comunicazione con il database.

### Database

- **MySQL / MariaDB**
  - salvataggio di utenti, pasti, alimenti, ricette, obiettivi e report.

### Librerie e package principali

- `http` per le chiamate REST;
- `barcode_scan2` per la scansione dei codici a barre;
- `flutter_local_notifications` e `timezone` per notifiche locali;
- `shared_preferences` per preferenze e sessione locale;
- `fl_chart` per grafici nutrizionali;
- `pdf` e `printing` per generazione e condivisione di report;
- `google_sign_in` e `sign_in_with_apple` per il login social.

### Strumenti di collaborazione

- **GitLab / Git**
  - versionamento del codice;
  - branch di sviluppo;
  - merge request;
  - collaborazione tra membri del team.

---

## Architettura del progetto

Il progetto è organizzato seguendo il principio della **separazione delle responsabilità**.

Ogni parte dell'app ha un compito preciso:

- il **frontend Flutter** gestisce l'interfaccia utente;
- i **provider Riverpod** gestiscono lo stato condiviso;
- i **services** comunicano con backend e API esterne;
- i **models** rappresentano i dati dell'app;
- il **backend PHP** riceve ed elabora le richieste;
- il **database MySQL/MariaDB** conserva i dati in modo persistente.

Questa organizzazione rende il progetto più leggibile, mantenibile e scalabile.

---

## Flusso dei dati

Esempio di flusso end-to-end:

1. L'utente interagisce con una schermata Flutter.
2. La schermata usa model e provider per organizzare i dati.
3. Un service invia una richiesta HTTP al backend PHP.
4. Il backend elabora la richiesta.
5. Il database salva o restituisce i dati.
6. Il backend invia una risposta in formato JSON.
7. Flutter decodifica il JSON.
8. Riverpod aggiorna lo stato.
9. L'interfaccia mostra i dati aggiornati.

Esempio pratico:

> L'utente aggiunge 100 g di pasta. L'app invia i dati al backend, il database salva l'alimento nel pasto e l'interfaccia aggiorna calorie, nutrienti e grafici giornalieri.

---

## Struttura indicativa delle cartelle

```text
nutriapp/
├── lib/
│   ├── screens/        # Schermate principali dell'app
│   ├── models/         # Modelli dati
│   ├── services/       # Chiamate API e comunicazione backend
│   ├── providers/      # Gestione stato con Riverpod
│   ├── domain/         # Logica di business
│   └── widgets/        # Componenti UI riutilizzabili
│
├── android/            # Configurazione Android
├── ios/                # Configurazione iOS
├── web/                # Supporto web, se previsto
├── windows/            # Supporto Windows, se previsto
│
├── fileDatabase/       # Script PHP e SQL backend/database
├── docs/               # Documentazione del progetto
└── README.md
```

---

## Database

Il database relazionale organizza le informazioni principali in tabelle collegate tra loro.

Tabelle principali:

- **users**
  - dati dell'account e informazioni personali dell'utente;

- **nutri_entries**
  - registrazioni alimentari associate a utenti e pasti;

- **custom_foods**
  - alimenti personalizzati creati dall'utente;

- **off_products**
  - prodotti recuperati da OpenFoodFacts o altre fonti esterne;

- **recipes**
  - ricette create dall'utente;

- **recipe_ingredients**
  - ingredienti collegati alle ricette;

- **otp_codes**
  - codici per verifica o autenticazione;

- **reports**
  - report generati o salvati.

L'uso di chiavi primarie e chiavi esterne permette di collegare utenti, pasti, alimenti, ricette e report evitando duplicazioni inutili.

---

## Installazione e avvio

> Le istruzioni possono variare in base alla struttura effettiva della repository.

### 1. Clonare la repository

```bash
git clone https://github.com/USERNAME/NOME_REPOSITORY.git
cd NOME_REPOSITORY
```

### 2. Installare le dipendenze Flutter

```bash
flutter pub get
```

### 3. Configurare il backend

Configurare il server PHP e il database MySQL/MariaDB.

Esempio:

1. creare un database MySQL/MariaDB;
2. importare gli script SQL presenti nella cartella `fileDatabase`;
3. configurare le credenziali di connessione nei file PHP;
4. verificare che gli endpoint backend siano raggiungibili dall'app.

### 4. Avviare l'app

Per eseguire l'app su emulatore o dispositivo collegato:

```bash
flutter run
```

Per generare un APK Android:

```bash
flutter build apk
```

Per generare una build iOS:

```bash
flutter build ios
```

> La build iOS richiede macOS e Xcode.

---

## Team

Il progetto è stato realizzato da:

- **Barakat Ismail**
  - Project Manager;
  - Backend Developer;
  - Data Engineer.

- **Donzelli Christian**
  - Nutrition Expert;
  - documentazione.

- **Maltese Emanuel**
  - Frontend Developer;
  - wireframe.

- **Yu Serena**
  - UX/UI Designer;
  - Frontend Developer;
  - mockup.

---

## Metodo di lavoro

Lo sviluppo è stato organizzato in sprint.

### Sprint 1 — Analisi, progettazione e formazione

Attività principali:

- raccolta dei requisiti;
- analisi degli stakeholder;
- Project Charter;
- Product Backlog;
- User Stories;
- wireframe e mockup;
- raccolta dati nutrizionali di base;
- formazione su Dart e Flutter.

### Sprint 2 — Base funzionale

Attività principali:

- registrazione manuale dei valori nutrizionali;
- calcolo automatico dei totali giornalieri;
- prime ricette personalizzate;
- salvataggio delle ricette.

### Sprint 3 — Funzionalità avanzate e rifinitura

Attività principali:

- scansione barcode;
- integrazione OpenFoodFacts;
- registrazione e login;
- soglie nutrizionali personalizzate;
- grafici e report;
- notifiche;
- rifinitura tecnica e grafica.

---

## Qualità del codice

Nel progetto sono state applicate alcune buone pratiche di sviluppo:

- separazione tra UI, logica, provider, services e models;
- widget riutilizzabili;
- naming semantico per variabili, funzioni e classi;
- refactoring delle schermate;
- commenti brevi e significativi;
- utilizzo di branch Git per feature e bugfix;
- merge request e review prima dell'integrazione.

---

## Sviluppi futuri

Possibili evoluzioni del progetto:

- miglioramento del sistema di raccomandazioni nutrizionali;
- integrazione con dispositivi wearable;
- dashboard per nutrizionisti;
- esportazione avanzata dei report;
- miglioramento del supporto multilingua;
- ampliamento delle fonti alimentari;
- pubblicazione sugli store Android e iOS;
- maggiore copertura di test automatici.

---

## Licenza

Questo progetto è stato realizzato a scopo scolastico/didattico.

Aggiungere qui la licenza scelta per la repository, ad esempio:

```text
MIT License
```

oppure specificare:

```text
Tutti i diritti riservati.
```

---

## Nota

NutriApp è un progetto didattico. Le informazioni nutrizionali mostrate dall'app devono essere considerate come supporto informativo e non sostituiscono il parere di un medico, nutrizionista o professionista sanitario.

---

## Configurazione locale (chiavi e segreti)

Nel repository non c'è nessuna chiave: i file che le contengono vanno creati a
mano, partendo dagli esempi.

### 1. Firebase / accesso con Google (Android)

```bash
cp android/app/google-services.json.example android/app/google-services.json
```

Poi riempilo con i valori del tuo progetto Firebase (Impostazioni progetto →
Le tue app → Android → `google-services.json`). Il file è in `.gitignore`:
finisce dentro l'APK, quindi non è un segreto forte, ma la chiave va comunque
ristretta al nome del package e alla firma dell'app dalla console Google
Cloud, o chiunque estragga l'APK può usarla a tuo nome.

### 2. Database e servizi del backend

```bash
cp fileDatabase/db_config.example.php fileDatabase/db_config.local.php
```

Dentro vanno host, utente, password e nome del database, più la chiave Brevo
per l'invio delle email di recupero password. In alternativa si impostano le
variabili d'ambiente `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` e
`BREVO_API_KEY` sull'hosting: il codice guarda prima quelle.

### 3. Chiave USDA (facoltativa)

Serve solo alla ricerca sull'archivio americano. Lato app si passa alla
compilazione, lato server è una variabile d'ambiente:

```bash
flutter build apk --release --dart-define=USDA_API_KEY=la-tua-chiave
export USDA_API_KEY=la-tua-chiave   # sul server
```

Senza, la ricerca funziona lo stesso su OpenFoodFacts e CREA.

### 4. Database

Segui `fileDatabase/INSTALLAZIONE.md`: crea il database, esegui i file di base
e poi le migrazioni nell'ordine indicato.
