// models/user_model.dart

class UserModel {
  // Dati anagrafici
  final int id;
  final String email;
  final String? firstName;
  final String? lastName;
  final double? weight;
  final double? height;
  final String? gender;
  final DateTime? birthDate;
  final String language;
  final String? profileImage;
  final DateTime createdAt;

  /// Consenso a proporre i propri alimenti personali al database pubblico
  /// (2026-09-12). Proporre, non pubblicare: gli alimenti passano in attesa e
  /// li vede solo chi rivede, finche' non sono approvati.
  ///
  /// Arriva da `na_users.share_custom_foods`. Su un server ancora senza quella
  /// colonna la chiave non c'e' e vale `false`: il default giusto per un
  /// consenso e' "non dato".
  final bool shareCustomFoods;

  // Obiettivi nutrizionali (Macro)
  final double currentWeight;
  final double targetWeight;
  final double calorieGoal;
  final double proteinGoal;
  final double fatGoal;
  final double carbGoal;
  final double waterGoal;
  final double fiberGoal;
  final double sugarMax;
  final double saturatedFatsGoal;
  final double monounsaturatedFatsGoal;
  final double polyunsaturatedFatsGoal;
  final double transFatsMax;
  final double cholesterolMax;
  final double sodiumMax;

  // Obiettivi micronutrienti (Vitamine)
  final double vitAGoal;
  final double vitB1Goal;
  final double vitB2Goal;
  final double vitB3Goal;
  final double vitB5Goal;
  final double vitB6Goal;
  final double vitB7Goal;
  final double vitB9Goal;
  final double vitB11Goal;
  final double vitB12Goal;
  final double vitCGoal;
  final double vitDGoal;
  final double vitEGoal;
  final double vitKGoal;

  // Obiettivi micronutrienti (Minerali)
  final double arsenicGoal;
  final double biotinGoal;
  final double boronGoal;
  final double calciumGoal;
  final double chlorideGoal;
  final double cholineGoal;
  final double chromiumGoal;
  final double cobaltGoal;
  final double copperGoal;
  final double fluorideGoal;
  final double fluorineGoal;
  final double iodineGoal;
  final double ironGoal;
  final double magnesiumGoal;
  final double manganeseGoal;
  final double molybdenumGoal;
  final double phosphorusGoal;
  final double potassiumGoal;
  final double seleniumGoal;
  final double siliconGoal;
  final double sulfurGoal;
  final double tinGoal;
  final double vanadiumGoal;
  final double zincGoal;

  const UserModel({
    // Anagrafica
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.weight,
    this.height,
    this.gender,
    this.birthDate,
    this.language = 'Italiano',
    this.profileImage,
    required this.createdAt,
    // Macro
    this.currentWeight = 0,
    this.targetWeight = 0,
    this.calorieGoal = 0,
    this.proteinGoal = 0,
    this.fatGoal = 0,
    this.carbGoal = 0,
    this.waterGoal = 0,
    this.fiberGoal = 0,
    this.sugarMax = 0,
    this.saturatedFatsGoal = 0,
    this.monounsaturatedFatsGoal = 0,
    this.polyunsaturatedFatsGoal = 0,
    this.transFatsMax = 0,
    this.cholesterolMax = 0,
    this.sodiumMax = 0,
    // Vitamine
    this.vitAGoal = 0,
    this.vitB1Goal = 0,
    this.vitB2Goal = 0,
    this.vitB3Goal = 0,
    this.vitB5Goal = 0,
    this.vitB6Goal = 0,
    this.vitB7Goal = 0,
    this.vitB9Goal = 0,
    this.vitB11Goal = 0,
    this.vitB12Goal = 0,
    this.vitCGoal = 0,
    this.vitDGoal = 0,
    this.vitEGoal = 0,
    this.vitKGoal = 0,
    // Minerali
    this.arsenicGoal = 0,
    this.biotinGoal = 0,
    this.boronGoal = 0,
    this.calciumGoal = 0,
    this.chlorideGoal = 0,
    this.cholineGoal = 0,
    this.chromiumGoal = 0,
    this.cobaltGoal = 0,
    this.copperGoal = 0,
    this.fluorideGoal = 0,
    this.fluorineGoal = 0,
    this.iodineGoal = 0,
    this.ironGoal = 0,
    this.magnesiumGoal = 0,
    this.manganeseGoal = 0,
    this.molybdenumGoal = 0,
    this.phosphorusGoal = 0,
    this.potassiumGoal = 0,
    this.seleniumGoal = 0,
    this.siliconGoal = 0,
    this.sulfurGoal = 0,
    this.tinGoal = 0,
    this.vanadiumGoal = 0,
    this.zincGoal = 0,
    this.shareCustomFoods = false,
  });

  // Creazione dell'oggetto da JSON (risposta del server)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    double p(String key) => double.tryParse(json[key]?.toString() ?? '0') ?? 0;

    return UserModel(
      // Anagrafica
      id: int.tryParse(json['id'].toString()) ?? 0,
      email: json['email'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      weight: double.tryParse(json['weight']?.toString() ?? ''),
      height: double.tryParse(json['height']?.toString() ?? ''),
      gender: json['gender'],
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'])
          : null,
      language: json['language'] ?? 'Italiano',
      profileImage: json['profile_image'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      // 1, "1", true, "true": il valore passa da MySQL (tinyint) e da JSON, e
      // arriva in forme diverse a seconda di quale endpoint risponde.
      shareCustomFoods: json['share_custom_foods'] == 1 ||
          json['share_custom_foods'] == true ||
          json['share_custom_foods']?.toString() == '1' ||
          json['share_custom_foods']?.toString() == 'true',
      currentWeight: p('current_weight'),
      targetWeight: p('target_weight'),
      calorieGoal: p('calorie_goal'),
      proteinGoal: p('protein_goal'),
      fatGoal: p('fat_goal'),
      carbGoal: p('carb_goal'),
      waterGoal: p('water_goal'),
      fiberGoal: p('fiber_goal'),
      sugarMax: p('sugar_max'),
      saturatedFatsGoal: p('saturated_fats_goal'),
      monounsaturatedFatsGoal: p('monounsaturated_fats_goal'),
      polyunsaturatedFatsGoal: p('polyunsaturated_fats_goal'),
      transFatsMax: p('trans_fats_max'),
      cholesterolMax: p('cholesterol_max'),
      sodiumMax: p('sodium_max'),
      // Vitamine
      vitAGoal: p('vit_a_goal'),
      vitB1Goal: p('vit_b1_goal'),
      vitB2Goal: p('vit_b2_goal'),
      vitB3Goal: p('vit_b3_goal'),
      vitB5Goal: p('vit_b5_goal'),
      vitB6Goal: p('vit_b6_goal'),
      vitB7Goal: p('vit_b7_goal'),
      vitB9Goal: p('vit_b9_goal'),
      vitB11Goal: p('vit_b11_goal'),
      vitB12Goal: p('vit_b12_goal'),
      vitCGoal: p('vit_c_goal'),
      vitDGoal: p('vit_d_goal'),
      vitEGoal: p('vit_e_goal'),
      vitKGoal: p('vit_k_goal'),
      // Minerali
      arsenicGoal: p('arsenic_goal'),
      biotinGoal: p('biotin_goal'),
      boronGoal: p('boron_goal'),
      calciumGoal: p('calcium_goal'),
      chlorideGoal: p('chloride_goal'),
      cholineGoal: p('choline_goal'),
      chromiumGoal: p('chromium_goal'),
      cobaltGoal: p('cobalt_goal'),
      copperGoal: p('copper_goal'),
      fluorideGoal: p('fluoride_goal'),
      fluorineGoal: p('fluorine_goal'),
      iodineGoal: p('iodine_goal'),
      ironGoal: p('iron_goal'),
      magnesiumGoal: p('magnesium_goal'),
      manganeseGoal: p('manganese_goal'),
      molybdenumGoal: p('molybdenum_goal'),
      phosphorusGoal: p('phosphorus_goal'),
      potassiumGoal: p('potassium_goal'),
      seleniumGoal: p('selenium_goal'),
      siliconGoal: p('silicon_goal'),
      sulfurGoal: p('sulfur_goal'),
      tinGoal: p('tin_goal'),
      vanadiumGoal: p('vanadium_goal'),
      zincGoal: p('zinc_goal'),
    );
  }

  // Conversione in JSON per il database
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'weight': weight,
    'height': height,
    'gender': gender,
    'birth_date': birthDate?.toIso8601String().split('T').first,
    'language': language,
    'profile_image': profileImage,
    // Emesso perché `fromJson` lo legge: senza, il giro
    // toJson -> modifica -> fromJson usato in goal_page._saveGoals perdeva
    // la data di registrazione e la rimpiazzava con "adesso". Oggi
    // `createdAt` non è mostrato da nessuna schermata (quindi nessun danno
    // visibile) e non viene comunque inviato al server da updateGoals, ma
    // lasciare un campo che si azzera da solo è una trappola per dopo.
    'created_at': createdAt.toIso8601String(),
    'share_custom_foods': shareCustomFoods ? 1 : 0,
    'current_weight': currentWeight,
    'target_weight': targetWeight,
    'calorie_goal': calorieGoal,
    'protein_goal': proteinGoal,
    'fat_goal': fatGoal,
    'carb_goal': carbGoal,
    'water_goal': waterGoal,
    'fiber_goal': fiberGoal,
    'sugar_max': sugarMax,
    'saturated_fats_goal': saturatedFatsGoal,
    'monounsaturated_fats_goal': monounsaturatedFatsGoal,
    'polyunsaturated_fats_goal': polyunsaturatedFatsGoal,
    'trans_fats_max': transFatsMax,
    'cholesterol_max': cholesterolMax,
    'sodium_max': sodiumMax,
    'vit_a_goal': vitAGoal,
    'vit_b1_goal': vitB1Goal,
    'vit_b2_goal': vitB2Goal,
    'vit_b3_goal': vitB3Goal,
    'vit_b5_goal': vitB5Goal,
    'vit_b6_goal': vitB6Goal,
    'vit_b7_goal': vitB7Goal,
    'vit_b9_goal': vitB9Goal,
    'vit_b11_goal': vitB11Goal,
    'vit_b12_goal': vitB12Goal,
    'vit_c_goal': vitCGoal,
    'vit_d_goal': vitDGoal,
    'vit_e_goal': vitEGoal,
    'vit_k_goal': vitKGoal,
    'arsenic_goal': arsenicGoal,
    'biotin_goal': biotinGoal,
    'boron_goal': boronGoal,
    'calcium_goal': calciumGoal,
    'chloride_goal': chlorideGoal,
    'choline_goal': cholineGoal,
    'chromium_goal': chromiumGoal,
    'cobalt_goal': cobaltGoal,
    'copper_goal': copperGoal,
    'fluoride_goal': fluorideGoal,
    'fluorine_goal': fluorineGoal,
    'iodine_goal': iodineGoal,
    'iron_goal': ironGoal,
    'magnesium_goal': magnesiumGoal,
    'manganese_goal': manganeseGoal,
    'molybdenum_goal': molybdenumGoal,
    'phosphorus_goal': phosphorusGoal,
    'potassium_goal': potassiumGoal,
    'selenium_goal': seleniumGoal,
    'silicon_goal': siliconGoal,
    'sulfur_goal': sulfurGoal,
    'tin_goal': tinGoal,
    'vanadium_goal': vanadiumGoal,
    'zinc_goal': zincGoal,
  };

  UserModel copyWith({
    int? id,
    String? email,
    String? firstName,
    String? lastName,
    double? weight,
    double? height,
    String? gender,
    DateTime? birthDate,
    String? language,
    String? profileImage,
    DateTime? createdAt,
    bool? shareCustomFoods,
    double? currentWeight,
    double? targetWeight,
    double? calorieGoal,
    double? proteinGoal,
    double? fatGoal,
    double? carbGoal,
    double? waterGoal,
    double? fiberGoal,
    double? sugarMax,
    double? saturatedFatsGoal,
    double? monounsaturatedFatsGoal,
    double? polyunsaturatedFatsGoal,
    double? transFatsMax,
    double? cholesterolMax,
    double? sodiumMax,
    double? vitAGoal,
    double? vitB1Goal,
    double? vitB2Goal,
    double? vitB3Goal,
    double? vitB5Goal,
    double? vitB6Goal,
    double? vitB7Goal,
    double? vitB9Goal,
    double? vitB11Goal,
    double? vitB12Goal,
    double? vitCGoal,
    double? vitDGoal,
    double? vitEGoal,
    double? vitKGoal,
    double? arsenicGoal,
    double? biotinGoal,
    double? boronGoal,
    double? calciumGoal,
    double? chlorideGoal,
    double? cholineGoal,
    double? chromiumGoal,
    double? cobaltGoal,
    double? copperGoal,
    double? fluorideGoal,
    double? fluorineGoal,
    double? iodineGoal,
    double? ironGoal,
    double? magnesiumGoal,
    double? manganeseGoal,
    double? molybdenumGoal,
    double? phosphorusGoal,
    double? potassiumGoal,
    double? seleniumGoal,
    double? siliconGoal,
    double? sulfurGoal,
    double? tinGoal,
    double? vanadiumGoal,
    double? zincGoal,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      language: language ?? this.language,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      shareCustomFoods: shareCustomFoods ?? this.shareCustomFoods,
      currentWeight: currentWeight ?? this.currentWeight,
      targetWeight: targetWeight ?? this.targetWeight,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      carbGoal: carbGoal ?? this.carbGoal,
      waterGoal: waterGoal ?? this.waterGoal,
      fiberGoal: fiberGoal ?? this.fiberGoal,
      sugarMax: sugarMax ?? this.sugarMax,
      saturatedFatsGoal: saturatedFatsGoal ?? this.saturatedFatsGoal,
      monounsaturatedFatsGoal:
          monounsaturatedFatsGoal ?? this.monounsaturatedFatsGoal,
      polyunsaturatedFatsGoal:
          polyunsaturatedFatsGoal ?? this.polyunsaturatedFatsGoal,
      transFatsMax: transFatsMax ?? this.transFatsMax,
      cholesterolMax: cholesterolMax ?? this.cholesterolMax,
      sodiumMax: sodiumMax ?? this.sodiumMax,
      vitAGoal: vitAGoal ?? this.vitAGoal,
      vitB1Goal: vitB1Goal ?? this.vitB1Goal,
      vitB2Goal: vitB2Goal ?? this.vitB2Goal,
      vitB3Goal: vitB3Goal ?? this.vitB3Goal,
      vitB5Goal: vitB5Goal ?? this.vitB5Goal,
      vitB6Goal: vitB6Goal ?? this.vitB6Goal,
      vitB7Goal: vitB7Goal ?? this.vitB7Goal,
      vitB9Goal: vitB9Goal ?? this.vitB9Goal,
      vitB11Goal: vitB11Goal ?? this.vitB11Goal,
      vitB12Goal: vitB12Goal ?? this.vitB12Goal,
      vitCGoal: vitCGoal ?? this.vitCGoal,
      vitDGoal: vitDGoal ?? this.vitDGoal,
      vitEGoal: vitEGoal ?? this.vitEGoal,
      vitKGoal: vitKGoal ?? this.vitKGoal,
      arsenicGoal: arsenicGoal ?? this.arsenicGoal,
      biotinGoal: biotinGoal ?? this.biotinGoal,
      boronGoal: boronGoal ?? this.boronGoal,
      calciumGoal: calciumGoal ?? this.calciumGoal,
      chlorideGoal: chlorideGoal ?? this.chlorideGoal,
      cholineGoal: cholineGoal ?? this.cholineGoal,
      chromiumGoal: chromiumGoal ?? this.chromiumGoal,
      cobaltGoal: cobaltGoal ?? this.cobaltGoal,
      copperGoal: copperGoal ?? this.copperGoal,
      fluorideGoal: fluorideGoal ?? this.fluorideGoal,
      fluorineGoal: fluorineGoal ?? this.fluorineGoal,
      iodineGoal: iodineGoal ?? this.iodineGoal,
      ironGoal: ironGoal ?? this.ironGoal,
      magnesiumGoal: magnesiumGoal ?? this.magnesiumGoal,
      manganeseGoal: manganeseGoal ?? this.manganeseGoal,
      molybdenumGoal: molybdenumGoal ?? this.molybdenumGoal,
      phosphorusGoal: phosphorusGoal ?? this.phosphorusGoal,
      potassiumGoal: potassiumGoal ?? this.potassiumGoal,
      seleniumGoal: seleniumGoal ?? this.seleniumGoal,
      siliconGoal: siliconGoal ?? this.siliconGoal,
      sulfurGoal: sulfurGoal ?? this.sulfurGoal,
      tinGoal: tinGoal ?? this.tinGoal,
      vanadiumGoal: vanadiumGoal ?? this.vanadiumGoal,
      zincGoal: zincGoal ?? this.zincGoal,
    );
  }
}
