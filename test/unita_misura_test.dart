// Unità di misura in una schermata loro (2026-09-14).
//
// Si apre la schermata vera e si controlla la cosa che la rende piu' chiara
// della sezione di prima: l'esempio cambia appena si sceglie, prima di salvare.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutriapp/dictionary/translations.dart';
import 'package:nutriapp/screens/unita_misura_page.dart';
import 'package:nutriapp/theme_nutri.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('l\'esempio segue la scelta, e il pulsante si accende', (tester) async {
    tester.view.physicalSize = const Size(412 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: temaNutri(Brightness.light),
          home: const UnitaMisuraPage(),
        ),
      ),
    );
    await tester.pump();

    // Con le preferenze vuote l'app parte in inglese (locale_provider.dart).
    const lingua = 'English';
    final esempio = find.byKey(const Key('unita_esempio'));
    expect(tester.widget<Text>(esempio).data, '150 g · 250 kcal');
    expect(find.text(Translations.get(lingua, 'Tutte le impostazioni sono salvate')), findsOneWidget);

    await tester.tap(find.text(Translations.get(lingua, 'Once (oz)')));
    await tester.pump();
    // Punto e non virgola: l'esempio ora lo scrive UnitFormat, come ogni
    // altro numero dell'app. Prima era una stringa fissa all'italiana e in
    // inglese e cinese si leggeva "5,3 oz" (test di release 19/09).
    expect(tester.widget<Text>(esempio).data, '5.3 oz · 250 kcal');

    await tester.tap(find.text(Translations.get(lingua, 'Kilojoule')));
    await tester.pump();
    expect(tester.widget<Text>(esempio).data, '5.3 oz · 1046 kJ');
    expect(find.text(Translations.get(lingua, 'Salva impostazioni')), findsOneWidget);
  });
}
