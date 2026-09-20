import 'minerals.dart';
import 'vitamins.dart';
import 'fats.dart';
import 'macronutrients.dart';

class CustomFood {
  final int? id;
  final String user_mail;
  final String food_name;
  final String? barcode;
  final double base_weight_g;
  final Macronutrients macro;
  final Fats fats;
  final Minerals minerals;
  final Vitamins vitamins;
  final bool isFavorite;

  /// Visibilita' dell'alimento agli altri utenti (2026-09-12):
  /// `private` · `pending` (proposto) · `approved` (nel database pubblico) ·
  /// `rejected`. La decide il server; l'app la cambia solo con
  /// share_custom_food.php o con il consenso generale, mai salvando.
  final String sharedStatus;

  /// Foto e descrizione personalizzabili dall'utente (2026-07-24): quando si
  /// salva in libreria un alimento personalizzato, si può cambiare la foto
  /// (URL) e aggiungere una nota/descrizione libera.
  final String imageUrl;
  final String description;

  /// Metadati OpenFoodFacts (2026-07-24). Prima venivano persi: salvando in
  /// libreria un prodotto trovato dalla ricerca, Nutri-Score/NOVA/allergeni
  /// e compagnia sparivano e l'alimento salvato risultava più povero
  /// dell'originale. Stesso bug già corretto per gli ingredienti delle
  /// ricette, qui era rimasto aperto.
  ///
  /// ATTENZIONE: questi campi devono restare in `toJson()`, perché
  /// save_custom_food.php riscrive SEMPRE tutte queste colonne ad ogni
  /// salvataggio — se il modello smettesse di mandarle, un normale
  /// salvataggio le azzererebbe sul server.
  ///
  /// Richiedono le nuove colonne su na_custom_foods (ALTER TABLE completa
  /// nel docblock di fileDatabase/custom_food_columns.php).
  final String nutriscoreGrade;
  final int novaGroup;
  final int additivesN;
  final String allergens;
  final String labels;
  final int palmOilN;
  final int palmOilMaybeN;
  final String servingSize;
  final String categories;
  final String manufacturingPlaces;
  final String ingredientsText;
  final double alcoholPercent;
  final double caffeine;

  /// Campi aggiunti il 2026-08-30 con la migrazione
  /// `2026-08-29_alimenti_personali_completi.sql`, perche' un alimento creato
  /// a mano possa contenere tutto cio' che la ricerca restituisce piu' i dati
  /// di confezione del mockup "New product".
  ///
  /// I tre nullable non sono `double`/`int` con default 0 di proposito:
  /// `servings` a 0 significherebbe "zero porzioni" invece di "non lo so", e
  /// romperebbe il calcolo della porzione; 0 e' un valore legittimo per
  /// `nutriscoreScore` e non puo' fare da segnaposto per "assente".
  final String brand;
  final String environmentalScoreGrade;
  final String nutrientLevelsTags;
  final String quantity;
  final String packaging;
  final String additivesTags;
  final String? bestBefore;
  final int? nutriscoreScore;
  final double? netQuantityG;
  final int? servings;
  final double addedSugars;
  final double starch;
  final double polyols;
  final double lactose;

  const CustomFood({
    this.id,
    required this.user_mail,
    required this.food_name,
    this.barcode,
    this.base_weight_g = 100.0,
    this.macro = const Macronutrients(),
    this.fats = const Fats(),
    this.minerals = const Minerals(),
    this.vitamins = const Vitamins(),
    this.isFavorite = false,
    this.sharedStatus = 'private',
    this.imageUrl = '',
    this.description = '',
    this.nutriscoreGrade = '',
    this.novaGroup = 0,
    this.additivesN = 0,
    this.allergens = '',
    this.labels = '',
    this.palmOilN = 0,
    this.palmOilMaybeN = 0,
    this.servingSize = '',
    this.categories = '',
    this.manufacturingPlaces = '',
    this.ingredientsText = '',
    this.alcoholPercent = 0.0,
    this.caffeine = 0.0,
    this.brand = '',
    this.environmentalScoreGrade = '',
    this.nutrientLevelsTags = '',
    this.quantity = '',
    this.packaging = '',
    this.additivesTags = '',
    this.bestBefore,
    this.nutriscoreScore,
    this.netQuantityG,
    this.servings,
    this.addedSugars = 0.0,
    this.starch = 0.0,
    this.polyols = 0.0,
    this.lactose = 0.0,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'user_mail': user_mail,
    'food_name': food_name,
    if (barcode != null) 'barcode': barcode,
    'base_weight_g': base_weight_g,
    'is_favorite': isFavorite ? 1 : 0,
    'image_url': imageUrl,
    'description': description,
    'nutriscore_grade': nutriscoreGrade,
    'nova_group': novaGroup,
    'additives_n': additivesN,
    'allergens': allergens,
    'labels': labels,
    'palm_oil_n': palmOilN,
    'palm_oil_maybe_n': palmOilMaybeN,
    'serving_size': servingSize,
    'categories': categories,
    'manufacturing_places': manufacturingPlaces,
    'ingredients': ingredientsText,
    'alcohol_percent': alcoholPercent,
    'caffeine': caffeine,
    'brand': brand,
    'environmental_score_grade': environmentalScoreGrade,
    'nutrient_levels_tags': nutrientLevelsTags,
    'quantity': quantity,
    'packaging': packaging,
    'additives_tags': additivesTags,
    // I nullable vanno mandati anche quando sono null: save_custom_food.php
    // riscrive SEMPRE tutte le colonne, e un campo omesso verrebbe azzerato
    // invece di restare com'era.
    'best_before': bestBefore,
    'nutriscore_score': nutriscoreScore,
    'net_quantity_g': netQuantityG,
    'servings': servings,
    'added_sugars': addedSugars,
    'starch': starch,
    'polyols': polyols,
    'lactose': lactose,
    ...macro.toJson(),
    ...fats.toJson(),
    ...minerals.toJson(),
    ...vitamins.toJson(),
  };

  factory CustomFood.fromJson(Map<String, dynamic> json) {
    int asInt(String key) {
      final v = json[key];
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ??
          (double.tryParse(v?.toString() ?? '')?.toInt() ?? 0);
    }

    double asDouble(String key) {
      final v = json[key];
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    // I nullable devono distinguere "assente" da "zero": asInt/asDouble
    // restituiscono 0 anche per null, che qui sarebbe un dato inventato.
    int? asIntOrNull(String key) {
      final v = json[key];
      if (v == null || v.toString().trim().isEmpty) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? double.tryParse(v.toString())?.toInt();
    }

    double? asDoubleOrNull(String key) {
      final v = json[key];
      if (v == null || v.toString().trim().isEmpty) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    String? asStringOrNull(String key) {
      final v = json[key];
      if (v == null) return null;
      final t = v.toString().trim();
      return t.isEmpty ? null : t;
    }

    return CustomFood(
      id: int.tryParse(json['id'].toString()),
      user_mail: json['user_mail'] ?? '',
      food_name: json['food_name'] ?? '',
      barcode: json['barcode']?.toString(),
      base_weight_g: double.tryParse(json['base_weight_g'].toString()) ?? 100.0,
      isFavorite: (json['is_favorite'] == 1 || json['is_favorite'] == true),
      // Se il server e' indietro con la migrazione la chiave non c'e': privato.
      sharedStatus: (json['shared_status'] ?? 'private').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      nutriscoreGrade: (json['nutriscore_grade'] ?? '').toString(),
      novaGroup: asInt('nova_group'),
      additivesN: asInt('additives_n'),
      allergens: (json['allergens'] ?? '').toString(),
      labels: (json['labels'] ?? '').toString(),
      palmOilN: asInt('palm_oil_n'),
      palmOilMaybeN: asInt('palm_oil_maybe_n'),
      servingSize: (json['serving_size'] ?? '').toString(),
      categories: (json['categories'] ?? '').toString(),
      manufacturingPlaces: (json['manufacturing_places'] ?? '').toString(),
      ingredientsText: (json['ingredients'] ?? '').toString(),
      alcoholPercent: asDouble('alcohol_percent'),
      caffeine: asDouble('caffeine'),
      brand: (json['brand'] ?? '').toString(),
      environmentalScoreGrade: (json['environmental_score_grade'] ?? '').toString(),
      nutrientLevelsTags: (json['nutrient_levels_tags'] ?? '').toString(),
      quantity: (json['quantity'] ?? '').toString(),
      packaging: (json['packaging'] ?? '').toString(),
      additivesTags: (json['additives_tags'] ?? '').toString(),
      bestBefore: asStringOrNull('best_before'),
      nutriscoreScore: asIntOrNull('nutriscore_score'),
      netQuantityG: asDoubleOrNull('net_quantity_g'),
      servings: asIntOrNull('servings'),
      addedSugars: asDouble('added_sugars'),
      starch: asDouble('starch'),
      polyols: asDouble('polyols'),
      lactose: asDouble('lactose'),
      macro: Macronutrients(
        calories: double.tryParse(json['calories'].toString()) ?? 0.0,
        carbs: double.tryParse(json['carbs'].toString()) ?? 0.0,
        proteins: double.tryParse(json['proteins'].toString()) ?? 0.0,
        fats: double.tryParse(json['fats'].toString()) ?? 0.0,
        water: double.tryParse(json['water'].toString()) ?? 0.0,
        fibers: double.tryParse(json['fibers'].toString()) ?? 0.0,
        sugars: double.tryParse(json['sugars'].toString()) ?? 0.0,
      ),
      fats: Fats(
        saturated: double.tryParse(json['saturated_fats'].toString()) ?? 0.0,
        monounsaturated: double.tryParse(json['monounsaturated_fats'].toString()) ?? 0.0,
        polyunsaturated: double.tryParse(json['polyunsaturated_fats'].toString()) ?? 0.0,
        trans: double.tryParse(json['trans_fats'].toString()) ?? 0.0,
        cholesterol: double.tryParse(json['cholesterol'].toString()) ?? 0.0,
      ),
      minerals: Minerals(
        arsenic: double.tryParse(json['arsenic'].toString()) ?? 0.0,
        boron: double.tryParse(json['boron'].toString()) ?? 0.0,
        calcium: double.tryParse(json['calcium'].toString()) ?? 0.0,
        chloride: double.tryParse(json['chloride'].toString()) ?? 0.0,
        choline: double.tryParse(json['choline'].toString()) ?? 0.0,
        chromium: double.tryParse(json['chromium'].toString()) ?? 0.0,
        cobalt: double.tryParse(json['cobalt'].toString()) ?? 0.0,
        copper: double.tryParse(json['copper'].toString()) ?? 0.0,
        fluoride: double.tryParse(json['fluoride'].toString()) ?? 0.0,
        fluorine: double.tryParse(json['fluorine'].toString()) ?? 0.0,
        iodine: double.tryParse(json['iodine'].toString()) ?? 0.0,
        iron: double.tryParse(json['iron'].toString()) ?? 0.0,
        magnesium: double.tryParse(json['magnesium'].toString()) ?? 0.0,
        manganese: double.tryParse(json['manganese'].toString()) ?? 0.0,
        molybdenum: double.tryParse(json['molybdenum'].toString()) ?? 0.0,
        phosphorus: double.tryParse(json['phosphorus'].toString()) ?? 0.0,
        potassium: double.tryParse(json['potassium'].toString()) ?? 0.0,
        selenium: double.tryParse(json['selenium'].toString()) ?? 0.0,
        silicon: double.tryParse(json['silicon'].toString()) ?? 0.0,
        sulfur: double.tryParse(json['sulfur'].toString()) ?? 0.0,
        tin: double.tryParse(json['tin'].toString()) ?? 0.0,
        vanadium: double.tryParse(json['vanadium'].toString()) ?? 0.0,
        zinc: double.tryParse(json['zinc'].toString()) ?? 0.0,
      ),
      vitamins: Vitamins(
        a: double.tryParse(json['vit_a'].toString()) ?? 0.0,
        b1: double.tryParse(json['vit_b1'].toString()) ?? 0.0,
        b2: double.tryParse(json['vit_b2'].toString()) ?? 0.0,
        b3: double.tryParse(json['vit_b3'].toString()) ?? 0.0,
        b5: double.tryParse(json['vit_b5'].toString()) ?? 0.0,
        b6: double.tryParse(json['vit_b6'].toString()) ?? 0.0,
        b7: double.tryParse(json['vit_b7'].toString()) ?? 0.0,
        b9: double.tryParse(json['vit_b9'].toString()) ?? 0.0,
        b11: double.tryParse(json['vit_b11'].toString()) ?? 0.0,
        b12: double.tryParse(json['vit_b12'].toString()) ?? 0.0,
        c: double.tryParse(json['vit_c'].toString()) ?? 0.0,
        d: double.tryParse(json['vit_d'].toString()) ?? 0.0,
        e: double.tryParse(json['vit_e'].toString()) ?? 0.0,
        k: double.tryParse(json['vit_k'].toString()) ?? 0.0,
        biotin: double.tryParse(json['biotin'].toString()) ?? 0.0,
      ),
    );
  }
}
