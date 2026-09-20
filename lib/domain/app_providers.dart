import 'package:flutter_riverpod/legacy.dart';

// PROVIDERS DI IMPOSTAZIONI GLOBALI DELLA UI
// Questi servono solo per far funzionare i menu a tendina visivamente
// prima che l'utente prema "Salva" e mandi tutto al database.

/// Provider per la lingua selezionata nel menu a tendina
final linguaProvider = StateProvider<String>((ref) => 'Italiano');

/// Provider per il paese selezionato nel menu a tendina
final paeseProvider = StateProvider<String>((ref) => 'Italia');

/// Provider per l'unità di misura selezionata (es. Kg o Lb)
final unitProvider = StateProvider<String>((ref) => 'Kg');

/// Provider per l'indice corrente della BottomNavigationBar in MainLayout
final currentTabIndexProvider = StateProvider<int>((ref) => 0);

/// Provider per il pasto iniziale quando si naviga verso "Aggiungi"
final initialMealTypeProvider = StateProvider<String?>((ref) => null);

/// Primo rifiuto del tasto "indietro" da parte della schermata attiva.
///
/// La schermata mostrata dentro MainLayout puo' registrare qui una funzione:
/// se restituisce true vuol dire che ha gestito lei l'indietro (per esempio
/// tornando alla propria sotto-sezione principale) e MainLayout non deve
/// fare altro.
///
/// PERCHE' UN PROVIDER E NON UN PopScope ANNIDATO (2026-09-05): dentro la
/// stessa route i PopScope annidati vengono avvisati TUTTI, e non c'e' modo
/// per quello interno di dire a quello esterno "questa me la prendo io".
/// Con un solo PopScope in MainLayout la sequenza resta una sola e leggibile:
/// prima la schermata, poi la tab, poi l'uscita.
final gestoreIndietroProvider = StateProvider<bool Function()?>((ref) => null);

// ------------------- COSTANTI (Dati Statici Intoccabili) -------------------

/// Lista completa delle lingue supportate
const List<String> listaLingue = [
  'Italiano',
  'English',
  '简体中文',
  'العربية',
  'Spagnolo',
  'Francese',
  'Tedesco',
  'Portoghese',
];

/// Lista completa dei paesi (abbinati alle lingue)
const List<String> listaPaesi = ['Italia'];
