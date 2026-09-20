import 'package:flutter/material.dart';

import 'auth_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';
import '../dictionary/translations.dart';

/// BottomNavBar: Widget riutilizzabile per la navigazione tra le sezioni
///
/// Questo widget è indipendente da pagine specifiche per evitare import circolari
/// e mantieni la separazione delle responsabilità. La navigazione tra le pagine
/// è gestita dalla pagina padre tramite la callback [onItemSelected].
///
/// Parametri:
/// - [currentIndex]: indice della voce attualmente selezionata (0-based)
/// - [onItemSelected]: callback chiamata quando l'utente seleziona una voce
///
/// Voci disponibili:
/// - 0: Home (schermata principale con input dati)
/// - 1: Calendario (visualizzazione calendario)
/// - 2: Grafici (visualizzazione grafici dati)
/// - 3: Lista Ricette (elenco e gestione ricette)
class BottomNavBar extends ConsumerWidget {
  /// Indice della voce attiva (0 = Home, 1 = Calendario, 2 = Grafici, 3 = Lista Ricette)
  final int currentIndex;

  /// Callback chiamata quando l'utente seleziona una voce
  /// Riceve l'indice selezionato (0-3)
  final ValueChanged<int> onItemSelected;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).language;

    return BottomNavigationBar(
      currentIndex: currentIndex,
      // ===== STYLING =====
      // NB: questo widget oggi non e' istanziato da nessuna parte
      // (MainLayout ha la sua barra, ricostruita sul mockup). Tenuto
      // allineato al tema perche' un bianco fisso qui dentro tornerebbe a
      // rompere la modalita' scura il giorno in cui qualcuno lo riusa.
      backgroundColor: Nutri.bg,
      type: BottomNavigationBarType.fixed, // Consente 4+ voci senza animazione
      selectedItemColor: Nutri.green, // Icona verde quando selezionata
      unselectedItemColor: Nutri.muted, // Icona spenta quando non selezionata
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.green,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        color: Colors.grey,
      ),
      elevation: 8, // Ombra per staccare dalla pagina
      onTap: (index) {
        // Chiama la callback per notificare la pagina padre della selezione
        onItemSelected(index);
      },
      items: [
        // Home - Schermata principale con dati nutrizionali
        BottomNavigationBarItem(
          icon: const Icon(Icons.home),
          label: Translations.get(lang, 'Home'),
        ),
        // Calendario - Visualizzazione dei dati in calendario
        BottomNavigationBarItem(
          icon: const Icon(Icons.calendar_today),
          label: Translations.get(lang, 'nav_calendar'),
        ),
        // Grafici - Visualizzazione dei dati in grafici
        BottomNavigationBarItem(
          icon: const Icon(Icons.show_chart),
          label: Translations.get(lang, 'nav_graphics'),
        ),
        // Ricetta - apre la schermata per aggiungere/visualizzare ricette
        BottomNavigationBarItem(
          icon: const Icon(Icons.book),
          label: Translations.get(lang, 'nav_recipes'),
        ),
      ],
    );
  }
}
