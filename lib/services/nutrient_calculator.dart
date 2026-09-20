class NutrientCalculator {
  static Map<String, double> calculateAutomaticGoals({
    required double currentWeight,
    required double targetWeight,
    required double height,
    required int age,
    required String gender,
  }) {
    // Calcolo del metabolismo basale (Mifflin-St Jeor)
    double bmr;
    if (gender.toLowerCase() == 'uomo') {
      bmr = (10 * currentWeight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * currentWeight) + (6.25 * height) - (5 * age) - 161;
    }

    // Calcolo del fabbisogno calorico giornaliero (TDEE)
    double tdee = bmr * 1.375;

    // Regolazione in base all'obiettivo (dimagrimento o aumento peso)
    double dailyCalories;
    if (targetWeight < currentWeight) {
      // Weight loss: -500 kcal for approx 0.5kg/week
      dailyCalories = tdee - 500;
      // Safety floor (don't go below starvation levels)
      if (gender.toLowerCase() == 'uomo' && dailyCalories < 1500) dailyCalories = 1500;
      if (gender.toLowerCase() != 'uomo' && dailyCalories < 1200) dailyCalories = 1200;
    } else if (targetWeight > currentWeight) {
      // Weight gain: +300 kcal
      dailyCalories = tdee + 300;
    } else {
      // Maintenance
      dailyCalories = tdee;
    }

    // Ripartizione dei macronutrienti
    // Protein: 1.8g per kg (good for satiety and muscle retention)
    double proteinGrams = currentWeight * 1.8;
    // Fat: 0.8g per kg (healthy fats)
    double fatGrams = currentWeight * 0.8;
    // Carbs: remainder
    double proteinKcal = proteinGrams * 4;
    double fatKcal = fatGrams * 9;
    double carbKcal = dailyCalories - proteinKcal - fatKcal;
    
    // Ensure carbs don't go too low
    if (carbKcal < 100 * 4) {
      carbKcal = 100 * 4;
      // If we adjusted carbs up, we might need to lower fats or proteins to keep calories,
      // but usually 100g carbs is fine.
    }
    double carbGrams = carbKcal / 4;

    // Final caloric adjustment based on exact macros
    double finalCalories = (proteinGrams * 4) + (fatGrams * 9) + (carbGrams * 4);

    return {
      'calorie_goal': finalCalories,
      'protein_goal': proteinGrams,
      'fat_goal': fatGrams,
      'carb_goal': carbGrams,
      'fiber_goal': (finalCalories / 1000) * 14, // 14g per 1000kcal
      'sugar_max': (finalCalories * 0.1) / 4,    // Max 10% of kcal
      'saturated_fats_goal': (finalCalories * 0.1) / 9, // Max 10% of kcal
      'sodium_max': 2300.0,
      'cholesterol_max': 300.0,
    };
  }
}
