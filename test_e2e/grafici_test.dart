// Grafici e calendario con due mesi di dati: i quattro periodi, ogni metrica,
// intervallo di date scelto e tolto, PDF (anteprima e condivisione), poi il
// calendario: mesi avanti e indietro, giorno scelto, apertura del giorno.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/dictionary/translations.dart';
import 'package:nutriapp/models/metric_type.dart';

import 'banco.dart';

const email = 'giulia.e2e@prova.it';

void main() {
  setUpAll(preparaBanco);

  testWidgets('grafici e calendario', (t) async {
    // Sessanta giorni, uno su sette vuoto; oggi resta com'e'.
    final righe = <String>[];
    for (var n = 1; n <= 60; n++) {
      if (n % 7 == 0) continue;
      final kcal = 1500 + (n * 37) % 700;
      righe.add("('$email','Pranzo prova $n','Pranzo',NOW() - INTERVAL $n DAY,300,$kcal,${kcal * 0.12},${kcal * 0.05},${kcal * 0.035},5,20)");
    }
    await t.runAsync(() => sql("""
      DELETE FROM na_nutri_entries WHERE user_mail='$email' AND food_name LIKE 'Pranzo prova%';
      INSERT INTO na_nutri_entries (user_mail, food_name, meal_type, entry_date, weight_g, calories, carbs, proteins, fats, fibers, sugars)
      VALUES ${righe.join(',')};
    """));
    final b = Banco(t, 'gra');
    String tr(String k) => Translations.get('Italiano', k);
    await b.giro(() async {
      await b.avvia(preferenze: {'app_language': 'Italiano', 'user_email': email});
      await b.aspettaTesto('Aggiungi un alimento:');

      b.passo('grafici: periodi');
      await b.tocca(find.byIcon(Icons.show_chart), attesa: 3000);
      await b.scatta('giornaliero');
      for (final p in ['Settimanale', 'Mensile', 'Annuale']) {
        await b.tocca(find.text(tr(p)), attesa: 1500);
        await b.scatta(p.toLowerCase());
      }
      await b.tocca(find.text(tr('Settimanale')), attesa: 1500);

      b.passo('grafici: metriche');
      for (final m in MetricType.values.skip(1)) {
        final chip = find.text(tr(m.label));
        await t.ensureVisible(chip.first);
        await b.tocca(chip.first, attesa: 800);
        await b.scatta('metrica_${m.name}');
      }
      await t.ensureVisible(find.text(tr(MetricType.values.first.label)).first);
      await b.tocca(find.text(tr(MetricType.values.first.label)).first, attesa: 800);

      b.passo('grafici: intervallo di date');
      await t.ensureVisible(find.text(tr('Periodo')));
      await b.tocca(find.text(tr('Periodo')), attesa: 1500);
      await b.scatta('scelta_intervallo');
      final matita = find.byIcon(Icons.edit_outlined);
      if (matita.evaluate().isNotEmpty) {
        await b.tocca(matita.first, attesa: 800);
        await b.scatta('intervallo_testo');
        final campi = find.byType(TextField);
        final oggi = DateTime.now();
        final da = oggi.subtract(const Duration(days: 20));
        final a = oggi.subtract(const Duration(days: 5));
        String f(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
        await b.scrivi(campi.at(0), f(da));
        await b.scrivi(campi.at(1), f(a));
        await b.scatta('intervallo_scritto');
      }
      final ok = find.text('Conferma').evaluate().isNotEmpty ? find.text('Conferma') : find.text('Salva');
      await b.tocca(ok.last, attesa: 2500);
      await b.scatta('intervallo_applicato');
      final togli = find.byIcon(Icons.close);
      if (togli.evaluate().isNotEmpty) {
        await b.tocca(togli.first, attesa: 2000);
        await b.scatta('intervallo_tolto');
      }

      b.passo('grafici: PDF');
      await t.drag(find.byType(Scrollable).last, const Offset(0, -3000));
      await b.attendi(400);
      await b.scatta('fondo_grafici');
      await b.tocca(find.text(tr('Condividi PDF')), attesa: 4000);
      b.diario.writeln('PDF condivisi: ${b.pdfCondivisi}');
      await b.viaSnackbar();
      await b.tocca(find.text(tr('Stampa PDF')), attesa: 4000);
      await b.scatta('anteprima_pdf');
      await b.indietro();
      await b.attendi(1500);

      b.passo('calendario');
      await b.tocca(find.byIcon(Icons.calendar_month), attesa: 3000);
      await b.scatta('calendario');
      await b.tocca(find.byIcon(Icons.chevron_left).first, attesa: 2000);
      await b.scatta('mese_prima');
      await b.tocca(find.byIcon(Icons.chevron_left).first, attesa: 2000);
      await b.scatta('due_mesi_prima');
      await b.tocca(find.byIcon(Icons.chevron_right).first, attesa: 1500);
      await b.tocca(find.byIcon(Icons.chevron_right).first, attesa: 1500);
      await b.tocca(find.byIcon(Icons.chevron_right).first, attesa: 1500);
      await b.scatta('mese_dopo');
      await b.tocca(find.byIcon(Icons.chevron_left).first, attesa: 1500);
      final dieci = find.text('10');
      if (dieci.evaluate().isNotEmpty) {
        await b.tocca(dieci.first, attesa: 1200);
        await b.scatta('giorno_10');
      }
      final apri = find.text(tr('Apri questo giorno'));
      if (apri.evaluate().isNotEmpty) {
        await t.ensureVisible(apri);
        await b.tocca(apri, attesa: 3000);
        await b.scatta('giorno_aperto');
      }
    });
  }, skip: senzaServer);
}
