// Comunita': ricette consigliate (per te, piu' piaciute, piu' nuove), filtri,
// like dall'elenco e dal dettaglio (anche sulla propria), coerenza del cuore
// fra dettaglio ed elenco; poi "Le mie segnalazioni" con gli esiti decisi dal
// pannello (una accettata, una rifiutata con motivazione, ricetta approvata).
// Parte dai dati preparati a mano e dalle decisioni prese nel pannello.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/dictionary/translations.dart';

import 'banco.dart';

const email = 'giulia.e2e@prova.it';

void main() {
  setUpAll(preparaBanco);

  testWidgets('comunita e mie segnalazioni', (t) async {
    await t.runAsync(() => sql("DELETE FROM na_recipe_likes WHERE user_mail='$email'"));
    final b = Banco(t, 'com');
    String tr(String k) => Translations.get('Italiano', k);
    Future<String> likes() async => (await t.runAsync(() => sql(
        "SELECT IFNULL(GROUP_CONCAT(r.recipe_name ORDER BY r.recipe_name),'(nessuno)') FROM na_recipe_likes l JOIN na_recipes r ON r.id=l.recipe_id WHERE l.user_mail='$email'")))!;
    await b.giro(() async {
      await b.avvia(preferenze: {'app_language': 'Italiano', 'user_email': email});
      await b.aspettaTesto('Aggiungi un alimento:');

      b.passo('comunita dentro Aggiungi');
      // La scheda Ricette della pagina Aggiungi ha la sotto-scheda Comunita':
      // si registra un pasto con la ricetta di un altro senza cambiare pagina.
      await b.tocca(find.byIcon(Icons.add).last, attesa: 2000);
      await b.tocca(find.text(tr('recipes_tab_title')), attesa: 2500);
      await b.scatta('aggiungi_ricette');
      await b.tocca(find.text(tr('recipes_tab_public')).last, attesa: 3000);
      await b.scatta('aggiungi_comunita');
      b.diario.writeln('ricetta pubblica dentro Aggiungi: ${b.vede('Pasta e ceci')}');
      await b.indietro();
      await b.attendi(1200);

      b.passo('consigliate: per te');
      await b.tocca(find.byIcon(Icons.bookmark), attesa: 2500);
      await b.tocca(find.text(tr('recipes_tab_public')), attesa: 3000);
      await b.scatta('per_te');

      b.passo('like dall elenco');
      await b.tocca(find.byIcon(Icons.favorite_border).first, attesa: 2000);
      await b.scatta('like_elenco');
      b.diario.writeln('LIKE dopo il primo: ${await likes()}');

      b.passo('piu piaciute e piu nuove');
      await b.tocca(find.text(tr('public_mode_liked')), attesa: 2500);
      await b.scatta('piaciute');
      await b.tocca(find.text(tr('public_mode_new')), attesa: 2500);
      await b.scatta('nuove');

      b.passo('filtri');
      await b.tocca(find.textContaining(tr('public_filters')).first, attesa: 1500);
      await b.scatta('filtri');
      final dolce = find.text(tr('course_dolce'));
      if (dolce.evaluate().isNotEmpty) await b.tocca(dolce.first, attesa: 400);
      await b.tocca(find.text(tr('public_filters_apply')).last, attesa: 2500);
      await b.scatta('filtro_dolce');
      await b.tocca(find.textContaining(tr('public_filters')).first, attesa: 1500);
      await b.tocca(find.text(tr('public_filters_clear')).last, attesa: 1200);
      b.diario.writeln('foglio filtri ancora aperto dopo Azzera: ${b.vede(tr('public_filters_apply'))}');
      if (b.vede(tr('public_filters_apply'))) await b.tocca(find.text(tr('public_filters_apply')).last, attesa: 2500);
      await b.scatta('filtri_azzerati');

      b.passo('dettaglio pubblico e like');
      await t.scrollUntilVisible(find.text('Pasta e ceci'), 300,
          scrollable: find.byType(Scrollable).last, maxScrolls: 20);
      await b.tocca(find.text('Pasta e ceci').first, attesa: 2500);
      await b.scatta('dettaglio_pubblico');
      await b.tocca(find.byIcon(Icons.favorite_border).first, attesa: 2000);
      await b.scatta('dettaglio_like');
      await b.indietro();
      await b.attendi(1500);
      await b.scatta('elenco_dopo_dettaglio');
      b.diario.writeln('LIKE dopo il dettaglio: ${await likes()}');

      b.passo('segnala una ricetta di un altro');
      // 21/09: dall'app arrivava "Errore del server". Qui si controlla il
      // giro intero, endpoint compreso, e che la riga finisca nel database.
      await t.scrollUntilVisible(find.text('Pasta e ceci'), 300,
          scrollable: find.byType(Scrollable).last, maxScrolls: 20);
      await b.tocca(find.text('Pasta e ceci').first, attesa: 2500);
      await b.tocca(find.byIcon(Icons.outlined_flag).first, attesa: 1500);
      await b.scatta('segnala_ricetta');
      await b.tocca(find.text(tr('report_recipe_issue_valori')), attesa: 600);
      await b.scrivi(find.byType(TextField).last, 'Le calorie non tornano (prova E2E)');
      await b.viaSnackbar();
      await b.tocca(find.text(tr('report_send')).last, attesa: 3000);
      await b.scatta('segnalazione_ricetta_inviata');
      b.diario.writeln('SEGNALAZIONE RICETTA: ${await t.runAsync(() => sql("SELECT IFNULL(GROUP_CONCAT(CONCAT_WS('|',recipe_name,issue,status)),'(nessuna)') FROM na_recipe_reports WHERE user_mail='$email'"))}');
      await b.indietro();
      await b.attendi(1500);

      b.passo('la propria ricetta');
      for (var giro = 0; giro < 6 && !b.vede('Torta di mele della nonna'); giro++) {
        await t.drag(find.byType(Scrollable).last, const Offset(0, 400));
        await b.attendi(400);
      }
      await b.scatta('mia_in_elenco');
      b.diario.writeln('"La tua ricetta" visibile: ${b.vedeParte(tr('public_recipe_yours'))}');

      b.passo('togli like dal dettaglio');
      await t.scrollUntilVisible(find.text('Pasta e ceci'), 300,
          scrollable: find.byType(Scrollable).last, maxScrolls: 20);
      await b.tocca(find.text('Pasta e ceci').first, attesa: 2500);
      await b.tocca(find.byIcon(Icons.favorite).first, attesa: 2000);
      await b.indietro();
      await b.attendi(1500);
      b.diario.writeln('LIKE dopo averne tolto uno: ${await likes()}');

      b.passo('le mie segnalazioni');
      await b.tocca(find.byIcon(Icons.settings), attesa: 1500);
      await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await b.attendi(300);
      await b.tocca(find.text(tr('my_reports_title')), attesa: 3000);
      await b.scatta('mie_segnalazioni');
      // Le schede si prendono per posizione: i titoli veri ("Dati alimento",
      // "Ricette pubbliche") non sono le chiavi my_reports_tab_*.
      await b.tocca(find.byType(Tab).at(1), attesa: 1500);
      await b.scatta('mie_ricette_pubbliche');
      await b.tocca(find.byType(Tab).at(0), attesa: 1500);
      final rifiutata = find.textContaining('Mela cotogna');
      if (rifiutata.evaluate().isNotEmpty) {
        await b.tocca(rifiutata.first, attesa: 1500);
        await b.scatta('segnalazione_aperta');
      }
    });
  }, skip: senzaServer);
}
