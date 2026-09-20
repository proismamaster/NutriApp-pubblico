// Segnalazione di un alimento: foglio "Segnala un errore" (invio senza tipo,
// poi con tipo e nota), proposta dei valori corretti con nome, calorie,
// categoria, foto del prodotto e nota; poi "Le mie segnalazioni".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/dictionary/translations.dart';

import 'banco.dart';

const email = 'giulia.e2e@prova.it';

void main() {
  setUpAll(preparaBanco);

  testWidgets('segnala alimento e proponi valori', (t) async {
    await t.runAsync(() => sql("DELETE FROM na_report_photos WHERE report_id IN (SELECT id FROM na_food_reports WHERE user_mail='$email'); DELETE FROM na_food_reports WHERE user_mail='$email';"));
    final b = Banco(t, 'seg');
    b.fotoFinta = '$cartellaScatti/acc_01_login.png';
    String tr(String k) => Translations.get('Italiano', k);
    Future<String> db(String q) async => (await t.runAsync(() => sql(q)))!;
    await b.giro(() async {
      await b.avvia(preferenze: {'app_language': 'Italiano', 'user_email': email});
      await b.aspettaTesto('Aggiungi un alimento:');

      b.passo('apri il prodotto');
      await b.tocca(find.byIcon(Icons.add).last, attesa: 2000);
      await b.scrivi(find.byType(TextField).first, 'mela');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await b.aspettaTesto('Mela cotogna', secondi: 20);
      await b.tocca(find.text('Mela cotogna'), attesa: 2000);
      // I valori CREA sono per 100 g di parte edibile: la scheda aperta a
      // 100 g deve mostrare quelli del database, non riscalati (19/09).
      final kcalDb = await db("SELECT ROUND(calories) FROM na_local_db WHERE food_name='MELA COTOGNA'");
      expect(find.textContaining('AGGIUNGI $kcalDb kcal'), findsOneWidget,
          reason: 'la scheda deve mostrare le $kcalDb kcal del database');
      await t.drag(find.byType(Scrollable).first, const Offset(0, -4000));
      await b.attendi(500);
      await b.scatta('scheda_fondo');

      b.passo('foglio segnalazione');
      await b.tocca(find.byIcon(Icons.flag_outlined).first, attesa: 1500);
      await b.scatta('foglio');
      await b.tocca(find.text(tr('report_send')).last, attesa: 1200);
      await b.scatta('invio_senza_tipo');
      await b.tocca(find.text(tr('report_issue_nome')), attesa: 600);
      final nota = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
      if (nota.evaluate().isNotEmpty) await b.scrivi(nota.first, 'Il nome dovrebbe essere "Mela cotogna cruda".');
      await b.scatta('foglio_compilato');
      await b.tocca(find.text(tr('report_send')).last, attesa: 2500);
      await b.scatta('segnalazione_inviata');
      b.diario.writeln('REPORT: ${await db("SELECT IFNULL(GROUP_CONCAT(CONCAT_WS('|',kind,issue,LEFT(note,30),status) SEPARATOR ' || '),'(nessuna)') FROM na_food_reports WHERE user_mail='$email'")}');

      b.passo('di nuovo: gia segnalato');
      await b.viaSnackbar();
      await b.tocca(find.byIcon(Icons.flag_outlined).first, attesa: 1500);
      await b.tocca(find.text(tr('report_issue_nome')), attesa: 600);
      await b.tocca(find.text(tr('report_send')).last, attesa: 2500);
      await b.scatta('seconda_segnalazione');

      b.passo('proponi i valori');
      await b.viaSnackbar();
      await b.tocca(find.byIcon(Icons.flag_outlined).first, attesa: 1500);
      await b.tocca(find.text(tr('report_issue_valori')), attesa: 800);
      await b.scatta('foglio_valori');
      await b.tocca(find.text(tr('propose_title')).last, attesa: 2500);
      await b.scatta('proposta');
      final campi = find.byType(TextField);
      b.diario.writeln('campi nella proposta: ${campi.evaluate().length}');
      // Nome e calorie: i primi campi di testo e numero della pagina.
      await b.scrivi(campi.at(0), 'Mela cotogna cruda');
      await t.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await b.attendi(300);
      await b.scatta('proposta_giu');
      // Ogni campo e' un'etichetta ("Calorie (kcal)") sopra la sua casella.
      final campoCalorie = find.descendant(
          of: find.ancestor(of: find.textContaining('${tr('Calorie')} ('), matching: find.byType(Column)).first,
          matching: find.byType(TextField));
      if (campoCalorie.evaluate().isNotEmpty) {
        await b.scrivi(campoCalorie.first, 'abc');
        await b.scatta('calorie_non_numero');
        await b.scrivi(campoCalorie.first, '57');
      } else {
        b.problemi.add('[proposta] campo Calorie non trovato');
      }
      await b.scatta('proposta_calorie');

      b.passo('foto del prodotto');
      // I titoli di sezione sono in maiuscolo.
      final foto = find.byWidgetPredicate((w) => w is Text && (w.data ?? '').toUpperCase() == tr('propose_product_photo').toUpperCase());
      await t.scrollUntilVisible(foto, 400, scrollable: find.byType(Scrollable).first, maxScrolls: 40);
      {
        await t.ensureVisible(foto);
        await b.attendi(300);
        await b.scatta('sezione_foto');
        final aggiungiFoto = find.byIcon(Icons.photo_camera_outlined);
        if (aggiungiFoto.evaluate().isNotEmpty) {
          await b.tocca(aggiungiFoto.first, attesa: 800);
          await b.scatta('scelta_foto');
          await b.tocca(find.text(tr('propose_photo_gallery')), attesa: 4000);
          await b.scatta('foto_caricata');
        } else {
          b.problemi.add('[foto] pulsante per aggiungere la foto non trovato');
        }
      }

      b.passo('nota e invio');
      final notaProposta = find.widgetWithText(TextField, tr('propose_note_hint'));
      if (notaProposta.evaluate().isNotEmpty) {
        await t.ensureVisible(notaProposta);
        await b.scrivi(notaProposta, 'Etichetta fotografata al supermercato.');
      }
      await b.viaSnackbar();
      await b.tocca(find.text(tr('propose_send')).last, attesa: 3000);
      await b.scatta('proposta_inviata');
      b.diario.writeln('PROPOSTA: ${await db("SELECT IFNULL(GROUP_CONCAT(CONCAT_WS('|',kind,issue,status,LEFT(note,20),LEFT(proposed_json,300),(SELECT COUNT(*) FROM na_report_photos p WHERE p.report_id=r.id)) SEPARATOR ' || '),'(nessuna)') FROM na_food_reports r WHERE user_mail='$email'")}');
      final ok = find.text(tr('propose_done_ok'));
      if (ok.evaluate().isNotEmpty) await b.tocca(ok, attesa: 1500);
      await b.scatta('dopo_proposta');
    });
  }, skip: senzaServer);
}
