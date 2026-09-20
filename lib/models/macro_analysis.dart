import '../logic/unit_format.dart';


import 'analysis_point.dart';

/// Analisi derivata sui macro aggregati.
///
/// Incapsula tutta la logica di quota energetica, macro dominante e possibili
/// incoerenze tra calorie registrate e calorie dedotte dai macronutrienti.
class MacroAnalysis {
  final double carbs;
  final double proteins;
  final double fats;
  final double loggedCalories;

  MacroAnalysis({
    required this.carbs,
    required this.proteins,
    required this.fats,
    required this.loggedCalories,
  });

  double get macroCalories => (carbs * 4) + (proteins * 4) + (fats * 9);

  /// True se nel periodo ci sono macronutrienti registrati.
  ///
  /// Quando è false, [dominantLabel]/[dominantEnergyShare] non hanno un
  /// significato reale (tutte le quote sono 0): i chiamanti devono
  /// controllare questo flag prima di mostrare un "macro predominante",
  /// altrimenti si rischia di dichiarare un vincitore su un confronto 0-0-0.
  bool get hasMacroData => macroCalories > 0;

  double get carbsEnergyShare =>
      macroCalories <= 0 ? 0 : (carbs * 4) / macroCalories;

  double get proteinsEnergyShare =>
      macroCalories <= 0 ? 0 : (proteins * 4) / macroCalories;

  double get fatsEnergyShare =>
      macroCalories <= 0 ? 0 : (fats * 9) / macroCalories;

  double get dominantEnergyShare => [
    carbsEnergyShare,
    proteinsEnergyShare,
    fatsEnergyShare,
  ].reduce((current, next) => current > next ? current : next);

  String get dominantLabel {
    if (fatsEnergyShare >= carbsEnergyShare &&
        fatsEnergyShare >= proteinsEnergyShare) {
      return 'Grassi';
    }
    if (proteinsEnergyShare >= carbsEnergyShare) {
      return 'Proteine';
    }
    return 'Carboidrati';
  }

  String get dominantEnergyShareLabel =>
      '${(dominantEnergyShare * 100).round()}%';

  bool get showDominanceWarning => dominantEnergyShare >= 0.80;

  bool get showCalorieMismatchWarning {
    if (loggedCalories <= 0 || macroCalories <= 0) {
      return false;
    }

    final ratio = macroCalories / loggedCalories;
    return ratio > 1.35 || ratio < 0.65;
  }

  String get macroCaloriesLabel => UnitFormat.e(macroCalories);

  String get loggedCaloriesLabel => UnitFormat.e(loggedCalories);

  factory MacroAnalysis.fromPoints(List<AnalysisPoint> points) {
    var carbs = 0.0;
    var proteins = 0.0;
    var fats = 0.0;
    var loggedCalories = 0.0;

    for (final point in points) {
      carbs += point.carbs;
      proteins += point.proteins;
      fats += point.fats;
      loggedCalories += point.calories;
    }

    return MacroAnalysis(
      carbs: carbs,
      proteins: proteins,
      fats: fats,
      loggedCalories: loggedCalories,
    );
  }
}
