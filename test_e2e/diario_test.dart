// Il diario dopo la giornata: dettaglio del giorno, voce in sola lettura,
// modifica con la matita (peso e pasto), eliminazione, cambio giorno con
// aggiunta a ieri, dettaglio del pasto, peso dalla Home. Parte dai dati
// lasciati da giornata_test (tre voci oggi).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banco.dart';

const email = 'giulia.e2e@prova.it';

Future<String> voci(WidgetTester t, String quando) async => (await t.runAsync(() => sql(
        "SELECT IFNULL(GROUP_CONCAT(CONCAT(meal_type,':',LEFT(food_name,14),':',ROUND(weight_g),'g:',ROUND(calories),'kcal') ORDER BY id SEPARATOR ' | '),'(nessuna)') "
        "FROM na_nutri_entries WHERE user_mail='$email' AND DATE(entry_date)=$quando")))!;

void main() {
  setUpAll(preparaBanco);

  testWidgets('diario', (t) async {
    // Stato di partenza fisso: tre voci oggi, nessuna ieri.
    await t.runAsync(() => sql("""
      DELETE FROM na_nutri_entries WHERE user_mail='$email';
      INSERT INTO na_nutri_entries (user_mail, food_name, meal_type, entry_date, weight_g, calories, carbs, proteins, fats, fibers, sugars)
      VALUES ('$email','Dill Pickle Salad','Colazione',NOW(),150,780,73.5,16.5,46.5,9,15),
             ('$email','MELA  polpa secca','Pranzo',NOW(),100,243,57,1,1,8,50),
             ('$email','Pasta al pomodoro della nonna','Cena',NOW(),250,160,28,6,3.5,0,0);
    """));
    final b = Banco(t, 'dia');
    await b.giro(() async {
      await b.avvia(preferenze: {'app_language': 'Italiano', 'user_email': email});
      await b.aspettaTesto('Aggiungi un alimento:');
      await b.attendi(1500);
      b.diario.writeln('OGGI: ${await voci(t, 'CURDATE()')}');

      b.passo('dettaglio del giorno');
      await b.tocca(find.text('Dettagli'), attesa: 1000);
      await b.aspettaTesto('Dill Pickle Salad', secondi: 15);
      await b.scatta('dettaglio_giorno');

      b.passo('voce in sola lettura');
      await b.tocca(find.text('Dill Pickle Salad'), attesa: 1500);
      await b.scatta('sola_lettura');
      await b.indietro();

      b.passo('matita: 200 g e pasto Pranzo');
      await b.tocca(find.byIcon(Icons.edit_outlined), attesa: 1500);
      await b.scatta('matita');
      await b.scrivi(find.byType(TextField).last, '200');
      await b.tocca(find.text('Colazione').last, attesa: 600);
      await b.scatta('scelta_pasto');
      await b.tocca(find.text('Pranzo').last, attesa: 600);
      await b.tocca(find.textContaining('SALVA'), attesa: 2500);
      await b.attendi(3000);
      await b.scatta('dopo_salva');
      b.diario.writeln('OGGI dopo modifica: ${await voci(t, 'CURDATE()')}');

      b.passo('elimina con conferma');
      await b.aspettaTesto('Pranzo', secondi: 10);
      await b.tocca(find.text('Pranzo').first, attesa: 1000);
      await b.aspettaTesto('MELA  polpa secca', secondi: 10);
      await b.scatta('pranzo');
      await b.tocca(find.byIcon(Icons.delete_outline).last, attesa: 800);
      await b.scatta('conferma_elimina');
      await b.tocca(find.text('Annulla'), attesa: 800);
      b.diario.writeln('OGGI dopo annulla: ${await voci(t, 'CURDATE()')}');
      await b.tocca(find.byIcon(Icons.delete_outline).last, attesa: 800);
      await b.tocca(find.text('Elimina').last, attesa: 2000);
      await b.attendi(3000);
      await b.scatta('dopo_elimina');
      b.diario.writeln('OGGI dopo elimina: ${await voci(t, 'CURDATE()')}');
      await b.indietro();
      await b.attendi(5000);
      await b.scatta('home_dopo_dettaglio');

      b.passo('ieri: aggiungo a colazione');
      await b.tocca(find.byIcon(Icons.chevron_left).first, attesa: 1500);
      await b.attendi(4000);
      await b.scatta('home_ieri');
      await b.tocca(find.byIcon(Icons.add).first);
      await b.scrivi(find.widgetWithText(TextField, 'Cerca alimento...'), 'pesca');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await b.aspettaTesto('Pesca', secondi: 20);
      await b.tocca(find.text('Pesca').first, attesa: 1500);
      await b.tocca(find.textContaining('AGGIUNGI'), attesa: 2500);
      await b.attendi(2500);
      await b.scatta('home_ieri_dopo');
      b.diario.writeln('IERI: ${await voci(t, 'CURDATE() - INTERVAL 1 DAY')}');
      b.diario.writeln('OGGI: ${await voci(t, 'CURDATE()')}');

      b.passo('avanti fino a domani');
      await b.tocca(find.byIcon(Icons.chevron_right).first, attesa: 1500);
      await b.scatta('home_oggi_di_nuovo');
      await b.tocca(find.byIcon(Icons.chevron_right).first, attesa: 1500);
      await b.scatta('home_domani');

      b.passo('dettaglio del pasto');
      await b.tocca(find.byIcon(Icons.chevron_left).first, attesa: 1500);
      await b.tocca(find.text('Cena'), attesa: 1000);
      await b.attendi(3000);
      await b.scatta('dettaglio_cena');
      await b.indietro();
      await b.attendi(1500);

      b.passo('cambi di giorno rapidi');
      // Indietro 3 giorni e avanti 2 senza aspettare: deve restare ieri, con
      // i numeri di ieri (una voce, la pesca).
      for (final icona in [Icons.chevron_left, Icons.chevron_left, Icons.chevron_left, Icons.chevron_right, Icons.chevron_right]) {
        await t.tap(find.byIcon(icona).first);
        await t.pump(const Duration(milliseconds: 60));
      }
      await b.attendi(6000);
      await b.scatta('dopo_cambi_rapidi');

      b.passo('peso +/-');
      final pesoPrima = await t.runAsync(() => sql("SELECT weight FROM na_users WHERE email='$email'"));
      // Il + del peso, non quello della barra in basso: sta nella riga del -.
      final rigaPeso = find.ancestor(of: find.byIcon(Icons.remove), matching: find.byType(Row)).first;
      final piu = find.descendant(of: rigaPeso, matching: find.byIcon(Icons.add));
      await b.tocca(piu, attesa: 2500);
      await b.tocca(piu, attesa: 2500);
      await b.tocca(find.byIcon(Icons.remove), attesa: 2500);
      await b.scatta('peso');
      final pesoDopo = await t.runAsync(() => sql("SELECT CONCAT(weight,' / obiettivi: ',calorie_goal,'/',carb_goal,'/',target_weight) FROM na_users WHERE email='$email'"));
      b.diario.writeln('PESO prima $pesoPrima, dopo $pesoDopo');
    });
  }, skip: senzaServer);
}
