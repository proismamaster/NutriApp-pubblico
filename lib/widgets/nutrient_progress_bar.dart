import 'package:flutter/material.dart';

import '../logic/unit_format.dart';

class NutrientProgressBar extends StatelessWidget {
  final String label;
  final double currentValue;
  final double goalValue;
  final Color color;
  /// 'kcal' fa convertire il numero nell'unita' di energia scelta, 'g'
  /// nell'unita' di peso scelta (once dal 18/09); le altre sigle (mg, µg dei
  /// micronutrienti) si scrivono come sono, perche' non hanno un equivalente
  /// in once.
  final String unit;

  const NutrientProgressBar({
    super.key,
    required this.label,
    required this.currentValue,
    required this.goalValue,
    required this.color,
    this.unit = 'g',
  });

  @override
  Widget build(BuildContext context) {
    // Se l'obiettivo è 0 ma abbiamo mangiato qualcosa, siamo in eccesso
    final bool isOverLimit = goalValue <= 0 ? currentValue > 0 : currentValue > goalValue;
    
    // Calcolo frazione: se goal è 0, la barra è piena (rossa) se abbiamo mangiato qualcosa
    final fraction = (goalValue <= 0) 
        ? (currentValue > 0 ? 1.0 : 0.0) 
        : (currentValue / goalValue).clamp(0.0, 1.0);

    final progressColor = isOverLimit ? Colors.redAccent.shade100 : color;
    final valueTextColor = isOverLimit ? Colors.redAccent : Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(label,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text(
                switch (unit) {
                  'kcal' => '${UnitFormat.eValore(currentValue)}/${UnitFormat.eValore(goalValue)} ${UnitFormat.eSigla}',
                  'g' => '${UnitFormat.pNumero(currentValue)}/${UnitFormat.pNumero(goalValue)} ${UnitFormat.pSigla}',
                  _ => '${currentValue.toStringAsFixed(0)}/${goalValue.toStringAsFixed(0)} $unit',
                },
                style: TextStyle(
                  fontSize: 12,
                  color: valueTextColor,
                  fontWeight: isOverLimit ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: fraction,
              color: progressColor,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
