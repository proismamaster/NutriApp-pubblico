import 'analysis_point.dart';

/// Punto dati aggregato per un singolo intervallo temporale (es. un giorno).
///
/// Contiene la somma di calorie e macronutrienti di tutte le voci
/// che ricadono nel periodo [periodStart], e l'etichetta [label] dell'asse X.
class HistoryPoint {
  const HistoryPoint({
    required this.periodStart,
    required this.label,
    required this.calories,
    required this.carbs,
    required this.proteins,
    required this.fats,
    this.hasData = true,
    this.giorniConDati = 0,
  });

  /// Data di inizio del periodo aggregato (es. lunedì per una settimana).
  final DateTime periodStart;

  /// Etichetta testuale mostrata sull'asse X del grafico.
  final String label;

  final double calories;
  final double carbs;
  final double proteins;
  final double fats;

  /// True se nel periodo esiste almeno una entry alimentare registrata.
  ///
  /// Quando è false, tutti i valori sopra sono a 0 solo perché il periodo è
  /// stato riempito per completare una serie temporale continua (nessun
  /// "buco" invisibile nel grafico) — NON perché l'utente ha effettivamente
  /// registrato zero calorie/macro quel giorno. I calcoli aggregati (totale,
  /// media, picco, insight) devono escludere i punti con hasData=false.
  final bool hasData;

  /// Quanti GIORNI del periodo hanno almeno una voce. Un mese in corso ne ha
  /// meno di trenta: confrontare il suo totale con l'obiettivo di un mese
  /// intero raccontava un digiuno che non c'e' stato (test di release 19/09).
  final int giorniConDati;

  /// Converte il punto in un [AnalysisPoint] usato da [MacroAnalysis] e [MacroTotals].
  AnalysisPoint toAnalysisPoint() {
    return AnalysisPoint(
      carbs: carbs,
      proteins: proteins,
      fats: fats,
      calories: calories,
    );
  }
}
