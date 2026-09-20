import 'package:flutter/material.dart';

import 'logic/unit_format.dart';
import 'theme_nutri.dart';

import 'widgets/auth_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_gate.dart';
import 'providers/locale_provider.dart';
import 'services/notification_service.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inizializzazione notifiche
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint("Errore inizializzazione notifiche: $e");
  }
  
  // Avviamo l'app con Riverpod
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(appSettingsProvider).isDarkMode;
    final lang = ref.watch(appSettingsProvider).language;

    // Allinea la palette delle schermate nuove al tema scelto, PRIMA che
    // qualunque schermata si disegni. Senza questa riga quelle schermate
    // restano chiare mentre la cornice (barra in alto e navigazione) diventa
    // scura — che e' esattamente il difetto segnalato da Ismail: "viene
    // lasciato in nero solo il contorno mentre il contenuto rimane bianco".
    Nutri.applicaTema(isDark ? Brightness.dark : Brightness.light);

    // Stessa cosa per le unita' di misura scelte in "Lingua e paese": vanno
    // note prima che una schermata scriva un peso o un'energia, altrimenti la
    // prima costruzione mostra i grammi e solo la seconda le once.
    final impostazioni = ref.watch(appSettingsProvider);
    UnitFormat.applica(
      peso: impostazioni.weightUnit,
      energia: impostazioni.energyUnit,
    );

    Locale getLocale(String language) {
      switch (language) {
        case 'English':
          return const Locale('en', '');
        case '简体中文':
          return const Locale('zh', '');
        case 'العربية':
          return const Locale('ar', '');
        case 'Italiano':
        default:
          return const Locale('it', '');
      }
    }

    return MaterialApp(
      title: 'NutriApp',
      // Cambiando schermata i messaggi in basso sparicono: restavano appesi
      // sopra la pagina nuova, dove non c'entravano piu' niente e coprivano i
      // pulsanti (test di release 19/09).
      navigatorObservers: [_PuliziaMessaggi()],
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      locale: getLocale(lang),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('it', ''),
        Locale('en', ''),
        Locale('zh', ''),
        Locale('ar', ''),
      ],
      // I DUE TEMI ESCONO DALLA STESSA PALETTE (2026-09-07).
      //
      // Prima no: le schermate ridisegnate leggevano da `Nutri` (fondo
      // #11150F, un nero appena verde) e tutte le altre dal ColorScheme di
      // Material, che qui era `Colors.black` puro. Risultato: passando da una
      // schermata all'altra il nero cambiava, ed e' il difetto che Ismail ha
      // riassunto con "alcune screen sono di un nero diverso da un'altra, il
      // background deve essere coerente". Ora c'e' una fonte sola: cambiare
      // `Nutri.bg` sposta tutta l'app insieme.
      theme: temaNutri(Brightness.light),
      darkTheme: temaNutri(Brightness.dark),
      // AuthGate gestisce lo stato di login iniziale
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }

}

/// Toglie i messaggi in basso quando si cambia schermata.
class _PuliziaMessaggi extends NavigatorObserver {
  void _pulisci() {
    final contesto = navigator?.context;
    if (contesto != null) ScaffoldMessenger.of(contesto).clearSnackBars();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _pulisci();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _pulisci();
}
