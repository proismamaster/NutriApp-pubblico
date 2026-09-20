import 'package:flutter/material.dart';

import 'auth_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dictionary/translations.dart';
import '../providers/locale_provider.dart';

/// Card gialla che elenca una lista di osservazioni testuali automatiche.
///
/// Ogni insight è una stringa breve; viene mostrato con un pallino arancione
/// come punto elenco. Riutilizzabile ovunque si voglia presentare insight.
class InsightCard extends ConsumerWidget {
  const InsightCard({super.key, required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).language;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Nutri.noteBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Nutri.noteBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: Color(0xFFC58900),
              ),
              const SizedBox(width: 8),
              Text(
                Translations.get(lang, 'Analisi automatica'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Nutri.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.circle,
                      size: 7,
                      color: Color(0xFFC58900),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight,
                      style: TextStyle(
                        fontSize: 13,
                        color: Nutri.ink,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
