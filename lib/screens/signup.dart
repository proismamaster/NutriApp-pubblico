import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../logic/limiti_corpo.dart';

import '../logic/unit_format.dart';

import '../services/api_services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nutriapp/models/nutrient_field_config.dart';
import '../MainLayout.dart';
import '../models/user_model.dart';
import '../domain/user_provider.dart';
import '../logic/nutrient_controller_manager.dart';
import '../widgets/nutrient_group.dart';
import '../dictionary/translations.dart';
import '../providers/locale_provider.dart';
import '../widgets/auth_style.dart';
import 'markdown_viewer_page.dart';
import '../widgets/modern_loader.dart';
import '../widgets/nutri_select.dart';
import '../services/nutrient_calculator.dart';
import 'package:intl/intl.dart';


class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final NutrientControllerManager _manager = NutrientControllerManager();

  // Gestione dei controller per i vari campi
  final _nameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _currentWeightCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  // Tieni traccia dell'avanzamento nella registrazione
  int _currentStep = 1;
  bool _obscurePass = true;
  bool _usePersonalPlan = false;
  bool _acceptPrivacy = false;
  bool? _setLimitsNow;
  bool _isSendingOTP = false;
  /// True dopo un tentativo di avanzare con il passo incompleto: il
  /// motivo compare sotto al pulsante solo da quel momento, come nel mockup.
  bool _triedStep = false;
  String _selectedGender = 'Donna';
  File? _profileImage;
  final _searchCtrl = TextEditingController();

  // Gestione dell'OTP e delle immagini
  Timer? _timer;
  String? _profileImageBase64;
  DateTime? _birthDate;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    _manager.init([
      'calorie_goal',
      'protein_goal',
      'fat_goal',
      'carb_goal',
      'fiber_goal',
      'sugar_max',
      'saturated_fats_goal',
      'monounsaturated_fats_goal',
      'polyunsaturated_fats_goal',
      'trans_fats_max',
      'cholesterol_max',
      'sodium_max',
      'vit_a_goal',
      'vit_b1_goal',
      'vit_b2_goal',
      'vit_b3_goal',
      'vit_b5_goal',
      'vit_b6_goal',
      'vit_b7_goal',
      'vit_b9_goal',
      'vit_b11_goal',
      'vit_b12_goal',
      'vit_c_goal',
      'vit_d_goal',
      'vit_e_goal',
      'vit_k_goal',
      'biotin_goal',
      'arsenic_goal',
      'boron_goal',
      'calcium_goal',
      'chloride_goal',
      'choline_goal',
      'chromium_goal',
      'cobalt_goal',
      'copper_goal',
      'fluoride_goal',
      'fluorine_goal',
      'iodine_goal',
      'iron_goal',
      'magnesium_goal',
      'manganese_goal',
      'molybdenum_goal',
      'phosphorus_goal',
      'potassium_goal',
      'selenium_goal',
      'silicon_goal',
      'sulfur_goal',
      'tin_goal',
      'zinc_goal',
    ]);

    // Aggiornamento automatico delle calorie in base ai macro
    _manager.controllers['carb_goal']?.addListener(_updateCalorieGoal);
    _manager.controllers['protein_goal']?.addListener(_updateCalorieGoal);
    _manager.controllers['fat_goal']?.addListener(_updateCalorieGoal);
  }

  void _updateCalorieGoal() {
    // In grammi e kcal qualunque unita' ci sia scritta (18/09: once e kJ).
    final carbs = _manager.valore('carb_goal');
    final proteins = _manager.valore('protein_goal');
    final fats = _manager.valore('fat_goal');

    final minCalories = (carbs * 4) + (proteins * 4) + (fats * 9);
    
    final calorieController = _manager.controllers['calorie_goal'];
    // NB: si legge e si scrive tramite _manager.valore/_manager.scrivi, che
    // sanno se il campo e' in kcal o in kJ.
    if (calorieController != null) {
      if (calorieController.text.isEmpty) {
        _manager.scrivi('calorie_goal', minCalories);
      }
    }
  }


  @override
  void dispose() {
    _manager.dispose();
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _currentWeightCtrl.dispose();
    _targetWeightCtrl.dispose();
    _otpCtrl.dispose();
    _searchCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _requestOTP() async {
    if (_resendCooldown > 0) return;

    setState(() => _isSendingOTP = true);
    final success = await ref.read(userProvider.notifier).sendOTP(_emailCtrl.text.trim());
    setState(() => _isSendingOTP = false);
    
    if (success) {
      setState(() {
        _resendCooldown = 30;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendCooldown == 0) {
          timer.cancel();
        } else {
          setState(() {
            _resendCooldown--;
          });
        }
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? Translations.get(ref.read(appSettingsProvider).language, 'Codice inviato via email!') : Translations.get(ref.read(appSettingsProvider).language, 'Errore nell\'invio del codice.')),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyOTP() async {
    final success = await ref.read(userProvider.notifier).verifyOTP(
      _emailCtrl.text.trim(),
      _otpCtrl.text.trim(),
    );
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Translations.get(ref.read(appSettingsProvider).language, 'Email verificata con successo!')), backgroundColor: Colors.green),
        );
        setState(() => _currentStep++);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Translations.get(ref.read(appSettingsProvider).language, 'Codice non valido o scaduto.')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Nutri.bg,
          body: SafeArea(
            child: Column(
              children: [
                // Intestazione del mockup: indietro, titolo, pillola lingua.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          icon: Icon(Icons.arrow_back, color: Nutri.green, size: 25),
                          onPressed: () {
                            if (_currentStep > 1) {
                              setState(() => _currentStep--);
                            } else {
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: Text(
                          Translations.get(lang, 'Registrazione'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Nutri.green,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      // Stesso foglio dal basso degli altri select (18/09).
                      GestureDetector(
                        onTap: () async {
                          final scelta = await mostraSceltaNutri<String>(
                            context,
                            titolo: Translations.get(lang, 'Lingua'),
                            selezionato: lang,
                            opzioni: const [
                              NutriOpzione('English', 'English'),
                              NutriOpzione('Italiano', 'Italiano'),
                              NutriOpzione('简体中文', '简体中文'),
                              NutriOpzione('العربية', 'العربية'),
                            ],
                          );
                          if (scelta == null) return;
                          await ref
                              .read(appSettingsProvider.notifier)
                              .saveSettings(scelta, ref.read(appSettingsProvider).country);
                        },
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.language, size: 17, color: Nutri.green),
                              const SizedBox(width: 5),
                              Text(
                                _codiceLingua(lang),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: Nutri.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStepIndicator(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Titolo e sottotitolo del passo corrente, come nel
                        // mockup: dicono dove sei e perche' servono quei dati.
                        Text(
                          _stepTitle(lang),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Nutri.ink,
                            letterSpacing: -0.6,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _stepSub(lang),
                          style: TextStyle(fontSize: 13.5, color: Nutri.muted, height: 1.45),
                        ),
                        const SizedBox(height: 20),
                        _buildCurrentStep(),
                      ],
                    ),
                  ),
                ),
            _buildBottomNav(),
          ],
        ),
      ),
    ),
        if (_isSavingFull)
          // Mostra il caricamento durante la registrazione
          VeloDiCaricamento(messaggio: Translations.get(lang, 'Registrazione in corso...')),
      ],
    );
  }

  // ===================== mockup "NutriApp Registration" (29/08) =====================

  /// Etichette dei passi, calcolate sul flusso VERO dell'app.
  ///
  /// Il mockup ne disegna due fissi ("Account", "About you"), ma qui i passi
  /// sono 3, 4 o 5 a seconda che l'utente scelga il piano personalizzato e i
  /// limiti nutrizionali. Mostrarne due sarebbe una bugia su quanto manca, ed
  /// e' l'unico punto in cui mi discosto dal mockup di proposito.
  List<String> get _stepLabels {
    final lang = ref.read(appSettingsProvider).language;
    return [
      Translations.get(lang, 'Account'),
      Translations.get(lang, 'Su di te'),
      if (_usePersonalPlan && _setLimitsNow == true) Translations.get(lang, 'Obiettivi'),
      Translations.get(lang, 'Verifica'),
      Translations.get(lang, 'Riepilogo'),
    ];
  }

  String _stepTitle(String lang) {
    switch (_currentStep) {
      case 1:
        return Translations.get(lang, 'Crea il tuo account');
      case 2:
        return Translations.get(lang, 'Parlaci di te');
      default:
        if (_isOtpStep) return Translations.get(lang, 'Verifica la tua email');
        if (_isNutrientStep) return Translations.get(lang, 'Personalizza i tuoi obiettivi');
        return Translations.get(lang, 'Ci siamo quasi');
    }
  }

  String _stepSub(String lang) {
    switch (_currentStep) {
      case 1:
        return Translations.get(lang, 'Userai questi dati per accedere.');
      case 2:
        return Translations.get(lang, 'Ci servono per stimare il tuo obiettivo calorico giornaliero.');
      default:
        if (_isOtpStep) {
          return '${Translations.get(lang, 'Abbiamo inviato un codice OTP a ')}${_emailCtrl.text}';
        }
        if (_isNutrientStep) {
          return Translations.get(lang, 'Espandi le sezioni per impostare i limiti desiderati.');
        }
        return Translations.get(lang, 'Controlla i dati e completa la registrazione.');
    }
  }

  int get _nutrientStepIndex => 3;
  int get _otpStepIndex => (_usePersonalPlan && _setLimitsNow == true) ? 4 : 3;
  bool get _isNutrientStep =>
      _usePersonalPlan && _setLimitsNow == true && _currentStep == _nutrientStepIndex;
  bool get _isOtpStep => _currentStep == _otpStepIndex;

  // --- validazione live, come nel mockup: il pulsante resta spento finche'
  // --- non e' tutto a posto, e il motivo compare solo dopo un tentativo.

  bool get _emailOk => RegExp(r'^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$').hasMatch(_emailCtrl.text.trim());

  /// 0-4: lunghezza, maiuscola, cifra, simbolo. Stessa formula del mockup.
  int get _pwScore {
    final pw = _passCtrl.text;
    var s = 0;
    if (pw.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) s++;
    if (RegExp(r'[0-9]').hasMatch(pw)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) s++;
    return s;
  }

  int? get _age {
    if (_birthDate == null) return null;
    final oggi = DateTime.now();
    var a = oggi.year - _birthDate!.year;
    final m = oggi.month - _birthDate!.month;
    if (m < 0 || (m == 0 && oggi.day < _birthDate!.day)) a -= 1;
    return a;
  }

  double get _heightValue => double.tryParse(_heightCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _weightValue => double.tryParse(_currentWeightCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _targetValue => double.tryParse(_targetWeightCtrl.text.replaceAll(',', '.')) ?? 0;
  bool get _heightOk => LimitiCorpo.erroreAltezza(_heightValue) == null;

  /// Chiavi dei messaggi di eta', peso e obiettivo, o null se vanno bene
  /// (limiti in LimitiCorpo, 14/09). Prima bastava "maggiore di zero".
  String? get _erroreEta => LimitiCorpo.erroreNascita(_birthDate);
  String? get _errorePeso => LimitiCorpo.errorePeso(_weightValue);
  String? get _erroreObiettivo =>
      LimitiCorpo.erroreObiettivo(_targetValue, altezzaCm: _heightOk ? _heightValue : null);

  bool get _step1Ok =>
      _nameCtrl.text.trim().isNotEmpty &&
      _surnameCtrl.text.trim().isNotEmpty &&
      _emailOk &&
      _passCtrl.text.length >= 8 &&
      _passCtrl.text == _confirmPassCtrl.text &&
      _acceptPrivacy;

  bool get _step2Ok =>
      _erroreEta == null &&
      _heightOk &&
      _errorePeso == null &&
      _erroreObiettivo == null &&
      _setLimitsNow != null;

  String _stepHint(String lang) {
    if (_currentStep == 1) {
      if (_nameCtrl.text.trim().isEmpty || _surnameCtrl.text.trim().isEmpty) {
        return Translations.get(lang, 'Inserisci nome e cognome.');
      }
      if (!_emailOk) return Translations.get(lang, 'Inserisci un indirizzo email valido');
      if (_passCtrl.text.length < 8) {
        return Translations.get(lang, 'La password deve contenere almeno 8 caratteri.');
      }
      if (_passCtrl.text != _confirmPassCtrl.text) {
        return Translations.get(lang, 'Le due password non coincidono.');
      }
      return Translations.get(lang, 'Devi accettare la privacy per continuare');
    }
    final eta = _erroreEta;
    if (eta == 'limit_age_young') return Translations.get(lang, 'limit_age_young');
    if (eta == 'limit_age_old') return Translations.get(lang, 'limit_age_old');
    if (eta != null) return Translations.get(lang, 'Inserisci la tua data di nascita.');
    if (!_heightOk) return Translations.get(lang, 'Altezza ammessa fra 100 e 230 cm.');
    if (_currentWeightCtrl.text.trim().isEmpty || _targetWeightCtrl.text.trim().isEmpty) {
      return Translations.get(lang, 'Inserisci peso attuale e obiettivo.');
    }
    if (_errorePeso != null) return Translations.get(lang, 'limit_weight');
    if (_erroreObiettivo == 'limit_target_bmi') return Translations.get(lang, 'limit_target_bmi');
    if (_erroreObiettivo != null) return Translations.get(lang, 'limit_target');
    return Translations.get(lang, 'Scegli se impostare i limiti nutrizionali ora.');
  }

  /// La stessa stima che verra' poi salvata: NutrientCalculator, non una
  /// formula a parte. Prima qui valevano 1.4 e -400 e si annunciavano 1530
  /// kcal, mentre nel profilo ne arrivavano 1391 (test di release 19/09).
  /// Resta una stima, dichiarata tale nel testo sotto: si cambia quando si
  /// vuole dagli obiettivi.
  ({String line, String note})? get _calorieEstimate {
    final a = _age;
    if (!_heightOk || _errorePeso != null || a == null || _erroreEta != null) return null;
    final lang = ref.read(appSettingsProvider).language;
    final obiettivi = NutrientCalculator.calculateAutomaticGoals(
      currentWeight: _weightValue,
      targetWeight: _targetValue,
      height: _heightValue,
      age: a,
      gender: _selectedGender == 'Uomo' ? 'uomo' : 'donna',
    );
    final delta = _weightValue - _targetValue;
    final target = (obiettivi['calorie_goal'] ?? 0).round();
    // Stesso separatore decimale della frase accanto: in italiano si leggeva
    // "5.5 kg ... a circa 0,4 kg" (test di release 19/09).
    String kg(double v) {
      final t = v.toStringAsFixed(1);
      return lang == 'Italiano' ? t.replaceAll('.', ',') : t;
    }

    final note = delta > 0.05
        ? '${Translations.get(lang, 'Per perdere')} ${kg(delta)} kg ${Translations.get(lang, 'a circa 0,4 kg a settimana. Puoi cambiarlo quando vuoi.')}'
        : delta < -0.05
            ? '${Translations.get(lang, 'Per aumentare di')} ${kg(delta.abs())} kg ${Translations.get(lang, 'gradualmente. Puoi cambiarlo quando vuoi.')}'
            : Translations.get(lang, 'Per mantenere il peso attuale. Puoi cambiarlo quando vuoi.');
    return (
      line: '${Translations.get(lang, 'Obiettivo suggerito')} ${UnitFormat.e(target)}/${Translations.get(lang, 'giorno')}',
      note: note,
    );
  }

  /// Sigla di due lettere per la pillola lingua del mockup ("EN", non
  /// "English"): nell'intestazione lo spazio e' quello che e'.
  String _codiceLingua(String lang) {
    switch (lang) {
      case 'Italiano':
        return 'IT';
      case '简体中文':
        return 'ZH';
      case 'العربية':
        return 'AR';
      default:
        return 'EN';
    }
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: NutriStepBar(labels: _stepLabels, current: _currentStep),
    );
  }

  Widget _buildOTPStep() {
    final lang = ref.watch(appSettingsProvider).language;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: Nutri.surfaceSoft, shape: BoxShape.circle),
            child: Icon(Icons.mark_email_read_outlined, size: 34, color: Nutri.green),
          ),
        ),
        const SizedBox(height: 24),
        const NutriFieldLabel('OTP'),
        NutriField(
          controller: _otpCtrl,
          icon: Icons.password,
          hint: Translations.get(lang, 'Inserisci il codice a 6 cifre'),
          keyboard: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: (_isSendingOTP || _resendCooldown > 0) ? null : _requestOTP,
            child: Text(
              _isSendingOTP
                  ? Translations.get(lang, 'Invio in corso...')
                  : (_resendCooldown > 0
                      ? '${Translations.get(lang, 'Reinvia tra')} $_resendCooldown s'
                      : Translations.get(lang, 'Non hai ricevuto il codice? Reinvia')),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: (_isSendingOTP || _resendCooldown > 0) ? Nutri.mutedSoft : Nutri.green,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountStep() {
    final lang = ref.watch(appSettingsProvider).language;
    final iniziali = ((_nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim()[0] : '') +
            (_surnameCtrl.text.trim().isNotEmpty ? _surnameCtrl.text.trim()[0] : ''))
        .toUpperCase();
    final pw = _passCtrl.text;
    final score = _pwScore;
    final strengthColors = [Nutri.danger, Color(0xFFD9A400), Color(0xFF7FA92B), Nutri.green];
    final sColor = pw.isEmpty ? Nutri.mutedSoft : strengthColors[(score - 1).clamp(0, 3)];
    final strengthNames = [
      Translations.get(lang, 'Debole'),
      Translations.get(lang, 'Discreta'),
      Translations.get(lang, 'Buona'),
      Translations.get(lang, 'Forte'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card foto profilo: nel mockup mostra le iniziali finche' non se ne
        // carica una, invece di un segnaposto grigio anonimo.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Nutri.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Nutri.fieldBorder),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4EFDE),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFD3E2CC)),
                        image: _profileImage != null
                            ? DecorationImage(image: FileImage(_profileImage!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _profileImage != null
                          ? null
                          : Text(
                              iniziali.isEmpty ? '—' : iniziali,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                color: Nutri.green,
                                letterSpacing: -0.5,
                              ),
                            ),
                    ),
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Nutri.greenFill,
                          shape: BoxShape.circle,
                          border: Border.all(color: Nutri.card, width: 2.5),
                        ),
                        child: Icon(Icons.photo_camera, size: 14, color: Nutri.onGreenFill),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Translations.get(lang, 'Foto profilo'),
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: Nutri.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      Translations.get(lang, 'Facoltativa. Fino ad allora usiamo le tue iniziali.'),
                      style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NutriFieldLabel(Translations.get(lang, 'Nome')),
                  NutriField(
                    controller: _nameCtrl,
                    hint: 'Marco',
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NutriFieldLabel(Translations.get(lang, 'Cognome')),
                  NutriField(
                    controller: _surnameCtrl,
                    hint: 'Rossi',
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        NutriFieldLabel(Translations.get(lang, 'Email')),
        NutriField(
          controller: _emailCtrl,
          icon: Icons.mail_outline,
          hint: 'nome@email.it',
          keyboard: TextInputType.emailAddress,
          error: _emailCtrl.text.trim().length > 3 && !_emailOk,
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 16),
        NutriFieldLabel(Translations.get(lang, 'Password')),
        NutriField(
          controller: _passCtrl,
          icon: Icons.lock_outline,
          hint: Translations.get(lang, 'Almeno 8 caratteri'),
          obscure: _obscurePass,
          onChanged: (_) => setState(() {}),
          trailing: GestureDetector(
            onTap: () => setState(() => _obscurePass = !_obscurePass),
            child: Icon(
              _obscurePass ? Icons.visibility : Icons.visibility_off,
              size: 20,
              color: Nutri.mutedSoft,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < score ? sColor : Nutri.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Text(
                pw.isEmpty
                    ? Translations.get(lang, 'Sicurezza password')
                    : strengthNames[(score - 1).clamp(0, 3)],
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: sColor),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        NutriFieldLabel(Translations.get(lang, 'Conferma Password')),
        NutriField(
          controller: _confirmPassCtrl,
          icon: Icons.lock_outline,
          hint: Translations.get(lang, 'Ripeti password'),
          obscure: _obscurePass,
          error: _confirmPassCtrl.text.isNotEmpty && _confirmPassCtrl.text != pw,
          onChanged: (_) => setState(() {}),
          trailing: (_confirmPassCtrl.text.isNotEmpty && _confirmPassCtrl.text == pw)
              ? Icon(Icons.check_circle, size: 20, color: Nutri.green)
              : null,
        ),
        if (_confirmPassCtrl.text.isNotEmpty && _confirmPassCtrl.text != pw)
          NutriInlineError(Translations.get(lang, 'Le due password non coincidono.')),

        const SizedBox(height: 20),
        // Non e' nel mockup ma e' una funzione vera dell'app: decide se piu'
        // avanti compare il passo degli obiettivi personalizzati.
        NutriCheckbox(
          value: _usePersonalPlan,
          onChanged: (v) => setState(() => _usePersonalPlan = v),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Translations.get(lang, 'Usa Piano Personalizzato'),
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Nutri.ink),
              ),
              const SizedBox(height: 2),
              Text(
                Translations.get(lang, 'Imposta obiettivi calorici e nutrienti specifici'),
                style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft, height: 1.35),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        NutriPrivacyCheck(
          value: _acceptPrivacy,
          onChanged: (v) => setState(() => _acceptPrivacy = v),
          testoPrima: Translations.get(lang, 'Accetto la '),
          testoLink: Translations.get(lang, 'privacy policy'),
          onApriInformativa: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MarkdownViewerPage(
                title: 'Informativa sulla privacy',
                assetPathPrefix: 'assets/docs/privacy',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoStep() {
    final lang = ref.watch(appSettingsProvider).language;
    final stima = _calorieEstimate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NutriFieldLabel(Translations.get(lang, 'Genere')),
        _buildGenderSelector(),

        const SizedBox(height: 18),
        NutriFieldLabel(Translations.get(lang, 'Data di nascita')),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              // Solo date che danno un'eta' ammessa (14/09): prima si poteva
              // scegliere anche oggi, cioe' un utente di zero anni.
              initialDate: LimitiCorpo.dataInizialeCalendario(_birthDate),
              firstDate: LimitiCorpo.nascitaPiuLontana(),
              lastDate: LimitiCorpo.nascitaPiuRecente(),
              initialEntryMode: DatePickerEntryMode.input,
            );
            if (date != null) setState(() => _birthDate = date);
          },
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: Nutri.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Nutri.fieldBorder, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.cake_outlined, size: 20, color: Nutri.mutedSoft),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    _birthDate == null
                        ? Translations.get(lang, 'Data di nascita')
                        : DateFormat('dd/MM/yyyy').format(_birthDate!),
                    style: TextStyle(
                      fontSize: 16,
                      color: _birthDate == null ? Nutri.hint : Nutri.ink,
                    ),
                  ),
                ),
                if (_age != null)
                  Text(
                    '$_age ${Translations.get(lang, 'anni')}',
                    style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),
        NutriFieldLabel(Translations.get(lang, 'Altezza')),
        NutriField(
          controller: _heightCtrl,
          hint: '174',
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          suffixText: 'cm',
          error: _heightCtrl.text.isNotEmpty && !_heightOk,
          onChanged: (_) => setState(() {}),
        ),
        if (_heightCtrl.text.isNotEmpty && !_heightOk)
          NutriInlineError(Translations.get(lang, 'Altezza ammessa fra 100 e 230 cm.')),

        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NutriFieldLabel(Translations.get(lang, 'Peso attuale')),
                  NutriField(
                    controller: _currentWeightCtrl,
                    hint: '72.0',
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    suffixText: 'kg',
                    error: _currentWeightCtrl.text.isNotEmpty && _errorePeso != null,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_currentWeightCtrl.text.isNotEmpty && _errorePeso != null)
                    NutriInlineError(Translations.get(lang, 'limit_weight')),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NutriFieldLabel(Translations.get(lang, 'Obiettivo peso')),
                  NutriField(
                    controller: _targetWeightCtrl,
                    hint: '68.0',
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    suffixText: 'kg',
                    error: _targetWeightCtrl.text.isNotEmpty && _erroreObiettivo != null,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_targetWeightCtrl.text.isNotEmpty && _erroreObiettivo != null)
                    NutriInlineError(
                      _erroreObiettivo == 'limit_target_bmi'
                          ? Translations.get(lang, 'limit_target_bmi')
                          : Translations.get(lang, 'limit_target'),
                    ),
                ],
              ),
            ),
          ],
        ),

        if (stima != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
            decoration: BoxDecoration(
              color: Nutri.surfaceSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.insights, size: 19, color: Nutri.green),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stima.line,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Nutri.ink),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        stima.note,
                        style: TextStyle(fontSize: 12.5, color: Nutri.muted, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        NutriFieldLabel(Translations.get(lang, 'Vuoi impostare i limiti nutrizionali ora?')),
        _limitCard(
          selected: _setLimitsNow == true,
          label: Translations.get(lang, 'Sì, impostali ora'),
          caption: Translations.get(lang, 'Scegli calorie e macro nel passaggio successivo.'),
          onTap: () => setState(() => _setLimitsNow = true),
        ),
        const SizedBox(height: 8),
        _limitCard(
          selected: _setLimitsNow == false,
          label: Translations.get(lang, 'No, usa il piano suggerito'),
          caption: Translations.get(lang, 'Li impostiamo dai tuoi dati. Puoi cambiarli quando vuoi.'),
          onTap: () => setState(() => _setLimitsNow = false),
        ),
      ],
    );
  }

  /// Card radio del mockup: pallino a sinistra, titolo e spiegazione a destra,
  /// bordo verde quando selezionata.
  Widget _limitCard({
    required bool selected,
    required String label,
    required String caption,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Nutri.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Nutri.green : Nutri.fieldBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Nutri.green : Nutri.fieldBorder,
                  width: 2,
                ),
              ),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Nutri.green : Colors.transparent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: Nutri.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    caption,
                    style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    final lang = ref.watch(appSettingsProvider).language;
    return Row(
      children: [
        // Solo donna e uomo (15/09): il sesso serve al calcolo delle calorie,
        // e "Altro" veniva trattato come uomo senza dirlo.
        for (final g in const ['Donna', 'Uomo']) ...[
          if (g != 'Donna') const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedGender = g),
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedGender == g ? Nutri.greenFill : Nutri.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedGender == g ? Nutri.greenFill : Nutri.fieldBorder,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  Translations.get(lang, g),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _selectedGender == g ? FontWeight.bold : FontWeight.w500,
                    color: _selectedGender == g ? Colors.white : Nutri.label,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<NutrientFieldConfig> _getVitaminConfigs() {
    final Map<String, (String, String)> vitamins = {
      'vit_a_goal': ('Vitamina A', 'µg'),
      'vit_b1_goal': ('Vitamina B1', 'mg'),
      'vit_b2_goal': ('Vitamina B2', 'mg'),
      'vit_b3_goal': ('Vitamina B3', 'mg'),
      'vit_b5_goal': ('Vitamina B5', 'mg'),
      'vit_b6_goal': ('Vitamina B6', 'mg'),
      'vit_b7_goal': ('Vitamina B7', 'µg'),
      'vit_b9_goal': ('Vitamina B9', 'µg'),
      'vit_b11_goal': ('Vitamina B11', 'µg'),
      'vit_b12_goal': ('Vitamina B12', 'µg'),
      'vit_c_goal': ('Vitamina C', 'mg'),
      'vit_d_goal': ('Vitamina D', 'µg'),
      'vit_e_goal': ('Vitamina E', 'mg'),
      'vit_k_goal': ('Vitamina K', 'µg'),
      'biotin_goal': ('Biotina', 'µg'),
    };

    return vitamins.entries.map((e) => _manager.getConfig(
      e.key,
      label: e.value.$1,
      suffix: e.value.$2,
    )).toList();
  }

  List<NutrientFieldConfig> _getMineralConfigs() {
    final Map<String, (String, String)> minerals = {
      'sodium_max': ('Sodio (max)', 'mg'),
      'arsenic_goal': ('Arsenico', 'µg'),
      'boron_goal': ('Boro', 'mg'),
      'calcium_goal': ('Calcio', 'mg'),
      'chloride_goal': ('Cloruro', 'mg'),
      'choline_goal': ('Colina', 'mg'),
      'chromium_goal': ('Cromo', 'µg'),
      'cobalt_goal': ('Cobalto', 'µg'),
      'copper_goal': ('Rame', 'mg'),
      'fluoride_goal': ('Fluoruro', 'mg'),
      'fluorine_goal': ('Fluoro', 'mg'),
      'iodine_goal': ('Iodio', 'µg'),
      'iron_goal': ('Ferro', 'mg'),
      'magnesium_goal': ('Magnesio', 'mg'),
      'manganese_goal': ('Manganese', 'mg'),
      'molybdenum_goal': ('Molibdeno', 'µg'),
      'phosphorus_goal': ('Fosforo', 'mg'),
      'potassium_goal': ('Potassio', 'mg'),
      'selenium_goal': ('Selenio', 'µg'),
      'silicon_goal': ('Silicio', 'mg'),
      'sulfur_goal': ('Zolfo', 'mg'),
      'tin_goal': ('Stagno', 'mg'),
      'vanadium_goal': ('Vanadio', 'µg'),
      'zinc_goal': ('Zinco', 'mg'),
    };

    return minerals.entries.map((e) => _manager.getConfig(
      e.key,
      label: e.value.$1,
      suffix: e.value.$2,
    )).toList();
  }

  Widget _buildCurrentStep() {
    // Carica la schermata corrispondente al passaggio attuale
    
    if (_currentStep == 1) return _buildAccountStep();
    if (_currentStep == 2) return _buildPersonalInfoStep();
    
    int nextStep = 3;
    if (_usePersonalPlan) {
      if (_setLimitsNow == true) {
        if (_currentStep == nextStep) return _buildNutrientStep();
        nextStep++;
      }
    }
    
    if (_currentStep == nextStep) return _buildOTPStep();
    return _buildFinalSummary();
}

  Widget _buildNutrientStep() {
    final lang = ref.watch(appSettingsProvider).language;
    return Column(
      children: [
        Text(
          Translations.get(lang, 'Personalizza i tuoi obiettivi'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          Translations.get(lang, 'Espandi le sezioni per impostare i limiti desiderati.'),
          style: TextStyle(color: Nutri.body),
        ),
        const SizedBox(height: 20),
        _buildCollapsibleSection(
          title: Translations.get(lang, 'Macronutrienti'),
          icon: Icons.restaurant,
          configs: [
            _manager.getConfig('calorie_goal', label: Translations.get(lang, 'Goal Calorie'), suffix: UnitFormat.eSigla),
            _manager.getConfig('carb_goal', label: Translations.get(lang, 'Carboidrati'), suffix: UnitFormat.pSigla),
            _manager.getConfig('protein_goal', label: Translations.get(lang, 'Proteine'), suffix: UnitFormat.pSigla),
            _manager.getConfig('fat_goal', label: Translations.get(lang, 'Grassi'), suffix: UnitFormat.pSigla),
          ],
        ),
        _buildCollapsibleSection(
          title: Translations.get(lang, 'Dettagli Macro'),
          icon: Icons.pie_chart_outline,
          configs: [
            _manager.getConfig('fiber_goal', label: Translations.get(lang, 'Fibre'), suffix: UnitFormat.pSigla),
            _manager.getConfig('sugar_max', label: Translations.get(lang, 'Zuccheri max'), suffix: UnitFormat.pSigla),
            _manager.getConfig('saturated_fats_goal', label: Translations.get(lang, 'Grassi saturi'), suffix: UnitFormat.pSigla),
            _manager.getConfig('cholesterol_max', label: Translations.get(lang, 'Colesterolo max'), suffix: 'mg'),
          ],
        ),
        _buildCollapsibleSection(
          title: Translations.get(lang, 'Vitamine'),
          icon: Icons.health_and_safety_outlined,
          configs: _getVitaminConfigs(),
        ),
        _buildCollapsibleSection(
          title: Translations.get(lang, 'Minerali'),
          icon: Icons.category_outlined,
          configs: _getMineralConfigs(),
        ),
      ],
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    required List<NutrientFieldConfig> configs,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Nutri.divider),
      ),
      child: ExpansionTile(
        // Organizzazione delle impostazioni per categorie
        leading: Icon(icon, color: Colors.green),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        shape: const Border(), // Rimuove i bordi predefiniti dell'ExpansionTile
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: NutrientGroup(title: '', configs: configs),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalSummary() {
    final lang = ref.watch(appSettingsProvider).language;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
        const SizedBox(height: 24),
        Text(
          Translations.get(lang, 'Ottimo lavoro!'),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          Translations.get(lang, 'Sei pronto per iniziare il tuo percorso con NutriApp.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Nutri.muted, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final lang = ref.watch(appSettingsProvider).language;
    final totale = _stepLabels.length;
    final ultimo = _currentStep == totale;
    // Sui passi che il mockup non copre (obiettivi, OTP, riepilogo) non c'e'
    // una condizione di completezza da valutare: si prosegue sempre, come
    // prima. La validazione live vale solo sui due passi ridisegnati.
    final ok = _currentStep == 1
        ? _step1Ok
        : _currentStep == 2
            ? _step2Ok
            : true;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
      decoration: BoxDecoration(
        color: Nutri.bg,
        border: Border(top: BorderSide(color: Nutri.disabledBg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NutriPrimaryButton(
            label: _isOtpStep
                ? Translations.get(lang, 'Verifica Codice')
                : ultimo
                    ? Translations.get(lang, 'Completa Registrazione')
                    : Translations.get(lang, 'Continua'),
            icon: _isOtpStep
                ? Icons.check
                : ultimo
                    ? Icons.check
                    : Icons.arrow_forward,
            enabled: ok,
            onTap: () async {
              if (!ok) {
                setState(() => _triedStep = true);
                return;
              }
              if (_currentStep < totale) {
                if (_isOtpStep) {
                  await _verifyOTP();
                  return;
                }
                if (_currentStep == 2) _performAutomaticCalculation();
                // Il codice parte quando si entra nel passo di verifica,
                // non prima: stessa regola di sempre.
                if (_currentStep == _otpStepIndex - 1) await _requestOTP();
                if (mounted) setState(() { _currentStep++; _triedStep = false; });
              } else {
                _completeRegistration();
              }
            },
          ),
          if (!ok && _triedStep)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                _stepHint(lang),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft),
              ),
            ),
        ],
      ),
    );
  }

  /// Foto profilo scelta in registrazione: caricata sul server (2026-09-05).
  ///
  /// Prima finiva in base64 dentro il profilo utente, che viene riletto a ogni
  /// accesso. Ora il file va in uploads/ e nel profilo resta un indirizzo.
  /// L'anteprima locale compare subito, il caricamento avviene dopo: cosi'
  /// l'iscrizione non si blocca ad aspettare la rete.
  Future<void> _pickImage() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (image == null || !mounted) return;
    setState(() => _profileImage = File(image.path));

    final esito = await ApiServices.uploadImage(
      userMail: _emailCtrl.text.trim(),
      file: File(image.path),
    );
    if (!mounted) return;
    if (esito.url != null) {
      setState(() => _profileImageBase64 = esito.url);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Foto non caricata: ${esito.errore}'),
        backgroundColor: const Color(0xFFB4553C),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _performAutomaticCalculation() {
    if (_birthDate == null) return;

    final weight = LimitiCorpo.numero(_currentWeightCtrl.text) ?? 70.0;
    final target = LimitiCorpo.numero(_targetWeightCtrl.text) ?? weight;
    final height = LimitiCorpo.numero(_heightCtrl.text) ?? 170.0;
    
    // Calcolo età
    final now = DateTime.now();
    int age = now.year - _birthDate!.year;
    if (now.month < _birthDate!.month || 
        (now.month == _birthDate!.month && now.day < _birthDate!.day)) {
      age--;
    }

    final results = NutrientCalculator.calculateAutomaticGoals(
      currentWeight: weight,
      targetWeight: target,
      height: height,
      age: age,
      gender: _selectedGender,
    );

    // Imposta i valori calcolati
    _manager.setValues(results.map((key, value) => MapEntry(key, value.toStringAsFixed(1))));
  }

  bool _isSavingFull = false;

  Future<void> _completeRegistration() async {
    // Nessun Form da validare qui (19/09): ogni passo e' gia' controllato
    // prima di andare avanti. Prima c'era `_formKey.currentState!.validate()`
    // su una chiave mai collegata a un Form: currentState era null e la
    // registrazione con email si fermava SEMPRE all'ultimo passo, con
    // un'eccezione e nessun account creato (trovato nel test di release).
    if (_isSavingFull) return;

    setState(() => _isSavingFull = true);

    // Esegui la registrazione dell'account
    final signUpError = await ref
        .read(userProvider.notifier)
        .signup(
          email: _emailCtrl.text,
          password: _passCtrl.text,
          firstName: _nameCtrl.text,
          lastName: _surnameCtrl.text,
          weight: LimitiCorpo.numero(_currentWeightCtrl.text),
          height: LimitiCorpo.numero(_heightCtrl.text),
          // La colonna e' enum('male','female') (19/09): mandare "Donna" la
          // lasciava vuota, e al riavvio l'app chiedeva di nuovo il profilo.
          gender: _selectedGender == 'Uomo' ? 'male' : 'female',
          birthDate: _birthDate?.toIso8601String().split('T').first,
          profileImage: _profileImageBase64,
        );

    if (signUpError != null) {
      if (mounted) {
        setState(() => _isSavingFull = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(signUpError), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // 2. Salvataggio Obiettivi (Automatici o Personalizzati)
    final currentUser = ref.read(userProvider);
    if (currentUser != null) {
      final Map<String, dynamic> json = currentUser.toJson();
      
      // Valori calcolati (o inseriti manualmente se personalizzati)
      final nutrientValues = _manager.getValues();

      nutrientValues.forEach((key, value) {
        json[key] = value;
      });

      // Dati fisici
      json['current_weight'] = LimitiCorpo.numero(_currentWeightCtrl.text) ?? json['current_weight'];
      json['target_weight'] = LimitiCorpo.numero(_targetWeightCtrl.text) ?? json['target_weight'];

      final updatedUser = UserModel.fromJson(json);
      await ref.read(userProvider.notifier).updateGoals(updatedUser);
    }

    if (mounted) {
      setState(() => _isSavingFull = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
      );
    }
  }
}
