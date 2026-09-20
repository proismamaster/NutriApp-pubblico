import 'package:flutter/material.dart';
import '../../dictionary/translations.dart';
import '../nutri_select.dart';

class WaterReminderSection extends StatelessWidget {
  final bool isEnabled;
  final int? remindersCount;
  final String selectedFrequency;
  final List<String> frequencies;
  final bool showCustomPicker;
  final int customHours;
  final int customMinutes;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String?> onFrequencyChanged;
  final ValueChanged<int> onChangeHours;
  final ValueChanged<int> onChangeMinutes;
  final ValueChanged<TimeOfDay?> onStartTimeChanged;
  final ValueChanged<TimeOfDay?> onEndTimeChanged;
  final String lang;

  const WaterReminderSection({
    super.key,
    required this.isEnabled,
    required this.remindersCount,
    required this.selectedFrequency,
    required this.frequencies,
    required this.showCustomPicker,
    required this.customHours,
    required this.customMinutes,
    required this.startTime,
    required this.endTime,
    required this.onToggle,
    required this.onFrequencyChanged,
    required this.onChangeHours,
    required this.onChangeMinutes,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    required this.lang,
  });

  String _summary() {
    if (!isEnabled) return Translations.get(lang, 'notif_off');
    if (remindersCount == null) return Translations.get(lang, 'notif_end_before_start');
    return '$remindersCount ${Translations.get(lang, 'notif_reminders_a_day')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const waterColor = Color(0xFF3C86B4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.water_drop, color: waterColor, size: 22),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Translations.get(lang, 'Promemoria acqua'),
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(context, 'notif_time_range'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimeTile(
                            context,
                            Translations.get(lang, 'Inizio'),
                            startTime,
                            onStartTimeChanged,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, size: 18, color: scheme.outline),
                        ),
                        Expanded(
                          child: _buildTimeTile(
                            context,
                            Translations.get(lang, 'Fine'),
                            endTime,
                            onEndTimeChanged,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _sectionLabel(context, 'notif_frequency'),
                    const SizedBox(height: 10),
                    NutriSelect<String>(
                      titolo: Translations.get(lang, 'notif_frequency'),
                      valore: selectedFrequency,
                      opzioni: [
                        for (final freq in frequencies) NutriOpzione(freq, Translations.get(lang, freq)),
                      ],
                      onCambiato: onFrequencyChanged,
                    ),
                    if (showCustomPicker)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel(context, null, text: Translations.get(lang, 'Intervallo personalizzato')),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildPickerColumn(context, Translations.get(lang, 'Ore'), customHours, onChangeHours),
                                const SizedBox(width: 26),
                                _buildPickerColumn(context, Translations.get(lang, 'Minuti'), customMinutes, onChangeMinutes, true),
                              ],
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Container(
                        padding: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: scheme.outlineVariant)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notifications_active_outlined, size: 17, color: waterColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                remindersCount != null
                                    ? '$remindersCount ${Translations.get(lang, 'notif_reminders_a_day')} · '
                                        '${startTime.format(context)} - ${endTime.format(context)}'
                                    : Translations.get(lang, 'notif_end_before_start'),
                                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String? key, {String? text}) {
    return Text(
      text ?? Translations.get(lang, key!),
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        letterSpacing: .8,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildTimeTile(BuildContext context, String label, TimeOfDay time, ValueChanged<TimeOfDay?> onChanged) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        onChanged(picked);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 3),
            Text(
              time.format(context),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerColumn(BuildContext context, String label, int value, ValueChanged<int> onChanged, [bool pad = false]) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        IconButton(
          icon: Icon(Icons.add_circle_outline, color: scheme.primary),
          onPressed: () => onChanged(1),
        ),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.primary, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              pad ? value.toString().padLeft(2, '0') : value.toString(),
              style: TextStyle(fontSize: 28, color: scheme.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.remove_circle_outline, color: scheme.primary),
          onPressed: () => onChanged(-1),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
