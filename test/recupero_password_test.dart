// Recupero password in tre passi (2026-09-14).
//
// PERCHE' ESISTE: il dialogo di prima rispondeva "Email non trovata o codice
// errato" a qualunque errore, compreso un server senza reset_password.php.
// Questi test fanno girare la SCHERMATA VERA con un server finto e controllano
// che ogni risposta porti al suo messaggio e al passo giusto.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutriapp/dictionary/translations.dart';
import 'package:nutriapp/screens/recupero_password_page.dart';
import 'package:nutriapp/theme_nutri.dart';

// Con le preferenze vuote l'app parte in inglese (locale_provider.dart).
const _lingua = 'English';
String _t(String chiave) => Translations.get(_lingua, chiave);

class _ServerFinto {
  final inviati = <String>[];
  final cambi = <List<String>>[];
  Map<String, dynamic> rispostaInvio = {'status': 'success', 'message': 'Codice inviato'};
  Map<String, dynamic> rispostaCambio = {'status': 'success', 'code': 'ok'};

  Future<Map<String, dynamic>> invia(String email) async {
    inviati.add(email);
    return rispostaInvio;
  }

  Future<Map<String, dynamic>> controlla(String email, String codice) async => codice == '123456'
      ? {'status': 'success', 'code': 'ok'}
      : {'status': 'error', 'code': 'wrong_code', 'remaining': 4};

  Future<Map<String, dynamic>> cambia(String email, String codice, String password) async {
    cambi.add([email, codice, password]);
    return rispostaCambio;
  }
}

Future<void> _apri(WidgetTester tester, _ServerFinto server) async {
  tester.view.physicalSize = const Size(412 * 2, 900 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: temaNutri(Brightness.light),
        debugShowCheckedModeBanner: false,
        home: RecuperoPasswordPage(
          inviaCodice: server.invia,
          controllaCodice: server.controlla,
          cambiaPassword: server.cambia,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _scrivi(WidgetTester tester, String chiave, String testo) async {
  await tester.enterText(
    find.descendant(of: find.byKey(Key(chiave)), matching: find.byType(TextField)),
    testo,
  );
  await tester.pump();
}

/// Tocca un pulsante e lascia finire la chiamata finta. Niente pumpAndSettle:
/// il conto alla rovescia per rimandare il codice ridisegna ogni secondo.
Future<void> _premi(WidgetTester tester, String etichetta) async {
  await tester.tap(find.text(etichetta));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _finoAlCodice(WidgetTester tester) async {
  await _scrivi(tester, 'recupero_email', 'io@prova.test');
  await _premi(tester, _t('recovery_send_code'));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('percorso completo: email, codice sbagliato e poi giusto, password nuova', (tester) async {
    final server = _ServerFinto();
    await _apri(tester, server);

    await _finoAlCodice(tester);
    expect(server.inviati, ['io@prova.test']);
    expect(find.textContaining('io@prova.test'), findsOneWidget,
        reason: 'il passo 2 dice a quale indirizzo e\' andato il codice');

    await _scrivi(tester, 'recupero_codice', '000000');
    await _premi(tester, _t('recovery_verify'));
    expect(find.text(_t('recovery_wrong_code').replaceAll('{n}', '4')), findsOneWidget,
        reason: 'codice sbagliato, con i tentativi rimasti');

    // Incollato dalla mail con uno spazio in mezzo: deve valere lo stesso.
    await _scrivi(tester, 'recupero_codice', '123 456');
    await _premi(tester, _t('recovery_verify'));
    expect(find.text(_t('recovery_password_title')), findsOneWidget);

    await _scrivi(tester, 'recupero_password', 'corta');
    expect(find.text(_t('recovery_password_short')), findsOneWidget);
    await _premi(tester, _t('recovery_save'));
    expect(server.cambi, isEmpty, reason: 'con la password corta non si chiama il server');

    await _scrivi(tester, 'recupero_password', 'unapasswordlunga');
    await _scrivi(tester, 'recupero_conferma', 'unapasswordlungA');
    expect(find.text(_t('recovery_password_mismatch')), findsOneWidget);

    await _scrivi(tester, 'recupero_conferma', 'unapasswordlunga');
    await _premi(tester, _t('recovery_save'));
    expect(server.cambi, [
      ['io@prova.test', '123456', 'unapasswordlunga'],
    ]);
    expect(find.text(_t('recovery_done_title')), findsOneWidget);
  });

  testWidgets('codice scaduto al momento di salvare: si torna al passo del codice, col motivo', (tester) async {
    final server = _ServerFinto()..rispostaCambio = {'status': 'error', 'code': 'expired'};
    await _apri(tester, server);

    await _finoAlCodice(tester);
    await _scrivi(tester, 'recupero_codice', '123456');
    await _premi(tester, _t('recovery_verify'));
    await _scrivi(tester, 'recupero_password', 'unapasswordlunga');
    await _scrivi(tester, 'recupero_conferma', 'unapasswordlunga');
    await _premi(tester, _t('recovery_save'));

    expect(find.text(_t('recovery_expired')), findsOneWidget);
    expect(find.text(_t('recovery_verify')), findsOneWidget, reason: 'di nuovo al passo 2');
  });

  testWidgets('mail non partita: messaggio chiaro e, sotto, il motivo del server', (tester) async {
    final server = _ServerFinto()
      ..rispostaInvio = {
        'status': 'error',
        'message': 'Chiave Brevo non configurata sul server',
      };
    await _apri(tester, server);

    await _finoAlCodice(tester);

    expect(find.text(_t('recovery_send_failed')), findsOneWidget);
    expect(find.textContaining('Chiave Brevo'), findsOneWidget);
    expect(find.text(_t('recovery_send_code')), findsOneWidget, reason: 'resta al passo 1');
  });

  testWidgets('la freccia indietro dal passo 2 torna all\'email, non chiude il recupero', (tester) async {
    final server = _ServerFinto();
    await _apri(tester, server);

    await _finoAlCodice(tester);
    expect(find.text(_t('recovery_verify')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(find.text(_t('recovery_email_title')), findsOneWidget);
    expect(find.text(_t('recovery_send_code')), findsOneWidget);
  });
}
