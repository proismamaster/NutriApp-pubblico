// Schermi diversi: telefono piccolo, telefono comune, telefono grande e
// tablet. Stesso giro sulle schermate principali; il banco raccoglie da solo
// gli sforamenti di layout (RenderFlex overflowed) e i testi tagliati.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/dictionary/translations.dart';

import 'banco.dart';

const email = 'giulia.e2e@prova.it';

void main() {
  setUpAll(preparaBanco);

  for (final (larghezza, altezza, nome) in [
    (320.0, 568.0, 'piccolo'),
    (360.0, 640.0, 'comune'),
    (800.0, 1280.0, 'tablet'),
  ]) {
    testWidgets('schermo $nome', (t) async {
      final b = Banco(t, 'sch_$nome');
      String tr(String k) => Translations.get('Italiano', k);
      await b.giro(() async {
        await b.avvia(
          preferenze: {'app_language': 'Italiano', 'user_email': email},
          schermo: Size(larghezza, altezza),
        );
        await b.aspettaTesto('Aggiungi un alimento:', secondi: 15);
        await b.scatta('home');
        await t.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await b.attendi(400);
        await b.scatta('home_giu');

        b.passo('dettagli');
        await b.tocca(find.text(tr('home_details_link')), attesa: 2500);
        await b.scatta('dettaglio');
        await b.indietro();
        await b.attendi(1200);

        b.passo('aggiungi');
        await b.tocca(find.byIcon(Icons.add).last, attesa: 2000);
        await b.scatta('aggiungi');
        await b.indietro();
        await b.attendi(1000);

        b.passo('calendario');
        await b.tocca(find.byIcon(Icons.calendar_month), attesa: 2500);
        await b.scatta('calendario');

        b.passo('ricette');
        await b.tocca(find.byIcon(Icons.bookmark), attesa: 2500);
        await b.scatta('ricette');
        await b.tocca(find.text(tr('recipes_tab_public')), attesa: 2500);
        await b.scatta('consigliate');

        b.passo('grafici');
        await b.tocca(find.byIcon(Icons.show_chart), attesa: 2500);
        await b.scatta('grafici');

        b.passo('impostazioni');
        await b.tocca(find.byIcon(Icons.settings), attesa: 2000);
        await b.scatta('impostazioni');
        await b.tocca(find.text(tr('I miei obiettivi')), attesa: 2500);
        await b.scatta('obiettivi');
      });
    }, skip: senzaServer);
  }
}
