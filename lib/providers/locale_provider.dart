import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final String language;
  final String country;
  final bool isDarkMode;

  /// Unità di peso: 'metric' (grammi) o 'imperial' (once).
  ///
  /// Aggiunte il 2026-09-05 con il mockup "Language & country", che le chiede
  /// esplicitamente. Sono una PREFERENZA DI VISUALIZZAZIONE: i valori restano
  /// salvati in grammi e kcal ovunque — nel database, nelle API, nei calcoli —
  /// e la conversione avviene solo nel momento in cui il numero viene scritto
  /// a schermo. Convertire alla fonte avrebbe significato avere due unità di
  /// misura mescolate nello stesso database, che è il modo classico per
  /// ritrovarsi con calorie sbagliate senza capire perché.
  final String weightUnit;

  /// Unità di energia: 'kcal' o 'kj'.
  final String energyUnit;

  AppSettings({
    required this.language,
    required this.country,
    this.isDarkMode = false,
    this.weightUnit = 'metric',
    this.energyUnit = 'kcal',
  });

  AppSettings copyWith({
    String? language,
    String? country,
    bool? isDarkMode,
    String? weightUnit,
    String? energyUnit,
  }) {
    return AppSettings(
      language: language ?? this.language,
      country: country ?? this.country,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      weightUnit: weightUnit ?? this.weightUnit,
      energyUnit: energyUnit ?? this.energyUnit,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  /// Unico paese supportato dall'app (la schermata Lingua e paese offre solo
  /// questo: vedi `_listaPaesi` in country_language_page.dart). Il default
  /// storico era 'United States', che non e' mai stato selezionabile: chi non
  /// aveva mai aperto quella schermata si ritrovava l'anteprima in Impostazioni
  /// con un paese inesistente nell'app. Corretto il 2026-08-29.
  static const String _defaultCountry = 'Italia';

  AppSettingsNotifier()
    : super(AppSettings(language: 'English', country: _defaultCountry)) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('app_language') ?? 'English';
    final savedCountry = prefs.getString('app_country');
    final dark = prefs.getBool('app_dark_mode') ?? false;
    // Chi ha gia' l'app installata ha 'United States' scritto nelle preferenze
    // dal vecchio default: lo riportiamo all'unico paese esistente e lo
    // riscriviamo, altrimenti l'anteprima resterebbe sbagliata finche' non si
    // apre e salva a mano la schermata Lingua e paese.
    final country = (savedCountry == null || savedCountry != _defaultCountry)
        ? _defaultCountry
        : savedCountry;
    if (savedCountry != country) {
      await prefs.setString('app_country', country);
    }
    state = AppSettings(
      language: lang,
      country: country,
      isDarkMode: dark,
      weightUnit: prefs.getString('app_weight_unit') ?? 'metric',
      energyUnit: prefs.getString('app_energy_unit') ?? 'kcal',
    );
  }

  Future<void> saveSettings(String language, String country) async {
    state = state.copyWith(language: language, country: country);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', language);
    await prefs.setString('app_country', country);
  }

  /// Salva le unità di misura scelte.
  Future<void> saveUnits({String? weightUnit, String? energyUnit}) async {
    final prefs = await SharedPreferences.getInstance();
    if (weightUnit != null) await prefs.setString('app_weight_unit', weightUnit);
    if (energyUnit != null) await prefs.setString('app_energy_unit', energyUnit);
    state = state.copyWith(weightUnit: weightUnit, energyUnit: energyUnit);
  }

  Future<void> saveDarkMode(bool value) async {
    state = state.copyWith(isDarkMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_dark_mode', value);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
      return AppSettingsNotifier();
    });
