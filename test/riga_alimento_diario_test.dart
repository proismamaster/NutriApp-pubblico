// Voce del diario: tocco in sola lettura, matita sulla scheda prodotto (17/09).
//
// PERCHE' ESISTE: Ismail voleva le voci del dettaglio giorno e del dettaglio
// pasto coerenti. Toccandole si vedono i dettagli senza poterli cambiare; la
// matita apre la scheda prodotto della ricerca (non l'inserimento manuale) con
// pasto e peso gia' scelti.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutriapp/dictionary/translations.dart';
import 'package:nutriapp/domain/user_provider.dart';
import 'package:nutriapp/models/food_entry.dart';
import 'package:nutriapp/models/macronutrients.dart';
import 'package:nutriapp/models/user_model.dart';
import 'package:nutriapp/theme_nutri.dart';
import 'package:nutriapp/widgets/riga_alimento_diario.dart';

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
        calorieGoal: 2000,
      );
}

String _t(String chiave) => Translations.get('English', chiave);

final _voce = FoodEntry(
  id: 5,
  user_mail: 'test@example.com',
  food_name: 'Pasta al pomodoro',
  meal_type: 'Pranzo',
  entry_date: DateTime(2026, 9, 16, 13),
  weight_g: 150,
  macro: const Macronutrients(calories: 270, carbs: 50, proteins: 9, fats: 3),
);

Future<void> _apri(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412 * 2, 915 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [userProvider.overrideWith(() => _UtenteFinto())],
      child: MaterialApp(
        theme: temaNutri(Brightness.light),
        home: Scaffold(
          body: RigaAlimentoDiario(voce: _voce, lang: 'English', onCambiata: () {}, onElimina: () {}),
        ),
      ),
    ),
  );
}

Future<void> _attendi(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
  // A transizione finita la riga sotto esce di scena: la sua matita non conta.
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Finder _campoConTesto(String testo) =>
    find.byWidgetPredicate((w) => w is EditableText && w.controller.text == testo);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'initialize' ? true : null,
    );
  });

  testWidgets('la matita apre la scheda prodotto con pasto e peso di prima', (tester) async {
    await _apri(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await _attendi(tester);

    expect(find.text(_t('product_found_title')), findsOneWidget, reason: 'la scheda della ricerca, non il modulo manuale');
    // Dal 18/09 il pasto e' un NutriSelect: il valore scelto e' testo, non
    // un campo scrivibile.
    expect(find.text(_t('Pranzo')), findsOneWidget, reason: 'pasto gia\' scelto');
    expect(_campoConTesto('150'), findsOneWidget, reason: 'peso gia\' scritto');
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget, reason: 'si puo\' segnalare');
    expect(find.byTooltip(_t('Modifica')), findsOneWidget, reason: 'e sbloccare i valori');
    expect(find.textContaining(_t('SALVA')), findsOneWidget);
  });

  testWidgets('il tocco sulla riga mostra i dettagli senza poterli cambiare', (tester) async {
    await _apri(tester);
    await tester.tap(find.text('Pasta al pomodoro'));
    await _attendi(tester);

    expect(find.text(_t('product_found_title')), findsOneWidget);
    expect(find.byTooltip(_t('Modifica')), findsNothing);
    expect(find.textContaining(_t('SALVA')), findsNothing);
    expect(find.text(_t('Seleziona Pasto')), findsNothing);
  });
}
