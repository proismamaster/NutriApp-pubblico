import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/settings/meal_reminder_section.dart';
import '../widgets/settings/water_reminder_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dictionary/translations.dart';
import '../providers/locale_provider.dart';
import '../services/notification_service.dart';
import '../widgets/product_footer.dart';


class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _mealReminderEnabled = true;
  bool _waterReminderEnabled = true;

  final Map<String, String> _mealTimes = {
    'Colazione': '7:30 AM',
    'Pranzo': '12:00 PM',
    'Cena': '7:00 PM',
    'Snacks': '3:00 PM',
  };

  // Attivazione per singolo pasto (mockup Notifications, richiesta
  // 2026-08-23): prima esisteva solo l'interruttore globale "Promemoria
  // pasti", non si poteva silenziare uno spuntino specifico senza spegnere
  // anche colazione/pranzo/cena.
  final Map<String, bool> _mealEnabled = {
    'Colazione': true,
    'Pranzo': true,
    'Cena': true,
    'Snacks': true,
  };

  final List<String> _waterFrequencies = [
    'Ogni 30 minuti',
    'Ogni 1 ora',
    'Ogni 2 ore',
    'Personalizzato',
  ];
  String _selectedWaterFrequency = 'Ogni 1 ora';
  bool _showCustomWaterPicker = false;
  int _customWaterHours = 1;
  int _customWaterMinutes = 0;

  TimeOfDay _waterStartTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _waterEndTime = const TimeOfDay(hour: 22, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _verificaPermessi();
  }

  /// Chiede il permesso e, se manca, lo dice apertamente.
  ///
  /// Prima l'esito veniva ignorato: gli interruttori restavano accesi e i
  /// promemoria non arrivavano mai, senza che niente lo spiegasse.
  Future<void> _verificaPermessi() async {
    final concesso = await NotificationService().requestPermissions();
    if (!mounted || concesso) return;
    final lang = ref.read(appSettingsProvider).language;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Translations.get(lang, 'Le notifiche sono disattivate per NutriApp: attivale dalle impostazioni del telefono, altrimenti i promemoria non arriveranno.')),
        backgroundColor: const Color(0xFFB4553C),
        duration: const Duration(seconds: 7),
      ),
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mealReminderEnabled = prefs.getBool('meal_reminder_enabled') ?? true;
      _waterReminderEnabled = prefs.getBool('water_reminder_enabled') ?? true;
      
      _mealTimes['Colazione'] = prefs.getString('meal_time_Colazione') ?? '7:30 AM';
      _mealTimes['Pranzo'] = prefs.getString('meal_time_Pranzo') ?? '12:00 PM';
      _mealTimes['Cena'] = prefs.getString('meal_time_Cena') ?? '7:00 PM';
      _mealTimes['Snacks'] = prefs.getString('meal_time_Snacks') ?? '3:00 PM';

      for (final meal in _mealEnabled.keys) {
        _mealEnabled[meal] = prefs.getBool('meal_enabled_$meal') ?? true;
      }

      _selectedWaterFrequency = prefs.getString('water_frequency') ?? 'Ogni 1 ora';
      if (_selectedWaterFrequency == 'DECIDO IO') _selectedWaterFrequency = 'Personalizzato';
      _showCustomWaterPicker = (_selectedWaterFrequency == 'Personalizzato');
      _customWaterHours = prefs.getInt('water_custom_hours') ?? 1;
      _customWaterMinutes = prefs.getInt('water_custom_minutes') ?? 0;

      final startHour = prefs.getInt('water_start_hour') ?? 8;
      final startMin = prefs.getInt('water_start_min') ?? 0;
      _waterStartTime = TimeOfDay(hour: startHour, minute: startMin);

      final endHour = prefs.getInt('water_end_hour') ?? 22;
      final endMin = prefs.getInt('water_end_min') ?? 0;
      _waterEndTime = TimeOfDay(hour: endHour, minute: endMin);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('meal_reminder_enabled', _mealReminderEnabled);
    await prefs.setBool('water_reminder_enabled', _waterReminderEnabled);
    
    for (var entry in _mealTimes.entries) {
      await prefs.setString('meal_time_${entry.key}', entry.value);
    }
    for (var entry in _mealEnabled.entries) {
      await prefs.setBool('meal_enabled_${entry.key}', entry.value);
    }

    await prefs.setString('water_frequency', _selectedWaterFrequency);
    await prefs.setInt('water_custom_hours', _customWaterHours);
    await prefs.setInt('water_custom_minutes', _customWaterMinutes);
    await prefs.setInt('water_start_hour', _waterStartTime.hour);
    await prefs.setInt('water_start_min', _waterStartTime.minute);
    await prefs.setInt('water_end_hour', _waterEndTime.hour);
    await prefs.setInt('water_end_min', _waterEndTime.minute);
  }

  Future<void> _updateAllNotifications() async {
    await _saveSettings();
    await NotificationService().cancelAllNotifications();

    if (_mealReminderEnabled) {
      int id = 100;
      _mealTimes.forEach((meal, time) {
        if (_mealEnabled[meal] == false) return;
        final parts = time.split(' ');
        final timeParts = parts[0].split(':');
        int hour = int.parse(timeParts[0]);
        final int minute = int.parse(timeParts[1]);
        if (parts[1] == 'PM' && hour < 12) hour += 12;
        if (parts[1] == 'AM' && hour == 12) hour = 0;

        final now = DateTime.now();
        DateTime scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        NotificationService().scheduleNotification(
          id: id++,
          title: Translations.get(ref.read(appSettingsProvider).language, 'NutriApp: È ora di ${Translations.get(ref.read(appSettingsProvider).language, meal)}!'),
          body: Translations.get(ref.read(appSettingsProvider).language, 'Non dimenticare di registrare il tuo pasto.'),
          scheduledDate: scheduledDate,
        );
      });
    }

    if (_waterReminderEnabled) {
      int intervalMinutes = 60;
      if (_selectedWaterFrequency == 'Ogni 30 minuti') intervalMinutes = 30;
      if (_selectedWaterFrequency == 'Ogni 2 ore') intervalMinutes = 120;
      if (_selectedWaterFrequency == 'Personalizzato') {
        intervalMinutes = (_customWaterHours * 60) + _customWaterMinutes;
      }


      if (intervalMinutes > 0) {
        final now = DateTime.now();
        DateTime startTime = DateTime(now.year, now.month, now.day, _waterStartTime.hour, _waterStartTime.minute);
        DateTime endTime = DateTime(now.year, now.month, now.day, _waterEndTime.hour, _waterEndTime.minute);

        if (endTime.isBefore(startTime)) {
          endTime = endTime.add(const Duration(days: 1));
        }

        int id = 200;
        DateTime nextReminder = startTime;
        
        // Se l'orario di inizio è già passato oggi, iniziamo dal prossimo intervallo utile o domani
        if (nextReminder.isBefore(now)) {
          while (nextReminder.isBefore(now)) {
            nextReminder = nextReminder.add(Duration(minutes: intervalMinutes));
          }
        }

        // Programmiamo promemoria finché non superiamo l'orario di fine (limite max 20 notifiche per non intasare)
        int count = 0;
        while (nextReminder.isBefore(endTime) && count < 20) {
          NotificationService().scheduleNotification(
            id: id++,
            title: Translations.get(ref.read(appSettingsProvider).language, 'NutriApp: Idratazione!'),
            body: Translations.get(ref.read(appSettingsProvider).language, 'È ora di bere un bicchiere d\'acqua.'),
            scheduledDate: nextReminder,
          );
          nextReminder = nextReminder.add(Duration(minutes: intervalMinutes));
          count++;
        }
      }
    }
  }

  /// Stessa `showTimePicker` nativa gia' usata per l'orario inizio/fine
  /// acqua (WaterReminderSection._buildTimeTile) — prima qui c'era invece un
  /// overlay fatto a mano con frecce su/giu', unico caso della pagina a non
  /// usare il time picker di sistema (mockup Notifications: entrambe le
  /// sezioni usano lo stesso controllo nativo).
  Future<void> _showTimePicker(String meal) async {
    if (!_mealReminderEnabled) return;
    final timeString = _mealTimes[meal]!;
    final period = timeString.contains('AM') ? 'AM' : 'PM';
    final parts = timeString.replaceAll(' AM', '').replaceAll(' PM', '').split(':');
    int hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (picked == null || !mounted) return;

    final displayHour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
    final displayPeriod = picked.period == DayPeriod.am ? 'AM' : 'PM';
    setState(() {
      _mealTimes[meal] = '$displayHour:${picked.minute.toString().padLeft(2, '0')} $displayPeriod';
    });
    _updateAllNotifications();
    _showSnackBar(Translations.get(ref.read(appSettingsProvider).language, 'Orario promemoria salvato!'));
  }

  void _updateWaterFrequency(String? newValue) {
    if (newValue == null) return;
    setState(() {
      _selectedWaterFrequency = newValue;
      _showCustomWaterPicker = (newValue == 'Personalizzato');
    });
    _updateAllNotifications();
    _showSnackBar(Translations.get(ref.read(appSettingsProvider).language, 'Frequenza acqua aggiornata!'));
  }

  /// Minuti fra un promemoria acqua e il successivo — stessa lettura della
  /// frequenza gia' usata per programmare le notifiche in
  /// _updateAllNotifications, estratta qui per condividerla con il conteggio
  /// mostrato nella UI (mockup Notifications: "N promemoria al giorno").
  int _waterIntervalMinutes() {
    if (_selectedWaterFrequency == 'Ogni 30 minuti') return 30;
    if (_selectedWaterFrequency == 'Ogni 2 ore') return 120;
    if (_selectedWaterFrequency == 'Personalizzato') {
      return (_customWaterHours * 60) + _customWaterMinutes;
    }
    return 60;
  }

  /// Quanti promemoria acqua cadono davvero fra inizio e fine fascia —
  /// null se l'orario di fine non e' dopo quello di inizio (stesso caso che
  /// _updateAllNotifications gestisce spostando la fine al giorno dopo, ma
  /// qui vogliamo avvisare l'utente invece di far finta di niente).
  int? _waterRemindersCount() {
    final interval = _waterIntervalMinutes();
    if (interval <= 0) return null;
    final startMin = _waterStartTime.hour * 60 + _waterStartTime.minute;
    final endMin = _waterEndTime.hour * 60 + _waterEndTime.minute;
    if (endMin <= startMin) return null;
    return ((endMin - startMin) / interval).floor() + 1;
  }

  void _toggleMealEnabled(String meal) {
    setState(() => _mealEnabled[meal] = !(_mealEnabled[meal] ?? true));
    _updateAllNotifications();
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green, duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          Translations.get(lang, 'Notifiche'),
          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
                MealReminderSection(
                  lang: lang,
                  isEnabled: _mealReminderEnabled,
                  mealTimes: _mealTimes,
                  mealEnabled: _mealEnabled,
                  onToggle: (v) {
                    setState(() => _mealReminderEnabled = v);
                    _updateAllNotifications();
                  },
                  onTimeTap: _showTimePicker,
                  onMealToggle: _toggleMealEnabled,
                ),
                const SizedBox(height: 30),
                WaterReminderSection(
                  lang: lang,
                  isEnabled: _waterReminderEnabled,
                  remindersCount: _waterRemindersCount(),
                  selectedFrequency: _selectedWaterFrequency,
                  frequencies: _waterFrequencies,
                  showCustomPicker: _showCustomWaterPicker,
                  customHours: _customWaterHours,
                  customMinutes: _customWaterMinutes,
                  startTime: _waterStartTime,
                  endTime: _waterEndTime,
                  onToggle: (v) {
                    setState(() => _waterReminderEnabled = v);
                    _updateAllNotifications();
                  },
                  onFrequencyChanged: _updateWaterFrequency,
                  onChangeHours: (d) => setState(() { 
                    _customWaterHours += d; 
                    if (_customWaterHours > 23) _customWaterHours = 0; 
                    if (_customWaterHours < 0) _customWaterHours = 23; 
                    _updateAllNotifications(); 
                  }),
                  onChangeMinutes: (d) => setState(() { 
                    _customWaterMinutes += d; 
                    if (_customWaterMinutes > 59) _customWaterMinutes = 0; 
                    if (_customWaterMinutes < 0) _customWaterMinutes = 59; 
                    _updateAllNotifications(); 
                  }),
                  onStartTimeChanged: (time) {
                    if (time != null) {
                      setState(() => _waterStartTime = time);
                      _updateAllNotifications();
                    }
                  },
                  onEndTimeChanged: (time) {
                    if (time != null) {
                      setState(() => _waterEndTime = time);
                      _updateAllNotifications();
                    }
                  },
                ),
            const ProductFooter(),
          ],
        ),
      ),
    );
  }

}

