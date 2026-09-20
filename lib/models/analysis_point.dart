/// Punto dati aggregato usato come input per [MacroAnalysis].
///
/// Rappresenta i macronutrienti e le calorie di un singolo intervallo
/// temporale (giorno, settimana, mese, anno).
class AnalysisPoint {
  const AnalysisPoint({
    required this.carbs,
    required this.proteins,
    required this.fats,
    required this.calories,
  });

  final double carbs;
  final double proteins;
  final double fats;
  final double calories;
}
