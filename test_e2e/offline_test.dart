// Server irraggiungibile: cosa vede chi apre l'app senza rete. Si lancia con
// NUTRI_API su una porta chiusa:
//   flutter test test_e2e/offline_test.dart --dart-define=NUTRI_API=http://127.0.0.1:8799/
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/dictionary/translations.dart';

import 'banco.dart';

const email = 'giulia.e2e@prova.it';

void main() {
  setUpAll(preparaBanco);

  testWidgets('senza server', (t) async {
    // Il profilo che un accesso riuscito avrebbe lasciato in memoria: lo si
    // prende dal server vero (porta 8790), che qui resta acceso.
    final profilo = (await t.runAsync(() async {
      // Serve una sessione vera: dal 20/09 il profilo si scarica solo con il
      // gettone.
      final token = List.generate(64, (i) => '0123456789abcdef'[i % 16]).join();
      await sql("INSERT IGNORE INTO na_sessions (token, user_mail) VALUES ('$token','$email')");
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:8790/get_user_data.php?email=$email'));
      req.headers.set('X-Auth-Token', token);
      final resp = await req.close();
      final corpo = await resp.transform(utf8.decoder).join();
      return jsonEncode(jsonDecode(corpo)['data']);
    }))!;
    final b = Banco(t, 'off');
    String tr(String k) => Translations.get('Italiano', k);
    await b.giro(() async {
      await b.avvia(preferenze: {
        'app_language': 'Italiano',
        'user_email': email,
        // Come dopo un accesso riuscito: l'ultimo profilo scaricato.
        'profilo_in_cache': profilo,
      });
      await b.attendi(6000);
      await b.scatta('home');
      // Senza server si resta dentro con l'ultimo profilo salvato.
      expect(find.textContaining('Aggiungi un alimento'), findsOneWidget,
          reason: "senza rete l'app non deve tornare alla pagina di accesso");

      b.passo('dettagli');
      final dettagli = find.text(tr('home_details_link'));
      if (dettagli.evaluate().isNotEmpty) {
        await b.tocca(dettagli, attesa: 4000);
        await b.scatta('dettaglio');
        await b.indietro();
        await b.attendi(1500);
      }

      b.passo('ricerca');
      await b.tocca(find.byIcon(Icons.add).last, attesa: 2500);
      await b.scrivi(find.byType(TextField).first, 'mela');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await b.attendi(6000);
      await b.scatta('ricerca');
      await b.indietro();
      await b.attendi(1200);

      b.passo('calendario e grafici');
      await b.tocca(find.byIcon(Icons.calendar_month), attesa: 4000);
      await b.scatta('calendario');
      await b.tocca(find.byIcon(Icons.show_chart), attesa: 4000);
      await b.scatta('grafici');
      await b.tocca(find.byIcon(Icons.bookmark), attesa: 4000);
      await b.scatta('ricette');

      b.passo('peso dalla Home');
      await b.tocca(find.text('NutriApp').last, attesa: 2000);
      final piu = find.byIcon(Icons.add).first;
      await b.tocca(piu, attesa: 3000);
      await b.scatta('peso');
    });
  }, skip: !serverLocale.startsWith('http://127.0.0.1'));
}
