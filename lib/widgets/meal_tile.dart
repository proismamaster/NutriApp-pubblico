import 'package:flutter/material.dart';

import '../logic/unit_format.dart';

/// Tile di un pasto nella griglia 2x2 della home (mockup Home Final,
/// sostituisce la vecchia lista verticale BuildMealItem). Mostra
/// kcal mangiate/target del pasto con una barra di progresso — il target
/// per pasto e' una quota % dell'obiettivo calorico giornaliero (nessun
/// target per-pasto reale esiste ancora nel profilo utente).
class MealTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final double eatenKcal;
  final double targetKcal;
  final bool hasEntries;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const MealTile({
    super.key,
    required this.label,
    required this.icon,
    required this.eatenKcal,
    required this.targetKcal,
    required this.hasEntries,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Senza obiettivo (profilo nuovo, o obiettivi azzerati da un server
    // vecchio — screenshot del 17/09 con "418/0 kcal") qualunque cosa mangiata
    // e' "oltre": barra piena e rossa, e si scrivono le sole kcal invece di un
    // "/0" che sembra un conto vero.
    final bool senzaObiettivo = targetKcal <= 0;
    final bool over = eatenKcal > 0 && (senzaObiettivo || eatenKcal > targetKcal);
    final double fraction = senzaObiettivo
        ? (eatenKcal > 0 ? 1.0 : 0.0)
        : (eatenKcal / targetKcal).clamp(0.0, 1.0);

    final Color tileBg = hasEntries ? scheme.primaryContainer.withValues(alpha: .35) : scheme.surface;
    final Color tileBorder = hasEntries ? scheme.primary.withValues(alpha: .4) : scheme.outlineVariant;
    final Color kcalColor = over
        ? scheme.error
        : hasEntries
            ? scheme.onSurface
            : scheme.onSurfaceVariant;
    final Color barColor = over ? scheme.error : scheme.primary;

    return Material(
      color: tileBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tileBorder),
          ),
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 22, color: scheme.primary),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onAdd,
                    child: Icon(Icons.add, size: 20, color: scheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                senzaObiettivo
                    ? '${UnitFormat.eValore(eatenKcal)} ${UnitFormat.eSigla}'
                    : '${UnitFormat.eValore(eatenKcal)}/${UnitFormat.eValore(targetKcal)} ${UnitFormat.eSigla}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: kcalColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 4,
                  color: barColor,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
