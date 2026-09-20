// ⚠️ CODICE MORTO — verificato 2026-07-24
//
// Nessuno dei provider di questo file è referenziato da nessuna parte
// dell'app (controllato con una ricerca su tutto `lib/`). Gli obiettivi
// nutrizionali veri viaggiano dentro `UserModel` tramite `userProvider`
// (vedi `goal_page.dart` e `daily_detail_page.dart`), non qui.
//
// Attenzione a non "collegarli" per sbaglio pensando che siano lo stato
// buono: sono valori fissi scritti a mano che non arrivano dal database e
// non ci tornano. Nemmeno `selectedLanguageProvider` è quello in uso — la
// lingua vera sta in `appSettingsProvider` (locale_provider.dart).
//
// Il file NON è stato cancellato in autonomia perché contiene riferimenti a
// lavori di altre persone del team (vedi commenti sotto): va eliminato dopo
// una conferma, non di iniziativa.

import 'package:flutter_riverpod/legacy.dart';

// --- MACRO OBIETTIVI ---
// Collegare i suoi Textfield direttamente a questi provider
final goalProteinsProvider = StateProvider<double>((ref) => 80.0);
final goalCarbsProvider = StateProvider<double>((ref) => 200.0);
final goalFatsProvider = StateProvider<double>((ref) => 60.0);

// --- MICRO OBIETTIVI ---
final microGoalsProvider = StateProvider<Map<String, double>>((ref) {
  return {'vit_c': 90.0, 'vit_d': 20.0, 'calcio': 1000.0, 'ferro': 14.0};
});

// --- SETTINGS (Es. Lingua) ---
// Serena sta lavorando al menu a tendina della lingua. Ecco il suo stato:
final selectedLanguageProvider = StateProvider<String>((ref) => 'Italiano');

// --- ACCOUNT SELECTION ---
// Per il bottom sheet di selezione account di Serena
final selectedAccountProvider = StateProvider<String>(
  (ref) => 'Profilo Personale',
);
