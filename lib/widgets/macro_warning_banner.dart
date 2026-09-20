import 'package:flutter/material.dart';

import 'auth_style.dart';
import '../models/macro_analysis.dart';
import '../dictionary/translations.dart';

/// Banner arancione che avvisa su squilibri nella distribuzione dei macro.
///
/// Viene mostrato se [MacroAnalysis.showDominanceWarning] oppure
/// [MacroAnalysis.showCalorieMismatchWarning] sono veri.
/// Rimane invisibile (SizedBox) se non ci sono avvisi.
class MacroWarningBanner extends StatelessWidget {
  const MacroWarningBanner({super.key, required this.analysis, required this.lang});

  final MacroAnalysis analysis;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final messages = <String>[];
    if (analysis.showDominanceWarning) {
      messages.add(
        '${Translations.get(lang, analysis.dominantLabel)} ${Translations.get(lang, 'sopra l’80% della quota energetica: possibile squilibrio o dato anomalo.')}',
      );
    }
    if (analysis.showCalorieMismatchWarning) {
      messages.add(
        Translations.get(lang, 'I macro corrispondono a {macroKcal}, ma le calorie registrate sono {loggedKcal}.')
            .replaceFirst('{macroKcal}', analysis.macroCaloriesLabel)
            .replaceFirst('{loggedKcal}', analysis.loggedCaloriesLabel),
      );
    }

    if (messages.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Nutri.warnBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Nutri.warnBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.warning_amber_rounded, color: Color(0xFFD36A1D)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              messages.join(' '),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7B3E11),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
