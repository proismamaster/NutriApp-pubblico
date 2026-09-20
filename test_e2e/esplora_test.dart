// Esplorazione: apre l'app senza accesso e fotografa la prima schermata in
// ogni lingua, chiaro e scuro, su telefono stretto e largo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'banco.dart';

void main() {
  setUpAll(preparaBanco);

  for (final lingua in ['Italiano', 'English', '简体中文', 'العربية']) {
    for (final scuro in [false, true]) {
      testWidgets('primo avvio $lingua ${scuro ? 'scuro' : 'chiaro'}', (t) async {
        final b = Banco(t, 'avvio_${lingua.hashCode.abs() % 1000}_${scuro ? 's' : 'c'}');
        await b.avvia(preferenze: {'app_language': lingua, 'app_dark_mode': scuro});
        await b.scatta('login');
        await b.chiudi();
      }, skip: senzaServer);
    }
  }

  testWidgets('primo avvio telefono piccolo', (t) async {
    final b = Banco(t, 'avvio_piccolo');
    await b.avvia(preferenze: {'app_language': 'Italiano'}, schermo: const Size(320, 568));
    await b.scatta('login');
    await b.chiudi();
  }, skip: senzaServer);
}
