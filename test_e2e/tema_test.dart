// Chiaro/scuro dalla barra in alto, anche dopo essere passati dalla pagina
// Aggiungi: non deve lasciare errori (19/09: ogni tocco ne produceva quattro,
// "_lifecycleState != _ElementLifecycle.defunct").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banco.dart';

const email = 'giulia.e2e@prova.it';

void main() {
  setUpAll(preparaBanco);

  testWidgets('tema scuro', (t) async {
    final b = Banco(t, 'tem');
    await b.giro(() async {
      await b.avvia(preferenze: {'app_language': 'Italiano', 'user_email': email});
      await b.aspettaTesto('Aggiungi un alimento:');

      b.passo('scuro e chiaro dalla Home');
      await b.tocca(find.byIcon(Icons.dark_mode_outlined), attesa: 1200);
      await b.scatta('scuro');
      await b.tocca(find.byIcon(Icons.light_mode_outlined), attesa: 1200);

      b.passo('dopo la pagina Aggiungi');
      await b.tocca(find.byIcon(Icons.add).last, attesa: 2000);
      await b.tocca(find.text('NutriApp').last, attesa: 1500);
      await b.tocca(find.byIcon(Icons.dark_mode_outlined), attesa: 1200);
      await b.scatta('scuro_dopo_aggiungi');
      await b.tocca(find.byIcon(Icons.light_mode_outlined), attesa: 1200);

      b.passo('dopo calendario e grafici');
      await b.tocca(find.byIcon(Icons.calendar_month), attesa: 2000);
      await b.tocca(find.byIcon(Icons.show_chart), attesa: 2500);
      await b.tocca(find.byIcon(Icons.dark_mode_outlined), attesa: 1500);
      await b.scatta('scuro_grafici');
      await b.tocca(find.byIcon(Icons.light_mode_outlined), attesa: 1200);
      expect(b.problemi, isEmpty, reason: 'il cambio di tema non deve lasciare errori');
    });
  }, skip: senzaServer);
}
