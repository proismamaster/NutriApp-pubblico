# Giri end-to-end (banco di prova)

Qui dentro l'app VERA — `MyApp`, con AuthGate, tema, lingue e unita' — gira
dentro `flutter_test` e parla con un server PHP **locale** via rete vera. Gli
scenari fanno quello che farebbe una persona (tocchi, testo, cambi di pagina)
e il database di prova registra cosa succede davvero.

Nati il 19/09 per il test di release: senza emulatore Android e senza Visual
Studio, questo e' l'unico modo di provare l'app intera su questa macchina.

## Regola prima di tutte

**Non tocchiamo mai il server vero.** Senza `NUTRI_API` che punta a
`http://127.0.0.1`, ogni scenario si salta da solo (`skip: senzaServer`), e il
banco blocca via `HttpOverrides` qualunque host che non sia 127.0.0.1.

## Come si lancia

1. Un database di prova (predefinito `nutriapp_e2e`): si crea con i file di
   `fileDatabase/` seguendo `fileDatabase/INSTALLAZIONE.md`.
2. Un PHP in ascolto sulla copia degli endpoint:
   `php -S 127.0.0.1:8790 -t <cartella con i .php>`
3. Poi:

```bash
flutter test test_e2e/diario_test.dart --dart-define=NUTRI_API=http://127.0.0.1:8790/
```

Variabili d'ambiente utili: `E2E_SCATTI` (dove salvare scatti e diari),
`E2E_FONTS` (i font di Flutter, senza i quali i testi sono rettangoli),
`E2E_MYSQL` (il client mysql), `E2E_DB` (il database di prova).

## Cosa lascia

Per ogni scenario, in `E2E_SCATTI`: gli scatti PNG passo per passo, un
`<scenario>.log` con il testo visibile a ogni scatto, gli errori raccolti e le
righe di controllo lette dal database. Il banco segnala da solo:

- gli errori di Flutter (compresi gli sforamenti di layout);
- i testi non tradotti nella lingua in prova (chiavi grezze o parole italiane
  rimaste dove non dovrebbero).

## Gli scenari

| File | Cosa prova |
|---|---|
| `esplora_test.dart` | giro rapido delle schermate principali |
| `registrazione_test.dart` | registrazione con OTP, validazioni comprese |
| `accesso_test.dart` | accesso sbagliato e giusto, recupero password, sessione dopo il riavvio |
| `giornata_test.dart` | aggiungere alimenti in tutti i modi |
| `diario_test.dart` | dettaglio giorno, modifica, eliminazione, cambio giorno |
| `ricette_test.dart` | ricetta nuova, preferito, condivisione, diario, eliminazione |
| `comunita_test.dart` | ricette consigliate, like, filtri, le mie segnalazioni |
| `segnala_test.dart` | segnalazione di un alimento e proposta dei valori con foto |
| `codice_test.dart` | codice a barre: trovato, sconosciuto, annullato, permesso negato |
| `libreria_test.dart` | alimenti salvati: uso, modifica, eliminazione |
| `impostazioni_test.dart` | lingua e unita' al volo, profilo, obiettivi, notifiche, uscita |
| `grafici_test.dart` | periodi, metriche, intervallo, PDF, calendario |
| `lingue_test.dart` | tutte le schermate in italiano, inglese, cinese e arabo |
| `schermi_test.dart` | telefono piccolo, telefono comune, tablet |
| `tema_test.dart` | chiaro/scuro, anche dopo altre schermate |
| `prolungato_test.dart` | dodici giri di uso continuo, totali confrontati col database |
| `offline_test.dart` | server irraggiungibile (si lancia con una porta chiusa) |

`offline_test.dart` vuole una porta senza nessuno in ascolto:

```bash
flutter test test_e2e/offline_test.dart --dart-define=NUTRI_API=http://127.0.0.1:8799/
```
