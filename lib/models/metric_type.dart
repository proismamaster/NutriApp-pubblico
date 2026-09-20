import 'package:flutter/material.dart';

import '../logic/unit_format.dart';
import '../widgets/auth_style.dart';
import 'history_point.dart';

/// Metrica nutrizionale visualizzabile nei grafici.
///
/// Ogni valore porta con sé etichetta, unità di misura, colore e icona.
/// Il metodo [readFromPoint] estrae il valore corrispondente da un [HistoryPoint].
enum MetricType {
  // Colori validati con la skill dataviz (17/09) in chiaro e in scuro: prima
  // calorie rosso acceso, carboidrati giallo, proteine blu e grassi viola, mai
  // controllati insieme e senza una variante per il tema scuro.
  calories('Calorie', 'kcal', Color(0xFF1B7A33), Color(0xFF3E9B4F), Icons.local_fire_department_outlined),
  carbs('Carboidrati', 'g', Color(0xFF2A78D6), Color(0xFF3987E5), Icons.grain_outlined),
  proteins('Proteine', 'g', Color(0xFFEB6834), Color(0xFFD95926), Icons.fitness_center_outlined),
  fats('Grassi', 'g', Color(0xFF1BAF7A), Color(0xFF199E70), Icons.opacity_outlined);

  const MetricType(this.label, this.unit, this._chiaro, this._scuro, this.icon);

  final String label;
  final String unit;
  final Color _chiaro;
  final Color _scuro;
  final IconData icon;

  Color get color => Nutri.scuro ? _scuro : _chiaro;


  /// Estrae il valore della metrica da un punto già aggregato,
  /// centralizzando la logica ed evitando switch ripetuti.
  double readFromPoint(HistoryPoint point) {
    switch (this) {
      case MetricType.calories:
        return point.calories;
      case MetricType.carbs:
        return point.carbs;
      case MetricType.proteins:
        return point.proteins;
      case MetricType.fats:
        return point.fats;
    }
  }

  /// Unita' come va SCRITTA: segue la preferenza dell'utente, kcal o kJ per
  /// le calorie, grammi o once per i macro (le once dal 18/09: prima i macro
  /// restavano in grammi anche con le once scelte).
  String get unitVisibile =>
      this == MetricType.calories ? UnitFormat.eSigla : UnitFormat.pSigla;

  /// Il valore nell'unita' scelta. I dati restano in kcal e grammi: si
  /// converte solo per disegnare e scrivere.
  double visibile(double value) =>
      this == MetricType.calories ? UnitFormat.eInUnita(value) : UnitFormat.pInUnita(value);

  /// Formatta il valore con l'unità di misura (1 decimale sotto 100, 0 sopra).
  String format(double value) => scrivi(visibile(value));

  /// Come [format], per un valore gia' nell'unita' scelta (i grafici disegnano
  /// valori gia' convertiti).
  String scrivi(double v) => '${v.toStringAsFixed(v >= 100 ? 0 : 1)} $unitVisibile';

  /// Versione compatta del formato: usa "k" per migliaia (es. "1.2k kcal").
  ///
  /// Il moltiplicatore "k" è sempre separato dall'unità di misura, per evitare
  /// concatenazioni scorrette come "kkcal" quando l'unità è già "kcal".
  String shortFormat(double value) => scriviBreve(visibile(value));

  /// Come [shortFormat], per un valore gia' nell'unita' scelta.
  String scriviBreve(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k $unitVisibile';
    return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} $unitVisibile';
  }
}
