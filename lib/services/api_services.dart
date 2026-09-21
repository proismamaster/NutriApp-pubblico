import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nutriapp/models/custom_food.dart';

import '../models/contributi_utente.dart';
import '../models/food_entry.dart';
import '../models/daily_summary.dart';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';
import '../models/physical_measurement.dart';

/// Un singolo aggiornamento della ricerca "live" (vedi
/// [ApiServices.searchProductsStream]): [results] è lo stato aggregato più
/// aggiornato (già deduplicato e ordinato), [networkError] segnala che
/// tutte le fonti hanno fallito, [isDone] indica se è l'ultimo aggiornamento
/// (tutte le fonti hanno risposto) o se altre sono ancora in corso e
/// potrebbero aggiungere/riordinare risultati a breve.
typedef SearchUpdate = ({
  List<Map<String, dynamic>> results,
  bool networkError,
  bool isDone,
});

/// Criterio di ordinamento della ricerca prodotti (barra "Ordina per",
/// richiesta 2026-08-23). [relevance] resta il default: lo score ibrido
/// testo+popolarità già usato prima di questa modifica. Gli altri sono
/// ordinamenti semplici lato client sul risultato già unito/deduplicato,
/// così funzionano identici su tutte le fonti (CREA/OFF-locale/USDA) senza
/// dover ripetere la logica in ogni endpoint PHP.
enum SearchSortMode {
  relevance,
  popularity,
  nameAsc,
  nameDesc,
  nutriscore,
  nova,
  ecoscore,
}

/// Filtri per i tre punteggi standard OpenFoodFacts (Nutri-Score, NOVA,
/// Eco-Score), richiesta 2026-08-23 (mockup "App mobile con filtri e
/// ordinamento"). Applicati lato client sul risultato già unito fra le
/// fonti, stesso motivo di [SearchSortMode]: CREA/USDA non hanno questi
/// campi, quindi un prodotto senza il punteggio scelto esce correttamente
/// dal filtro invece di richiedere un caso speciale per fonte.
typedef ScoreFilters = ({
  Set<String> nutriscore, // 'a'..'e'
  Set<int> nova, // 1..4
  Set<String> ecoscore, // 'a'..'e'
});

const ScoreFilters nessunFiltroScore = (nutriscore: {}, nova: {}, ecoscore: {});

class ApiServices {
  /// Indirizzo del server, con la barra finale. In produzione e' quello del
  /// Galilei; per le prove si punta un server locale senza toccare il codice:
  /// `--dart-define=NUTRI_API=http://127.0.0.1:8790/` (19/09, test di release).
  static const String base = String.fromEnvironment(
    'NUTRI_API',
    defaultValue: 'https://progetti.galileicrema.org/nutriapp/',
  );

  /// Gettone della sessione: il server lo consegna all'accesso e da quel
  /// momento riconosce l'utente da questo, non dall'email scritta nella
  /// richiesta. Prima chiunque poteva chiedere i dati di un altro cambiando
  /// un parametro (test di release 19/09).
  static String? gettone;

  /// Rete dell'app: un client solo, che attacca il gettone a ogni richiesta.
  static final http.Client _rete = _ClientConGettone();

  static const String _urlServerSave =
      '${base}save_entry.php';
  static const String _urlServerLoad =
      '${base}get_entry.php';
  static const String _urlServerDelete =
      '${base}delete_entry.php';
  static const String _urlServerUpdate =
      '${base}update_entry.php';
  static const String _urlServerDailySummary =
      '${base}get_daily_summary.php';
  static const String _urlServerSaveRecipe =
      '${base}save_recipe.php';
  static const String _urlServerLoadRecipes =
      '${base}get_recipes.php';
  static const String _urlServerRecipeDelete =
      '${base}delete_recipe.php';
  static const String _urlServerUpdateRecipe =
      '${base}update_recipe.php';
  static const String _urlServerSignup =
      '${base}signup.php';
  static const String _urlServerLogin =
      '${base}login.php';
  static const String _urlServerUpdateGoals =
      '${base}update_goals.php';
  static const String _urlServerUpdateProfile =
      '${base}update_profile.php';
  static const String _urlServerGetUserData =
      '${base}get_user_data.php';
  static const String _urlServerSaveCustomFood =
      '${base}save_custom_food.php';
  static const String _urlServerFetchCustomFoods =
      '${base}get_custom_foods.php';
  static const String _urlServerDeleteCustomFood =
      '${base}delete_custom_food.php';
  static const String _urlServerSendOTP =
      '${base}send_otp.php';
  static const String _urlServerVerifyOTP =
      '${base}verify_otp.php';
  static const String _urlServerSocialLogin =
      '${base}social_login.php';
  static const String _urlServerResetPassword =
      '${base}reset_password.php';
  /// Alimenti personali approvati da un admin, per la ricerca di tutti
  /// (2026-09-14). Vedi search_community_foods.php.
  static const String _urlServerSearchCommunity =
      '${base}search_community_foods.php';

  static const String _urlServerSearchCrea =
      '${base}search_crea_foods.php';
  // Cache locale di prodotti OpenFoodFacts importati in blocco (na_off_products,
  // vedi fileDatabase/search_off_products.php e fileDatabase/tools/import_off_italy.py).
  // Popolata 2026-07-24 con l'export bulk italiano (214k+ prodotti): è ora la
  // fonte primaria per la ricerca testuale, non dipende da rate limit/uptime
  // di nessun servizio esterno.
  static const String _urlServerSearchOffProducts =
      '${base}search_off_products.php';
  static const String _urlServerListInsegne =
      '${base}list_insegne.php';
  static const String _urlServerSaveReport =
      '${base}save_report.php';
  // Collaborazione fra utenti (2026-09-12): segnalazioni sui dati,
  // condivisione dei propri alimenti/ricette, elenco delle ricette pubbliche.
  // Richiedono la migrazione 2026-09-12_collaborazione_community.sql e i file
  // PHP omonimi piu' community_comune.php caricati via FTP.
  static const String _urlServerSaveFoodReport =
      '${base}save_food_report.php';
  // Segnalazione di una ricetta pubblica (21/09): tabella `na_recipe_reports`,
  // migrazione 2026-09-21_segnalazioni_ricette.sql.
  static const String _urlServerSaveRecipeReport =
      '${base}save_recipe_report.php';
  static const String _urlServerSetSharingPreference =
      '${base}set_sharing_preference.php';
  static const String _urlServerShareCustomFood =
      '${base}share_custom_food.php';
  static const String _urlServerShareRecipe =
      '${base}share_recipe.php';
  static const String _urlServerPublicRecipes =
      '${base}get_public_recipes.php';
  static const String _urlServerMyReports =
      '${base}get_my_reports.php';
  static const String _urlServerRecipeLike =
      '${base}toggle_recipe_like.php';
  // Traduzione automatica ingredienti (MyMemory lato server, con cache),
  // richiesta 2026-07-24. Vedi fileDatabase/translate_text.php.
  static const String _urlServerTranslate =
      '${base}translate_text.php';

  /// Mappa il nome lingua usato in Translations.strings ('Italiano',
  /// 'English', '简体中文', 'العربية') al codice ISO a 2 lettere richiesto
  /// da translate_text.php. Le chiavi di Translations sono nomi visualizzati,
  /// non codici — vedi lib/dictionary/translations.dart.
  static String _isoLangCode(String displayLanguage) {
    switch (displayLanguage) {
      case 'Italiano':
        return 'it';
      case 'English':
        return 'en';
      case '简体中文':
        return 'zh';
      case 'العربية':
        return 'ar';
      default:
        return 'it';
    }
  }

  /// Traduce [text] (tipicamente un elenco ingredienti OpenFoodFacts) nella
  /// lingua dell'app se necessario. Ritorna il testo originale (invariato)
  /// se la richiesta fallisce o se il testo è già nella lingua giusta —
  /// mai un errore visibile o un campo vuoto per l'utente.
  static Future<({String text, bool wasTranslated})> translateIngredients(
    String text,
    String displayLanguage,
  ) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return (text: text, wasTranslated: false);
    try {
      final target = _isoLangCode(displayLanguage);
      final url = Uri.parse(
        '$_urlServerTranslate?text=${Uri.encodeComponent(trimmed)}&target=$target',
      );
      final response = await _rete.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final String translated = data['translated_text'] ?? trimmed;
          final bool sameLanguage = data['same_language'] == true;
          return (text: translated, wasTranslated: !sameLanguage);
        }
      }
    } catch (e) {
      debugPrint("Traduzione ingredienti fallita, mostro il testo originale: $e");
    }
    return (text: text, wasTranslated: false);
  }

  // Credenziali USDA FDC (American DB). NON hardcodare qui la key: passarla
  // a build-time con `--dart-define=USDA_API_KEY=...` (o
  // `--dart-define-from-file=dart_define.json`, escluso da git — vedi
  // dart_define.example.json nella root del repo). Nota: qualunque valore
  // finisce comunque nel bundle compilato dell'app (rischio noto per i
  // secret lato client, vedi vault → DECISIONS), ma non resta più nel
  // sorgente versionato.
  static const String _usdaApiKey = String.fromEnvironment('USDA_API_KEY');

  /// POST form-urlencoded con la risposta intera del server (2026-09-14).
  ///
  /// Distingue tre casi che prima diventavano tutti `false`: nessuna rete
  /// (`network`), una pagina che non e' JSON — il 404 di un file mai caricato,
  /// un errore fatale di PHP — (`server_error`, con lo stato HTTP), e la
  /// risposta vera, restituita cosi' com'e'.
  static Future<Map<String, dynamic>> _postModulo(String url, Map<String, String> campi) async {
    final http.Response response;
    try {
      response = await _rete
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: campi,
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      return {'status': 'error', 'code': 'network'};
    }
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
    } catch (_) {
      // Non e' JSON: si ricade sotto.
    }
    return {'status': 'error', 'code': 'server_error', 'message': 'HTTP ${response.statusCode}'};
  }

  static Future<bool> sendOTP(String email) async =>
      (await sendOTPEsito(email))['status'] == 'success';

  /// Come [sendOTP], ma con la risposta intera: il recupero password deve poter
  /// dire PERCHE' il codice non e' partito. "Chiave Brevo non configurata" e
  /// "nessuna rete" si risolvono in modi opposti, e un `false` li rendeva uguali.
  static Future<Map<String, dynamic>> sendOTPEsito(String email) =>
      _postModulo(_urlServerSendOTP, {'email': email});

  static Future<bool> verifyOTP(String email, String otp) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerVerifyOTP),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'email': email, 'otp': otp},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Recupero password, passi 2 e 3 (2026-09-14).
  ///
  /// Senza [newPassword] controlla soltanto il codice, senza consumarlo; con
  /// [newPassword] lo ricontrolla e cambia la password. La risposta ha sempre
  /// `status` e un `code` fisso (elenco in reset_password.php) che la
  /// schermata traduce in un messaggio.
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    String? newPassword,
  }) =>
      _postModulo(_urlServerResetPassword, {
        'email': email,
        'otp': otp,
        if (newPassword == null) 'check_only': '1' else 'new_password': newPassword,
      });

  static Future<Map<String, dynamic>?> socialLogin({
    required String email,
    required String provider,
    required String providerId,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerSocialLogin),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'provider': provider,
          'provider_id': providerId,
          'first_name': firstName,
          'last_name': lastName,
        }),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchProductByBarcode(
    String barcode, {
    String lang = 'it',
    String userMail = '',
  }) async {
    try {
      final langCode = (lang == 'English') ? 'en' : 'it';
      Map<String, dynamic>? bestResult;

      // 1. Proviamo prima sul nostro database locale. L'email serve a cercare
      // il codice nella libreria di CHI chiede: senza, il server rispondeva
      // con l'alimento privato di un altro utente (test di release 19/09).
      final localUrl =
          '${base}get_product_by_barcode.php?barcode=$barcode&lang=$langCode'
          '&user_mail=${Uri.encodeQueryComponent(userMail)}';
      final localResp = await _rete
          .get(Uri.parse(localUrl))
          .timeout(const Duration(seconds: 3));

      if (localResp.statusCode == 200) {
        final localData = json.decode(localResp.body);
        if (localData['status'] == 'success' && localData['product'] != null) {
          bestResult = _mapPhpProduct(localData['product'], langCode: langCode);
          if (_isDataComplete(bestResult)) return bestResult;
        }
      }

      // 2. Se non lo troviamo o dati incompleti, proviamo su OpenFoodFacts
      final offUrl =
          'https://it.openfoodfacts.org/api/v0/product/$barcode.json';
      final offResp = await _rete.get(
        Uri.parse(offUrl),
        headers: {'User-Agent': 'NutriApp - Android - 1.2'},
      );

      if (offResp.statusCode == 200) {
        final offData = json.decode(offResp.body);
        if (offData['status'] == 1 && offData['product'] != null) {
          final p = offData['product'];
          final offResult = _mapOpenFoodFactsToInternal(p, langCode: langCode);
          
          // Se OFF ha dati completi, lo usiamo. Altrimenti lo teniamo come backup e proviamo USDA.
          if (_isDataComplete(offResult)) return offResult;
          bestResult ??= offResult; 
        }
      }

      // 3. Come ultima spiaggia, usiamo il database americano (USDA)
      final fdcUrl = Uri.parse(
        'https://api.nal.usda.gov/fdc/v1/foods/search?api_key=$_usdaApiKey&query=$barcode',
      );
      final fdcResp = await _rete
          .get(fdcUrl)
          .timeout(const Duration(seconds: 4));
      if (fdcResp.statusCode == 200) {
        final data = json.decode(fdcResp.body);
        final List foods = data['foods'] ?? [];
        if (foods.isNotEmpty) {
          final usdaResult = _mapUsdaToInternal(foods.first);
          if (_isDataComplete(usdaResult)) return usdaResult;
          bestResult ??= usdaResult;
        }
      }

      return bestResult;
    } catch (e) {
      return null;
    }
  }

  static bool _isDataComplete(Map<String, dynamic>? data) {
    if (data == null) return false;
    final double kcal = _parseDouble(data['calories']);
    final double prot = _parseDouble(data['proteins']);
    final double carb = _parseDouble(data['carbs']);
    final double fat = _parseDouble(data['fats']);
    // Consideriamo i dati completi se abbiamo almeno le calorie o almeno due
    // macro principali. "Due qualsiasi delle tre" e' cio' che il commento ha
    // sempre detto, ma il codice guardava solo proteine e carboidrati: un
    // prodotto con carboidrati e grassi (l'olio, la pasta secca) risultava
    // incompleto pur avendo due macro su tre.
    final macroPresenti =
        (prot > 0 ? 1 : 0) + (carb > 0 ? 1 : 0) + (fat > 0 ? 1 : 0);
    return kcal > 0 || macroPresenti >= 2;
  }

  static Map<String, dynamic> _mapOpenFoodFactsToInternal(
    Map<String, dynamic> p, {
    String langCode = 'it',
  }) {
    final nut = p['nutriments'] ?? {};
    String name =
        p['product_name_$langCode'] ??
        p['product_name_it'] ??
        p['product_name'] ??
        p['generic_name_$langCode'] ??
        p['generic_name_it'] ??
        'Prodotto scansionato';
    String? brand = p['brands'];
    if (brand != null &&
        brand.isNotEmpty &&
        !name.toLowerCase().contains(brand.toLowerCase())) {
      name = '$name ($brand)';
    }

    double kcal = 0.0;
    if (nut['energy-kcal_100g'] != null) {
      kcal = _parseDouble(nut['energy-kcal_100g']);
    } else if (nut['energy-kcal_serving'] != null) {
      kcal = _parseDouble(nut['energy-kcal_serving']);
    } else if (nut['energy-kcal'] != null) {
      kcal = _parseDouble(nut['energy-kcal']);
    } else if (nut['energy_100g'] != null) {
      // Se abbiamo solo kJ (energy_100g), convertiamo in kcal
      kcal = _parseDouble(nut['energy_100g']) / 4.184;
    } else if (nut['energy_serving'] != null) {
      kcal = _parseDouble(nut['energy_serving']) / 4.184;
    } else if (nut['energy-kj_100g'] != null) {
      kcal = _parseDouble(nut['energy-kj_100g']) / 4.184;
    }

    double findNut(String key) {
      return _parseDouble(nut['${key}_100g']) > 0 
          ? _parseDouble(nut['${key}_100g']) 
          : _parseDouble(nut[key]);
    }

    return {
      'food_name': _toSentenceCase(name),
      'barcode': p['code']?.toString(),
      'base_weight_g': 100.0,
      'calories': kcal,
      'proteins': findNut('proteins'),
      'carbs': findNut('carbohydrates'),
      'fats': findNut('fat'),
      'fibers': findNut('fiber'),
      'sugars': findNut('sugars'),
      'saturated_fats': findNut('saturated-fat'),
      'sodium': findNut('sodium') * 1000,
      'vit_a': findNut('vitamin-a') * 1000000,
      'vit_c': findNut('vitamin-c') * 1000,
      'vit_d': findNut('vitamin-d') * 1000000,
      'vit_b12': findNut('vitamin-b12') * 1000000,
      'iron': findNut('iron') * 1000,
      'calcium': findNut('calcium') * 1000,
      'serving_quantity': _extractServingQuantity(p),
    };
  }

  static double _extractServingQuantity(Map<String, dynamic> p) {
    if (p['serving_quantity'] != null) return _parseDouble(p['serving_quantity']);
    final String? size = p['serving_size']?.toString();
    if (size != null) {
      // Prova a estrarre il primo numero dalla stringa (es "150 g" -> 150)
      final match = RegExp(r'(\d+[\.,]?\d*)').firstMatch(size);
      if (match != null) return _parseDouble(match.group(1));
    }
    // Fallback: prova a usare la quantità totale della confezione
    final String? totalQty = p['quantity']?.toString();
    if (totalQty != null) {
      final match = RegExp(r'(\d+[\.,]?\d*)').firstMatch(totalQty);
      if (match != null) return _parseDouble(match.group(1));
    }
    return 0.0;
  }

  /// Versione "live" della ricerca prodotti: interroga CREA, cache OFF
  /// locale, OFF live e USDA in parallelo, ma **non aspetta la fonte più
  /// lenta prima di mostrare qualcosa** — emette un aggiornamento ogni volta
  /// che una singola fonte risponde, così la UI può mostrare i primi
  /// risultati (tipicamente CREA/cache locale, i più veloci perché non
  /// dipendono da API esterne) mentre le altre fonti sono ancora in volo,
  /// invece di bloccare tutto dietro il tempo della fonte più lenta.
  /// [insegne] filtra i risultati da `na_off_products` a uno o più
  /// supermercati (vedi `na_product_retailer` / `list_insegne.php`) —
  /// "questa insegna è stata VISTA vendere il prodotto durante la
  /// raccolta", non disponibilità in tempo reale. Si applica solo alla
  /// fonte OFF locale: CREA/USDA non hanno un concetto di insegna, restano
  /// invariate. [sortMode] riordina il risultato finale già unito fra le
  /// fonti (default: rilevanza).
  static Stream<SearchUpdate> searchProductsStream(
    String query, {
    List<String>? insegne,
    ScoreFilters scoreFilters = nessunFiltroScore,
    SearchSortMode sortMode = SearchSortMode.relevance,
  }) {
    final controller = StreamController<SearchUpdate>();
    final hasInsegne = insegne != null && insegne.isNotEmpty;
    final hasScoreFilters = scoreFilters.nutriscore.isNotEmpty ||
        scoreFilters.nova.isNotEmpty ||
        scoreFilters.ecoscore.isNotEmpty;
    final hasBrowseFilter = hasInsegne || hasScoreFilters;

    () async {
      // 1. SANIFICAZIONE: rimuove punteggiatura finale e spazi extra
      String sanitizedQuery = query
          .trim()
          .replaceAll(RegExp(r'[.,\-]$'), '')
          .trim();
      final String cleanQuery = _preprocessQuery(sanitizedQuery);

      // Query vuota ammessa SOLO con almeno un filtro attivo (insegna e/o
      // punteggio): "sfoglia" senza aver digitato nulla (tap diretto sul
      // filtro) è un caso d'uso legittimo, non un errore — vedi
      // search_off_products.php. In quel caso CREA/USDA non hanno senso (non
      // supportano insegna, e una query vuota per loro non vorrebbe dire
      // niente): solo la fonte OFF.
      if (cleanQuery.isEmpty && !hasBrowseFilter) {
        controller.add((
          results: <Map<String, dynamic>>[],
          networkError: false,
          isDone: true,
        ));
        await controller.close();
        return;
      }
      if (cleanQuery.isEmpty) {
        final result = await _searchOffProductsLocalDb('', insegne: insegne);
        final filtered = _applyScoreFilters(result ?? [], scoreFilters);
        final sorted = _sortResults(filtered, sortMode, '');
        controller.add((
          results: sorted,
          networkError: result == null,
          isDone: true,
        ));
        await controller.close();
        return;
      }

      // _searchOpenFoodFactsItalianDb (ricerca LIVE su cgi/search.pl, l'endpoint
      // legacy di OpenFoodFacts) NON e' piu' tra le fonti della ricerca testuale
      // da qui: da quando na_off_products e' popolata con l'export bulk italiano
      // (214k+ prodotti, 2026-07-24), quella fonte era quasi sempre ridondante
      // e spesso rispondeva con errore (503 diffusi lato OFF dall'aprile 2026,
      // vedi PROBLEMS.md) dopo aver comunque fatto aspettare la UI fino al
      // timeout. Resta usata SOLO per lo scan barcode (getProductByBarcode),
      // che chiama un endpoint OFF diverso e sano (api/v0/product/{barcode}.json,
      // non cgi/search.pl) — quello va tenuto: trova prodotti nuovi non ancora
      // presenti nell'export bulk locale.
      final futures = <Future<List<Map<String, dynamic>>?>>[
        _searchCreaItalianDb(cleanQuery),
        _searchOffProductsLocalDb(cleanQuery, insegne: insegne),
        _searchUsdaAmericanDb(cleanQuery),
        _searchCommunityFoods(cleanQuery),
      ];

      final collected = <Map<String, dynamic>>[];
      int failedCount = 0;
      int remaining = futures.length;

      void emit() {
        final isDone = remaining == 0;

        // Rimozione duplicati basata sul nome
        final seen = <String>{};
        final uniqueResults = collected.where((item) {
          final name = (item['food_name'] ?? '').toString().toLowerCase();
          return name.isNotEmpty && seen.add(name);
        }).toList();

        final filteredResults = _applyScoreFilters(uniqueResults, scoreFilters);
        final sortedResults = _sortResults(filteredResults, sortMode, cleanQuery);

        // "Tutte le fonti fallite" ha senso solo a ricerca conclusa: se una
        // fonte veloce ha già dato 0 risultati ma altre sono ancora in
        // corso, non è ancora un errore di rete, è solo presto per dirlo.
        final networkError = isDone && failedCount == futures.length;

        // Nessun tetto artificiale qui (richiesta esplicita 2026-07-24): tutti
        // i risultati raccolti vengono mostrati, gia' ordinati per rilevanza
        // sopra. Il tetto reale resta quello lato SQL (vedi search_off_products.php
        // / search_crea_foods.php), alzato per non tagliare troppo presto ma
        // comunque limitato per non appesantire query su tabelle da 214k righe.
        if (controller.isClosed) return;
        controller.add((
          results: sortedResults,
          networkError: networkError,
          isDone: isDone,
        ));
      }

      for (final future in futures) {
        // Volutamente non "await"-ato qui: ogni fonte deve poter emettere
        // il proprio aggiornamento in modo indipendente, non appena
        // risponde, senza aspettare le altre.
        future.then((result) {
          remaining--;
          if (result == null) {
            failedCount++;
          } else {
            collected.addAll(result);
          }
          emit();
          if (remaining == 0) controller.close();
        });
      }
    }();

    return controller.stream;
  }

  /// Risultato di una ricerca prodotti: [results] è sempre una lista valida
  /// (eventualmente vuota), [networkError] è true solo se **tutte** le fonti
  /// esterne hanno fallito per un problema di rete/timeout/HTTP — permette
  /// alla UI di distinguere "nessun risultato" da "errore di connessione".
  /// Implementata sopra [searchProductsStream]: aspetta l'ultimo
  /// aggiornamento (tutte le fonti risposte) invece di mostrarli
  /// progressivamente — utile se in futuro serve un risultato "completo"
  /// in un colpo solo. La UI di ricerca usa direttamente
  /// [searchProductsStream] per mostrare risultati non appena arrivano.
  static Future<({List<Map<String, dynamic>> results, bool networkError})>
  searchProducts(
    String query, {
    List<String>? insegne,
    ScoreFilters scoreFilters = nessunFiltroScore,
    SearchSortMode sortMode = SearchSortMode.relevance,
  }) async {
    final last = await searchProductsStream(
      query,
      insegne: insegne,
      scoreFilters: scoreFilters,
      sortMode: sortMode,
    ).last;
    return (results: last.results, networkError: last.networkError);
  }

  /// Restringe [results] a chi rispetta i punteggi selezionati in
  /// [filters] (multi-selezione, OR fra i valori dello stesso punteggio,
  /// AND fra punteggi diversi). Un filtro vuoto per un punteggio non
  /// restringe nulla su quel campo. Un prodotto senza il campo (CREA/USDA
  /// non hanno nutriscore_grade/nova_group/environmental_score_grade) esce
  /// dal filtro se quel punteggio ha una selezione attiva — non c'e' modo
  /// di sapere se rispetterebbe il criterio, quindi non si include.
  static List<Map<String, dynamic>> _applyScoreFilters(
    List<Map<String, dynamic>> results,
    ScoreFilters filters,
  ) {
    if (filters.nutriscore.isEmpty && filters.nova.isEmpty && filters.ecoscore.isEmpty) {
      return results;
    }
    return results.where((item) {
      if (filters.nutriscore.isNotEmpty) {
        final g = (item['nutriscore_grade'] ?? '').toString().toLowerCase();
        if (!filters.nutriscore.contains(g)) return false;
      }
      if (filters.nova.isNotEmpty) {
        final n = (item['nova_group'] as num?)?.toInt();
        if (n == null || !filters.nova.contains(n)) return false;
      }
      if (filters.ecoscore.isNotEmpty) {
        final e = (item['environmental_score_grade'] ?? '').toString().toLowerCase();
        if (!filters.ecoscore.contains(e)) return false;
      }
      return true;
    }).toList();
  }

  /// Ordina il risultato già unito fra le fonti secondo [mode]. Per
  /// [SearchSortMode.relevance] resta lo score ibrido testo+popolarità
  /// (comportamento pre-2026-08-23, invariato). Gli altri modi sono
  /// ordinamenti semplici: campi assenti (es. `unique_scans_n`/
  /// `nutriscore_grade` per CREA/USDA, che non li hanno) finiscono in fondo
  /// invece di rompere l'ordinamento o essere trattati come "i migliori".
  static List<Map<String, dynamic>> _sortResults(
    List<Map<String, dynamic>> results,
    SearchSortMode mode,
    String query,
  ) {
    final sorted = List<Map<String, dynamic>>.from(results);
    switch (mode) {
      case SearchSortMode.relevance:
        final qLower = query.toLowerCase();
        sorted.sort((a, b) {
          final double scoreA = _calculateHybridScore(a, qLower);
          final double scoreB = _calculateHybridScore(b, qLower);
          if (scoreA != scoreB) return scoreB.compareTo(scoreA);
          // Fallback: nome più corto (di solito più generico/rilevante)
          return (a['food_name'] as String).length.compareTo(
            (b['food_name'] as String).length,
          );
        });
        break;
      case SearchSortMode.popularity:
        sorted.sort((a, b) {
          final int scansA = (a['unique_scans_n'] as num?)?.toInt() ?? 0;
          final int scansB = (b['unique_scans_n'] as num?)?.toInt() ?? 0;
          return scansB.compareTo(scansA);
        });
        break;
      case SearchSortMode.nameAsc:
        sorted.sort(
          (a, b) => (a['food_name'] ?? '').toString().toLowerCase().compareTo(
            (b['food_name'] ?? '').toString().toLowerCase(),
          ),
        );
        break;
      case SearchSortMode.nameDesc:
        sorted.sort(
          (a, b) => (b['food_name'] ?? '').toString().toLowerCase().compareTo(
            (a['food_name'] ?? '').toString().toLowerCase(),
          ),
        );
        break;
      case SearchSortMode.nutriscore:
        // a..e -> 0..4, mancante/non valido -> 5 (in fondo, non "il migliore").
        int rank(Map<String, dynamic> item) {
          final g = (item['nutriscore_grade'] ?? '').toString().toLowerCase();
          const order = ['a', 'b', 'c', 'd', 'e'];
          final i = order.indexOf(g);
          return i == -1 ? 5 : i;
        }

        sorted.sort((a, b) => rank(a).compareTo(rank(b)));
        break;
      case SearchSortMode.nova:
        // 1..4 -> meno lavorato prima; mancante -> in fondo.
        int rank(Map<String, dynamic> item) {
          final n = (item['nova_group'] as num?)?.toInt();
          return (n == null || n < 1 || n > 4) ? 5 : n;
        }

        sorted.sort((a, b) => rank(a).compareTo(rank(b)));
        break;
      case SearchSortMode.ecoscore:
        int rank(Map<String, dynamic> item) {
          final g = (item['environmental_score_grade'] ?? '').toString().toLowerCase();
          const order = ['a', 'b', 'c', 'd', 'e'];
          final i = order.indexOf(g);
          return i == -1 ? 5 : i;
        }

        sorted.sort((a, b) => rank(a).compareTo(rank(b)));
        break;
    }
    return sorted;
  }

  static double _calculateHybridScore(Map<String, dynamic> item, String query) {
    double score = 0;
    // Normalizziamo anche il nome dal DB per gestire accenti e apostrofi
    final String name = _removeDiacritics(
      (item['raw_name'] ?? '').toString().toLowerCase(),
    );
    final String brand = (item['brand'] ?? '').toString().toLowerCase();

    // LIVELLO 1: Corrispondenza Testo (Dominante)
    if (name == query) {
      score += 1000;
    } else if (name.startsWith(query)) {
      score += 500;
    } else if (name.contains(' $query') || name.contains('$query ')) {
      score += 200;
    }

    // Match per singole parole
    final queryWords = query.split(' ').where((w) => w.length > 2).toList();
    int wordMatches = 0;
    for (final word in queryWords) {
      if (name.contains(word)) {
        wordMatches++;
        score += 50;
      }
    }
    if (queryWords.isNotEmpty && wordMatches == queryWords.length) {
      score += 100; // Bonus se contiene tutte le parole della query
    }

    if (brand.isNotEmpty && query.contains(brand)) {
      score += 50;
    }

    // Penalizzazione per termini troppo specifici/derivati se la query è corta
    if (query.length < 6) {
      final derivatives = ['nettare', 'bevanda', 'preparato', 'condimento'];
      if (derivatives.any((d) => name.contains(d))) score -= 200;
    }

    // LIVELLO 2: Priorità Database (Spareggio)
    if (item['source'] == 'crea_it') {
      score += 150; // Priorità assoluta a DB locale
    } else if (item['source'] == 'openfoodfacts_it' ||
        item['source'] == 'off_local_it') {
      // Stesso punteggio per OFF live e OFF importato in locale: stessa
      // fonte di dati, cambia solo il canale (live vs cache locale).
      score += 80;
    } else if (item['source'] == 'community') {
      // Approvati da un admin (14/09): sopra USDA, sotto CREA e OFF, che
      // hanno fonti ufficiali dietro.
      score += 60;
    } else if (item['source'] == 'usda_american_db') {
      score += 0; // Fallback USDA
    }

    return score;
  }

  static String _removeDiacritics(String str) {
    const withDia = 'àáâãäåòóôõöøèéêëðçìíîïùúûüñšÿ';
    const withoutDia = 'aaaaaaooooooeeeeeciiiiuuuuunsy';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    // Rimuove anche l'apostrofo finale o interno che spesso sostituisce l'accento
    str = str.replaceAll("'", " ");
    return str;
  }

  /// Normalizzazione testo per ricerca (accenti/apostrofi rimossi, minuscolo,
  /// filler word italiane tolte): stessa logica usata internamente per le
  /// fonti server (CREA/OFF-locale/USDA), esposta qui in modo che anche la
  /// ricerca client-side sugli alimenti personalizzati (`entry_menu_page.dart`,
  /// che non passa mai da queste API PHP) usi lo stesso trattamento invece di
  /// un confronto grezzo che ignora accenti/ordine delle parole.
  static String normalizeForSearch(String q) => _preprocessQuery(q);

  static String _preprocessQuery(String q) {
    // Rimosso 'con' e 'senza' dai filler per non perdere il senso della ricerca
    final fillers = [
      'di',
      'del',
      'della',
      'dei',
      'degli',
      'delle',
      'al',
      'alla',
      'ai',
      'agli',
      'alle',
      'in',
      'un',
      'una',
      'lo',
      'la',
      'il',
    ];

    String normalized = _removeDiacritics(q.toLowerCase());

    return normalized
        .split(' ')
        .where((w) => !fillers.contains(w) && w.isNotEmpty)
        .join(' ');
  }

  /// Restituisce `null` se la fonte ha fallito per un problema di
  /// rete/timeout/HTTP (distinto da "nessun risultato", che è `[]`).
  static Future<List<Map<String, dynamic>>?> _searchCreaItalianDb(
    String q,
  ) async {
    try {
      final url = Uri.parse(
        '$_urlServerSearchCrea?query=${Uri.encodeComponent(q)}',
      );
      final response = await _rete.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final List foods = data['foods'] ?? [];
          return foods.map((f) => _mapCreaToInternal(f)).toList();
        }
        // Risposta 200 ma senza status "success": nessun risultato valido,
        // non un errore di rete.
        return [];
      }
      debugPrint("CREA Search Error: HTTP ${response.statusCode}");
      return null;
    } catch (e) {
      debugPrint("CREA Search Error: $e");
      return null;
    }
  }

  /// Alimenti della comunita': quelli personali che un admin ha approvato
  /// (2026-09-14). Prima l'approvazione non li mostrava a nessuno, perche'
  /// nessun endpoint li restituiva agli altri utenti.
  /// `null` se la fonte ha fallito (anche un server senza il file nuovo, 404),
  /// `[]` se non ha trovato niente.
  static Future<List<Map<String, dynamic>>?> _searchCommunityFoods(String q) async {
    try {
      final url = Uri.parse('$_urlServerSearchCommunity?query=${Uri.encodeComponent(q)}');
      final response = await _rete.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      if (data is! Map || data['status'] != 'success') return [];
      final List foods = data['foods'] ?? [];
      return foods
          .whereType<Map>()
          .map((f) => _mapCommunityToInternal(Map<String, dynamic>.from(f)))
          .toList();
    } catch (e) {
      debugPrint("Community Search Error: $e");
      return null;
    }
  }

  static Map<String, dynamic> _mapCommunityToInternal(Map<String, dynamic> food) {
    // Le colonne di na_custom_foods hanno gli stessi nomi usati dal resto
    // dell'app (calories, vit_c, ...): si tengono tutte, i numeri come numeri.
    const testuali = {
      'food_name', 'brand', 'barcode', 'image_url', 'nutriscore_grade', 'allergens',
      'labels', 'serving_size', 'categories', 'ingredients', 'quantity',
    };
    final mappa = <String, dynamic>{};
    food.forEach((chiave, valore) {
      mappa[chiave] = testuali.contains(chiave) ? (valore ?? '').toString() : _parseDouble(valore);
    });
    final nome = (food['food_name'] ?? '').toString();
    mappa['food_name'] = _toSentenceCase(nome);
    mappa['raw_name'] = nome.toLowerCase();
    mappa['brand'] = (food['brand'] ?? '').toString().toLowerCase();
    mappa['source'] = 'community';
    // L'id NON resta come `id`: la pagina dell'alimento lo leggerebbe come un
    // alimento della propria libreria, da modificare invece che da aggiungere.
    mappa['community_id'] = (food['id'] ?? '').toString();
    mappa.remove('id');
    final base = _parseDouble(food['base_weight_g']);
    mappa['base_weight_g'] = base > 0 ? base : 100.0;
    mappa['nova_group'] = _parseInt(food['nova_group']);
    return mappa;
  }

  static Map<String, dynamic> _mapCreaToInternal(Map<String, dynamic> food) {
    final String label = food['food_name'] ?? 'Alimento CREA';
    return {
      'food_name': _toSentenceCase(label),
      'raw_name': label.toLowerCase(),
      'brand': '',
      'source': 'crea_it',
      // I valori CREA sono per 100 g di PARTE EDIBILE, sempre. La colonna
      // `base_weight_g` di na_local_db contiene invece la percentuale di parte
      // edibile (mandorle 24, noci secche 39, mela cotogna 79): usarla come
      // peso di riferimento gonfiava tutto di 100/edibile — 542 kcal delle
      // mandorle diventavano 2258 kcal per 100 g (test di release 19/09).
      'base_weight_g': 100.0,
      'calories': _parseDouble(food['calories']),
      'proteins': _parseDouble(food['proteins']),
      'carbs': _parseDouble(food['carbs']),
      'fats': _parseDouble(food['fats']),
      'fibers': _parseDouble(food['fibers']),
      'sugars': _parseDouble(food['sugars']),
      'saturated_fats': _parseDouble(food['saturated_fats']),
      'sodium': _parseDouble(food['sodium']),
      'calcium': _parseDouble(food['calcium']),
      'iron': _parseDouble(food['iron']),
      'vit_c': _parseDouble(food['vit_c']),
    };
  }

  /// Restituisce `null` se la fonte ha fallito per un problema di
  /// rete/timeout/HTTP (distinto da "nessun risultato", che è `[]`).
  /// Interroga la cache locale di prodotti OFF importati in blocco
  /// (`na_off_products`, indicizzata FULLTEXT lato server) invece della
  /// ricerca live su OpenFoodFacts — vedi `_urlServerSearchOffProducts`.
  static Future<List<Map<String, dynamic>>?> _searchOffProductsLocalDb(
    String q, {
    List<String>? insegne,
  }) async {
    try {
      final insegnaParam = (insegne != null && insegne.isNotEmpty)
          ? '&insegna=${Uri.encodeComponent(insegne.join(','))}'
          : '';
      final url = Uri.parse(
        '$_urlServerSearchOffProducts?query=${Uri.encodeComponent(q)}$insegnaParam',
      );
      final response = await _rete.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final List foods = data['foods'] ?? [];
          return foods.map((f) => _mapOffLocalToInternal(f)).toList();
        }
        return [];
      }
      debugPrint("OFF locale Search Error: HTTP ${response.statusCode}");
      return null;
    } catch (e) {
      debugPrint("OFF locale Search Error: $e");
      return null;
    }
  }

  /// Elenco insegne disponibili per il filtro di ricerca, con quanti
  /// prodotti ciascuna copre — per popolare il menu a tendina. Lista vuota
  /// (non un errore) se il server non ha ancora `na_product_retailer`.
  static Future<List<({String insegna, int nProdotti})>> fetchInsegne() async {
    try {
      final response = await _rete
          .get(Uri.parse(_urlServerListInsegne))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return [];
      final data = json.decode(response.body);
      if (data['status'] != 'success') return [];
      final List elenco = data['insegne'] ?? [];
      return elenco
          .map(
            (e) => (
              insegna: (e['insegna'] ?? '').toString(),
              nProdotti: (e['n_prodotti'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((e) => e.insegna.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint("Elenco insegne error: $e");
      return [];
    }
  }

  static Map<String, dynamic> _mapOffLocalToInternal(Map<String, dynamic> food) {
    final String label = food['food_name'] ?? 'Prodotto OpenFoodFacts';
    final String brand = (food['brand'] ?? '').toString();
    return {
      'food_name': _toSentenceCase(label),
      'raw_name': label.toLowerCase(),
      'barcode': food['barcode']?.toString(),
      'brand': brand.toLowerCase(),
      'source': 'off_local_it',
      'base_weight_g': 100.0,
      // Metadati extra 2026-07-24 (Nutri-Score, NOVA, additivi, allergeni,
      // etichette, olio di palma, foto, porzione, categoria, luogo di
      // produzione, ingredienti, alcol, caffeina): presenti solo per
      // prodotti importati da OFF (fonte 'off_local_it'), le altre fonti
      // (CREA/USDA/personali) non li hanno e restano vuoti/0 di default,
      // gestito lato UI in product_info_sheet.dart (sezioni che si
      // nascondono da sole se non c'è nulla da mostrare).
      'nutriscore_grade': (food['nutriscore_grade'] ?? '').toString(),
      'nova_group': _parseInt(food['nova_group']),
      'additives_n': _parseInt(food['additives_n']),
      'allergens': (food['allergens'] ?? '').toString(),
      'labels': (food['labels'] ?? '').toString(),
      'palm_oil_n': _parseInt(food['palm_oil_n']),
      'palm_oil_maybe_n': _parseInt(food['palm_oil_maybe_n']),
      'image_url': (food['image_url'] ?? '').toString(),
      'serving_size': (food['serving_size'] ?? '').toString(),
      'categories': (food['categories'] ?? '').toString(),
      // Categoria PROPOSTA da un modello (mai un fatto): valorizzata dal
      // server solo quando `categories` è vuoto E almeno 2 metodi indipendenti
      // concordano (vedi search_off_products.php -> attachPredictedCategories).
      // Va mostrata SEMPRE con un'indicazione visiva distinta, mai come un
      // sinonimo di 'categories' — vedi DATA-QUALITY-PLAN.md §5-bis regola 4/6.
      'predicted_category': (food['predicted_category'] ?? '').toString(),
      'predicted_category_sources': (food['predicted_category_sources'] ?? '').toString(),
      'predicted_category_agreement': _parseInt(food['predicted_category_agreement']),
      // Campi aggiunti 2026-08-22 dopo l'audit dei campi OFF mai importati.
      // `nutrient_levels_tags` e' il "semaforo" (grassi/saturi/zuccheri/sale
      // in quantita' bassa/media/alta), il dato piu' leggibile per chi non sa
      // interpretare i numeri. `quantity` e' il peso della CONFEZIONE, da non
      // confondere con `serving_size` che e' la porzione.
      'nutrient_levels_tags': (food['nutrient_levels_tags'] ?? '').toString(),
      'quantity': (food['quantity'] ?? '').toString(),
      'added_sugars': _parseDouble(food['added_sugars']),
      'starch': _parseDouble(food['starch']),
      'polyols': _parseDouble(food['polyols']),
      'lactose': _parseDouble(food['lactose']),
      'manufacturing_places': (food['manufacturing_places'] ?? '').toString(),
      'ingredients': (food['ingredients'] ?? '').toString(),
      'alcohol_percent': _parseDouble(food['alcohol_percent']),
      'caffeine': _parseDouble(food['caffeine']),
      'calories': _parseDouble(food['calories']),
      'proteins': _parseDouble(food['proteins']),
      'carbs': _parseDouble(food['carbs']),
      'fats': _parseDouble(food['fats']),
      'water': _parseDouble(food['water']),
      'fibers': _parseDouble(food['fibers']),
      'sugars': _parseDouble(food['sugars']),
      'saturated_fats': _parseDouble(food['saturated_fats']),
      'monounsaturated_fats': _parseDouble(food['monounsaturated_fats']),
      'polyunsaturated_fats': _parseDouble(food['polyunsaturated_fats']),
      'trans_fats': _parseDouble(food['trans_fats']),
      'cholesterol': _parseDouble(food['cholesterol']),
      'sodium': _parseDouble(food['sodium']),
      'calcium': _parseDouble(food['calcium']),
      'iron': _parseDouble(food['iron']),
      'magnesium': _parseDouble(food['magnesium']),
      'phosphorus': _parseDouble(food['phosphorus']),
      'potassium': _parseDouble(food['potassium']),
      'zinc': _parseDouble(food['zinc']),
      'copper': _parseDouble(food['copper']),
      'manganese': _parseDouble(food['manganese']),
      'chloride': _parseDouble(food['chloride']),
      'selenium': _parseDouble(food['selenium']),
      'iodine': _parseDouble(food['iodine']),
      'fluoride': _parseDouble(food['fluoride']),
      'chromium': _parseDouble(food['chromium']),
      'molybdenum': _parseDouble(food['molybdenum']),
      'vit_a': _parseDouble(food['vit_a']),
      'vit_b1': _parseDouble(food['vit_b1']),
      'vit_b2': _parseDouble(food['vit_b2']),
      'vit_b3': _parseDouble(food['vit_b3']),
      'vit_b5': _parseDouble(food['vit_b5']),
      'vit_b6': _parseDouble(food['vit_b6']),
      'vit_b7': _parseDouble(food['vit_b7']),
      'vit_b9': _parseDouble(food['vit_b9']),
      'vit_b11': _parseDouble(food['vit_b11']),
      'vit_b12': _parseDouble(food['vit_b12']),
      'vit_c': _parseDouble(food['vit_c']),
      'vit_d': _parseDouble(food['vit_d']),
      'vit_e': _parseDouble(food['vit_e']),
      'vit_k': _parseDouble(food['vit_k']),
      'biotin': _parseDouble(food['biotin']),
    };
  }

  /// Traduce una query verso l'inglese usando l'endpoint gratuito non
  /// ufficiale di Google Translate (`sl=auto` per non assumere l'italiano
  /// come lingua sorgente). USDA FDC è un database in inglese: senza
  /// traduzione, cercare "mela" o "pasta al pomodoro" non trova quasi mai
  /// nulla. In caso di errore restituisce la query originale invariata.
  static Future<String> _translateToEnglish(String text) async {
    try {
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single',
      ).replace(
        queryParameters: {
          'client': 'gtx',
          'sl': 'auto',
          'tl': 'en',
          'dt': 't',
          'q': text,
        },
      );
      // Timeout volutamente stretto: la traduzione è un arricchimento, non
      // deve rallentare sensibilmente la ricerca se Google Translate è lento.
      // In caso di timeout usiamo comunque la query originale (fallback sotto).
      final response = await _rete.get(url).timeout(const Duration(milliseconds: 1500));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty && data[0] is List) {
          final buffer = StringBuffer();
          for (final segment in data[0]) {
            if (segment is List && segment.isNotEmpty) {
              buffer.write(segment[0]);
            }
          }
          final translated = buffer.toString().trim();
          if (translated.isNotEmpty) return translated;
        }
      }
    } catch (e) {
      debugPrint("Traduzione query USDA fallita, uso l'originale: $e");
    }
    return text;
  }

  /// Restituisce `null` se la fonte ha fallito per un problema di
  /// rete/timeout/HTTP (distinto da "nessun risultato", che è `[]`).
  static Future<List<Map<String, dynamic>>?> _searchUsdaAmericanDb(
    String q,
  ) async {
    try {
      final translatedQuery = await _translateToEnglish(q);
      // pageSize=200 e' il massimo consentito dall'API USDA FDC (non alziamo
      // oltre, l'API lo rifiuterebbe): tetto piu' alto del precedente 50 per
      // la stessa richiesta 2026-07-24 di non tagliare risultati troppo presto.
      final url = Uri.parse(
        'https://api.nal.usda.gov/fdc/v1/foods/search?api_key=$_usdaApiKey&query=${Uri.encodeComponent(translatedQuery)}&pageSize=200',
      );
      final response = await _rete.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List foods = data['foods'] ?? [];
        return foods.map((f) => _mapUsdaToInternal(f)).toList();
      }
      debugPrint("FDC Search Error: HTTP ${response.statusCode}");
      return null;
    } catch (e) {
      debugPrint("FDC Search Error: $e");
      return null;
    }
  }

  static Map<String, dynamic> _mapUsdaToInternal(Map<String, dynamic> food) {
    final List nutrients = food['foodNutrients'] ?? [];

    double findNut(int id) {
      final n = nutrients.firstWhere(
        (element) =>
            element['nutrientId'] == id ||
            element['nutrientNumber'] == id.toString(),
        orElse: () => null,
      );
      return _parseDouble(n?['value']);
    }

    final String label = food['description'] ?? 'Alimento USDA';
    final String? brand = food['brandOwner'] ?? food['brandName'];

    return {
      'food_name': _toSentenceCase(label),
      'raw_name': label.toLowerCase(),
      'barcode': food['gtinUpc']?.toString(),
      'brand': brand?.toLowerCase() ?? '',
      'source': 'usda_american_db',
      'base_weight_g': 100.0,
      'calories': findNut(1008),
      'proteins': findNut(1003),
      'carbs': findNut(1005),
      'fats': findNut(1004),
      'fibers': findNut(1079),
      'sugars': findNut(1063),
      'saturated_fats': findNut(1258),
      'sodium': findNut(1093),
      'water': findNut(1051),
      'calcium': findNut(1087),
      'iron': findNut(1089),
      'potassium': findNut(1092),
      'vit_a': findNut(1106),
      'vit_c': findNut(1162),
      'vit_d': findNut(1114),
      'vit_b12': findNut(1178),
      'serving_quantity': _parseDouble(food['servingSize']),
    };
  }

  // _searchOpenFoodFactsItalianDb/_mapOpenFoodFactsProducts (ricerca LIVE su
  // cgi/search.pl) rimossi 2026-07-24: quell'endpoint e' l'API legacy di
  // OpenFoodFacts, rate-limited e soggetta a errori 503 diffusi lato loro dopo
  // aprile 2026 (vedi PROBLEMS.md nel vault). Da quando na_off_products e'
  // popolata con l'export bulk italiano (214k+ prodotti, stessa fonte dati ma
  // locale e affidabile), teneva la ricerca in attesa fino al timeout per un
  // beneficio quasi nullo. Se in futuro serve una ricerca LIVE su OFF, la
  // strada indicata dal loro stesso team e' il pacchetto ufficiale
  // pub.dev/packages/openfoodfacts o l'API Search-a-licious
  // (search.openfoodfacts.org), non questo endpoint in via di dismissione.
  // Il barcode scan resta su OFF live (vedi getProductByBarcode sopra): usa
  // api/v0/product/{barcode}.json, un endpoint diverso e sano.

  static String _toSentenceCase(String text) {
    if (text.isEmpty) return text;
    String t = text;
    if (text == text.toUpperCase()) t = text.toLowerCase();
    return t[0].toUpperCase() + t.substring(1);
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? double.tryParse(value.toString())?.toInt() ?? 0;
  }

  static Future<bool> sendFoodEntry(FoodEntry entry) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerSave),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(entry.toJson()),
      );
      // save_entry.php risponde 200 anche quando rifiuta ("status":"error"):
      // fermarsi al codice HTTP faceva dire "aggiunto" a chi non aveva
      // aggiunto niente (test di release 19/09).
      if (response.statusCode != 200) return false;
      final corpo = json.decode(response.body);
      return corpo is Map && corpo['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  /// Le voci del diario. Con [da] e [a] si chiedono solo i giorni che
  /// servono: senza filtro il server manda TUTTO lo storico a ogni
  /// aggiornamento della Home, e dopo qualche mese sono migliaia di righe
  /// (test di release 19/09).
  static Future<List<FoodEntry>> fetchFoodEntries(
    String userMail, {
    DateTime? da,
    DateTime? a,
  }) async {
    try {
      String giorno(DateTime d) => d.toIso8601String().split('T').first;
      final filtro = [
        if (da != null) 'from=${giorno(da)}',
        if (a != null) 'to=${giorno(a)}',
      ].join('&');
      final response = await _rete.get(
        Uri.parse('$_urlServerLoad?user_mail=$userMail${filtro.isEmpty ? '' : '&$filtro'}'),
      );
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => FoodEntry.fromJson(data)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> deleteFoodEntries(String userMail, int id) async {
    try {
      final response = await _rete.get(
        Uri.parse('$_urlServerDelete?user_mail=$userMail&id=$id'),
      );
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['status'] == 'success';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static const String _urlServerUploadImage =
      '${base}upload_image.php';

  /// Carica una foto sul server e restituisce l'indirizzo pubblico, oppure il
  /// motivo del fallimento.
  ///
  /// PERCHE' NON BASE64 NEL DATABASE: era la strada presa prima, e su una
  /// ricetta si rompeva con "Error saving recipe" — una foto compressa supera
  /// comunque di molto la colonna, e allargarla avrebbe solo spostato il peso
  /// su ogni lettura dell'elenco. Qui torna indietro un indirizzo corto.
  ///
  /// Restituisce un record invece di una stringa nullable perche' "non ha
  /// funzionato" da solo non basta: l'utente deve sapere SE e' colpa della
  /// rete, del file o del server, e finora quell'informazione si perdeva.
  static Future<({String? url, String? errore})> uploadImage({
    required String userMail,
    required File file,
  }) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse(_urlServerUploadImage))
        ..fields['user_mail'] = userMail
        ..files.add(await http.MultipartFile.fromPath('image', file.path));
      // Dal client dell'app, non da req.send(): il gettone serve anche qui.
      final streamed = await _rete.send(req).timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);
      final data = jsonDecode(resp.body);
      if (data['status'] == 'success' && (data['url'] ?? '').toString().isNotEmpty) {
        return (url: data['url'].toString(), errore: null);
      }
      return (url: null, errore: (data['message'] ?? 'Errore sconosciuto').toString());
    } catch (e) {
      return (url: null, errore: e.toString());
    }
  }

  static Future<bool> updateFoodEntry(FoodEntry entry) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerUpdate),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(entry.toJson()),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<DailySummary?> getDailySummary(
    String userMail,
    String mealType,
    DateTime date,
  ) async {
    try {
      String formattedDate =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      String url =
          '$_urlServerDailySummary?user_mail=$userMail&date=$formattedDate';
      if (mealType.isNotEmpty) url += '&meal_type=$mealType';
      final response = await _rete.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'success') {
          return DailySummary.fromJson(jsonResponse['totals']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> saveRecipe(Recipe recipe, String userEmail) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerSaveRecipe),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(recipe.toJson(userEmail)),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Recipe>> fetchRecipes(String userEmail) async =>
      await fetchRecipesOrNull(userEmail) ?? [];

  /// Come [fetchRecipes] ma null quando il server non ha risposto — stessa
  /// ragione spiegata su [fetchCustomFoodsOrNull].
  static Future<List<Recipe>?> fetchRecipesOrNull(String userEmail) async {
    try {
      final response = await _rete.get(
        Uri.parse('$_urlServerLoadRecipes?user_mail=$userEmail'),
      );
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => Recipe.fromJson(data)).toList();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> deleteRecipe(String userMail, String id) async =>
      (await deleteRecipeDetailed(userMail, id)).ok;

  /// Come [deleteRecipe], e dice se la ricetta e' rimasta pubblica (15/09):
  /// una ricetta approvata e' del database, e cancellarla la toglie solo dalle
  /// proprie.
  static Future<({bool ok, bool keptPublic})> deleteRecipeDetailed(String userMail, String id) async {
    try {
      final response = await _rete.get(
        Uri.parse('$_urlServerRecipeDelete?user_mail=$userMail&id=$id'),
      );
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return (ok: jsonResponse['status'] == 'success', keptPublic: jsonResponse['kept_public'] == true);
      }
      return (ok: false, keptPublic: false);
    } catch (e) {
      return (ok: false, keptPublic: false);
    }
  }

  static Future<bool> updateRecipe(String userEmail, Recipe recipe) async =>
      (await updateRecipeDetailed(userEmail, recipe)).errore == null;

  /// Come [updateRecipe] ma restituisce il MOTIVO del fallimento.
  ///
  /// PERCHE' (2026-09-05): save_recipe.php e update_recipe.php rimandano gia'
  /// il messaggio vero dell'eccezione — quale colonna, quale vincolo — ma
  /// l'app lo buttava via e mostrava "Errore salvataggio ricetta" e basta.
  /// Con un errore che non dice niente si finisce a indovinare, ed e'
  /// esattamente cio' che e' successo con "Error saving recipe".
  static Future<({bool ok, String? errore})> updateRecipeDetailed(
    String userEmail,
    Recipe recipe,
  ) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerUpdateRecipe),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(recipe.toJson(userEmail)),
      );
      if (response.statusCode != 200) {
        return (ok: false, errore: 'HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') return (ok: true, errore: null);
      return (ok: false, errore: (data['message'] ?? 'senza messaggio').toString());
    } catch (e) {
      return (ok: false, errore: e.toString());
    }
  }

  /// Come [saveRecipe] ma restituisce il motivo del fallimento.
  static Future<({bool ok, String? errore})> saveRecipeDetailed(
    Recipe recipe,
    String userEmail,
  ) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerSaveRecipe),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(recipe.toJson(userEmail)),
      );
      if (response.statusCode != 200) {
        return (ok: false, errore: 'HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') return (ok: true, errore: null);
      return (ok: false, errore: (data['message'] ?? 'senza messaggio').toString());
    } catch (e) {
      return (ok: false, errore: e.toString());
    }
  }

  static Future<Map<String, dynamic>?> signup({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    double? weight,
    double? height,
    String? gender,
    String? birthDate,
    String? profileImage,
  }) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerSignup),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'weight': weight?.toString() ?? '',
          'height': height?.toString() ?? '',
          'gender': gender ?? '',
          'birth_date': birthDate ?? '',
          'profile_image': profileImage ?? '',
        },
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerLogin),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getUserData(String email) async {
    try {
      final response = await _rete.get(
        Uri.parse('$_urlServerGetUserData?email=$email'),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Salva gli obiettivi. `null` se e' andata, altrimenti il messaggio.
  ///
  /// Manda SEMPRE tutti i campi (17/09): il vecchio update_goals.php azzera le
  /// colonne che non riceve. [includeTargetWeight] a false lascia fuori solo
  /// il peso obiettivo, per non far rifiutare tutto da uno fuori limite.
  static Future<String?> updateGoals({
    required int userId,
    bool includeTargetWeight = true,
    double currentWeight = 0,
    double targetWeight = 0,
    double calorieGoal = 0,
    double proteinGoal = 0,
    double fatGoal = 0,
    double carbGoal = 0,
    double waterGoal = 0,
    double fiberGoal = 0,
    double sugarMax = 0,
    double saturatedFatsGoal = 0,
    double monounsaturatedFatsGoal = 0,
    double polyunsaturatedFatsGoal = 0,
    double transFatsMax = 0,
    double cholesterolMax = 0,
    double sodiumMax = 0,
    double vitAGoal = 0,
    double vitB1Goal = 0,
    double vitB2Goal = 0,
    double vitB3Goal = 0,
    double vitB5Goal = 0,
    double vitB6Goal = 0,
    double vitB7Goal = 0,
    double vitB9Goal = 0,
    double vitB11Goal = 0,
    double vitB12Goal = 0,
    double vitCGoal = 0,
    double vitDGoal = 0,
    double vitEGoal = 0,
    double vitKGoal = 0,
    double arsenicGoal = 0,
    double biotinGoal = 0,
    double boronGoal = 0,
    double calciumGoal = 0,
    double chlorideGoal = 0,
    double cholineGoal = 0,
    double chromiumGoal = 0,
    double cobaltGoal = 0,
    double copperGoal = 0,
    double fluorideGoal = 0,
    double fluorineGoal = 0,
    double iodineGoal = 0,
    double ironGoal = 0,
    double magnesiumGoal = 0,
    double manganeseGoal = 0,
    double molybdenumGoal = 0,
    double phosphorusGoal = 0,
    double potassiumGoal = 0,
    double seleniumGoal = 0,
    double siliconGoal = 0,
    double sulfurGoal = 0,
    double tinGoal = 0,
    double vanadiumGoal = 0,
    double zincGoal = 0,
  }) async {
    try {
      final Map<String, String> body = {
        'user_id': userId.toString(),
        'current_weight': currentWeight.toString(),
        'target_weight': targetWeight.toString(),
        'calorie_goal': calorieGoal.toString(),
        'protein_goal': proteinGoal.toString(),
        'fat_goal': fatGoal.toString(),
        'carb_goal': carbGoal.toString(),
        'water_goal': waterGoal.toString(),
        'fiber_goal': fiberGoal.toString(),
        'sugar_max': sugarMax.toString(),
        'saturated_fats_goal': saturatedFatsGoal.toString(),
        'monounsaturated_fats_goal': monounsaturatedFatsGoal.toString(),
        'polyunsaturated_fats_goal': polyunsaturatedFatsGoal.toString(),
        'trans_fats_max': transFatsMax.toString(),
        'cholesterol_max': cholesterolMax.toString(),
        'sodium_max': sodiumMax.toString(),
        'vit_a_goal': vitAGoal.toString(),
        'vit_b1_goal': vitB1Goal.toString(),
        'vit_b2_goal': vitB2Goal.toString(),
        'vit_b3_goal': vitB3Goal.toString(),
        'vit_b5_goal': vitB5Goal.toString(),
        'vit_b6_goal': vitB6Goal.toString(),
        'vit_b7_goal': vitB7Goal.toString(),
        'vit_b9_goal': vitB9Goal.toString(),
        'vit_b11_goal': vitB11Goal.toString(),
        'vit_b12_goal': vitB12Goal.toString(),
        'vit_c_goal': vitCGoal.toString(),
        'vit_d_goal': vitDGoal.toString(),
        'vit_e_goal': vitEGoal.toString(),
        'vit_k_goal': vitKGoal.toString(),
        'arsenic_goal': arsenicGoal.toString(),
        'biotin_goal': biotinGoal.toString(),
        'boron_goal': boronGoal.toString(),
        'calcium_goal': calciumGoal.toString(),
        'chloride_goal': chlorideGoal.toString(),
        'choline_goal': cholineGoal.toString(),
        'chromium_goal': chromiumGoal.toString(),
        'cobalt_goal': cobaltGoal.toString(),
        'copper_goal': copperGoal.toString(),
        'fluoride_goal': fluorideGoal.toString(),
        'fluorine_goal': fluorineGoal.toString(),
        'iodine_goal': iodineGoal.toString(),
        'iron_goal': ironGoal.toString(),
        'magnesium_goal': magnesiumGoal.toString(),
        'manganese_goal': manganeseGoal.toString(),
        'molybdenum_goal': molybdenumGoal.toString(),
        'phosphorus_goal': phosphorusGoal.toString(),
        'potassium_goal': potassiumGoal.toString(),
        'selenium_goal': seleniumGoal.toString(),
        'silicon_goal': siliconGoal.toString(),
        'sulfur_goal': sulfurGoal.toString(),
        'tin_goal': tinGoal.toString(),
        'vanadium_goal': vanadiumGoal.toString(),
        'zinc_goal': zincGoal.toString(),
      };
      if (!includeTargetWeight) body.remove('target_weight');

      final response = await _rete.post(
        Uri.parse(_urlServerUpdateGoals),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode != 200) return 'Errore di rete. Riprova.';
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') return null;
      return (data['message'] ?? 'Errore nel salvataggio degli obiettivi.').toString();
    } catch (e) {
      return 'Errore di rete. Riprova.';
    }
  }

  static Future<bool> updateUserProfile({
    required int userId,
    String? firstName,
    String? lastName,
    double? height,
    String? gender,
    String? birthDate,
    String? profileImage,
  }) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerUpdateProfile),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'user_id': userId.toString(),
          'first_name': firstName ?? '',
          'last_name': lastName ?? '',
          'height': height?.toString() ?? '',
          'gender': gender ?? '',
          'birth_date': birthDate ?? '',
          'profile_image': profileImage ?? '',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<DateTime, DailySummary?>> getHistoricalSummaries(
    String userMail,
    DateTime startDate,
    DateTime endDate,
  ) async {
    Map<DateTime, DailySummary?> summaries = {};
    for (
      DateTime date = startDate;
      date.isBefore(endDate.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      DailySummary? summary = await getDailySummary(userMail, '', date);
      summaries[date] = summary;
    }
    return summaries;
  }

  /// Chiude la sessione sul server. Se la rete non c'e' si esce lo stesso:
  /// il gettone scade da solo dopo novanta giorni.
  static Future<void> logout() async {
    if ((gettone ?? '').isEmpty) return;
    try {
      await _rete.post(Uri.parse('${base}logout.php')).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Niente rete: l'uscita dall'app avviene comunque.
    }
  }

  static Future<bool> savePhysicalMeasurement(
    PhysicalMeasurement measurement,
    String userEmail,
  ) async {
    try {
      final response = await _rete.post(
        Uri.parse(
          '${base}save_physical.php',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(measurement.toJson(userEmail)),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<PhysicalMeasurement>> fetchPhysicalMeasurements(
    String userEmail,
  ) async {
    try {
      final response = await _rete.get(
        Uri.parse(
          '${base}get_physical.php?user_email=$userEmail',
        ),
      );
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((data) => PhysicalMeasurement.fromJson(data))
            .toList();
      }
      throw Exception('Errore nel caricamento delle misurazioni fisiche');
    } catch (e) {
      return [];
    }
  }

  static Future<bool> saveCustomFood(CustomFood food) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerSaveCustomFood),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(food.toJson()),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> toggleCustomFoodFavorite(
    String userMail,
    int id,
    bool isFavorite,
  ) async {
    try {
      // Usiamo l'endpoint di salvataggio che supporta anche l'update se l'ID è presente
      final response = await _rete.post(
        Uri.parse(_urlServerSaveCustomFood),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': id,
          'user_mail': userMail,
          'is_favorite': isFavorite ? 1 : 0,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> toggleRecipeFavorite(
    String userMail,
    String id,
    bool isFavorite,
  ) async {
    try {
      // Usiamo l'endpoint di update della ricetta
      // Dato che l'endpoint PHP richiede tutti i dati, in una app reale
      // servirebbe un endpoint specifico o caricare i dati prima.
      // Qui ipotizziamo un comportamento flessibile del backend o facciamo un update parziale se supportato.
      final response = await _rete.post(
        Uri.parse(_urlServerUpdateRecipe),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': id,
          'user_mail': userMail,
          'is_favorite': isFavorite ? 1 : 0,
          // Inviamo dummy per non far fallire il PHP se non supporta update parziali
          'recipe_name': '',
          'ingredients': [],
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchCustomFoods(
    String userMail,
  ) async =>
      await fetchCustomFoodsOrNull(userMail) ?? [];

  /// Come [fetchCustomFoods] ma restituisce null quando il server non ha
  /// risposto, invece di una lista vuota.
  ///
  /// PERCHE' LA DISTINZIONE (2026-09-05): con la lista vuota in tutti e due i
  /// casi, chi legge non puo' sapere se ricadere sulla copia locale. Ricadere
  /// sempre farebbe riapparire un alimento appena cancellato; non ricadere
  /// mai lascia la ricerca senza gli alimenti dell'utente appena manca la
  /// rete. Serve saperlo.
  static Future<List<Map<String, dynamic>>?> fetchCustomFoodsOrNull(
    String userMail,
  ) async {
    try {
      final response = await _rete.get(
        Uri.parse('$_urlServerFetchCustomFoods?user_mail=$userMail'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['foods']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> deleteCustomFood(String userMail, int id) async =>
      (await deleteCustomFoodDetailed(userMail, id)).ok;

  /// Come [deleteCustomFood], e dice se l'alimento e' rimasto pubblico (15/09).
  static Future<({bool ok, bool keptPublic})> deleteCustomFoodDetailed(String userMail, int id) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerDeleteCustomFood),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_mail': userMail, 'id': id}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (ok: data['status'] == 'success', keptPublic: data['kept_public'] == true);
      }
      return (ok: false, keptPublic: false);
    } catch (e) {
      return (ok: false, keptPublic: false);
    }
  }

  /// Ricerca per nome → risultati nel formato atteso dall'UI, con flag di
  /// errore di rete separato da "nessun risultato" (vedi [searchProducts]).
  static Future<({List<Map<String, dynamic>> results, bool networkError})>
  searchFood(String query) async {
    return searchProducts(query);
  }

  // Converte il JSON del PHP nel formato che l'UI e il DB si aspettano
  static Map<String, dynamic> _mapPhpProduct(
    Map<String, dynamic> p, {
    String langCode = 'it',
  }) {
    // Se la lingua è inglese, proviamo a usare 'name_en' se presente nel JSON del server,
    // altrimenti usiamo il campo 'name' standard.
    String name = (langCode == 'en')
        ? (p['name_en'] ?? p['name'] ?? p['food_name'] ?? '')
        : (p['name'] ?? p['food_name'] ?? '');
    final brand = p['brand'] as String? ?? '';
    if (brand.isNotEmpty && !name.toLowerCase().contains(brand.toLowerCase())) {
      name = '$name ($brand)';
    }

    return {
      //Metadati
      'food_name': name.isNotEmpty ? name : 'Prodotto sconosciuto',
      'barcode': p['barcode']?.toString(),
      'raw_name': name.toLowerCase(),
      'brand': brand.toLowerCase(),
      'source': p['source'] ?? '',
      'base_weight_g': _parseDouble(p['base_weight_g'] ?? 100.0),
      //Macro
      'calories': _parseDouble(p['calories']),
      'proteins': _parseDouble(p['proteins']),
      'carbs': _parseDouble(p['carbs']),
      'fats': _parseDouble(p['fats']),
      'fibers': _parseDouble(p['fibers']),
      'sugars': _parseDouble(p['sugars']),
      'saturated_fats': _parseDouble(p['saturated_fats']),
      'monounsaturated_fats': _parseDouble(p['monounsaturated_fats']),
      'polyunsaturated_fats': _parseDouble(p['polyunsaturated_fats']),
      'serving_quantity': _parseDouble(p['serving_quantity']),
      'trans_fats': _parseDouble(p['trans_fats']),
      'water': _parseDouble(p['water']),

      'cholesterol': _parseDouble(p['cholesterol']),
      'sodium': _parseDouble(p['sodium']),
      'calcium': _parseDouble(p['calcium']),
      'iron': _parseDouble(p['iron']),
      'magnesium': _parseDouble(p['magnesium']),
      'phosphorus': _parseDouble(p['phosphorus']),
      'potassium': _parseDouble(p['potassium']),
      'zinc': _parseDouble(p['zinc']),
      'copper': _parseDouble(p['copper']),
      'manganese': _parseDouble(p['manganese']),
      'chloride': _parseDouble(p['chloride']),

      'selenium': _parseDouble(p['selenium']),
      'iodine': _parseDouble(p['iodine']),
      'fluoride': _parseDouble(p['fluoride']),
      'chromium': _parseDouble(p['chromium']),
      'molybdenum': _parseDouble(p['molybdenum']),

      'vit_b1': _parseDouble(p['vit_b1']),
      'vit_b2': _parseDouble(p['vit_b2']),
      'vit_b3': _parseDouble(p['vit_b3']),
      'vit_b5': _parseDouble(p['vit_b5']),
      'vit_b6': _parseDouble(p['vit_b6']),
      'vit_c': _parseDouble(p['vit_c']),
      'vit_e': _parseDouble(p['vit_e']),

      'vit_a': _parseDouble(p['vit_a']),
      'vit_b7': _parseDouble(p['vit_b7']),
      'vit_b9': _parseDouble(p['vit_b9']),
      'vit_b11': _parseDouble(p['vit_b11']),
      'vit_b12': _parseDouble(p['vit_b12']),
      'vit_d': _parseDouble(p['vit_d']),
      'vit_k': _parseDouble(p['vit_k']),
    };
  }

  /// Invia una segnalazione.
  ///
  /// I campi oltre alla descrizione sono arrivati con il mockup "Report
  /// Problem" (2026-09-05): senza il tipo e la schermata, una segnalazione e'
  /// un paragrafo da leggere e interpretare a mano, impossibile da raggruppare.
  /// I facoltativi vuoti non vengono spediti affatto, cosi' il server li
  /// registra come NULL invece che come stringhe vuote.
  static Future<Map<String, dynamic>> saveReport({
    required String userEmail,
    required String problemDescription,
    String kind = '',
    String screen = '',
    String contactEmail = '',
    String diagnostics = '',
  }) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerSaveReport),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_email': userEmail,
          'problem_description': problemDescription,
          if (kind.isNotEmpty) 'kind': kind,
          if (screen.isNotEmpty) 'screen': screen,
          if (contactEmail.isNotEmpty) 'contact_email': contactEmail,
          if (diagnostics.isNotEmpty) 'diagnostics': diagnostics,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Errore del server'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // ------------------------------------------------------------------
  // Collaborazione fra utenti (2026-09-12)
  //
  // Tre funzioni che stavano ferme in ROADMAP: segnalare un alimento
  // sbagliato, proporre i propri alimenti al database pubblico, proporre una
  // ricetta per la sezione "Consigliate". Nessuna di queste PUBBLICA: mettono
  // in attesa, e la pubblicazione la decide una revisione. Finche' il pannello
  // admin non esiste, l'approvazione si fa a mano su phpMyAdmin (le query
  // pronte stanno in fondo alla migrazione).
  //
  // Tutte restituiscono la mappa del server invece di un bool: il messaggio
  // serve. "Migrazione mancante" e "file non caricato via FTP" sono i due
  // errori piu' probabili all'inizio, e un `false` secco li renderebbe
  // indistinguibili da un problema di rete — l'equivoco che in questo
  // progetto e' costato piu' tempo di ogni altro.
  // ------------------------------------------------------------------

  /// Segnala che un alimento del database e' sbagliato.
  ///
  /// [issue] e' una delle voci ammesse dal server: valori, nome, categoria,
  /// immagine, duplicato, altro. Una voce fuori elenco viene rifiutata la',
  /// non qui: l'elenco valido e' quello del database, e tenerne una copia in
  /// Dart vorrebbe dire avere due elenchi che possono divergere.
  static Future<Map<String, dynamic>> saveFoodReport({
    required String userEmail,
    required String foodName,
    required String issue,
    String barcode = '',
    String source = '',
    String fieldName = '',
    String suggestedValue = '',
    String note = '',
    // Dal 13/09 la segnalazione puo' portare la correzione: `proposed` sono
    // SOLO i campi toccati (colonna -> valore), `photos` le foto gia' caricate
    // con [uploadImage] e il loro ruolo (fronte, tabella, ingredienti, altro).
    // Le chiavi di `proposed` le verifica il pannello contro le colonne vere
    // prima di scrivere: qui non c'e' una seconda lista da tenere allineata.
    // Dal 18/09 un valore puo' essere anche testo (nome, marca, categoria,
    // indirizzo della foto), non solo un numero.
    Map<String, dynamic>? proposed,
    List<Map<String, String>>? photos,
    String kind = 'correzione',
  }) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerSaveFoodReport),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_mail': userEmail,
          'food_name': foodName,
          'issue': issue,
          // I facoltativi vuoti non partono affatto, cosi' il server li
          // registra come NULL: una colonna piena di '' non si distingue da
          // una risposta data e poi cancellata.
          if (barcode.isNotEmpty) 'barcode': barcode,
          if (source.isNotEmpty) 'source': source,
          if (fieldName.isNotEmpty) 'field_name': fieldName,
          if (suggestedValue.isNotEmpty) 'suggested_value': suggestedValue,
          if (note.isNotEmpty) 'note': note,
          if (proposed != null && proposed.isNotEmpty) 'proposed': proposed,
          if (photos != null && photos.isNotEmpty) 'photos': photos,
          'kind': kind,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'status': 'error', 'message': 'Errore del server'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Segnala una ricetta pubblica (21/09).
  ///
  /// [issue] e' una delle voci ammesse dal server: contenuto, valori, copia,
  /// pericolosa, spam, altro. Come per gli alimenti, la voce fuori elenco la
  /// rifiuta il server e non l'app: l'elenco valido e' quello del database, e
  /// tenerne una copia in Dart vorrebbe dire avere due elenchi che divergono.
  ///
  /// Non cambia niente nella ricetta: la segnalazione nasce in attesa e la
  /// guarda chi rivede i contenuti.
  static Future<Map<String, dynamic>> saveRecipeReport({
    required String userEmail,
    required int recipeId,
    required String issue,
    String note = '',
  }) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerSaveRecipeReport),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_mail': userEmail,
          'recipe_id': recipeId,
          'issue': issue,
          // La nota vuota non parte affatto: sul server diventa NULL, e una
          // colonna piena di '' non si distingue da una risposta cancellata.
          if (note.isNotEmpty) 'note': note,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'status': 'error', 'message': 'Errore del server'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Consenso generale a proporre i propri alimenti personali.
  ///
  /// Accendendolo, gli alimenti ancora privati passano in attesa; spegnendolo
  /// rientrano. Gli alimenti gia' approvati NON vengono toccati: quelli si
  /// ritirano uno per uno con [shareCustomFood]. La risposta dice quanti sono
  /// cambiati (`foods_changed`) e quanti restano pubblici (`foods_public`).
  static Future<Map<String, dynamic>> setSharingPreference({
    required String userEmail,
    required bool share,
  }) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerSetSharingPreference),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_mail': userEmail, 'share_custom_foods': share}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'status': 'error', 'message': 'Errore del server'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Propone o ritira UN alimento personale. Ritira anche quelli gia'
  /// pubblici: e' il solo modo per togliere qualcosa dal database pubblico.
  static Future<Map<String, dynamic>> shareCustomFood({
    required String userEmail,
    required int id,
    required bool share,
  }) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerShareCustomFood),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_mail': userEmail, 'id': id, 'share': share}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'status': 'error', 'message': 'Errore del server'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Propone o ritira UNA ricetta per la sezione "Consigliate".
  ///
  /// Una ricetta senza ingredienti viene rifiutata dal server con
  /// `reason: no_ingredients`: la' si giudica dagli ingredienti e dalle
  /// calorie, e senza non c'e' niente da guardare.
  ///
  /// 15/09: proporre chiede le categorie ([mealTypes] almeno uno e [course]);
  /// senza, il server risponde `reason: categories_missing`. Ritirare una
  /// ricetta approvata risponde `reason: locked`.
  static Future<Map<String, dynamic>> shareRecipe({
    required String userEmail,
    required String id,
    required bool share,
    List<String> mealTypes = const [],
    String? course,
    List<String> dietTags = const [],
  }) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerShareRecipe),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_mail': userEmail,
          'id': int.tryParse(id) ?? 0,
          'share': share,
          if (share) 'meal_types': mealTypes,
          if (share && course != null) 'course': course,
          if (share) 'diet_tags': dietTags,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'status': 'error', 'message': 'Errore del server'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Le ricette pubbliche degli altri utenti (sezione "Consigliate").
  ///
  /// Null quando il server non ha risposto: la scheda deve poter distinguere
  /// "non c'e' ancora nessuna ricetta pubblica" da "non sono riuscito a
  /// chiedere". Il primo caso e' normale — all'inizio la coda e' vuota — il
  /// secondo no, e mostrarli allo stesso modo nasconderebbe un guasto.
  /// Stessa scelta di [fetchRecipesOrNull].
  ///
  /// 15/09: [mode] nuove · piaciute · per_te; [nowMeal] e' il pasto dell'ora
  /// del telefono (vedi pasto_attuale.dart); [meal], [course], [diet] filtrano
  /// con i valori a lista chiusa di na_recipes.
  static Future<List<Recipe>?> fetchPublicRecipes(
    String userEmail, {
    String mode = 'nuove',
    String? nowMeal,
    String? meal,
    String? course,
    String? diet,
  }) async {
    try {
      final response = await _rete.get(
        Uri.parse(_urlServerPublicRecipes).replace(queryParameters: {
          'user_mail': userEmail,
          'mode': mode,
          if (nowMeal != null) 'now_meal': nowMeal,
          if (meal != null) 'meal': meal,
          if (course != null) 'course': course,
          if (diet != null) 'diet': diet,
        }),
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['status'] != 'success') return null;
      final lista = decoded['recipes'] as List? ?? [];
      return lista
          .map((d) => Recipe.fromJson(d as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return null;
    }
  }

  /// Le proprie segnalazioni con l'esito (schermata "Le mie segnalazioni").
  ///
  /// Null quando il server non ha risposto: la schermata deve poter
  /// distinguere "non hai ancora segnalato niente" da "non sono riuscito a
  /// chiedere" — il primo e' uno stato normale, il secondo un guasto, e con lo
  /// stesso schermo vuoto il secondo si nasconderebbe dietro il primo.
  ///
  /// 15/09: una chiamata sola per le tre schede — segnalazioni sui dati e
  /// problemi dell'app, ricette e alimenti proposti.
  static Future<ContributiUtente?> fetchMyContributions(String userEmail) async {
    try {
      final response = await _rete.get(
        Uri.parse('$_urlServerMyReports?user_mail=${Uri.encodeQueryComponent(userEmail)}'),
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['status'] != 'success') return null;
      return ContributiUtente.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e) {
      return null;
    }
  }

  /// Mette o toglie il like a una ricetta pubblica (15/09). Restituisce la
  /// risposta del server: `liked` e `likes_count`, oppure `reason`
  /// (`not_public`, `own_recipe`).
  static Future<Map<String, dynamic>> toggleRecipeLike({
    required String userEmail,
    required String recipeId,
    required bool like,
  }) async {
    try {
      final response = await _rete.post(
        Uri.parse(_urlServerRecipeLike),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_mail': userEmail,
          'recipe_id': int.tryParse(recipeId) ?? 0,
          'like': like,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'status': 'error', 'message': 'Errore del server'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }
}

/// Client HTTP dell'app: aggiunge il gettone di sessione a ogni richiesta.
///
/// Passare da `http.get`/`http.post` a questo client e' l'unico modo per non
/// dimenticare l'intestazione in una delle quaranta chiamate (19/09).
class _ClientConGettone extends http.BaseClient {
  final http.Client _interno = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final t = ApiServices.gettone;
    if (t != null && t.isNotEmpty) request.headers['X-Auth-Token'] = t;
    return _interno.send(request);
  }
}
