// Alimenti salvati: elenco, aggiunta al diario dalla libreria, modifica
// (nome, peso di riferimento, calorie) e controllo nel DB, eliminazione con
// annulla e conferma.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/dictionary/translations.dart';

import 'banco.dart';

const email = 'giulia.e2e@prova.it';

/// L'icona sulla stessa riga del testo: quella con il centro piu' vicino in verticale.
Finder iconaSullaRiga(WidgetTester t, String testo, IconData icona) {
  final y = t.getCenter(find.text(testo)).dy;
  final tutte = find.byIcon(icona).evaluate().toList();
  double dy(Element e) => ((e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy - y).abs();
  tutte.sort((a, b) => dy(a).compareTo(dy(b)));
  return find.byElementPredicate((e) => identical(e, tutte.first));
}

void main() {
  setUpAll(preparaBanco);

  testWidgets('libreria', (t) async {
    await t.runAsync(() => sql("""
      DELETE FROM na_custom_foods WHERE user_mail='$email' AND food_name LIKE 'Yogurt prova%';
      INSERT INTO na_custom_foods (user_mail, food_name, base_weight_g, calories, carbs, proteins, fats, fibers, sugars)
      VALUES ('$email','Yogurt prova greco',150,146,6,15,7,0,6);"""));
    final b = Banco(t, 'lib');
    String tr(String k) => Translations.get('Italiano', k);
    Future<String> db(String q) async => (await t.runAsync(() => sql(q)))!;
    Future<String> yogurt() => db("SELECT IFNULL(GROUP_CONCAT(CONCAT_WS('|',food_name,base_weight_g,calories,proteins)),'(nessuno)') FROM na_custom_foods WHERE user_mail='$email' AND food_name LIKE 'Yogurt%'");
    await b.giro(() async {
      await b.avvia(preferenze: {'app_language': 'Italiano', 'user_email': email});
      await b.aspettaTesto('Aggiungi un alimento:');

      b.passo('alimenti salvati');
      await b.tocca(find.byIcon(Icons.add).last, attesa: 2000);
      await b.tocca(find.text(tr('search_saved_foods')), attesa: 2500);
      await b.scatta('salvati');

      b.passo('aggiungi dalla libreria');
      await b.tocca(find.text('Yogurt prova greco'), attesa: 2500);
      await b.scatta('scheda_libreria');
      await b.tocca(find.text(tr('meal_pick_hint')), attesa: 800);
      await b.tocca(find.text(tr('Colazione')).last, attesa: 600);
      await b.viaSnackbar();
      await b.tocca(find.textContaining('AGGIUNGI').last, attesa: 3000);
      b.diario.writeln('DIARIO: ${await db("SELECT IFNULL(GROUP_CONCAT(CONCAT(meal_type,':',food_name,':',ROUND(weight_g),'g:',ROUND(calories))),'(nessuna)') FROM na_nutri_entries WHERE user_mail='$email' AND food_name LIKE 'Yogurt%'")}');
      await b.scatta('dopo_aggiunta');

      b.passo('modifica');
      await b.tocca(find.byIcon(Icons.add).last, attesa: 2000);
      await b.tocca(find.text(tr('search_saved_foods')), attesa: 2500);
      await b.tocca(iconaSullaRiga(t, 'Yogurt prova greco', Icons.edit_note), attesa: 2500);
      await b.scatta('modifica');
      await b.scrivi(find.widgetWithText(TextField, 'Yogurt prova greco'), 'Yogurt prova greco 0%');
      await b.scatta('modifica_nome');
      await b.viaSnackbar();
      final salva = find.textContaining(RegExp('SALVA|Salva'));
      await b.tocca(salva.last, attesa: 3000);
      await b.scatta('dopo_modifica');
      b.diario.writeln('DOPO MODIFICA: ${await yogurt()}');

      b.passo('elimina: annulla poi conferma');
      if (!b.vede('Yogurt prova greco 0%')) {
        await b.tocca(find.text(tr('search_saved_foods')), attesa: 2000);
      }
      final cestino = iconaSullaRiga(t, 'Yogurt prova greco 0%', Icons.delete_outline);
      await b.tocca(cestino, attesa: 1200);
      await b.scatta('conferma_elimina');
      await b.tocca(find.text(tr('Annulla')).last, attesa: 800);
      b.diario.writeln('DOPO ANNULLA: ${await yogurt()}');
      await b.tocca(iconaSullaRiga(t, 'Yogurt prova greco 0%', Icons.delete_outline), attesa: 1200);
      await b.tocca(find.text(tr('Elimina')).last, attesa: 2500);
      await b.scatta('dopo_elimina');
      b.diario.writeln('DOPO ELIMINA: ${await yogurt()}');
    });
  }, skip: senzaServer);
}
