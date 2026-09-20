// Test dell'interpretazione delle porzioni.
//
// PERCHÉ QUESTI TEST (2026-07-24): qui si è annidato per due volte di
// seguito lo stesso bug, ogni prodotto proponeva sempre e solo "100 g" e la
// porzione vera della confezione non veniva mai letta. La causa era
// concettuale: `base_weight_g` (il peso su cui sono espressi i nutrienti,
// che per OpenFoodFacts vale sempre 100) veniva scambiato per la porzione
// della confezione. I test qui sotto bloccano il ritorno di quell'errore.
//
// Lancio:  flutter test test/portion_parser_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriapp/logic/portion_parser.dart';

void main() {
  group('parseServingGrams', () {
    test('riconosce i formati che compaiono davvero in OpenFoodFacts', () {
      expect(parseServingGrams('30 g'), 30);
      expect(parseServingGrams('40g'), 40);
      expect(parseServingGrams('30 gr'), 30);
      expect(parseServingGrams('125 grammi'), 125);
      expect(parseServingGrams('1 barretta (35 g)'), 35);
      expect(parseServingGrams('1 porzione 30g'), 30);
      expect(parseServingGrams('3,5 g'), 3.5); // virgola decimale italiana
      expect(parseServingGrams('30 G'), 30); // maiuscolo
    });

    test('tratta i millilitri come grammi (approssimazione dichiarata)', () {
      expect(parseServingGrams('250 ml'), 250);
      expect(parseServingGrams('1 bicchiere (200 ml)'), 200);
    });

    test('ignora il numero che non è un peso', () {
      // "1 barretta": l'1 non è il peso, il peso è quello fra parentesi.
      expect(parseServingGrams('1 barretta (35 g)'), 35);
      expect(parseServingGrams('1 tazza'), isNull);
      expect(parseServingGrams(''), isNull);
      expect(parseServingGrams('   '), isNull);
      expect(parseServingGrams('una porzione'), isNull);
    });

    test('scarta i valori assurdi invece di propagarli', () {
      expect(parseServingGrams('0 g'), isNull);
      expect(parseServingGrams('5000 g'), isNull); // dato OFF malformato
      expect(parseServingGrams('2000 g'), 2000); // limite incluso
    });
  });

  group('productPortionGrams', () {
    test('preferisce serving_quantity quando c\'è', () {
      expect(
        productPortionGrams({'serving_quantity': 45, 'serving_size': '30 g'}),
        45,
      );
    });

    test('ripiega su serving_size quando serving_quantity manca o è 0', () {
      expect(productPortionGrams({'serving_size': '30 g'}), 30);
      expect(
        productPortionGrams({'serving_quantity': 0, 'serving_size': '30 g'}),
        30,
      );
    });

    test('NON usa base_weight_g come porzione (bug corretto due volte)', () {
      // base_weight_g vale sempre 100 per i prodotti OpenFoodFacts: se
      // venisse usato come porzione, questo prodotto proporrebbe 100 g
      // invece dei 30 g reali della confezione.
      final data = {'base_weight_g': 100.0, 'serving_size': '30 g'};
      expect(productPortionGrams(data), 30);
    });

    test('torna 0 quando il prodotto non dichiara nessuna porzione', () {
      expect(productPortionGrams({'base_weight_g': 100.0}), 0);
      expect(productPortionGrams({}), 0);
    });
  });

  group('availablePortions', () {
    test('propone 100 g più la porzione reale, in ordine crescente', () {
      expect(availablePortions({'serving_size': '30 g'}), [30, 100]);
      expect(availablePortions({'serving_quantity': 250}), [100, 250]);
    });

    test('non duplica 100 g se la porzione è già 100 g', () {
      expect(availablePortions({'serving_size': '100 g'}), [100]);
    });

    test('resta il solo 100 g se non c\'è una porzione dichiarata', () {
      expect(availablePortions({'base_weight_g': 100.0}), [100]);
    });
  });

  group('formatGrams', () {
    test('niente ".0" inutile sugli interi, decimali mantenuti', () {
      expect(formatGrams(40), '40');
      expect(formatGrams(100.0), '100');
      expect(formatGrams(12.5), '12.5');
    });
  });
}
