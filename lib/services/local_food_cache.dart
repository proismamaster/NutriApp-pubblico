import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';

/// Copia sul telefono degli alimenti personali e delle ricette dell'utente.
///
/// PERCHE' ESISTE (2026-09-05): la "libreria personale" viveva solo sul
/// server. La ricerca la mescola gia' ai risultati esterni, ma la lista da
/// cui pesca arriva da `get_custom_foods.php`: senza rete quella lista e'
/// vuota, e cercando un alimento creato dall'utente stesso non usciva NIENTE
/// — proprio la cosa che dovrebbe esserci sempre, perche' e' sua.
///
/// PERCHE' NON UN DATABASE VERO (sqflite): sono decine di righe, non
/// migliaia, e vengono lette tutte insieme all'apertura della schermata per
/// filtrarle in memoria. Una tabella SQL aggiungerebbe una dipendenza,
/// migrazioni e uno schema da tenere allineato a quello del server, per
/// interrogazioni che qui non esistono.
///
/// La copia e' per utente: due account sullo stesso telefono non devono
/// vedersi gli alimenti a vicenda.
class LocalFoodCache {
  const LocalFoodCache._();

  static String _chiaveAlimenti(String email) => 'cache_alimenti_$email';
  static String _chiaveRicette(String email) => 'cache_ricette_$email';

  static Future<void> salvaAlimenti(
    String email,
    List<Map<String, dynamic>> alimenti,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chiaveAlimenti(email), jsonEncode(alimenti));
  }

  static Future<List<Map<String, dynamic>>> leggiAlimenti(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final testo = prefs.getString(_chiaveAlimenti(email));
    if (testo == null || testo.isEmpty) return [];
    try {
      final lista = jsonDecode(testo) as List;
      return lista.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      // Copia illeggibile (formato cambiato fra due versioni dell'app):
      // meglio ripartire da zero che far crollare la schermata.
      return [];
    }
  }

  static Future<void> salvaRicette(String email, List<Recipe> ricette) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chiaveRicette(email),
      jsonEncode(ricette.map((r) => r.toJson(email)).toList()),
    );
  }

  static Future<List<Recipe>> leggiRicette(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final testo = prefs.getString(_chiaveRicette(email));
    if (testo == null || testo.isEmpty) return [];
    try {
      final lista = jsonDecode(testo) as List;
      return lista
          .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Cancella la copia di un utente: da chiamare all'uscita dall'account,
  /// altrimenti chi usa il telefono dopo di lui trova i suoi alimenti.
  static Future<void> svuota(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chiaveAlimenti(email));
    await prefs.remove(_chiaveRicette(email));
  }
}
