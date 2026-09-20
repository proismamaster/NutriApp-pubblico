import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';
import '../dictionary/translations.dart';
import '../models/daily_summary.dart';

// Stessi colori Nutri-Score gia' usati altrove nell'app (entry_menu_page,
// product_info_sheet): A verde pieno -> E rosso. NOVA/Eco-Score non avevano
// ancora una palette in home, adottata dal mockup Home Final.
const Map<String, Color> _nutriColors = {
  'A': Color(0xFF038141), 'B': Color(0xFF85BB2F), 'C': Color(0xFFFECB02),
  'D': Color(0xFFEE8100), 'E': Color(0xFFE63E11),
};
const Map<String, Color> _ecoColors = {
  'A': Color(0xFF0F7A3D), 'B': Color(0xFF6FAF2F), 'C': Color(0xFFE8B10C),
  'D': Color(0xFFE07A16), 'E': Color(0xFFD8412A),
};
const List<Color> _novaColors = [
  Color(0xFF2E7D32), Color(0xFF2E7D32), Color(0xFF6E9E28),
  Color(0xFFE09A12), Color(0xFFD8452E),
];

/// Riga "qualita' del giorno": media di Nutri-Score/NOVA/Eco-Score dei cibi
/// loggati (vedi migrations/2026-08-23_qualita_giorno.sql +
/// get_daily_summary.php). Mockup Home Final. Grigio/"—" quando non c'e'
/// ancora nessuna voce con punteggio, invece di un dato inventato.
class DayQualityRow extends ConsumerWidget {
  final DailySummary? summary;

  const DayQualityRow({super.key, required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).language;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant.withValues(alpha: .55);

    final int count = summary?.intakeCount ?? 0;
    final bool logged = count > 0;

    final String? nutriGrade = DailySummary.numToGrade(summary?.avgNutriscoreNum);
    final String? ecoGrade = DailySummary.numToGrade(summary?.avgEcoscoreNum);
    final double? novaVal = summary?.avgNova;

    final String caption = logged
        ? '${Translations.get(lang, 'home_quality_avg_of')} $count '
            '${Translations.get(lang, count == 1 ? 'home_items_logged_one' : 'home_items_logged_many')}'
        : Translations.get(lang, 'home_quality_empty');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              caption,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          _scoreEntry(context, 'NUTRI', nutriGrade, nutriGrade != null ? _nutriColors[nutriGrade] : null, muted),
          const SizedBox(width: 12),
          _scoreEntry(
            context, 'NOVA',
            novaVal?.toStringAsFixed(1),
            novaVal != null ? _novaColors[novaVal.round().clamp(1, 4) - 1] : null,
            muted,
          ),
          const SizedBox(width: 12),
          _scoreEntry(context, 'ECO', ecoGrade, ecoGrade != null ? _ecoColors[ecoGrade] : null, muted),
        ],
      ),
    );
  }

  Widget _scoreEntry(BuildContext context, String label, String? value, Color? color, Color muted) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // NB: niente Flexible qui. Questa riga vive dentro un contenitore a
        // larghezza libera (si dimensiona sul contenuto), e un figlio
        // flessibile in quel caso non ha uno spazio residuo da occupare:
        // Flutter lo rifiuta con "unbounded width constraints". Non puo'
        // nemmeno traboccare, proprio perche' il genitore si adatta a lei.
        Text(label, style: TextStyle(fontSize: 9.5, color: muted, letterSpacing: .3)),
        const SizedBox(width: 4),
        Text(
          value ?? '—',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color ?? muted,
          ),
        ),
      ],
    );
  }
}
