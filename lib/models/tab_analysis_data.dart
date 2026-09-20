import 'package:flutter/material.dart' show DateTimeRange;

import 'history_point.dart';
import 'macro_analysis.dart';
import 'macro_totals.dart';

/// Contenitore immutabile con tutti i valori necessari a disegnare una tab.
///
/// Viene costruito una volta sola per ogni tab attiva e passato ai widget
/// figli, evitando ricalcoli multipli durante il build.
class TabAnalysisData {
  const TabAnalysisData({
    required this.points,
    required this.totalValue,
    required this.averageValue,
    required this.peakPoint,
    required this.macroTotals,
    required this.macroAnalysis,
    required this.insights,
    required this.trackedPeriods,
    required this.totalPeriods,
    required this.window,
  });

  /// Punti aggregati usati per disegnare il grafico storico: copre l'intera
  /// finestra temporale in modo continuo, inclusi i periodi senza dati
  /// (vedi [HistoryPoint.hasData]).
  final List<HistoryPoint> points;

  /// Somma di tutti i valori della metrica selezionata nel periodo,
  /// calcolata solo sui punti con [HistoryPoint.hasData] true.
  final double totalValue;

  /// Media dei valori della metrica selezionata, calcolata solo sui punti
  /// con dati reali (non sui periodi riempiti a zero).
  final double averageValue;

  /// Punto con il valore più alto della metrica selezionata, tra i punti
  /// con dati reali.
  final HistoryPoint peakPoint;

  /// Totali grammi dei singoli macronutrienti nel periodo.
  final MacroTotals macroTotals;

  /// Analisi energetica derivata dai macronutrienti.
  final MacroAnalysis macroAnalysis;

  /// Osservazioni testuali generate automaticamente sull'andamento.
  final List<String> insights;

  /// Numero di periodi (giorni/settimane/mesi/anni) con almeno una entry.
  final int trackedPeriods;

  /// Numero totale di periodi civili nella finestra mostrata (>= trackedPeriods).
  final int totalPeriods;

  /// Finestra temporale effettivamente usata per questa tab: o il range
  /// esplicito scelto dall'utente, o la finestra di default del bucket.
  final DateTimeRange window;
}
