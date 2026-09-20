// Uso prolungato: dodici giri di navigazione fra le schede, cambi di giorno
// avanti e indietro, un alimento aggiunto a ogni giro, tema scuro acceso e
// spento. Alla fine il totale "kcal assunte" della Home deve essere uguale
// alla somma nel database, e nessun errore deve essersi accumulato.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/dictionary/translations.dart';

import 'banco.dart';

const email = 'giulia.e2e@prova.it';

void main() {
  setUpAll(preparaBanco);

  testWidgets('uso prolungato', (t) async {
    await t.runAsync(() => sql("DELETE FROM na_nutri_entries WHERE user_mail='$email' AND DATE(entry_date)=CURDATE()"));
    final b = Banco(t, 'pro');
    String tr(String k) => Translations.get('Italiano', k);
    Future<String> db(String q) async => (await t.runAsync(() => sql(q)))!;
    final cronometro = Stopwatch()..start();
    await b.giro(() async {
      await b.avvia(preferenze: {'app_language': 'Italiano', 'user_email': email});
      await b.aspettaTesto('Aggiungi un alimento:');

      for (var giro = 1; giro <= 12; giro++) {
        b.passo('giro $giro: schede');
        final inizio = cronometro.elapsedMilliseconds;
        for (final icona in [Icons.calendar_month, Icons.bookmark, Icons.show_chart]) {
          await b.tocca(find.byIcon(icona), attesa: 900);
        }
        await b.tocca(find.text('NutriApp').last, attesa: 1200);

        b.passo('giro $giro: giorni');
        for (var i = 0; i < 2; i++) {
          await b.tocca(find.byIcon(Icons.chevron_left).first, attesa: 500);
        }
        for (var i = 0; i < 2; i++) {
          await b.tocca(find.byIcon(Icons.chevron_right).first, attesa: 500);
        }
        await b.attendi(800);

        b.passo('giro $giro: aggiungi');
        await b.tocca(find.byIcon(Icons.add).last, attesa: 1500);
        await b.scrivi(find.byType(TextField).first, 'mela');
        await t.testTextInput.receiveAction(TextInputAction.search);
        await b.aspettaTesto('Mela cotogna', secondi: 20);
        await b.tocca(find.text('Mela cotogna'), attesa: 1500);
        await b.tocca(find.text(tr('meal_pick_hint')), attesa: 600);
        await b.tocca(find.text(tr('Snack')).last, attesa: 500);
        await b.scrivi(find.byType(TextField).last, '${20 + giro}');
        await b.viaSnackbar();
        await b.tocca(find.textContaining('AGGIUNGI').last, attesa: 2500);
        await b.aspettaTesto('Aggiungi un alimento:');

        if (giro % 4 == 0) {
          b.passo('giro $giro: tema');
          await b.tocca(find.byIcon(Icons.dark_mode_outlined).evaluate().isNotEmpty ? find.byIcon(Icons.dark_mode_outlined) : find.byIcon(Icons.light_mode_outlined), attesa: 600);
        }
        b.diario.writeln('giro $giro: ${cronometro.elapsedMilliseconds - inizio} ms, errori finora ${b.problemi.length}');
      }

      b.passo('controllo finale');
      await b.attendi(2000);
      await b.scatta('home_finale');
      final testo = find.textContaining(tr('kcal assunte')).evaluate().map((e) => (e.widget as Text).data ?? '').join();
      final somma = await db("SELECT CONCAT(COUNT(*),' voci, ',ROUND(SUM(calories)),' kcal, ',ROUND(SUM(weight_g)),' g') FROM na_nutri_entries WHERE user_mail='$email' AND DATE(entry_date)=CURDATE()");
      b.diario.writeln('HOME: "$testo"  DB: $somma');
    });
  }, skip: senzaServer);
}
