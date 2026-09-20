import 'package:nutriapp/models/analysis_point.dart';

class MacroTotals {
  final double carbs;
  final double proteins;
  final double fats;

  const MacroTotals({
    required this.carbs,
    required this.proteins,
    required this.fats,
  });

  double get total => carbs + proteins + fats;

  // Calcola la distribuzione macro partendo dai punti gia` aggregati del grafico corrente.
  factory MacroTotals.fromPoints(List<AnalysisPoint> points) {
    var carbs = 0.0;
    var proteins = 0.0;
    var fats = 0.0;

    for (final point in points) {
      carbs += point.carbs;
      proteins += point.proteins;
      fats += point.fats;
    }

    return MacroTotals(carbs: carbs, proteins: proteins, fats: fats);
  }
}
