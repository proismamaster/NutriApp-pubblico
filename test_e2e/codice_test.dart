// Codice a barre dalla Home: prodotto trovato e aggiunto, codice sconosciuto
// registrato a mano (con codice gia' compilato), scansione annullata, permesso
// della fotocamera negato.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/dictionary/translations.dart';

import 'banco.dart';

const email = 'giulia.e2e@prova.it';

void main() {
  setUpAll(preparaBanco);

  testWidgets('codice a barre', (t) async {
    await t.runAsync(() => sql("DELETE FROM na_nutri_entries WHERE user_mail='$email' AND DATE(entry_date)=CURDATE(); DELETE FROM na_custom_foods WHERE user_mail='$email' AND barcode='8000000000017';"));
    final b = Banco(t, 'cod');
    String tr(String k) => Translations.get('Italiano', k);
    Future<String> db(String q) async => (await t.runAsync(() => sql(q)))!;
    final scansiona = find.text(tr('home_scan_barcode'));
    await b.giro(() async {
      await b.avvia(preferenze: {'app_language': 'Italiano', 'user_email': email});
      await b.aspettaTesto('Aggiungi un alimento:');

      b.passo('prodotto trovato');
      b.codiceFinto = '0041190710751';
      await b.tocca(scansiona, attesa: 3000);
      await b.scatta('trovato');
      await b.tocca(find.text(tr('Scegli il pasto')), attesa: 800);
      await b.tocca(find.text(tr('Pranzo')).last, attesa: 600);
      await b.viaSnackbar();
      await b.tocca(find.textContaining('AGGIUNGI').last, attesa: 3000);
      await b.scatta('dopo_aggiunta');
      b.diario.writeln('OGGI: ${await db("SELECT IFNULL(GROUP_CONCAT(CONCAT(meal_type,':',food_name,':',ROUND(weight_g),'g:',ROUND(calories))),'(nessuna)') FROM na_nutri_entries WHERE user_mail='$email' AND DATE(entry_date)=CURDATE()")}');

      b.passo('codice sconosciuto');
      b.codiceFinto = '8000000000017';
      await b.tocca(scansiona, attesa: 3000);
      await b.scatta('sconosciuto');
      await b.tocca(find.text(tr('Registralo te!')).last, attesa: 2000);
      await b.scatta('manuale_con_codice');
      b.diario.writeln('codice compilato: ${b.vedeParte('8000000000017')}');

      b.passo('annullata');
      await b.indietro();
      await b.attendi(1200);
      b.codiceFinto = null;
      await b.tocca(scansiona, attesa: 1500);
      await b.scatta('annullata');

      b.passo('permesso negato');
      b.codiceFinto = 'NEGATO';
      await b.tocca(scansiona, attesa: 1500);
      await b.scatta('permesso_negato');
    });
  }, skip: senzaServer);
}
