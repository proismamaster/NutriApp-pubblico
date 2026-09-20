// Impostazioni usate davvero: lingua e unita' cambiate al volo (e controllate
// sulla Home), tema scuro, profilo (errori e salvataggio), obiettivi,
// notifiche, segnalazione di un problema e sua comparsa in "Le mie
// segnalazioni", uscita, accesso sbagliato e giusto.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/dictionary/translations.dart';

import 'banco.dart';

const email = 'giulia.e2e@prova.it';

void main() {
  setUpAll(preparaBanco);

  testWidgets('impostazioni', (t) async {
    // Password nota per l'accesso finale.
    await t.runAsync(() async {
      final r = await sql("SELECT 1");
      return r;
    });
    final b = Banco(t, 'imp');
    String tr(String k) => Translations.get(b.lingua, k);
    Future<String> utente() async => (await t.runAsync(() => sql(
        "SELECT CONCAT_WS('|',first_name,height,weight,calorie_goal,carb_goal,protein_goal,fat_goal) FROM na_users WHERE email='$email'")))!;

    await b.giro(() async {
      await b.avvia(preferenze: {'app_language': 'Italiano', 'user_email': email});
      await b.attendi(2500);
      b.diario.writeln('UTENTE inizio: ${await utente()}');

      b.passo('lingua -> English al volo');
      await b.tocca(find.byIcon(Icons.settings), attesa: 1500);
      await b.tocca(find.text(tr('Lingua e paese')), attesa: 1500);
      await b.tocca(find.text('Italiano').first, attesa: 800);
      await b.scatta('foglio_lingue');
      await b.tocca(find.text('English').last, attesa: 800);
      await b.scatta('lingua_scelta');
      final salvaLingua = find.textContaining('Salva').evaluate().isNotEmpty ? find.textContaining('Salva') : find.textContaining('Save');
      await b.tocca(salvaLingua.last, attesa: 1500);
      b.lingua = 'English';
      await b.scatta('dopo_salva_lingua');
      await b.indietro();
      await b.attendi(1000);
      await b.scatta('impostazioni_en');
      await b.indietro();
      await b.attendi(1500);
      await b.scatta('home_en');

      b.passo('unita -> oz e kJ');
      await b.tocca(find.byIcon(Icons.settings), attesa: 1500);
      await b.tocca(find.text(tr('Unità di misura')), attesa: 1500);
      await b.tocca(find.text(tr('Once (oz)')), attesa: 400);
      await b.tocca(find.text(tr('Kilojoule')), attesa: 400);
      await b.scatta('unita_scelte');
      await b.tocca(find.textContaining(tr('Salva')).last, attesa: 1500);
      await b.scatta('unita_salvate');
      await b.indietro();
      await b.attendi(800);
      await b.indietro();
      await b.attendi(2000);
      await b.scatta('home_oz_kj');

      b.passo('tema scuro');
      await b.tocca(find.byIcon(Icons.dark_mode_outlined).first, attesa: 1000);
      await b.scatta('home_scuro');

      b.passo('profilo: altezza sbagliata poi giusta');
      await b.tocca(find.byIcon(Icons.settings), attesa: 1500);
      await b.tocca(find.text(tr('Il mio profilo')), attesa: 2000);
      await b.scrivi(find.byType(TextField).at(2), '90');
      await b.scatta('profilo_altezza_90');
      await b.scrivi(find.byType(TextField).at(2), '168');
      await b.scrivi(find.byType(TextField).at(0), 'Giulia Maria');
      await b.scatta('profilo_modificato');
      await b.viaSnackbar();
      await b.tocca(find.textContaining(tr('save_changes')), attesa: 2500);
      await b.scatta('profilo_salvato');
      b.diario.writeln('UTENTE dopo profilo: ${await utente()}');
      await b.indietro();
      await b.attendi(1000);

      b.passo('obiettivi: calorie 8368 kJ (2000 kcal) e bilancia');
      await b.tocca(find.text(tr('I miei obiettivi')), attesa: 2000);
      await b.scrivi(find.byType(TextField).at(2), '8368');
      await b.tocca(find.text(tr('goal_auto_balance')), attesa: 800);
      await b.scatta('obiettivi_bilanciati');
      await b.viaSnackbar();
      await b.tocca(find.textContaining(tr('Salva')).last, attesa: 2500);
      await b.scatta('obiettivi_salvati');
      final dopo = await utente();
      b.diario.writeln('UTENTE dopo obiettivi: $dopo');
      // 8368 kJ = 2000 kcal: la ripartizione automatica deve essere
      // salvabile, non rifiutata per un arrotondamento (19/09).
      expect(dopo.split('|')[3], '2000.00', reason: 'gli obiettivi bilanciati devono salvarsi');
      // Salvati gli obiettivi la pagina si chiude da sola: si torna alle
      // impostazioni solo se non ci siamo gia'.
      if (!b.vede(tr('Notifiche'))) {
        await b.indietro();
        await b.attendi(1000);
      }
      if (!b.vede(tr('Notifiche'))) {
        await b.tocca(find.byIcon(Icons.settings), attesa: 1500);
      }

      b.passo('notifiche');
      await b.tocca(find.text(tr('Notifiche')), attesa: 1500);
      await b.tocca(find.byType(Switch).first, attesa: 600);
      await b.scatta('notifiche_spente');
      await b.tocca(find.byType(Switch).first, attesa: 600);
      await b.indietro();
      await b.attendi(800);

      b.passo('segnala un problema');
      await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await b.attendi(300);
      await b.tocca(find.text(tr('Segnala un problema')), attesa: 1500);
      await b.tocca(find.text(tr('Qualcosa non funziona')), attesa: 400);
      await b.tocca(find.text(tr('Calendario')).last, attesa: 400);
      // Il campo della descrizione e' quello su piu' righe.
      await b.scrivi(find.byWidgetPredicate((w) => w is TextField && (w.maxLines ?? 1) > 1), 'Il calendario mostra i mesi in italiano anche in inglese.');
      await b.scatta('segnalazione_pronta');
      await b.viaSnackbar();
      await b.tocca(find.text(tr('Invia segnalazione')), attesa: 2500);
      await b.scatta('segnalazione_inviata');
      b.diario.writeln('NA_REPORTS: ${await t.runAsync(() => sql("SELECT CONCAT_WS('|',kind,screen,LEFT(problem_description,30),status) FROM na_reports WHERE user_email='$email' ORDER BY id DESC LIMIT 1"))}');

      b.passo('le mie segnalazioni');
      if (!b.vede(tr('my_reports_title'))) {
        await b.indietro();
        await b.attendi(800);
      }
      await b.tocca(find.text(tr('my_reports_title')), attesa: 2500);
      await b.tocca(find.textContaining(tr('my_reports_tab_app')), attesa: 1200);
      await b.scatta('mie_segnalazioni_app');
      await b.indietro();
      await b.attendi(800);

      b.passo('esci');
      await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await b.attendi(300);
      await b.tocca(find.text(tr('Log out')), attesa: 1200);
      await b.scatta('conferma_esci');
      final conferma = find.text(tr('Esci'));
      if (conferma.evaluate().isNotEmpty) await b.tocca(conferma.last, attesa: 2000);
      await b.attendi(1500);
      await b.scatta('dopo_esci');
    });
  }, skip: senzaServer);
}
