import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutriapp/screens/graphic_page.dart';
import 'package:nutriapp/domain/app_providers.dart';
import 'screens/home_page.dart';
import 'screens/calendar_page.dart';
import 'screens/recipe_list_page.dart';
import 'screens/setting_page.dart';
import 'screens/entry_menu_page.dart';
import 'providers/locale_provider.dart';
import 'dictionary/translations.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  /// Momento del primo "indietro" premuto stando gia' sulla Home.
  DateTime? _primoIndietroSullaHome;

  /// Quanto vale il primo "indietro" prima di dimenticarsene.
  static const _finestraUscita = Duration(seconds: 2);

  /// Sequenza dell'indietro (2026-09-05).
  ///
  /// Prima non c'era niente: da una tab qualsiasi il tasto indietro chiudeva
  /// l'app di colpo, senza passare dalla Home e senza chiedere. Ora:
  ///
  /// 1. la schermata attiva puo' gestirselo da sola (la tab "Aggiungi" torna
  ///    alla sua sotto-sezione principale invece di uscire);
  /// 2. da qualunque tab che non sia la Home, si torna alla Home;
  /// 3. dalla Home il primo indietro avvisa, il secondo entro due secondi
  ///    chiude davvero. Il doppio tocco esiste perche' chiudere un diario
  ///    alimentare per sbaglio a meta' inserimento e' fastidioso, e perche'
  ///    e' la convenzione che gli utenti Android gia' conoscono.
  void _gestisciIndietro() {
    final gestore = ref.read(gestoreIndietroProvider);
    if (gestore != null && gestore()) return;

    final indice = ref.read(currentTabIndexProvider);
    if (indice != 0) {
      ref.read(currentTabIndexProvider.notifier).state = 0;
      ref.read(initialMealTypeProvider.notifier).state = null;
      return;
    }

    final adesso = DateTime.now();
    final primo = _primoIndietroSullaHome;
    if (primo != null && adesso.difference(primo) < _finestraUscita) {
      SystemNavigator.pop();
      return;
    }
    _primoIndietroSullaHome = adesso;
    final lang = ref.read(appSettingsProvider).language;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Translations.get(lang, 'exit_press_again')),
        duration: _finestraUscita,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentTabIndexProvider);
    final lang = ref.watch(appSettingsProvider).language;
    final isDark = ref.watch(appSettingsProvider).isDarkMode;
    
    // Lista delle pagine e titoli dinamici
    final List<Map<String, dynamic>> navigationItems = [
      {'title': 'NutriApp', 'page': const HomePage(), 'icon': Icons.home},
      {
        'title': Translations.get(lang, 'nav_calendar'),
        'page': const CalendarioPage(),
        'icon': Icons.calendar_month,
      },
      {
        'title': Translations.get(lang, 'nav_add'),
        'page': const EntryMenuPage(),
        'icon': Icons.add_circle,
      },
      {'title': Translations.get(lang, 'nav_recipes'), 'page': const RecipeListaPage(), 'icon': Icons.bookmark},
      {'title': Translations.get(lang, 'nav_graphics'), 'page': const GraphicPage(), 'icon': Icons.show_chart},
    ];

    final scheme = Theme.of(context).colorScheme;
    // 2026-09-01: il titolo della Home era allineato a sinistra e piu' piccolo
    // (20px) rispetto alle altre tab, perche' cosi' lo mostrava il mockup della
    // Home. Ma nell'app vera si passa da una tab all'altra con un tocco, e il
    // titolo che salta di posizione e di dimensione si nota subito. Ora e'
    // centrato come Calendario, Ricette e Grafici. Nota storica: le altre 3 tab
    // sono centrate (font 21px) — unica eccezione fra le tab, non un refuso.

    return PopScope(
      // canPop false sempre: l'uscita la decide _gestisciIndietro, che a
      // seconda di dove siamo torna alla Home o chiude davvero.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _gestisciIndietro();
      },
      child: Scaffold(
      appBar: AppBar(
        // Sulla Home il marchio sta a sinistra, logo piu' grande e accanto il
        // nome scritto (richiesta di Ismail, 21/09): il logo da solo e'
        // centrato come un titolo qualsiasi e non si legge come marchio.
        // Le altre schede tengono il loro titolo centrato, che dice dove sei.
        title: currentIndex == 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/img/logo.png',
                    height: 36,
                    semanticLabel: 'NutriApp',
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'NutriApp',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 21,
                      letterSpacing: -.2,
                    ),
                  ),
                ],
              )
            : Text(
                navigationItems[currentIndex]['title'],
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 21,
                  letterSpacing: -.2,
                ),
              ),
        centerTitle: currentIndex != 0,
        // Il marchio parte dal bordo come il contenuto della Home, non dal
        // rientro che Material riserva al titolo quando non c'e' il "indietro".
        titleSpacing: currentIndex == 0 ? 12 : NavigationToolbar.kMiddleSpacing,
        elevation: 1,
        automaticallyImplyLeading: false,
        actions: [
          // Chiaro/scuro a portata di mano (richiesta 2026-09-05): prima si
          // poteva cambiare solo entrando nelle impostazioni, cioe' tre tocchi
          // per una cosa che si fa piu' volte al giorno a seconda della luce.
          IconButton(
            tooltip: Translations.get(lang, isDark ? 'Modalita chiara' : 'Modalita scura'),
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: scheme.primary,
            ),
            onPressed: () =>
                ref.read(appSettingsProvider.notifier).saveDarkMode(!isDark),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: scheme.primary),
            onPressed: () {
              // Naviga alla pagina di impostazioni
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingPage()),
              );
            },
          ),
        ],
      ),
      body: navigationItems[currentIndex]['page'],
      bottomNavigationBar: _BottomNav(
        currentIndex: currentIndex,
        items: navigationItems,
        onTap: (index) {
          ref.read(currentTabIndexProvider.notifier).state = index;
          // Se cambiamo tab manualmente, resettiamo il pasto iniziale per evitare bug
          if (index != 2) {
            ref.read(initialMealTypeProvider.notifier).state = null;
          }
        },
      ),
      ),
    );
  }
}

/// Barra di navigazione inferiore, ricostruita a mano (non
/// `BottomNavigationBar` di Material) per replicare esattamente il mockup
/// "Claude Design": il pulsante centrale "Add" è un cerchio pieno verde con
/// "+" bianco, sempre — a differenza delle altre 4 voci non cambia mai
/// colore/peso quando è la tab attiva, il cerchio pieno è già il suo segnale
/// visivo. Le altre voci diventano verdi + testo semibold solo se attive.
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final List<Map<String, dynamic>> items;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.primary.withValues(alpha: .12))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(items.length, (index) {
              final bool isAdd = index == 2;
              final bool selected = currentIndex == index && !isAdd;
              final Color color = selected ? scheme.primary : scheme.onSurfaceVariant;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAdd)
                        Transform.translate(
                          offset: const Offset(0, -4),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                            child: Icon(Icons.add, color: scheme.onPrimary, size: 26),
                          ),
                        )
                      else
                        Icon(items[index]['icon'] as IconData, size: 24, color: color),
                      const SizedBox(height: 2),
                      Text(
                        items[index]['title'] as String,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
