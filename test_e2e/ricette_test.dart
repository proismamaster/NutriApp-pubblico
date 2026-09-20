// Ricette: nuova ricetta con ingredienti da ricerca e generico, salvataggio,
// dettaglio, preferito, modifica, condivisione con categorie, aggiunta al
// diario, eliminazione.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/dictionary/translations.dart';

import 'banco.dart';

const email = 'giulia.e2e@prova.it';

void main() {
  setUpAll(preparaBanco);

  testWidgets('ricette', (t) async {
    await t.runAsync(() => sql("DELETE FROM na_recipe_ingredients WHERE recipe_id IN (SELECT id FROM na_recipes WHERE user_mail='$email'); DELETE FROM na_recipes WHERE user_mail='$email';"));
    final b = Banco(t, 'ric');
    await b.giro(() async {
      await b.avvia(preferenze: {'app_language': 'Italiano', 'user_email': email});
      await b.attendi(2500);
      b.passo('ricette -> nuova');
      await b.tocca(find.byIcon(Icons.bookmark), attesa: 2500);
      await b.tocca(find.byType(FloatingActionButton), attesa: 2000);
      await b.scatta('nuova_vuota');

      b.passo('nome, porzioni, note');
      await b.scrivi(find.widgetWithText(TextField, 'Es. Zuppa di lenticchie'), 'Torta di mele della domenica');
      await b.scrivi(find.widgetWithText(TextField, 'Passaggi, tempi di cottura, note…'), 'Impastare, aggiungere le mele, 40 minuti a 180 gradi.');

      await b.scatta('nome_scritto');

      b.passo('ingrediente da ricerca');
      await b.tocca(find.text('Aggiungi').last, attesa: 2000);
      await b.scatta('cerca_ingrediente');
      await b.scrivi(find.widgetWithText(TextField, 'Cerca alimento...'), 'mela');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await b.aspettaTesto('Mela cotogna', secondi: 20);
      await b.tocca(find.text('Mela cotogna'), attesa: 2000);
      await b.scatta('ingrediente_scheda');
      await b.scrivi(find.byType(TextField).last, '300');
      await b.tocca(find.text('CONFERMA'), attesa: 2000);
      await b.scatta('dopo_ingrediente');

      b.passo('ingrediente generico');
      await b.tocca(find.text('Generico'), attesa: 1200);
      await b.scatta('generico');
      await b.scrivi(find.widgetWithText(TextField, 'Es. Verdura mista'), 'Farina 00');
      await b.scrivi(find.widgetWithText(TextField, 'Es. q.b., 2 cucchiai, un mazzetto'), '250 g');
      await b.tocca(find.text('Stimo io i valori'), attesa: 600);
      await b.scatta('generico_stima');
      // Campi della stima: calorie e carboidrati (in grammi per l'ingrediente intero).
      final campiStima = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
      if (campiStima.evaluate().length >= 4) {
        await b.scrivi(campiStima.at(2), '870');
        await b.scrivi(campiStima.at(3), '180');
      }
      await b.tocca(find.descendant(of: find.byType(BottomSheet), matching: find.text('Aggiungi')).last, attesa: 1500);
      await b.scatta('dopo_generico');

      b.passo('porzioni 8 e salva');
      for (var i = 0; i < 7; i++) {
        await t.tap(find.byIcon(Icons.add).first);
        await t.pump(const Duration(milliseconds: 100));
      }
      await b.scatta('prima_di_salvare');
      await b.tocca(find.text('Salva').last, attesa: 3000);
      await b.scatta('dopo_salva');
      b.diario.writeln('RICETTA: ${await t.runAsync(() => sql("SELECT CONCAT_WS('|',recipe_name,`portion`,LEFT(notes,20),shared_status,is_favorite) FROM na_recipes WHERE user_mail='$email'"))}');
      String tr(String k) => Translations.get('Italiano', k);
      Future<String> stato() async => (await t.runAsync(() => sql("SELECT CONCAT_WS('|',recipe_name,`portion`,shared_status,is_favorite,IFNULL(meal_types,''),IFNULL(course,'')) FROM na_recipes WHERE user_mail='$email'")))!;

      b.passo('dettaglio');
      await b.tocca(find.text('Torta di mele della domenica'), attesa: 2500);
      await b.scatta('dettaglio');
      await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await b.attendi(400);
      await b.scatta('dettaglio_giu');
      await b.indietro();
      await b.attendi(1500);

      b.passo('preferito');
      await b.tocca(find.byIcon(Icons.star_border_rounded), attesa: 2000);
      b.diario.writeln('dopo stella: ${await stato()}');
      await b.tocca(find.text('Preferiti').first, attesa: 1500);
      await b.scatta('preferiti');
      await b.tocca(find.text('Tutti').first, attesa: 1500);

      b.passo('condividi: senza categorie poi con');
      await b.tocca(find.byIcon(Icons.public_off), attesa: 1500);
      await b.scatta('categorie');
      await b.tocca(find.text(tr('share_categories_send')), attesa: 1000);
      await b.scatta('categorie_mancanti');
      await b.tocca(find.text(tr('meal_pranzo')).first, attesa: 300);
      await b.tocca(find.text(tr('meal_cena')).first, attesa: 300);
      await b.tocca(find.text(tr('course_dolce')).first, attesa: 300);
      await b.tocca(find.text(tr('share_categories_send')), attesa: 2500);
      await b.scatta('dopo_proposta');
      b.diario.writeln('dopo proposta: ${await stato()}');

      b.passo('modifica: nome');
      await b.tocca(find.byIcon(Icons.edit_outlined), attesa: 2500);
      await b.scatta('modifica');
      await b.scrivi(find.widgetWithText(TextField, 'Es. Zuppa di lenticchie'), 'Torta di mele della nonna');
      await b.viaSnackbar();
      await b.tocca(find.text('Salva').last, attesa: 3000);
      await b.scatta('dopo_modifica');
      b.diario.writeln('dopo modifica: ${await stato()}');
      expect((await stato()).split('|')[3], '1', reason: 'modificare la ricetta non deve togliere la stella');

      b.passo('aggiungi al diario da Aggiungi > Ricette Salvate');
      await b.tocca(find.byIcon(Icons.add).last, attesa: 2000);
      await b.tocca(find.byType(Tab).at(1), attesa: 2000);
      await b.scatta('ricette_salvate');
      await b.tocca(find.textContaining('Torta di mele').first, attesa: 2500);
      await b.scatta('ricetta_da_aggiungere');
      await b.tocca(find.text('Seleziona Pasto').evaluate().isNotEmpty ? find.text('Seleziona Pasto') : find.textContaining('pasto'), attesa: 800);
      await b.scatta('scegli_pasto_ricetta');
      await b.tocca(find.text('Snack').last, attesa: 600);
      // Due porzioni su otto: 999 / 8 * 2 = 250 kcal attese.
      final peso = find.byType(TextField).last;
      await b.scrivi(peso, '137');
      await b.scatta('ricetta_peso');
      await b.viaSnackbar();
      final aggiungi = find.textContaining('AGGIUNGI').evaluate().isNotEmpty ? find.textContaining('AGGIUNGI') : find.textContaining('Aggiungi al diario');
      await b.tocca(aggiungi.last, attesa: 3000);
      await b.scatta('dopo_aggiungi_ricetta');
      b.diario.writeln('DIARIO ricetta: ${await t.runAsync(() => sql("SELECT GROUP_CONCAT(CONCAT(meal_type,':',food_name,':',weight_g,':',calories)) FROM na_nutri_entries WHERE user_mail='$email' AND food_name LIKE 'Torta%'"))}');
      // 137 g di ricetta valgono la quota di calorie di quei grammi sul peso
      // totale: il generico con quantita' "250 g" DEVE stare nel peso, o le
      // calorie escono gonfiate (test di release 19/09).
      final atteso = await t.runAsync(() => sql(
          "SELECT ROUND(SUM(calories)*137/SUM(weight_g)) FROM na_recipe_ingredients WHERE recipe_id IN (SELECT id FROM na_recipes WHERE user_mail='$email')"));
      final messo = await t.runAsync(() => sql(
          "SELECT ROUND(calories) FROM na_nutri_entries WHERE user_mail='$email' AND food_name LIKE 'Torta%' ORDER BY id DESC LIMIT 1"));
      b.diario.writeln('kcal attese $atteso, messe $messo');
      expect(messo, atteso, reason: 'le calorie della porzione devono seguire il peso totale della ricetta');

      b.passo('elimina ricetta');
      await b.tocca(find.byIcon(Icons.bookmark), attesa: 2500);
      await b.tocca(find.byIcon(Icons.delete_outline).first, attesa: 1200);
      await b.scatta('conferma_elimina_ricetta');
      await b.tocca(find.text('Elimina').last, attesa: 3000);
      await b.scatta('dopo_elimina_ricetta');
      b.diario.writeln('dopo elimina: ${await stato()}');

      b.diario.writeln('INGREDIENTI: ${await t.runAsync(() => sql("SELECT GROUP_CONCAT(CONCAT(food_name,':',weight_g,':',calories)) FROM na_recipe_ingredients WHERE recipe_id IN (SELECT id FROM na_recipes WHERE user_mail='$email')"))}');
    });
  }, skip: senzaServer);
}
