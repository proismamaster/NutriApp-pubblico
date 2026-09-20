// Accesso: campi vuoti, email inesistente, password sbagliata, privacy non
// accettata, accesso giusto; recupero password con codice sbagliato e giusto,
// poi accesso con la password nuova; sessione che resta dopo il riavvio.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/dictionary/translations.dart';
import 'package:nutriapp/widgets/auth_style.dart';

import 'banco.dart';

const email = 'giulia.e2e@prova.it';

/// I campi della pagina in primo piano: sotto resta quella di accesso, con
/// campi uguali, e prenderli per indice globale pescava quelli sbagliati.
Finder campiInCima() => find.descendant(
      of: find.byType(Scaffold).last,
      matching: find.byType(TextField),
    );

Future<void> accettaPrivacy(Banco b) async {
  if (b.t.widget<NutriPrivacyCheck>(find.byType(NutriPrivacyCheck)).value) return;
  final r = b.t.getRect(find.byType(NutriPrivacyCheck));
  await b.t.tapAt(r.centerLeft + const Offset(10, 0));
  await b.attendi(300);
}

void main() {
  setUpAll(preparaBanco);

  testWidgets('accesso', (t) async {
    final b = Banco(t, 'acc');
    String tr(String k) => Translations.get('Italiano', k);
    await b.giro(() async {
      await b.avvia(preferenze: {'app_language': 'Italiano'});

      b.passo('vuoto');
      await b.scatta('login');
      await b.tocca(find.text('Accedi').last, attesa: 800);
      await b.scatta('accedi_vuoto');

      b.passo('email inesistente');
      await b.scrivi(find.widgetWithText(TextField, 'you@example.com'), 'nessuno@prova.it');
      await b.scrivi(find.widgetWithText(TextField, 'Password'), 'Password123!');
      await accettaPrivacy(b);
      await b.tocca(find.text('Accedi').last, attesa: 2500);
      await b.scatta('email_inesistente');

      b.passo('password sbagliata');
      await b.scrivi(find.byType(TextField).at(0), email);
      await b.scrivi(find.byType(TextField).at(1), 'sbagliata99');
      await b.viaSnackbar();
      await b.tocca(find.text('Accedi').last, attesa: 2500);
      await b.scatta('password_sbagliata');

      b.passo('recupero password');
      await b.viaSnackbar();
      await b.tocca(find.text('Password dimenticata?'), attesa: 1500);
      // Per chiave: la pagina di accesso resta sotto, con campi uguali.
      await b.scrivi(campiInCima().first, email);
      await b.scatta('recupero_email');
      // Per nome del pulsante: in questa pagina ce n'e' piu' d'uno per passo
      // ("Cambia email" accanto a "Verifica il codice").
      await b.tocca(find.text(tr('recovery_send_code')), attesa: 2500);
      await b.scatta('recupero_codice');
      await b.scrivi(campiInCima().first, '000000');
      await b.tocca(find.text(tr('recovery_verify')), attesa: 2000);
      await b.scatta('recupero_codice_sbagliato');
      final codice = await t.runAsync(() => sql("SELECT code FROM na_otp_codes WHERE email='$email' ORDER BY id DESC LIMIT 1"));
      await b.scrivi(campiInCima().first, codice ?? '');
      await b.tocca(find.text(tr('recovery_verify')), attesa: 2500);
      await b.scatta('recupero_password');
      await b.scrivi(campiInCima().first, 'NuovaPass2026!');
      if (campiInCima().evaluate().length > 1) {
        await b.scrivi(campiInCima().at(1), 'NuovaPass2026!');
      }
      await b.tocca(find.text(tr('recovery_save')), attesa: 2500);
      await b.scatta('recupero_fatto');
      final torna = find.byType(NutriPrimaryButton);
      if (torna.evaluate().isNotEmpty) await b.tocca(torna.last, attesa: 1500);

      b.passo('accesso con la nuova');
      // Si torna alla pagina di accesso: due campi, email e password.
      for (var giro = 0; giro < 4 && find.byType(TextField).evaluate().length < 2; giro++) {
        await b.indietro();
        await b.attendi(1200);
      }
      await b.scrivi(find.byType(TextField).at(0), email);
      await b.scrivi(find.byType(TextField).at(1), 'NuovaPass2026!');
      await accettaPrivacy(b);
      await b.viaSnackbar();
      await b.tocca(find.text('Accedi').last, attesa: 3000);
      await b.aspettaTesto('Aggiungi un alimento:', secondi: 10);
      await b.scatta('home_dopo_accesso');
    });
  }, skip: senzaServer);

  testWidgets('la sessione resta dopo il riavvio', (t) async {
    final b = Banco(t, 'acc_riavvio');
    await b.giro(() async {
      await b.avvia(preferenze: {'app_language': 'Italiano', 'user_email': email});
      await b.aspettaTesto('Aggiungi un alimento:', secondi: 10);
      await b.scatta('home_riavvio');
    });
  }, skip: senzaServer);
}
