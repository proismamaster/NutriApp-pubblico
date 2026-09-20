import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';
import '../utils/date_labels.dart';

/// Selettore di giorno con etichetta relativa ("Oggi"/"Ieri"/nome del
/// giorno) + data completa sotto, e frecce a cerchio — ridisegnato 2026-08-23
/// sul mockup Home Final. Stessa API di prima (date/onDateChanged) cosi'
/// daily_detail_page.dart continua a funzionare senza modifiche.
class DaySelector extends ConsumerWidget {
  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;

  const DaySelector({
    super.key,
    required this.date,
    required this.onDateChanged,
  });

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).language;
    final today = DateTime.now();
    final relative = relativeDayLabel(lang, date, today);
    final full = fullDateLabel(lang, date);
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        _chevron(
          context,
          Icons.chevron_left,
          () => onDateChanged(date.subtract(const Duration(days: 1))),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _pickDate(context),
            child: Column(
              children: [
                Text(
                  relative,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 2),
                // Se l'etichetta relativa e' gia' la data completa (oltre la
                // settimana) non ripetiamo la stessa riga due volte.
                if (relative != full)
                  Text(
                    full,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
        _chevron(
          context,
          Icons.chevron_right,
          () => onDateChanged(date.add(const Duration(days: 1))),
        ),
      ],
    );
  }

  Widget _chevron(BuildContext context, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && !_sameDay(picked, date)) {
      onDateChanged(picked);
    }
  }
}
