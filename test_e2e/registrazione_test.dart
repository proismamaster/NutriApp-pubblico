// Registrazione completa di un utente nuovo, come la farebbe una persona:
// prima con errori (campi vuoti, email sbagliata, password corta o diverse),
// poi giusta fino alla Home.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/widgets/auth_style.dart';

import 'banco.dart';

Finder campo(String suggerimento) => find.widgetWithText(TextField, suggerimento);

void main() {
  setUpAll(preparaBanco);

  testWidgets('registrazione', (t) async {
    const email = 'giulia.e2e@prova.it';
    await t.runAsync(() => sql("DELETE FROM na_users WHERE email='$email'; DELETE FROM na_otp_codes WHERE email='$email';"));

    final b = Banco(t, 'reg');
    await b.giro(() async {
    await b.avvia(preferenze: {'app_language': 'Italiano'});
    b.passo('login -> registrati');
    await b.tocca(find.text('Registrati'));

    b.passo('passo 1 vuoto');
    await b.tocca(find.text('Continua'));
    await b.scatta('p1_vuoto');

    b.passo('passo 1 errori');
    await b.scrivi(campo('Marco'), 'Giulia');
    await b.scrivi(campo('Rossi'), 'Bianchi');
    await b.scrivi(campo('nome@email.it'), 'giulia@');
    await b.scrivi(campo('Almeno 8 caratteri'), 'corta');
    await b.scrivi(campo('Ripeti password'), 'diversa');
    await b.tocca(find.text('Continua'));
    await b.scatta('p1_errori');

    b.passo('passo 1 giusto');
    await b.scrivi(find.byType(TextField).at(2), email);
    await b.scrivi(find.byType(TextField).at(3), 'Password123!');
    await b.scrivi(find.byType(TextField).at(4), 'Password123!');
    // La casella, non il link: toccare "privacy policy" apre l'informativa.
    final privacy = t.getRect(find.byType(NutriPrivacyCheck));
    await t.tapAt(privacy.centerLeft + const Offset(10, 0));
    await b.attendi(300);
    await b.tocca(find.text('Continua'));
    await b.scatta('p2');

    b.passo('passo 2 vuoto');
    await b.tocca(find.text('Continua'));
    await b.scatta('p2_vuoto');

    b.passo('passo 2 limiti');
    await b.tocca(find.text('Donna'));
    await b.tocca(find.text('Data di nascita').last);
    await b.scatta('calendario');
    await b.scrivi(find.byType(TextField).last, '15/03/2000');
    await b.tocca(find.text('OK'));
    await b.scrivi(find.widgetWithText(TextField, '174'), '90');
    await b.scrivi(find.widgetWithText(TextField, '72.0'), '400');
    await b.scrivi(find.widgetWithText(TextField, '68.0'), '20');
    await b.tocca(find.text('Continua'));
    await b.scatta('p2_limiti');

    b.passo('passo 2 giusto');
    await b.scrivi(find.byType(TextField).at(0), '165');
    await b.scrivi(find.byType(TextField).at(1), '63,5');
    await b.scrivi(find.byType(TextField).at(2), '58');
    await b.tocca(find.text('No, usa il piano suggerito'));
    await b.scatta('p2_pieno');
    await b.tocca(find.text('Continua'), attesa: 2000);
    await b.scatta('p3');

    b.passo('otp');
    final t0 = DateTime.now();
    await b.aspettaTesto('Verifica la tua email', secondi: 20);
    b.diario.writeln('passaggio al codice dopo ${DateTime.now().difference(t0).inMilliseconds} ms');
    final codice = await t.runAsync(() => sql("SELECT code FROM na_otp_codes WHERE email='$email' ORDER BY id DESC LIMIT 1"));
    b.diario.writeln('codice OTP dal database: $codice');
    // La snackbar "Codice inviato" copre il pulsante per 4 secondi (difetto
    // segnato nel report): si aspetta che vada via.
    await b.viaSnackbar();
    await b.scrivi(find.byType(TextField).first, '000000');
    await b.tocca(find.text('Verifica Codice'), attesa: 1500);
    await b.scatta('otp_sbagliato');
    await b.viaSnackbar();
    await b.scrivi(find.byType(TextField).first, codice ?? '');
    await b.tocca(find.text('Verifica Codice'), attesa: 2500);
    await b.scatta('dopo_otp');
    await b.attendi(2000);
    await b.scatta('dopo_otp2');
    for (var i = 0; i < 3 && !b.vedeParte('Aggiungi'); i++) {
      await b.viaSnackbar();
      final avanti = find.text('Completa Registrazione').evaluate().isNotEmpty ? find.text('Completa Registrazione')
          : find.text('Continua');
      if (avanti.evaluate().isEmpty) break;
      await b.tocca(avanti.last, attesa: 3000);
      await b.scatta('fine_$i');
    }
    await b.aspettaTesto('Aggiungi un alimento:', secondi: 10);
    await b.scatta('home');
    b.diario.writeln('utente nel db: ${await t.runAsync(() => sql("SELECT CONCAT_WS('|',first_name,gender,birth_date,height,weight,target_weight,calorie_goal,carb_goal,protein_goal,fat_goal) FROM na_users WHERE email='$email'"))}');
    });
  }, skip: senzaServer);
}
