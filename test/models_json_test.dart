// Test delle mappature JSON dei modelli.
//
// PERCHÉ PROPRIO QUESTI TEST (2026-07-24): è esattamente qui che si sono
// annidati i bug più insidiosi del progetto, quelli che non danno nessun
// errore visibile e si notano solo mesi dopo guardando dati sbagliati:
//
//  - RecipeIngredient.fromJson leggeva chiavi con prefisso 'tot_'
//    ('tot_saturated', 'tot_vit_a', ...) che non esistono in nessun punto
//    della pipeline reale: ogni ingrediente di ricetta perdeva in silenzio
//    grassi dettagliati, vitamine e minerali, tutti azzerati a 0.
//  - I metadati OpenFoodFacts (Nutri-Score, NOVA, allergeni...) sparivano
//    salvando un prodotto in libreria o dentro una ricetta.
//
// Nessuno di questi due bug avrebbe superato i test qui sotto.
//
// Lancio:  flutter test test/models_json_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriapp/models/recipe_ingredient.dart';
import 'package:nutriapp/models/custom_food.dart';
import 'package:nutriapp/models/food_entry.dart';
import 'package:nutriapp/models/recipe.dart';
import 'package:nutriapp/models/user_model.dart';
import 'package:nutriapp/models/segnalazione_utente.dart';

/// JSON "completo" come quello che arriva dal server per un prodotto
/// OpenFoodFacts: un valore diverso per ogni campo, così se due campi
/// vengono scambiati fra loro il test se ne accorge (usare tutti 1 non
/// distinguerebbe uno scambio).
Map<String, dynamic> fullNutrientJson() => {
      'food_name': 'Barretta ai cereali',
      'unit': 'g',
      'weight_g': 40.0,
      // Macro
      'calories': 172.0,
      'carbs': 23.2,
      'proteins': 2.88,
      'fats': 6.8,
      'water': 1.2,
      'fibers': 2.6,
      'sugars': 8.8,
      // Grassi dettagliati
      'saturated_fats': 3.1,
      'monounsaturated_fats': 2.2,
      'polyunsaturated_fats': 1.3,
      'trans_fats': 0.4,
      'cholesterol': 5.5,
      // Vitamine
      'vit_a': 11.0, 'vit_b1': 12.0, 'vit_b2': 13.0, 'vit_b3': 14.0,
      'vit_b5': 15.0, 'vit_b6': 16.0, 'vit_b7': 17.0, 'vit_b9': 18.0,
      'vit_b11': 19.0, 'vit_b12': 20.0, 'vit_c': 21.0, 'vit_d': 22.0,
      'vit_e': 23.0, 'vit_k': 24.0, 'biotin': 25.0,
      // Minerali
      'sodium': 31.0, 'arsenic': 32.0, 'boron': 33.0, 'calcium': 34.0,
      'chloride': 35.0, 'choline': 36.0, 'chromium': 37.0, 'cobalt': 38.0,
      'copper': 39.0, 'fluoride': 40.0, 'fluorine': 41.0, 'iodine': 42.0,
      'iron': 43.0, 'magnesium': 44.0, 'manganese': 45.0, 'molybdenum': 46.0,
      'phosphorus': 47.0, 'potassium': 48.0, 'selenium': 49.0, 'silicon': 50.0,
      'sulfur': 51.0, 'tin': 52.0, 'vanadium': 53.0, 'zinc': 54.0,
      // Metadati OpenFoodFacts
      'nutriscore_grade': 'c',
      'nova_group': 4,
      'additives_n': 5,
      'allergens': 'en:gluten,en:nuts',
      'labels': 'en:vegetarian',
      'palm_oil_n': 1,
      'palm_oil_maybe_n': 0,
      'image_url': 'https://example.org/foto.jpg',
      'serving_size': '40 g',
      'categories': 'en:snacks',
      'manufacturing_places': 'Italia',
      'ingredients': 'Fiocchi di avena, zucchero, olio di palma',
      'alcohol_percent': 0.0,
      'caffeine': 12.0,
    };

void main() {
  group('RecipeIngredient', () {
    test('non perde grassi dettagliati, vitamine e minerali (bug 2026-07-24)', () {
      final ing = RecipeIngredient.fromJson(fullNutrientJson());

      // Il bug originale azzerava proprio questi.
      expect(ing.fats.saturated, 3.1);
      expect(ing.fats.monounsaturated, 2.2);
      expect(ing.fats.polyunsaturated, 1.3);
      expect(ing.fats.trans, 0.4);
      expect(ing.fats.cholesterol, 5.5);

      expect(ing.vitamins.a, 11.0);
      expect(ing.vitamins.b12, 20.0);
      expect(ing.vitamins.biotin, 25.0);

      expect(ing.minerals.sodium, 31.0);
      expect(ing.minerals.iron, 43.0);
      expect(ing.minerals.zinc, 54.0);
    });

    test('mantiene i metadati OpenFoodFacts', () {
      final ing = RecipeIngredient.fromJson(fullNutrientJson());
      expect(ing.nutriscoreGrade, 'c');
      expect(ing.novaGroup, 4);
      expect(ing.additivesN, 5);
      expect(ing.allergens, 'en:gluten,en:nuts');
      expect(ing.palmOilN, 1);
      expect(ing.caffeine, 12.0);
      expect(ing.ingredientsText, contains('avena'));
    });

    test('round-trip toJson -> fromJson non perde nulla', () {
      final originale = RecipeIngredient.fromJson(fullNutrientJson());
      final ricreato = RecipeIngredient.fromJson(originale.toJson());

      expect(ricreato.name, originale.name);
      expect(ricreato.weight_g, originale.weight_g);
      expect(ricreato.macro.calories, originale.macro.calories);
      expect(ricreato.fats.saturated, originale.fats.saturated);
      expect(ricreato.vitamins.b9, originale.vitamins.b9);
      expect(ricreato.minerals.magnesium, originale.minerals.magnesium);
      expect(ricreato.nutriscoreGrade, originale.nutriscoreGrade);
      expect(ricreato.novaGroup, originale.novaGroup);
      expect(ricreato.imageUrl, originale.imageUrl);
    });

    test('regge valori mancanti o non numerici senza esplodere', () {
      final ing = RecipeIngredient.fromJson({
        'food_name': 'Alimento incompleto',
        'calories': 'abc', // testo dove ci si aspetta un numero
        'nova_group': '3.0', // intero scritto come decimale
      });
      expect(ing.name, 'Alimento incompleto');
      expect(ing.macro.calories, 0.0);
      expect(ing.fats.saturated, 0.0);
      expect(ing.novaGroup, 3);
    });
  });

  group('CustomFood', () {
    test('mantiene foto, descrizione e metadati OpenFoodFacts', () {
      final json = fullNutrientJson()
        ..['user_mail'] = 'test@example.org'
        ..['base_weight_g'] = 100.0
        ..['description'] = 'La mia nota';

      final food = CustomFood.fromJson(json);
      expect(food.imageUrl, 'https://example.org/foto.jpg');
      expect(food.description, 'La mia nota');
      expect(food.nutriscoreGrade, 'c');
      expect(food.novaGroup, 4);
      expect(food.allergens, 'en:gluten,en:nuts');
      expect(food.caffeine, 12.0);
    });

    test('toJson include SEMPRE i metadati: il server riscrive tutte le colonne', () {
      // Se questi campi sparissero da toJson, save_custom_food.php li
      // azzererebbe sul server ad ogni salvataggio: il test blocca la
      // regressione.
      const food = CustomFood(user_mail: 'a@b.c', food_name: 'Test');
      final json = food.toJson();
      for (final key in [
        'image_url', 'description', 'nutriscore_grade', 'nova_group',
        'additives_n', 'allergens', 'labels', 'palm_oil_n',
        'palm_oil_maybe_n', 'serving_size', 'categories',
        'manufacturing_places', 'ingredients', 'alcohol_percent', 'caffeine',
      ]) {
        expect(json.containsKey(key), isTrue, reason: 'manca la chiave "$key" in CustomFood.toJson()');
      }
    });

    test('il barcode resta una stringa, anche se il server lo manda come numero', () {
      // get_custom_foods.php castava a double tutte le colonne tranne 4,
      // quindi il barcode tornava numerico e diventava "8032123456789.0".
      final food = CustomFood.fromJson({
        'user_mail': 'a@b.c',
        'food_name': 'Test',
        'barcode': '8032123456789',
      });
      expect(food.barcode, '8032123456789');
      expect(food.barcode, isNot(contains('.')));
    });
  });

  group('FoodEntry', () {
    test('legge la data e i nutrienti dal formato del server', () {
      final json = fullNutrientJson()
        ..['user_mail'] = 'test@example.org'
        ..['meal_type'] = 'Colazione'
        ..['entry_date'] = '2026-07-24';

      final entry = FoodEntry.fromJson(json);
      expect(entry.entry_date.year, 2026);
      expect(entry.entry_date.month, 7);
      expect(entry.entry_date.day, 24);
      expect(entry.meal_type, 'Colazione');
      expect(entry.macro.calories, 172.0);
      expect(entry.fats.saturated, 3.1);
      expect(entry.minerals.iron, 43.0);
    });
  });

  // ------------------------------------------------------------------
  // Condivisione con la comunita' (2026-09-12)
  //
  // PERCHE' QUI: lo stato di condivisione viaggia in tre direzioni diverse
  // (dal server all'app, dall'app al server, e dentro la copia di una
  // ricetta), e se si perde lungo la strada il difetto e' invisibile — un
  // contenuto pubblico che sembra privato, o peggio il contrario. E' la
  // stessa famiglia di bug che ha fatto nascere questo file.
  // ------------------------------------------------------------------
  group('condivisione', () {
    test('Recipe legge stato e autore, e li porta nella copia', () {
      final recipe = Recipe.fromJson({
        'id': 7,
        'recipe_name': 'Pasta al pesto',
        'portion': '2',
        'notes': 'buona',
        'image_url': '',
        'is_favorite': 0,
        'shared_status': 'approved',
        'author_name': 'Ismail',
        'ingredients': [],
      });

      expect(recipe.sharedStatus, 'approved');
      expect(recipe.authorName, 'Ismail');
      expect(recipe.copy().sharedStatus, 'approved');
      expect(recipe.copy().authorName, 'Ismail');
    });

    test('Recipe senza le chiavi nuove e privata, non pubblica', () {
      // E' la risposta di un server ancora senza la migrazione: il default
      // sbagliato qui pubblicherebbe le ricette di tutti.
      final recipe = Recipe.fromJson({
        'id': 8,
        'recipe_name': 'Minestra',
        'portion': '1',
        'notes': '',
        'ingredients': [],
      });
      expect(recipe.sharedStatus, 'private');
      expect(recipe.authorName, '');
    });

    test('CustomFood legge lo stato di condivisione', () {
      final json = fullNutrientJson()
        ..['user_mail'] = 'test@example.org'
        ..['base_weight_g'] = 100.0
        ..['shared_status'] = 'pending';
      expect(CustomFood.fromJson(json).sharedStatus, 'pending');

      final senza = fullNutrientJson()
        ..['user_mail'] = 'test@example.org'
        ..['base_weight_g'] = 100.0;
      expect(CustomFood.fromJson(senza).sharedStatus, 'private');
    });

    test('UserModel legge il consenso in tutte le forme in cui arriva', () {
      // MySQL manda 1/0, JSON puo' mandare true/false o "1"/"0": tre strade
      // per lo stesso interruttore, e una sola gestita sarebbe un consenso
      // che si spegne da solo al prossimo accesso.
      for (final valore in [1, '1', true, 'true']) {
        final u = UserModel.fromJson({
          'id': 1,
          'email': 'a@b.c',
          'share_custom_foods': valore,
        });
        expect(u.shareCustomFoods, isTrue, reason: 'valore $valore');
      }
      for (final valore in [0, '0', false, null]) {
        final u = UserModel.fromJson({
          'id': 1,
          'email': 'a@b.c',
          'share_custom_foods': valore,
        });
        expect(u.shareCustomFoods, isFalse, reason: 'valore $valore');
      }
      // Chiave assente: consenso non dato.
      expect(
        UserModel.fromJson({'id': 1, 'email': 'a@b.c'}).shareCustomFoods,
        isFalse,
      );
    });

    test('il consenso sopravvive al giro toJson -> fromJson', () {
      // goal_page salva passando da toJson: un campo non emesso si azzera in
      // silenzio, ed e' gia' successo con created_at (vedi user_model.dart).
      final u = UserModel(
        id: 1,
        email: 'a@b.c',
        createdAt: DateTime(2026, 1, 1),
        shareCustomFoods: true,
      );
      expect(UserModel.fromJson(u.toJson()).shareCustomFoods, isTrue);
    });
  });

  // ------------------------------------------------------------------
  // Le mie segnalazioni (13/09)
  //
  // Lo stato che vede l'utente si ricava da tre campi (status, campi proposti,
  // campi accettati): se uno si perde lungo la strada, "accettata in parte"
  // diventa "accettata" o il contrario, e nessuno se ne accorge guardando.
  // ------------------------------------------------------------------
  group('segnalazioni', () {
    Map<String, dynamic> base() => {
          'id': 7,
          'food_name': 'Biscotti integrali',
          'barcode': '8005566778899',
          'issue': 'valori',
          'kind': 'correzione',
          'status': 'accepted',
          'created_at': '2026-09-07 10:15:00',
          'reviewed_at': '2026-09-08 09:00:00',
          'review_note': null,
          'proposed_fields': ['calories', 'sugars', 'fats'],
          'accepted_fields': ['calories'],
          'photos': [
            {'url': 'https://x/uploads/a.jpg', 'role': 'tabella'},
            {'url': 'https://x/uploads/b.jpg', 'role': 'fronte'},
          ],
        };

    test("legge tutti i campi dal formato del server", () {
      final s = SegnalazioneUtente.fromJson(base());
      expect(s.id, 7);
      expect(s.foodName, 'Biscotti integrali');
      expect(s.proposedFields, ['calories', 'sugars', 'fats']);
      expect(s.acceptedFields, ['calories']);
      expect(s.photoCount, 2);
      expect(s.createdAt, DateTime(2026, 9, 7, 10, 15));
      expect(s.reviewNote, '');
    });

    test("uno su tre accettato e' in parte, tre su tre no", () {
      expect(SegnalazioneUtente.fromJson(base()).accettataInParte, isTrue);
      final tutti = base()..['accepted_fields'] = ['calories', 'sugars', 'fats'];
      expect(SegnalazioneUtente.fromJson(tutti).accettataInParte, isFalse);
    });

    test("una rifiutata non e' mai in parte, e porta la motivazione", () {
      final rifiutata = base()
        ..['status'] = 'rejected'
        ..['accepted_fields'] = <String>[]
        ..['review_note'] = 'La foto non mostra la tabella.';
      final s = SegnalazioneUtente.fromJson(rifiutata);
      expect(s.accettataInParte, isFalse);
      expect(s.reviewNote, 'La foto non mostra la tabella.');
    });

    test("accettata senza proposta di valori non e' in parte", () {
      final senza = base()
        ..['issue'] = 'categoria'
        ..['proposed_fields'] = <String>[]
        ..['accepted_fields'] = <String>[];
      expect(SegnalazioneUtente.fromJson(senza).accettataInParte, isFalse);
    });

    test("uno stato sconosciuto si legge come in attesa, mai come accettata", () {
      final strano = base()..['status'] = 'qualcosa_di_nuovo';
      expect(SegnalazioneUtente.fromJson(strano).status, 'pending');
    });
  });
}
