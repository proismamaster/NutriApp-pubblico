// Unita' coerenti in tutta l'app (18/09).
//
// PERCHE' ESISTE: con i kJ scelti la Home diceva "7146 kcal rimanenti" per un
// numero in kJ e "0 kcal assunte" col numero delle kcal; con le once i macro
// restavano in grammi. Qui si controllano i pezzi da cui passa tutto il resto:
// i testi tradotti con la sigla al posto giusto, le barre dei macro, i campi
// degli obiettivi e le metriche dei grafici.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/dictionary/translations.dart';
import 'package:nutriapp/logic/nutrient_controller_manager.dart';
import 'package:nutriapp/logic/unit_format.dart';
import 'package:nutriapp/models/metric_type.dart';
import 'package:nutriapp/widgets/nutrient_progress_bar.dart';

const _lingue = ['Italiano', 'English', '简体中文', 'العربية'];

void main() {
  tearDown(() => UnitFormat.applica(peso: 'metric', energia: 'kcal'));

  test('nessun testo con l\'energia ha "kcal" scritto dentro', () {
    for (final lingua in _lingue) {
      for (final chiave in ['home_assunte', 'home_rimanenti', 'home_eccesso', 'goal_macros_above', 'goal_macros_below']) {
        final testo = Translations.get(lingua, chiave);
        expect(testo, contains('{u}'), reason: '$lingua/$chiave: "$testo"');
        expect(testo.toLowerCase(), isNot(contains('kcal')), reason: '$lingua/$chiave');
      }
      expect(Translations.get(lingua, 'of_2000_kcal_daily'), contains('{n}'), reason: lingua);
      expect(Translations.get(lingua, 'limit_calories'), allOf(contains('{min}'), contains('{max}')), reason: lingua);
    }
  });

  test('con i kJ la sigla nei testi diventa kJ', () {
    UnitFormat.applica(peso: 'metric', energia: 'kj');
    expect(UnitFormat.conUnita(Translations.get('English', 'home_rimanenti')), 'kJ remaining');
    expect(UnitFormat.eValore(1708), '7146');
  });

  test('con le once i pesi dei nutrienti non si arrotondano a zero', () {
    UnitFormat.applica(peso: 'imperial', energia: 'kcal');
    expect(UnitFormat.pNumero(150), '5.3');
    expect(UnitFormat.pNutriente(0.4), '0.01 oz');
    UnitFormat.applica(peso: 'metric', energia: 'kcal');
    expect(UnitFormat.pNutriente(0.4), '0.4 g');
    expect(UnitFormat.pNutriente(47.2), '47 g');
  });

  testWidgets('le barre dei macro seguono le once, quelle dei micronutrienti no', (tester) async {
    UnitFormat.applica(peso: 'imperial', energia: 'kj');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              NutrientProgressBar(label: 'Carboidrati', currentValue: 47, goalValue: 150, color: Colors.blue, unit: 'g'),
              NutrientProgressBar(label: 'Calorie', currentValue: 0, goalValue: 1708, color: Colors.blue, unit: 'kcal'),
              NutrientProgressBar(label: 'Calcio', currentValue: 300, goalValue: 1000, color: Colors.blue, unit: 'mg'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('1.7/5.3 oz'), findsOneWidget);
    expect(find.text('0/7146 kJ'), findsOneWidget);
    expect(find.text('300/1000 mg'), findsOneWidget);
  });

  test('gli obiettivi dei macro si scrivono in once e si salvano in grammi', () {
    UnitFormat.applica(peso: 'imperial', energia: 'kj');
    final m = NutrientControllerManager()..init(['carb_goal', 'calorie_goal', 'cholesterol_max']);
    m.setValues({'carb_goal': 150, 'calorie_goal': 2000, 'cholesterol_max': 300});
    expect(m.controllers['carb_goal']!.text, '5.29');
    expect(m.controllers['calorie_goal']!.text, '8368');
    expect(m.controllers['cholesterol_max']!.text, '300', reason: 'i milligrammi non cambiano');
    final salvati = m.getValues();
    expect(salvati['carb_goal'], closeTo(150, 0.2));
    expect(salvati['calorie_goal'], closeTo(2000, 0.2));
    expect(salvati['cholesterol_max'], 300);
    m.dispose();
  });

  test('i grafici disegnano e scrivono nell\'unita\' scelta', () {
    UnitFormat.applica(peso: 'imperial', energia: 'kj');
    expect(MetricType.calories.visibile(1000), closeTo(4184, 0.01));
    expect(MetricType.carbs.visibile(283.5), closeTo(10, 0.01));
    expect(MetricType.carbs.format(283.5), '10.0 oz');
    expect(MetricType.calories.scriviBreve(4184), '4.2k kJ');
  });
}
