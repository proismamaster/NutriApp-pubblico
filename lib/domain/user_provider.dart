// domain/user_provider.dart

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/limiti_corpo.dart';
import '../models/user_model.dart';
import '../services/api_services.dart';
import '../services/local_food_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'apple_auth_helper.dart';

// Provider principale per l'utente
final userProvider = NotifierProvider<UserNotifier, UserModel?>(() {
  return UserNotifier();
});

// Definizioni per i risultati dell'autenticazione
typedef AuthResult = ({String? error, bool isNew});

// Gestore dello stato dell'utente
class UserNotifier extends Notifier<UserModel?> {
  @override
  UserModel? build() => null; // null = nessun utente loggato

  Future<void> checkSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    // Il gettone prima di tutto: senza, ogni richiesta tornerebbe 401.
    ApiServices.gettone = prefs.getString('auth_token');
    final savedEmail = prefs.getString('user_email');
    if (savedEmail != null) {
      final errore = await _loadUserData(savedEmail);
      // Server irraggiungibile: si riparte dall'ultimo profilo scaricato
      // invece di rimandare alla pagina di accesso.
      if (errore != null) await _riprendiProfiloLocale(savedEmail);
    }
  }

  // Autenticazione social (Google e Apple)
  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();

      // Forza la disconnessione per mostrare il selettore dell'account ogni volta
      await googleSignIn.signOut();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return (error: 'Accesso annullato', isNew: false);

      final response = await ApiServices.socialLogin(
        email: googleUser.email,
        provider: 'google',
        providerId: googleUser.id,
        firstName: googleUser.displayName?.split(' ').first,
        lastName: googleUser.displayName?.contains(' ') == true
            ? googleUser.displayName?.split(' ').last
            : '',
      );

      return _handleAuthResponse(response, googleUser.email);
    } catch (e) {
      return (error: 'Errore durante l\'accesso con Google: $e', isNew: false);
    }
  }

  Future<AuthResult> signInWithApple() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isMacOS)) {
      return (
        error: 'Apple Sign-In non supportato su questa piattaforma',
        isNew: false,
      );
    }

    try {
      final scopes = await getAppleScopes();
      final credential = await performAppleSignIn(scopes);

      final String email = credential.email ?? '';
      if (email.isEmpty)
        return (error: 'Email non fornita da Apple', isNew: false);

      final response = await ApiServices.socialLogin(
        email: email,
        provider: 'apple',
        providerId: credential.userIdentifier ?? '',
        firstName: credential.givenName,
        lastName: credential.familyName,
      );

      return _handleAuthResponse(response, email);
    } catch (e) {
      return (error: 'Errore durante l\'accesso con Apple: $e', isNew: false);
    }
  }

  Future<AuthResult> _handleAuthResponse(
    Map<String, dynamic>? response,
    String email,
  ) async {
    if (response == null)
      return (error: 'Errore di rete. Riprova.', isNew: false);
    if (response['status'] == 'success') {
      state = UserModel.fromJson(response['user_data']);

      // Controlliamo se è un nuovo utente (gestendo vari formati del database)
      final rawIsNew = response['is_new'];
      final isNew =
          rawIsNew == true ||
          rawIsNew == 1 ||
          rawIsNew == '1' ||
          rawIsNew == 'true';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      // Il gettone di sessione: da qui in poi ogni richiesta lo porta con se',
      // e il server riconosce l'utente da quello (test di release 19/09).
      await _salvaGettone(prefs, response['token']);
      return (error: null, isNew: isNew);
    }
    return (
      error: (response['message'] ?? 'Errore sconosciuto.').toString(),
      isNew: false,
    );
  }

  // ─── LOGIN ──────────────────────────────────────────────────────────────────
  Future<AuthResult> login(String email, String password) async {
    final response = await ApiServices.login(email: email, password: password);
    return _handleAuthResponse(response, email);
  }

  // ─── OTP ────────────────────────────────────────────────────────────────────
  Future<bool> sendOTP(String email) async {
    return await ApiServices.sendOTP(email);
  }

  Future<bool> verifyOTP(String email, String otp) async {
    return await ApiServices.verifyOTP(email, otp);
  }

  // ─── SIGNUP ─────────────────────────────────────────────────────────────────
  Future<String?> signup({
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
    final response = await ApiServices.signup(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      weight: weight,
      height: height,
      gender: gender,
      birthDate: birthDate,
      profileImage: profileImage,
    );

    if (response == null) return 'Errore di rete. Riprova.';
    if (response['status'] != 'success') {
      return response['message'] ?? 'Errore sconosciuto.';
    }

    final prefs = await SharedPreferences.getInstance();
    // La registrazione consegna gia' il gettone: senza, il caricamento del
    // profilo subito dopo tornerebbe 401 (19/09).
    await _salvaGettone(prefs, response['token']);
    final loadError = await _loadUserData(email);
    if (loadError == null) {
      await prefs.setString('user_email', email);
    }
    return loadError;
  }

  // ─── UPDATE GOALS ────────────────────────────────────────────────────────────
  Future<String?> updateGoals(UserModel updatedUser) async {
    if (state == null) return 'Nessun utente loggato.';
    final errore = await _salvaObiettivi(updatedUser);
    if (errore == null) state = updatedUser;
    return errore;
  }

  /// Tutti gli obiettivi di [updatedUser], in una richiesta sola.
  Future<String?> _salvaObiettivi(UserModel updatedUser, {bool conObiettivoPeso = true}) {
    return ApiServices.updateGoals(
      includeTargetWeight: conObiettivoPeso,
      userId: updatedUser.id,
      currentWeight: updatedUser.currentWeight,
      targetWeight: updatedUser.targetWeight,
      calorieGoal: updatedUser.calorieGoal,
      proteinGoal: updatedUser.proteinGoal,
      fatGoal: updatedUser.fatGoal,
      carbGoal: updatedUser.carbGoal,
      waterGoal: updatedUser.waterGoal,
      fiberGoal: updatedUser.fiberGoal,
      sugarMax: updatedUser.sugarMax,
      saturatedFatsGoal: updatedUser.saturatedFatsGoal,
      monounsaturatedFatsGoal: updatedUser.monounsaturatedFatsGoal,
      polyunsaturatedFatsGoal: updatedUser.polyunsaturatedFatsGoal,
      transFatsMax: updatedUser.transFatsMax,
      cholesterolMax: updatedUser.cholesterolMax,
      sodiumMax: updatedUser.sodiumMax,
      vitAGoal: updatedUser.vitAGoal,
      vitB1Goal: updatedUser.vitB1Goal,
      vitB2Goal: updatedUser.vitB2Goal,
      vitB3Goal: updatedUser.vitB3Goal,
      vitB5Goal: updatedUser.vitB5Goal,
      vitB6Goal: updatedUser.vitB6Goal,
      vitB7Goal: updatedUser.vitB7Goal,
      vitB9Goal: updatedUser.vitB9Goal,
      vitB11Goal: updatedUser.vitB11Goal,
      vitB12Goal: updatedUser.vitB12Goal,
      vitCGoal: updatedUser.vitCGoal,
      vitDGoal: updatedUser.vitDGoal,
      vitEGoal: updatedUser.vitEGoal,
      vitKGoal: updatedUser.vitKGoal,
      arsenicGoal: updatedUser.arsenicGoal,
      biotinGoal: updatedUser.biotinGoal,
      boronGoal: updatedUser.boronGoal,
      calciumGoal: updatedUser.calciumGoal,
      chlorideGoal: updatedUser.chlorideGoal,
      cholineGoal: updatedUser.cholineGoal,
      chromiumGoal: updatedUser.chromiumGoal,
      cobaltGoal: updatedUser.cobaltGoal,
      copperGoal: updatedUser.copperGoal,
      fluorideGoal: updatedUser.fluorideGoal,
      fluorineGoal: updatedUser.fluorineGoal,
      iodineGoal: updatedUser.iodineGoal,
      ironGoal: updatedUser.ironGoal,
      magnesiumGoal: updatedUser.magnesiumGoal,
      manganeseGoal: updatedUser.manganeseGoal,
      molybdenumGoal: updatedUser.molybdenumGoal,
      phosphorusGoal: updatedUser.phosphorusGoal,
      potassiumGoal: updatedUser.potassiumGoal,
      seleniumGoal: updatedUser.seleniumGoal,
      siliconGoal: updatedUser.siliconGoal,
      sulfurGoal: updatedUser.sulfurGoal,
      tinGoal: updatedUser.tinGoal,
      vanadiumGoal: updatedUser.vanadiumGoal,
      zincGoal: updatedUser.zincGoal,
    );
  }

  /// Il peso attuale (Home, profilo). `null` se salvato, altrimenti il
  /// messaggio del server.
  ///
  /// Con il peso partono TUTTI gli obiettivi (17/09). Il 15/09 si mandava il
  /// solo peso, ma sull'hosting c'era ancora il vecchio update_goals.php, che
  /// scrive zero in ogni colonna non ricevuta: un tocco sul "+" del peso ha
  /// azzerato calorie e macro. Il peso obiettivo resta fuori solo se e' fuori
  /// limite (salvato prima del 14/09), perche' farebbe rifiutare tutto.
  Future<String?> updateWeight(double weight) async {
    final user = state;
    if (user == null) return 'Nessun utente loggato.';
    final aggiornato = user.copyWith(currentWeight: weight);
    final errore = await _salvaObiettivi(
      aggiornato,
      conObiettivoPeso: user.targetWeight == 0 || LimitiCorpo.erroreObiettivo(user.targetWeight) == null,
    );
    if (errore == null) state = aggiornato;
    return errore;
  }

  // ─── UPDATE PROFILE ──────────────────────────────────────────────────────────
  Future<String?> updateUserProfile({
    required String firstName,
    required String lastName,
    double? height,
    String? gender,
    DateTime? birthDate,
    String? profileImage,
  }) async {
    if (state == null) return 'Nessun utente loggato.';

    final success = await ApiServices.updateUserProfile(
      userId: state!.id,
      firstName: firstName,
      lastName: lastName,
      height: height,
      gender: gender,
      birthDate: birthDate?.toIso8601String().split('T').first,
      profileImage: profileImage,
    );

    if (success) {
      state = state!.copyWith(
        firstName: firstName,
        lastName: lastName,
        height: height,
        gender: gender,
        birthDate: birthDate,
        profileImage:
            profileImage ??
            state!.profileImage, // Mantiene quello vecchio se non modificato
      );
      return null;
    }
    return 'Errore nell\'aggiornamento del profilo.';
  }

  // ─── REFRESH ────────────────────────────────────────────────────────────────
  Future<String?> refreshUser() async {
    if (state == null) return 'Nessun utente loggato.';
    return await _loadUserData(state!.email);
  }

  /// Mette il gettone dove serve: in memoria per le richieste e nelle
  /// preferenze per il prossimo avvio.
  Future<void> _salvaGettone(SharedPreferences prefs, dynamic token) async {
    final t = (token ?? '').toString();
    if (t.isEmpty) return;
    ApiServices.gettone = t;
    await prefs.setString('auth_token', t);
  }

  // ─── LOGOUT ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    final email = state?.email;
    state = null;
    // Prima al server: la sessione va chiusa anche la', o il gettone resta
    // valido su un telefono che non e' piu' tuo (19/09).
    await ApiServices.logout();
    ApiServices.gettone = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('auth_token');
    await prefs.remove(_chiaveProfilo);
    // La copia della libreria personale sul telefono se ne va con l'account:
    // chi usa il dispositivo dopo non deve trovarsi i suoi alimenti.
    if (email != null) await LocalFoodCache.svuota(email);
  }

  // ─── HELPER PRIVATO ──────────────────────────────────────────────────────────
  Future<String?> _loadUserData(String email) async {
    final response = await ApiServices.getUserData(email);
    if (response == null) return 'Errore di rete. Riprova.';
    if (response['status'] != 'success') {
      return response['message'] ?? 'Errore sconosciuto.';
    }
    state = UserModel.fromJson(response['data']);
    await _salvaProfiloInLocale(response['data']);
    return null;
  }

  /// L'ultimo profilo scaricato, per poter riaprire l'app senza rete.
  static const _chiaveProfilo = 'profilo_in_cache';

  Future<void> _salvaProfiloInLocale(dynamic dati) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chiaveProfilo, jsonEncode(dati));
  }

  /// Rimette in piedi l'ultimo profilo salvato: senza rete l'app si apriva
  /// sulla pagina di accesso anche con la sessione salvata, e non si vedeva
  /// piu' niente (test di release 19/09).
  Future<bool> _riprendiProfiloLocale(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final salvato = prefs.getString(_chiaveProfilo);
    if (salvato == null) return false;
    try {
      final dati = jsonDecode(salvato) as Map<String, dynamic>;
      if ((dati['email'] ?? '').toString().toLowerCase() != email.toLowerCase()) return false;
      state = UserModel.fromJson(dati);
      return true;
    } catch (_) {
      return false;
    }
  }
}
