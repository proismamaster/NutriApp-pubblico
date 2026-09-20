// Giro di tutte le schermate principali in ogni lingua (e, per ogni lingua,
// con kJ e once): il banco controlla a ogni scatto chiavi grezze, testi non
// tradotti e parole italiane rimaste, e raccoglie gli errori di layout
// (arabo = da destra a sinistra).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/dictionary/translations.dart';

import 'banco.dart';

const email = 'giulia.e2e@prova.it';

void main() {
  setUpAll(preparaBanco);

  for (final (lingua, sigla) in [('English', 'en'), ('简体中文', 'zh'), ('العربية', 'ar'), ('Italiano', 'it')]) {
    testWidgets('schermate in $lingua', (t) async {
      final b = Banco(t, 'lin_$sigla');
      String tr(String chiave) => Translations.get(lingua, chiave);
      await b.giro(() async {
        await b.avvia(preferenze: {
          'app_language': lingua,
          'user_email': email,
          'app_energy_unit': 'kj',
          'app_weight_unit': 'imperial',
        });
        await b.attendi(3000);
        await b.scatta('home');

        b.passo('dettagli');
        await b.tocca(find.text(tr('home_details_link')), attesa: 3000);
        await b.scatta('dettaglio_giorno');
        await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
        await b.attendi(500);
        await b.scatta('dettaglio_giorno_giu');
        await b.indietro();
        await b.attendi(1500);

        b.passo('pasto');
        await b.tocca(find.text(tr('Colazione')).first, attesa: 3000);
        await b.scatta('pasto');
        await b.indietro();
        await b.attendi(1500);

        b.passo('aggiungi');
        // Il + al centro della barra in basso: e' l'ultimo "add" disegnato.
        await b.tocca(find.byIcon(Icons.add).last, attesa: 2000);
        await b.scatta('aggiungi');
        await b.tocca(find.byType(Tab).at(1), attesa: 1500);
        await b.scatta('ricette_salvate');
        await b.tocca(find.byType(Tab).at(2), attesa: 1500);
        await b.scatta('alimenti_salvati');
        await b.tocca(find.byType(Tab).at(0), attesa: 800);
        await b.tocca(find.text(tr('search_manual_link_2')), attesa: 2000);
        await b.scatta('manuale');
        await t.drag(find.byType(Scrollable).first, const Offset(0, -1400));
        await b.attendi(400);
        await b.scatta('manuale_meta');
        await t.drag(find.byType(Scrollable).first, const Offset(0, -3000));
        await b.attendi(400);
        await b.scatta('manuale_fondo');
        await b.indietro();
        await b.attendi(800);

        b.passo('calendario');
        await b.tocca(find.byIcon(Icons.calendar_month), attesa: 3000);
        await b.scatta('calendario');

        b.passo('ricette');
        await b.tocca(find.byIcon(Icons.bookmark), attesa: 3000);
        await b.scatta('ricette');

        b.passo('grafici');
        await b.tocca(find.byIcon(Icons.show_chart), attesa: 3000);
        await b.scatta('grafici');

        b.passo('impostazioni');
        await b.tocca(find.byIcon(Icons.settings), attesa: 2000);
        await b.scatta('impostazioni');
        await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
        await b.attendi(400);
        await b.scatta('impostazioni_giu');
        for (final (chiave, nome) in [
          ('Il mio profilo', 'profilo'),
          ('I miei obiettivi', 'obiettivi'),
          ('Notifiche', 'notifiche'),
          ('Lingua e paese', 'lingua_paese'),
          ('Unità di misura', 'unita'),
          ('Informativa sulla privacy', 'privacy'),
          ('Su di noi', 'su_di_noi'),
          ('Segnala un problema', 'segnala'),
          ('my_reports_title', 'mie_segnalazioni'),
          ('Aiuto', 'aiuto'),
        ]) {
          b.passo('impostazioni > $nome');
          final voce = find.text(tr(chiave));
          if (voce.evaluate().isEmpty) {
            b.problemi.add('[${nome}] voce "${tr(chiave)}" non trovata nelle impostazioni');
            continue;
          }
          await b.tocca(voce, attesa: 3000);
          await b.scatta(nome);
          await b.indietro();
          await b.attendi(1200);
        }
      });
    }, skip: senzaServer);
  }
}
