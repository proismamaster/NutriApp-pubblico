// Una giornata d'uso: accesso gia' fatto, si aggiungono alimenti ai pasti in
// tutti i modi (ricerca prodotti, alimenti generici, inserimento manuale),
// si modificano, si eliminano, si cambia giorno e si controllano i totali.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banco.dart';

const email = 'giulia.e2e@prova.it';

Future<String> vociDiOggi(WidgetTester t) async => (await t.runAsync(() => sql(
        "SELECT GROUP_CONCAT(CONCAT(meal_type,':',food_name,':',ROUND(weight_g),'g:',ROUND(calories),'kcal') SEPARATOR ' | ') "
        "FROM na_nutri_entries WHERE user_mail='$email' AND DATE(entry_date)=CURDATE()")))!;

void main() {
  setUpAll(preparaBanco);

  testWidgets('giornata', (t) async {
    await t.runAsync(() => sql("DELETE FROM na_nutri_entries WHERE user_mail='$email'"));
    final b = Banco(t, 'gio');
    await b.giro(() async {
      await b.avvia(preferenze: {'app_language': 'Italiano', 'user_email': email});
      await b.aspettaTesto('Aggiungi un alimento:');
      await b.scatta('home');

      b.passo('colazione: cerca prodotto');
      await b.tocca(find.byIcon(Icons.add).first);
      await b.scrivi(find.widgetWithText(TextField, 'Cerca alimento...'), 'pickle');
      await t.testTextInput.receiveAction(TextInputAction.search);
      final t0 = DateTime.now();
      await b.aspettaTesto('Pickle', parziale: true, secondi: 20);
      b.diario.writeln('risultati dopo ${DateTime.now().difference(t0).inMilliseconds} ms');
      await b.scatta('risultati_pickle');
      await b.tocca(find.textContaining('Pickle').first, attesa: 2000);
      await b.scatta('prodotto');

      b.passo('colazione: 150 g e aggiungi');
      await b.scrivi(find.byType(TextField).last, '150');
      await b.scatta('prodotto_150');
      await b.tocca(find.textContaining('AGGIUNGI'), attesa: 2500);
      await b.scatta('dopo_aggiungi');
      await b.attendi(4000);
      await b.scatta('dopo_aggiungi_4s');
      b.diario.writeln('DB: ${await vociDiOggi(t)}');

      b.passo('pranzo: alimento generico CREA');
      if (!b.vede('Aggiungi un alimento:')) await b.indietro();
      await b.aspettaTesto('Aggiungi un alimento:');
      await b.tocca(find.byIcon(Icons.add).at(1));
      await b.scrivi(find.widgetWithText(TextField, 'Cerca alimento...'), 'mela');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await b.aspettaTesto('MELA', parziale: true, secondi: 20);
      await b.scatta('risultati_mela');
      await b.tocca(find.textContaining('MELA').first, attesa: 2000);
      await b.scatta('mela');
      await b.tocca(find.textContaining('AGGIUNGI'), attesa: 2500);
      b.diario.writeln('DB: ${await vociDiOggi(t)}');
      if (!b.vede('Aggiungi un alimento:')) await b.indietro();
      await b.aspettaTesto('Aggiungi un alimento:');
      await b.scatta('home_2_voci');
      await b.attendi(4000);
      await b.scatta('home_2_voci_4s');

      b.passo('cena: inserimento manuale');
      await b.tocca(find.byIcon(Icons.add).at(2));
      await b.tocca(find.text('Registralo te!'), attesa: 1500);
      await b.scatta('manuale_vuoto');
      await b.tocca(find.textContaining('AGGIUNGI'), attesa: 800);
      await b.scatta('manuale_salva_vuoto');
      await t.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await b.attendi(300);
      await b.scatta('manuale_errore_in_cima');

      b.passo('cena: compila');
      await b.scrivi(find.widgetWithText(TextField, 'Nome prodotto'), 'Pasta al pomodoro della nonna Rosa con basilico fresco e parmigiano');
      await b.scrivi(find.widgetWithText(TextField, 'Calorie'), '160');
      await b.scrivi(find.widgetWithText(TextField, 'Carboidrati'), '28');
      await b.scrivi(find.widgetWithText(TextField, 'Proteine'), '6');
      await b.scrivi(find.widgetWithText(TextField, 'Grassi'), '3,5');
      await b.scrivi(find.widgetWithText(TextField, 'Peso'), '250');
      await b.scatta('manuale_pieno');
      await b.tocca(find.textContaining('AGGIUNGI'), attesa: 2500);
      await b.attendi(3000);
      await b.scatta('home_3_voci');
      b.diario.writeln('DB: ${await vociDiOggi(t)}');
      b.diario.writeln('libreria: ${await t.runAsync(() => sql("SELECT GROUP_CONCAT(CONCAT(food_name,':',base_weight_g,':',calories)) FROM na_custom_foods WHERE user_mail='$email'"))}');
    });
  }, skip: senzaServer);
}
