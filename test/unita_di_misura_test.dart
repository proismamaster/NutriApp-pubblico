// Le unita' di misura sono l'unico punto dove un errore di conversione non si
// vede: il numero a schermo resta plausibile, ma quello salvato e' sbagliato di
// un fattore 4,18 (kJ) o 28,3 (once). Questi test coprono soprattutto il giro
// completo — quello che l'utente digita deve tornare identico dopo essere
// passato per il modello — perche' e' li' che si perde silenziosamente.
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/logic/nutrient_controller_manager.dart';
import 'package:nutriapp/logic/unit_format.dart';

void main() {
  setUp(() => UnitFormat.applica(peso: 'metric', energia: 'kcal'));

  group('UnitFormat', () {
    test('in metrico e kcal i numeri non vengono toccati', () {
      expect(UnitFormat.p(100), '100 g');
      expect(UnitFormat.e(2000), '2000 kcal');
      expect(UnitFormat.aGrammi(100), 100);
    });

    test('once e kilojoule usano i fattori delle etichette nutrizionali', () {
      UnitFormat.applica(peso: 'imperial', energia: 'kj');
      // 100 g = 3,5274 oz, arrotondato a un decimale
      expect(UnitFormat.p(100), '3.5 oz');
      // 2000 kcal x 4,184 = 8368 kJ
      expect(UnitFormat.e(2000), '8368 kJ');
      expect(UnitFormat.pSigla, 'oz');
      expect(UnitFormat.eSigla, 'kJ');
    });

    test('un peso digitato in once torna in grammi', () {
      UnitFormat.applica(peso: 'imperial', energia: 'kcal');
      expect(UnitFormat.aGrammi(3.5), closeTo(99.2, 0.1));
      // giro completo: 250 g -> once mostrate -> di nuovo grammi
      final mostrato = double.parse(UnitFormat.pValore(250));
      expect(UnitFormat.aGrammi(mostrato), closeTo(250, 0.05));
    });

    test("un'unita' sconosciuta ricade sul metrico invece di inventare", () {
      UnitFormat.applica(peso: 'stones', energia: 'calorie-fate');
      expect(UnitFormat.p(100), '100 g');
      expect(UnitFormat.e(2000), '2000 kcal');
    });
  });

  group('NutrientControllerManager', () {
    late NutrientControllerManager manager;

    setUp(() {
      manager = NutrientControllerManager()
        ..init(['calorie_goal', 'carb_goal', 'calories', 'carbs']);
    });

    tearDown(() => manager.dispose());

    test('in kcal il campo mostra e restituisce lo stesso numero', () {
      manager.setValues({'calorie_goal': 2000});
      expect(manager.controllers['calorie_goal']!.text, '2000');
      expect(manager.getValues()['calorie_goal'], 2000);
    });

    test('in kJ il campo mostra kJ ma il modello riceve kcal', () {
      UnitFormat.applica(peso: 'metric', energia: 'kj');
      manager.setValues({'calorie_goal': 2000});
      // L'utente legge 8368 kJ...
      expect(manager.controllers['calorie_goal']!.text, '8368');
      // ...ma cio' che finisce nel database resta in kcal.
      expect(manager.getValues()['calorie_goal'], closeTo(2000, 0.5));
    });

    // 18/09, cambia la regola del 05/09 su richiesta di Ismail ("vale per
    // tutto anche con le once"): gli obiettivi dei macro seguono le once. I
    // valori per 100 g dell'inserimento manuale no: si copiano dall'etichetta,
    // che e' in grammi.
    test('gli obiettivi dei macro seguono le once, i valori per 100 g no', () {
      UnitFormat.applica(peso: 'imperial', energia: 'kj');
      manager.setValues({'carb_goal': 250, 'carbs': 12});
      expect(manager.controllers['carb_goal']!.text, '8.82');
      expect(manager.getValues()['carb_goal'], closeTo(250, 0.2));
      expect(manager.controllers['carbs']!.text, '12');
      expect(manager.getValues()['carbs'], 12);
    });

    test('valore() legge in kcal anche quando il campo e` in kJ', () {
      UnitFormat.applica(peso: 'metric', energia: 'kj');
      manager.controllers['calories']!.text = '418.4';
      expect(manager.valore('calories'), closeTo(100, 0.01));
      expect(manager.valore('carb_goal'), 0);
    });

    test('scrivi() mette nel campo cio` che l`utente deve leggere', () {
      UnitFormat.applica(peso: 'metric', energia: 'kj');
      manager.scrivi('calorie_goal', 1500);
      expect(manager.controllers['calorie_goal']!.text, '6276');
      manager.scrivi('carb_goal', 180);
      expect(manager.controllers['carb_goal']!.text, '180');
    });

    test('la virgola come separatore decimale non fa perdere il valore', () {
      manager.controllers['calories']!.text = '12,5';
      expect(manager.valore('calories'), 12.5);
    });
  });
}
