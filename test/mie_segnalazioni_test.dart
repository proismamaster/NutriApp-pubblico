// "Le mie segnalazioni" a quattro schede (2026-09-15, problemi dell'app a parte dal 17/09).
//
// PERCHE' ESISTE: Ismail ha chiesto di vedere nella stessa pagina gli errori
// sui dati, i problemi dell'app, le ricette e gli alimenti proposti, con
// ricerca, filtro per stato e ordinamento. Qui si apre la pagina VERA con dati
// finti e si controlla che ogni scheda mostri il suo, e che il filtro filtri.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/dictionary/translations.dart';
import 'package:nutriapp/domain/user_provider.dart';
import 'package:nutriapp/models/contributi_utente.dart';
import 'package:nutriapp/models/recipe.dart';
import 'package:nutriapp/models/user_model.dart';
import 'package:nutriapp/screens/mie_segnalazioni_page.dart';
import 'package:nutriapp/theme_nutri.dart';
import 'package:nutriapp/widgets/auth_style.dart';

class _UtenteFinto extends UserNotifier {
  @override
  UserModel? build() => UserModel(
        id: 1,
        email: 'test@example.com',
        firstName: 'Ismail',
        lastName: 'Barakat',
        height: 174,
        gender: 'male',
        birthDate: DateTime(2007, 9, 17),
        createdAt: DateTime(2026, 1, 1),
      );
}

String _t(String chiave) => Translations.get('English', chiave);

final _dati = ContributiUtente.fromJson({
  'reports': [
    {'id': 1, 'food_name': 'Croissant crema', 'issue': 'valori', 'status': 'rejected', 'review_note': 'Foto illeggibile', 'created_at': '2026-09-14 10:00:00'},
  ],
  'app_reports': [
    {'id': 7, 'description': 'Il grafico non si aggiorna', 'kind': 'bug', 'screen': 'Grafici', 'status': 'resolved', 'admin_note': 'Sistemato', 'created_at': '2026-09-15 09:00:00'},
  ],
  'recipes': [
    {'id': 3, 'name': 'Insalata di farro', 'shared_status': 'approved', 'likes': 4, 'removed': true, 'shared_at': '2026-09-10 12:00:00'},
  ],
  'foods': [
    {'id': 9, 'name': 'Hummus', 'brand': 'Casa', 'shared_status': 'pending', 'shared_at': '2026-09-11 12:00:00'},
  ],
});

Future<void> _apri(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412 * 2, 900 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [userProvider.overrideWith(() => _UtenteFinto())],
      child: MaterialApp(
        theme: temaNutri(Brightness.light),
        home: MieSegnalazioniPage(caricatore: (_) async => _dati),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('i contributi si leggono dalla risposta del server', () {
    expect(_dati.segnalazioni.single.status, 'rejected');
    expect(_dati.problemi.single.stato, 'resolved');
    expect(_dati.ricette.single.rimosso, isTrue);
    expect(_dati.ricette.single.like, 4);
    expect(_dati.alimenti.single.dettaglio, 'Casa');
    final strano = ProblemaApp.fromJson({'id': 1, 'description': 'x', 'status': 'boh'});
    expect(strano.stato, 'open', reason: 'uno stato sconosciuto non diventa "risolto"');
  });

  test('una ricetta pubblica porta categorie e like', () {
    final r = Recipe.fromJson({
      'id': 5, 'recipe_name': 'Farro', 'meal_types': 'pranzo,cena', 'course': 'piatto_unico',
      'diet_tags': '', 'likes_count': 3, 'liked_by_me': true, 'ingredients': [],
    });
    expect(r.mealTypes, ['pranzo', 'cena']);
    expect(r.dietTags, isEmpty);
    expect(r.likesCount, 3);
    expect(r.likedByMe, isTrue);
  });

  testWidgets('quattro schede, ognuna col suo contenuto', (tester) async {
    await _apri(tester);
    expect(find.text('${_t('my_reports_type_food')} (1)'), findsOneWidget);
    expect(find.text('${_t('my_reports_tab_app')} (1)'), findsOneWidget);
    expect(find.text('${_t('my_reports_tab_recipes')} (1)'), findsOneWidget);
    expect(find.text('${_t('my_reports_tab_foods')} (1)'), findsOneWidget);

    // Prima scheda: solo gli errori sui dati.
    expect(find.text('Croissant crema'), findsOneWidget);
    expect(find.text('Il grafico non si aggiorna'), findsNothing);

    // Seconda: i problemi dell'app, con la risposta di chi li ha gestiti.
    await tester.tap(find.text('${_t('my_reports_tab_app')} (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Il grafico non si aggiorna'), findsOneWidget);
    expect(find.text('Sistemato'), findsOneWidget);
    expect(find.text('Croissant crema'), findsNothing);

    // Quattro schede scorrono in orizzontale: quella delle ricette va portata in vista.
    final ricette = find.text('${_t('my_reports_tab_recipes')} (1)');
    await tester.ensureVisible(ricette);
    await tester.pumpAndSettle();
    await tester.tap(ricette);
    await tester.pumpAndSettle();
    expect(find.text('Insalata di farro'), findsOneWidget);
    expect(find.text(_t('contrib_likes').replaceAll('{n}', '4')), findsOneWidget);
    expect(find.text(_t('contrib_removed')), findsOneWidget);
  });

  testWidgets('il filtro per stato e la ricerca restringono la scheda aperta', (tester) async {
    await _apri(tester);
    // I filtri scorrono in orizzontale: il chip va portato in vista.
    Future<void> filtro(String chiave) async {
      final chip = find.widgetWithText(NutriChip, _t(chiave));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    await filtro('my_reports_filter_no');
    expect(find.text('Croissant crema'), findsOneWidget);
    await filtro('my_reports_filter_ok');
    expect(find.text('Croissant crema'), findsNothing);
    await filtro('Tutti');

    await tester.tap(find.text('${_t('my_reports_tab_app')} (1)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'grafico');
    await tester.pumpAndSettle();
    expect(find.text('Il grafico non si aggiorna'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'croissant');
    await tester.pumpAndSettle();
    expect(find.text('Il grafico non si aggiorna'), findsNothing);
  });

  testWidgets('ricerca e ordinamento non coprono i filtri', (tester) async {
    await _apri(tester);
    final ordina = tester.getRect(find.byIcon(Icons.sort));
    final rifiutati = tester.getRect(find.widgetWithText(NutriChip, _t('my_reports_filter_no')));
    // Il 17/09 l'ordinamento stava sulla riga dei filtri e tagliava "Rifiutati".
    expect(ordina.overlaps(rifiutati), isFalse);
    expect(ordina.bottom, lessThanOrEqualTo(rifiutati.top), reason: 'ordinamento sulla riga della ricerca, sopra i filtri');
  });
}
