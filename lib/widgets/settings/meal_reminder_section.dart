import 'package:flutter/material.dart';
import '../../dictionary/translations.dart';

const Map<String, IconData> _mealIcons = {
  'Colazione': Icons.coffee,
  'Pranzo': Icons.dinner_dining,
  'Cena': Icons.ramen_dining,
  'Snacks': Icons.cookie,
};

/// L'orario com'e' salvato ("7:30 AM") scritto come lo scrive la lingua:
/// 24 ore dappertutto tranne in inglese, dove AM/PM e' la norma. Prima
/// l'italiano leggeva "7:30 AM" (test di release 19/09).
String orarioNellaLingua(String salvato, String lang) {
  if (lang == 'English') return salvato;
  final pomeriggio = salvato.contains('PM');
  final pezzi = salvato.replaceAll(' AM', '').replaceAll(' PM', '').split(':');
  var ora = int.tryParse(pezzi.first) ?? 0;
  final minuti = pezzi.length > 1 ? (int.tryParse(pezzi[1]) ?? 0) : 0;
  if (pomeriggio && ora < 12) ora += 12;
  if (!pomeriggio && ora == 12) ora = 0;
  return '${ora.toString().padLeft(2, '0')}:${minuti.toString().padLeft(2, '0')}';
}

class MealReminderSection extends StatelessWidget {
  final bool isEnabled;
  final Map<String, String> mealTimes;
  final Map<String, bool> mealEnabled;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onTimeTap;
  final ValueChanged<String> onMealToggle;
  final String lang;

  const MealReminderSection({
    super.key,
    required this.isEnabled,
    required this.mealTimes,
    required this.mealEnabled,
    required this.onToggle,
    required this.onTimeTap,
    required this.onMealToggle,
    required this.lang,
  });

  /// Riassunto nell'intestazione: "N di 4 pasti · prossimo alle HH:MM", o
  /// "Tutti i pasti silenziati" se nessuno e' attivo — stessa logica del
  /// mockup Notifications, calcolata da dati reali (mealEnabled/mealTimes),
  /// non un testo fisso.
  String _summary() {
    if (!isEnabled) return Translations.get(lang, 'notif_off');
    final activeCount = mealEnabled.values.where((v) => v).length;
    if (activeCount == 0) return Translations.get(lang, 'notif_all_silenced');
    final firstActiveTime = mealTimes.entries
        .firstWhere((e) => mealEnabled[e.key] ?? true, orElse: () => mealTimes.entries.first)
        .value;
    return '$activeCount ${Translations.get(lang, 'notif_of_4_meals')} · '
        '${Translations.get(lang, 'notif_next_at')} ${orarioNellaLingua(firstActiveTime, lang)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.restaurant, color: Color(0xFFE0A81E), size: 22),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Translations.get(lang, 'Promemoria pasti'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(_summary(), style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Switch(value: isEnabled, onChanged: onToggle, activeThumbColor: scheme.primary),
          ],
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: isEnabled ? 1 : .45,
          child: IgnorePointer(
            ignoring: !isEnabled,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: mealTimes.entries.toList().asMap().entries.map((row) {
                  final index = row.key;
                  final meal = row.value.key;
                  final time = row.value.value;
                  final on = mealEnabled[meal] ?? true;
                  return Container(
                    decoration: BoxDecoration(
                      border: index == 0 ? null : Border(top: BorderSide(color: scheme.outlineVariant)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: on ? const Color(0xFFFBEFD9) : scheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _mealIcons[meal] ?? Icons.restaurant,
                            size: 19,
                            color: on ? const Color(0xFFB77A15) : scheme.outline,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Translations.get(lang, meal),
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w500,
                                  color: on ? scheme.onSurface : scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                on
                                    ? '${Translations.get(lang, 'notif_every_day_at')} ${orarioNellaLingua(time, lang)}'
                                    : Translations.get(lang, 'notif_silenced'),
                                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: on ? () => onTimeTap(meal) : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: on ? scheme.primaryContainer.withValues(alpha: .5) : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: on ? scheme.primary.withValues(alpha: .4) : scheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              orarioNellaLingua(time, lang),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: on ? scheme.primary : scheme.outline,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            on ? Icons.notifications_active : Icons.notifications_off,
                            size: 20,
                            color: on ? scheme.primary : scheme.outline,
                          ),
                          onPressed: () => onMealToggle(meal),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
