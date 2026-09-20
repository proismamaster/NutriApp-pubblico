import 'package:flutter/material.dart';

import 'widgets/auth_style.dart';

/// Tema Material costruito sui colori di [Nutri], per entrambe le luminosita'.
///
/// PERCHE' ESISTE (2026-09-07): l'app aveva due sorgenti di colore che non si
/// parlavano. Le schermate ridisegnate leggevano da `Nutri` (fondo #11150F,
/// un nero appena verde); tutte le altre dal ColorScheme di Material, che era
/// `Colors.black` puro. Passando da una schermata all'altra il nero cambiava
/// — il difetto che Ismail ha riassunto con "alcune screen sono di un nero
/// diverso da un'altra, il background deve essere coerente".
///
/// PERCHE' IN UN FILE SUO e non dentro `main.dart`: il test di verifica
/// visiva costruisce anche lui un MaterialApp, e prima si scriveva il proprio
/// tema a mano. Gli screenshot mostravano quindi colori che nell'app non
/// esistevano — una verifica visiva che verifica qualcosa d'altro e' peggio
/// che nessuna verifica. Da qui in poi il tema e' uno solo, e chi vuole
/// disegnare l'app lo chiede a questa funzione.
ThemeData temaNutri(Brightness b) {
  final scuro = b == Brightness.dark;

  // Verde di RIEMPIMENTO, non quello chiaro da testo: Material lo usa come
  // fondo dei pulsanti pieni, con `onPrimary` sopra. Vedi Nutri.greenFill per
  // il perche' i due non possono essere lo stesso colore.
  final primario = scuro ? const Color(0xFF2F8A44) : const Color(0xFF1B7A33);
  final fondo = scuro ? const Color(0xFF11150F) : const Color(0xFFF4F7EF);
  final superficie = scuro ? const Color(0xFF1B211A) : Colors.white;
  final inchiostro = scuro ? const Color(0xFFE6EDE3) : const Color(0xFF1F2A1C);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1B7A33),
      brightness: b,
      primary: primario,
      onPrimary: Colors.white,
      surface: fondo,
      onSurface: inchiostro,
      surfaceContainerHighest: superficie,
      outlineVariant: scuro ? const Color(0xFF2C352A) : const Color(0xFFE1E8DA),
    ),
    scaffoldBackgroundColor: fondo,
    appBarTheme: AppBarTheme(
      backgroundColor: fondo,
      foregroundColor: inchiostro,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: superficie,
      elevation: scuro ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: fondo,
      selectedItemColor: primario,
      unselectedItemColor:
          scuro ? const Color(0xFF97A193) : const Color(0xFF7D857A),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: superficie,
      contentTextStyle: TextStyle(color: inchiostro),
      // Staccato dal fondo: attaccato al bordo copriva i pulsanti fissi in
      // basso ("Verifica il codice", "Salva"), che restavano intoccabili
      // finche' non spariva (test di release 19/09).
      behavior: SnackBarBehavior.floating,
      insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
    ),
  );
}
