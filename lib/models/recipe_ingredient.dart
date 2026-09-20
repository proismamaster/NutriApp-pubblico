import 'macronutrients.dart';
import 'fats.dart';
import 'vitamins.dart';
import 'minerals.dart';

/// Modello del singolo ingrediente della ricetta
///
/// FIX 2026-07-24 (bug reale trovato, non solo la richiesta di isma):
/// `fromJson` leggeva chiavi con prefisso 'tot_' (es. 'tot_saturated',
/// 'tot_vit_a') che non esistono da nessuna parte nella pipeline reale —
/// né in ManualEntryPage._handleSave (che manda le chiavi "nude" di
/// Fats/Minerals/Vitamins.toJson()), né nella tabella na_recipe_ingredients
/// (colonne senza prefisso). Risultato: ogni ingrediente aggiunto a una
/// ricetta perdeva silenziosamente grassi dettagliati/vitamine/minerali,
/// azzerati a 0. Ora si delega ai fromJson dei modelli figli, che usano le
/// chiavi corrette (e sono l'unica fonte di verità per quel mapping).
///
/// Aggiunti anche i 14 campi extra OpenFoodFacts (Nutri-Score, NOVA,
/// additivi, allergeni, ecc.) cosi' un ingrediente trovato da na_off_products
/// non li perde più quando diventa un ingrediente di ricetta. Richiede le
/// nuove colonne su na_recipe_ingredients (vedi ALTER TABLE in PROBLEMS.md).
class RecipeIngredient {
  String name;
  String unit;
  double weight_g;
  Macronutrients macro;
  Fats fats;
  Minerals minerals;
  Vitamins vitamins;

  // Metadati OpenFoodFacts (vuoti/0 per ingredienti CREA/USDA/personali).
  String nutriscoreGrade;
  int novaGroup;
  int additivesN;
  String allergens;
  String labels;
  int palmOilN;
  int palmOilMaybeN;
  String imageUrl;
  String servingSize;
  String categories;
  String manufacturingPlaces;
  String ingredientsText;
  double alcoholPercent;
  double caffeine;
  String barcode;

  RecipeIngredient({
    required this.name,
    required this.unit,
    this.weight_g = 0.0,
    this.macro = const Macronutrients(),
    this.fats = const Fats(),
    this.minerals = const Minerals(),
    this.vitamins = const Vitamins(),
    this.nutriscoreGrade = '',
    this.novaGroup = 0,
    this.additivesN = 0,
    this.allergens = '',
    this.labels = '',
    this.palmOilN = 0,
    this.palmOilMaybeN = 0,
    this.imageUrl = '',
    this.servingSize = '',
    this.categories = '',
    this.manufacturingPlaces = '',
    this.ingredientsText = '',
    this.alcoholPercent = 0.0,
    this.caffeine = 0.0,
    this.barcode = '',
  });

  // Clona l'oggetto
  RecipeIngredient copy() => RecipeIngredient(
    name: name,
    unit: unit,
    weight_g: weight_g,
    macro: macro,
    fats: fats,
    minerals: minerals,
    vitamins: vitamins,
    nutriscoreGrade: nutriscoreGrade,
    novaGroup: novaGroup,
    additivesN: additivesN,
    allergens: allergens,
    labels: labels,
    palmOilN: palmOilN,
    palmOilMaybeN: palmOilMaybeN,
    imageUrl: imageUrl,
    servingSize: servingSize,
    categories: categories,
    manufacturingPlaces: manufacturingPlaces,
    ingredientsText: ingredientsText,
    alcoholPercent: alcoholPercent,
    caffeine: caffeine,
    barcode: barcode,
  );

  // Da Dart a JSON (Per salvare nel DB)
  Map<String, dynamic> toJson() {
    return {
      'food_name': name,
      'unit': unit,
      'weight_g': weight_g,
      ...macro.toJson(),
      ...fats.toJson(),
      ...minerals.toJson(),
      ...vitamins.toJson(),
      'nutriscore_grade': nutriscoreGrade,
      'nova_group': novaGroup,
      'additives_n': additivesN,
      'allergens': allergens,
      'labels': labels,
      'palm_oil_n': palmOilN,
      'palm_oil_maybe_n': palmOilMaybeN,
      'image_url': imageUrl,
      'serving_size': servingSize,
      'categories': categories,
      'manufacturing_places': manufacturingPlaces,
      'ingredients': ingredientsText,
      'alcohol_percent': alcoholPercent,
      'caffeine': caffeine,
      'barcode': barcode,
    };
  }

  // Da JSON a Dart (Per scaricare dal DB)
  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    double d(String key) => double.tryParse(json[key]?.toString() ?? '') ?? 0.0;
    int i(String key) {
      final v = json[key];
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? (d(key)).toInt();
    }
    String s(String key) => (json[key] ?? '').toString();

    return RecipeIngredient(
      name: json['food_name'] ?? 'Sconosciuto',
      unit: json['unit'] ?? 'g',
      weight_g: double.tryParse(json['weight_g'].toString()) ?? 0.0,
      macro: Macronutrients.fromJson(json),
      fats: Fats.fromJson(json),
      minerals: Minerals.fromJson(json),
      vitamins: Vitamins.fromJson(json),
      nutriscoreGrade: s('nutriscore_grade'),
      novaGroup: i('nova_group'),
      additivesN: i('additives_n'),
      allergens: s('allergens'),
      labels: s('labels'),
      palmOilN: i('palm_oil_n'),
      palmOilMaybeN: i('palm_oil_maybe_n'),
      imageUrl: s('image_url'),
      servingSize: s('serving_size'),
      categories: s('categories'),
      manufacturingPlaces: s('manufacturing_places'),
      ingredientsText: s('ingredients'),
      alcoholPercent: d('alcohol_percent'),
      caffeine: d('caffeine'),
      barcode: s('barcode'),
    );
  }
}
