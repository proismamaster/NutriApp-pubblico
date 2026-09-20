class NutrientLimits {
  final double? calories;
  final double? carbs;
  final double? proteins;
  final double? fats;
  final double? sugars;
  final double? fibers;
  final double? saturatedFats;
  final double? monounsaturatedFats;
  final double? polyunsaturatedFats;
  final double? transFats;
  final double? cholesterol;

  final double? vitaminA;
  final double? vitaminB1;
  final double? vitaminB2;
  final double? vitaminB3;
  final double? vitaminB5;
  final double? vitaminB6;
  final double? vitaminB7;
  final double? vitaminB9;
  final double? vitaminB11;
  final double? vitaminB12;
  final double? vitaminC;
  final double? vitaminD;
  final double? vitaminE;
  final double? vitaminK;

  final double? calcium;
  final double? iron;
  final double? potassium;
  final double? magnesium;
  final double? zinc;
  final double? sodium;
  final double? phosphorus;
  final double? selenium;
  final double? iodine;

  const NutrientLimits({
    this.calories,
    this.carbs,
    this.proteins,
    this.fats,
    this.sugars,
    this.fibers,
    this.saturatedFats,
    this.monounsaturatedFats,
    this.polyunsaturatedFats,
    this.transFats,
    this.cholesterol,
    this.vitaminA,
    this.vitaminB1,
    this.vitaminB2,
    this.vitaminB3,
    this.vitaminB5,
    this.vitaminB6,
    this.vitaminB7,
    this.vitaminB9,
    this.vitaminB11,
    this.vitaminB12,
    this.vitaminC,
    this.vitaminD,
    this.vitaminE,
    this.vitaminK,
    this.calcium,
    this.iron,
    this.potassium,
    this.magnesium,
    this.zinc,
    this.sodium,
    this.phosphorus,
    this.selenium,
    this.iodine,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};

    void write(String key, double? value) {
      if (value != null) {
        data[key] = value;
      }
    }

    write('calories', calories);
    write('carbs', carbs);
    write('proteins', proteins);
    write('fats', fats);
    write('sugars', sugars);
    write('fibers', fibers);
    write('saturated_fats', saturatedFats);
    write('monounsaturated_fats', monounsaturatedFats);
    write('polyunsaturated_fats', polyunsaturatedFats);
    write('trans_fats', transFats);
    write('cholesterol', cholesterol);
    write('vitamin_a', vitaminA);
    write('vitamin_b1', vitaminB1);
    write('vitamin_b2', vitaminB2);
    write('vitamin_b3', vitaminB3);
    write('vitamin_b5', vitaminB5);
    write('vitamin_b6', vitaminB6);
    write('vitamin_b7', vitaminB7);
    write('vitamin_b9', vitaminB9);
    write('vitamin_b11', vitaminB11);
    write('vitamin_b12', vitaminB12);
    write('vitamin_c', vitaminC);
    write('vitamin_d', vitaminD);
    write('vitamin_e', vitaminE);
    write('vitamin_k', vitaminK);
    write('calcium', calcium);
    write('iron', iron);
    write('potassium', potassium);
    write('magnesium', magnesium);
    write('zinc', zinc);
    write('sodium', sodium);
    write('phosphorus', phosphorus);
    write('selenium', selenium);
    write('iodine', iodine);

    return data;
  }

  factory NutrientLimits.fromJson(Map<String, dynamic> json) {
    double? parse(dynamic value) {
      if (value == null) return null;
      final text = value.toString().replaceAll(',', '.').trim();
      return text.isEmpty ? null : double.tryParse(text);
    }

    return NutrientLimits(
      calories: parse(json['calories']),
      carbs: parse(json['carbs']),
      proteins: parse(json['proteins']),
      fats: parse(json['fats']),
      sugars: parse(json['sugars']),
      fibers: parse(json['fibers']),
      saturatedFats: parse(json['saturated_fats']),
      monounsaturatedFats: parse(json['monounsaturated_fats']),
      polyunsaturatedFats: parse(json['polyunsaturated_fats']),
      transFats: parse(json['trans_fats']),
      cholesterol: parse(json['cholesterol']),
      vitaminA: parse(json['vitamin_a']),
      vitaminB1: parse(json['vitamin_b1']),
      vitaminB2: parse(json['vitamin_b2']),
      vitaminB3: parse(json['vitamin_b3']),
      vitaminB5: parse(json['vitamin_b5']),
      vitaminB6: parse(json['vitamin_b6']),
      vitaminB7: parse(json['vitamin_b7']),
      vitaminB9: parse(json['vitamin_b9']),
      vitaminB11: parse(json['vitamin_b11']),
      vitaminB12: parse(json['vitamin_b12']),
      vitaminC: parse(json['vitamin_c']),
      vitaminD: parse(json['vitamin_d']),
      vitaminE: parse(json['vitamin_e']),
      vitaminK: parse(json['vitamin_k']),
      calcium: parse(json['calcium']),
      iron: parse(json['iron']),
      potassium: parse(json['potassium']),
      magnesium: parse(json['magnesium']),
      zinc: parse(json['zinc']),
      sodium: parse(json['sodium']),
      phosphorus: parse(json['phosphorus']),
      selenium: parse(json['selenium']),
      iodine: parse(json['iodine']),
    );
  }
}
