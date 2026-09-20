import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/daily_summary.dart';
import 'nutrient_progress_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';
import '../dictionary/translations.dart';

class MicronutrientExpansionPanels extends ConsumerWidget {
  final UserModel? user;
  final DailySummary? sourceSummary;
  final double factor;

  const MicronutrientExpansionPanels({
    super.key,
    required this.user,
    required this.sourceSummary,
    this.factor = 1.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).language;

    final vitamins = [
      {'label': 'Vitamina A', 'val': sourceSummary?.totalVitamins.a ?? 0.0, 'goal': (user?.vitAGoal ?? 0.0) * factor, 'unit': 'µg'},
      {'label': 'Vitamina B1', 'val': sourceSummary?.totalVitamins.b1 ?? 0.0, 'goal': (user?.vitB1Goal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Vitamina B2', 'val': sourceSummary?.totalVitamins.b2 ?? 0.0, 'goal': (user?.vitB2Goal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Vitamina B3', 'val': sourceSummary?.totalVitamins.b3 ?? 0.0, 'goal': (user?.vitB3Goal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Vitamina B5', 'val': sourceSummary?.totalVitamins.b5 ?? 0.0, 'goal': (user?.vitB5Goal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Vitamina B6', 'val': sourceSummary?.totalVitamins.b6 ?? 0.0, 'goal': (user?.vitB6Goal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Vitamina B7', 'val': sourceSummary?.totalVitamins.b7 ?? 0.0, 'goal': (user?.vitB7Goal ?? 0.0) * factor, 'unit': 'µg'},
      {'label': 'Vitamina B9', 'val': sourceSummary?.totalVitamins.b9 ?? 0.0, 'goal': (user?.vitB9Goal ?? 0.0) * factor, 'unit': 'µg'},
      {'label': 'Vitamina B11', 'val': sourceSummary?.totalVitamins.b11 ?? 0.0, 'goal': (user?.vitB11Goal ?? 0.0) * factor, 'unit': 'µg'},
      {'label': 'Vitamina B12', 'val': sourceSummary?.totalVitamins.b12 ?? 0.0, 'goal': (user?.vitB12Goal ?? 0.0) * factor, 'unit': 'µg'},
      {'label': 'Vitamina C', 'val': sourceSummary?.totalVitamins.c ?? 0.0, 'goal': (user?.vitCGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Vitamina D', 'val': sourceSummary?.totalVitamins.d ?? 0.0, 'goal': (user?.vitDGoal ?? 0.0) * factor, 'unit': 'µg'},
      {'label': 'Vitamina E', 'val': sourceSummary?.totalVitamins.e ?? 0.0, 'goal': (user?.vitEGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Vitamina K', 'val': sourceSummary?.totalVitamins.k ?? 0.0, 'goal': (user?.vitKGoal ?? 0.0) * factor, 'unit': 'µg'},
      {'label': 'Biotina', 'val': sourceSummary?.totalVitamins.biotin ?? 0.0, 'goal': (user?.biotinGoal ?? 0.0) * factor, 'unit': 'µg'},
    ];

    final minerals = [
      {'label': 'Sodio', 'val': sourceSummary?.totalMinerals.sodium ?? 0.0, 'goal': (user?.sodiumMax ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Arsenico', 'val': sourceSummary?.totalMinerals.arsenic ?? 0.0, 'goal': (user?.arsenicGoal ?? 0.0) * factor, 'unit': 'µg'},
      {'label': 'Boro', 'val': sourceSummary?.totalMinerals.boron ?? 0.0, 'goal': (user?.boronGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Calcio', 'val': sourceSummary?.totalMinerals.calcium ?? 0.0, 'goal': (user?.calciumGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Cloruro', 'val': sourceSummary?.totalMinerals.chloride ?? 0.0, 'goal': (user?.chlorideGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Colina', 'val': sourceSummary?.totalMinerals.choline ?? 0.0, 'goal': (user?.cholineGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Cromo', 'val': sourceSummary?.totalMinerals.chromium ?? 0.0, 'goal': (user?.chromiumGoal ?? 0.0) * factor, 'unit': 'µg'},
      {'label': 'Cobalto', 'val': sourceSummary?.totalMinerals.cobalt ?? 0.0, 'goal': (user?.cobaltGoal ?? 0.0) * factor, 'unit': 'µg'},
      {'label': 'Rame', 'val': sourceSummary?.totalMinerals.copper ?? 0.0, 'goal': (user?.copperGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Fluoruro', 'val': sourceSummary?.totalMinerals.fluoride ?? 0.0, 'goal': (user?.fluorideGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Fluoro', 'val': sourceSummary?.totalMinerals.fluorine ?? 0.0, 'goal': (user?.fluorineGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Iodio', 'val': sourceSummary?.totalMinerals.iodine ?? 0.0, 'goal': (user?.iodineGoal ?? 0.0) * factor, 'unit': 'µg'},
      {'label': 'Ferro', 'val': sourceSummary?.totalMinerals.iron ?? 0.0, 'goal': (user?.ironGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Magnesio', 'val': sourceSummary?.totalMinerals.magnesium ?? 0.0, 'goal': (user?.magnesiumGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Manganese', 'val': sourceSummary?.totalMinerals.manganese ?? 0.0, 'goal': (user?.manganeseGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Molibdeno', 'val': sourceSummary?.totalMinerals.molybdenum ?? 0.0, 'goal': (user?.molybdenumGoal ?? 0.0) * factor, 'unit': 'µg'},
      {'label': 'Fosforo', 'val': sourceSummary?.totalMinerals.phosphorus ?? 0.0, 'goal': (user?.phosphorusGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Potassio', 'val': sourceSummary?.totalMinerals.potassium ?? 0.0, 'goal': (user?.potassiumGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Selenio', 'val': sourceSummary?.totalMinerals.selenium ?? 0.0, 'goal': (user?.seleniumGoal ?? 0.0) * factor, 'unit': 'µg'},
      {'label': 'Silicio', 'val': sourceSummary?.totalMinerals.silicon ?? 0.0, 'goal': (user?.siliconGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Zolfo', 'val': sourceSummary?.totalMinerals.sulfur ?? 0.0, 'goal': (user?.sulfurGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Stagno', 'val': sourceSummary?.totalMinerals.tin ?? 0.0, 'goal': (user?.tinGoal ?? 0.0) * factor, 'unit': 'mg'},
      {'label': 'Vanadio', 'val': sourceSummary?.totalMinerals.vanadium ?? 0.0, 'goal': (user?.vanadiumGoal ?? 0.0) * factor, 'unit': 'µg'},
      {'label': 'Zinco', 'val': sourceSummary?.totalMinerals.zinc ?? 0.0, 'goal': (user?.zincGoal ?? 0.0) * factor, 'unit': 'mg'},
    ];

    // Il Material serve al tocco: chi usa questi pannelli li mette dentro un
    // Container colorato, che copriva l'onda del tocco sui titoli — sembrava
    // che non rispondessero (test di release 19/09).
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          _group(context, ref, lang, Translations.get(lang, 'Vitamine'), vitamins),
          _group(context, ref, lang, Translations.get(lang, 'Minerali'), minerals),
        ],
      ),
    );
  }

  /// Solo i nutrienti con un valore registrato (>0) — mostrare tutti,
  /// azzerati compresi, era solo rumore quando quasi nessuno ha un valore
  /// (mockup Meal Detail v2: "N tracked" conta esattamente questi).
  Widget _group(
    BuildContext context,
    WidgetRef ref,
    String lang,
    String title,
    List<Map<String, Object>> nutrients,
  ) {
    final tracked = nutrients.where((n) => (n['val'] as double) > 0).toList();
    final scheme = Theme.of(context).colorScheme;

    return ExpansionTile(
      title: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Text(
            tracked.isEmpty ? '—' : '${tracked.length} ${Translations.get(lang, 'micro_tracked')}',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      children: tracked.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  Translations.get(lang, 'micro_empty'),
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ),
            ]
          : tracked
              .map(
                (n) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: NutrientProgressBar(
                    label: Translations.get(lang, n['label'] as String),
                    currentValue: n['val'] as double,
                    goalValue: n['goal'] as double,
                    color: _tierColor(scheme, n['val'] as double, n['goal'] as double),
                    unit: n['unit'] as String,
                  ),
                ),
              )
              .toList(),
    );
  }

  Color _tierColor(ColorScheme scheme, double val, double goal) {
    if (goal <= 0) return scheme.primary;
    final pct = val / goal;
    if (pct >= 0.5) return scheme.primary;
    if (pct >= 0.2) return scheme.primary.withValues(alpha: .7);
    return scheme.primary.withValues(alpha: .45);
  }
}
