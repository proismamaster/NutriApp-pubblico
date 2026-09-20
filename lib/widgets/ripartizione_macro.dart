import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dictionary/translations.dart';
import '../logic/unit_format.dart';
import '../models/macro_analysis.dart';
import '../models/macro_totals.dart';
import '../models/metric_type.dart';
import 'auth_style.dart';

/// Da dove arrivano le calorie del periodo: una barra sola divisa per
/// carboidrati, proteine e grassi, e sotto una riga per macro (17/09).
///
/// PRIMA c'erano una ciambella E tre barre con icone, cioe' lo stesso dato
/// due volte. Una barra al 100% dice la proporzione, le righe dicono grammi e
/// percentuale. I colori sono quelli delle metriche (validati con lo script
/// della skill dataviz, in chiaro e in scuro); il testo resta nei colori del
/// testo, e fra i segmenti c'e' uno spiraglio di 2 px invece di un bordo.
class RipartizioneMacro extends StatelessWidget {
  const RipartizioneMacro({
    super.key,
    required this.analisi,
    required this.totali,
    required this.lang,
  });

  final MacroAnalysis analisi;
  final MacroTotals totali;
  final String lang;

  @override
  Widget build(BuildContext context) {
    if (!analisi.hasMacroData) {
      return Text(
        Translations.get(lang, 'Nessun dato disponibile nel periodo selezionato.'),
        style: TextStyle(fontSize: 13, color: Nutri.muted),
      );
    }

    final voci = [
      (MetricType.carbs, analisi.carbsEnergyShare, totali.carbs),
      (MetricType.proteins, analisi.proteinsEnergyShare, totali.proteins),
      (MetricType.fats, analisi.fatsEnergyShare, totali.fats),
    ];
    final presenti = voci.where((v) => v.$2 > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: Row(
              // Senza stretch un ColoredBox vuoto e' alto 0: barra invisibile.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < presenti.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: math.max(1, (presenti[i].$2 * 1000).round()),
                    child: ColoredBox(color: presenti[i].$1.color),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final (metrica, quota, grammi) in voci)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: metrica.color, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    Translations.get(lang, metrica.label),
                    style: TextStyle(fontSize: 14, color: Nutri.ink),
                  ),
                ),
                Text(
                  UnitFormat.pNutriente(grammi),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Nutri.ink),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${(quota * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 13, color: Nutri.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
