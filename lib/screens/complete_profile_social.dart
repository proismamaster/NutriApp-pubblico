import 'package:flutter/material.dart';
import '../logic/limiti_corpo.dart';

import '../widgets/auth_style.dart';

import '../logic/unit_format.dart';

import '../services/api_services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../domain/user_provider.dart';
import '../MainLayout.dart';
import '../logic/nutrient_controller_manager.dart';
import '../widgets/nutrient_group.dart';
import '../models/nutrient_field_config.dart';
import '../dictionary/translations.dart';
import '../providers/locale_provider.dart';
import '../widgets/modern_loader.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/nutrient_calculator.dart';
import 'package:intl/intl.dart';

import '../providers/auth_gate.dart';

class CompleteProfileSocialPage extends ConsumerStatefulWidget {
  const CompleteProfileSocialPage({super.key});

  @override
  ConsumerState<CompleteProfileSocialPage> createState() => _CompleteProfileSocialPageState();
}

class _CompleteProfileSocialPageState extends ConsumerState<CompleteProfileSocialPage> {
  final _formKey = GlobalKey<FormState>();
  final NutrientControllerManager _manager = NutrientControllerManager();
  
  final _nameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();
  
  DateTime? _selectedBirthDate;
  
  String _selectedGender = 'Donna';
  bool _usePersonalPlan = false;
  bool _setLimitsNow = false;
  int _currentStep = 1;
  bool _isSaving = false;
  
  File? _imageFile;
  String? _base64Image;
  final ImagePicker _picker = ImagePicker();

  /// Sceglie la foto profilo e la carica sul server (2026-09-05).
  ///
  /// PRIMA veniva codificata in base64 e infilata dentro il profilo utente,
  /// che viaggia a ogni lettura dell'account. E' la stessa strada che sulle
  /// ricette si e' gia' rotta ("Error saving recipe"): ora il file va in
  /// uploads/ e nel profilo resta un indirizzo corto.
  ///
  /// L'anteprima locale si vede subito (_imageFile), il caricamento avviene
  /// dopo: cosi' l'utente non resta a guardare un cerchio vuoto mentre la
  /// foto sale.
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (image == null || !mounted) return;
    setState(() => _imageFile = File(image.path));

    final esito = await ApiServices.uploadImage(
      userMail: ref.read(userProvider)?.email ?? '',
      file: File(image.path),
    );
    if (!mounted) return;
    if (esito.url != null) {
      setState(() => _base64Image = esito.url);
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

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    if (user != null) {
      _nameCtrl.text = user.firstName ?? '';
      _surnameCtrl.text = user.lastName ?? '';
      // Anche cio' che il profilo sa gia': arrivare a campi vuoti e doverli
      // riscrivere tutti sembrava un errore dell'app (test di release 19/09).
      final altezza = user.height ?? 0;
      if (altezza > 0) _heightCtrl.text = altezza.toStringAsFixed(0);
      if (user.currentWeight > 0) _weightCtrl.text = user.currentWeight.toStringAsFixed(1);
      if (user.targetWeight > 0) _targetWeightCtrl.text = user.targetWeight.toStringAsFixed(1);
      if ((user.gender ?? '').isNotEmpty) {
        _selectedGender = user.gender!.toLowerCase().startsWith('m') ? 'Uomo' : 'Donna';
      }
      _selectedBirthDate = user.birthDate;
    }
    
    // Inizializzazione di TUTTI i nutrienti (Macro, Micro, Minerali)
    _manager.init([
      'calorie_goal', 'protein_goal', 'fat_goal', 'carb_goal', 'fiber_goal', 'sugar_max',
      'saturated_fats_goal', 'monounsaturated_fats_goal', 'polyunsaturated_fats_goal',
      'trans_fats_max', 'cholesterol_max', 'sodium_max',
      'vit_a_goal', 'vit_b1_goal', 'vit_b2_goal', 'vit_b3_goal', 'vit_b5_goal', 'vit_b6_goal',
      'vit_b7_goal', 'vit_b9_goal', 'vit_b11_goal', 'vit_b12_goal', 'vit_c_goal', 'vit_d_goal',
      'vit_e_goal', 'vit_k_goal', 'biotin_goal', 'arsenic_goal', 'boron_goal', 'calcium_goal',
      'chloride_goal', 'choline_goal', 'chromium_goal', 'cobalt_goal', 'copper_goal',
      'fluoride_goal', 'fluorine_goal', 'iodine_goal', 'iron_goal', 'magnesium_goal',
      'manganese_goal', 'molybdenum_goal', 'phosphorus_goal', 'potassium_goal', 'selenium_goal',
      'silicon_goal', 'sulfur_goal', 'tin_goal', 'vanadium_goal', 'zinc_goal',
    ]);

    // Listener per il calcolo automatico delle calorie (minimo basato su macro)
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
    
    final calCtrl = _manager.controllers['calorie_goal'];
    if (calCtrl != null && calCtrl.text.isEmpty) {
      _manager.scrivi('calorie_goal', minCalories);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _surnameCtrl.dispose(); _heightCtrl.dispose();
    _weightCtrl.dispose(); _targetWeightCtrl.dispose(); _manager.dispose();
    super.dispose();
  }

  void _performAutomaticCalculation() {
    if (_selectedBirthDate == null) return;

    final weight = LimitiCorpo.numero(_weightCtrl.text) ?? 70.0;
    final target = LimitiCorpo.numero(_targetWeightCtrl.text) ?? weight;
    final height = LimitiCorpo.numero(_heightCtrl.text) ?? 170.0;
    
    // Calcolo età
    final now = DateTime.now();
    int age = now.year - _selectedBirthDate!.year;
    if (now.month < _selectedBirthDate!.month || 
        (now.month == _selectedBirthDate!.month && now.day < _selectedBirthDate!.day)) {
      age--;
    }

    final results = NutrientCalculator.calculateAutomaticGoals(
      currentWeight: weight,
      targetWeight: target,
      height: height,
      age: age,
      gender: _selectedGender,
    );

    _manager.setValues(results.map((key, value) => MapEntry(key, value.toStringAsFixed(1))));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Translations.get(ref.read(appSettingsProvider).language, 'Inserisci la tua data di nascita'))),
      );
      return;
    }

    final user = ref.read(userProvider);
    if (user == null) return;

    setState(() => _isSaving = true);

    // Esegui calcolo se non è stato fatto (o aggiorna)
    _performAutomaticCalculation();

    // 1. Aggiorna Profilo Anagrafico
    String genderToSend = 'male';
    if (_selectedGender == 'Donna') genderToSend = 'female';
    // Solo donna o uomo (15/09): "Altro" diventava uomo senza dirlo. 

    final profileError = await ref.read(userProvider.notifier).updateUserProfile(
      firstName: _nameCtrl.text.trim(),
      lastName: _surnameCtrl.text.trim(),
      height: LimitiCorpo.numero(_heightCtrl.text),
      gender: genderToSend, 
      birthDate: _selectedBirthDate,
      profileImage: _base64Image,
    );

    if (profileError != null) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(profileError), backgroundColor: Colors.red));
      }
      return;
    }

    // 2. Prepara e invia Obiettivi (Goals)
    final updatedUserInState = ref.read(userProvider)!;
    final Map<String, dynamic> json = updatedUserInState.toJson();
    
    // Prendi i valori (calcolati o personalizzati)
    final nutrientValues = _manager.getValues();
    nutrientValues.forEach((key, value) => json[key] = value);
    
    json['current_weight'] = LimitiCorpo.numero(_weightCtrl.text) ?? updatedUserInState.currentWeight;
    json['target_weight'] = LimitiCorpo.numero(_targetWeightCtrl.text) ?? updatedUserInState.targetWeight;

    final goalsError = await ref.read(userProvider.notifier).updateGoals(UserModel.fromJson(json));

    if (mounted) {
      setState(() => _isSaving = false);
      if (goalsError == null) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainLayout()), (r) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(goalsError), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    int totalSteps = (_usePersonalPlan && _setLimitsNow) ? 2 : 1;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Nutri.bg,
      appBar: AppBar(
        title: Text(Translations.get(lang, 'Configurazione Iniziale'), style: TextStyle(color: Nutri.green, fontWeight: FontWeight.bold)),
        backgroundColor: Nutri.bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Nutri.green),
          onPressed: () async {
            await ref.read(userProvider.notifier).logout();
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const AuthGate()),
                (route) => false,
              );
            }
          },
        ),
      ),
      body: Form(
        key: _formKey,
        // Rivalida ad ogni modifica dopo la prima interazione (2026-09-12):
        // senza questo un campo obbligatorio corretto dopo un tentativo di
        // avanzamento continuava a mostrare il rosso di prima. Stesso
        // difetto dell'altezza in "Il mio profilo".
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _currentStep == 1 ? _buildStep1() : _buildNutrientStep(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, 
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // La data non e' un campo del Form: si controlla qui, prima
                    // di calcolare obiettivi su un'eta' che non puo' esistere.
                    final erroreData = LimitiCorpo.erroreNascita(_selectedBirthDate);
                    if (erroreData != null) {
                      _mostraErroreData(erroreData, lang);
                      return;
                    }
                    if (_currentStep < totalSteps) {
                      // Se stiamo per andare allo step dei nutrienti, calcoliamo quelli automatici come base
                      if (_currentStep == 1) {
                        _performAutomaticCalculation();
                      }
                      setState(() => _currentStep++);
                    } else {
                      _submit();
                    }
                  }
                },
                child: Text(_currentStep == totalSteps ? Translations.get(lang, 'Concludi') : Translations.get(lang, 'Continua'), 
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
        if (_isSaving)
          VeloDiCaricamento(messaggio: Translations.get(lang, 'Salvataggio profilo...')),
      ],
    );
  }

  void _mostraErroreData(String chiave, String lang) {
    final testo = chiave == 'limit_age_young'
        ? Translations.get(lang, 'limit_age_young')
        : chiave == 'limit_age_old'
            ? Translations.get(lang, 'limit_age_old')
            : Translations.get(lang, 'Inserisci la tua data di nascita');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
  }

  /// Testo di un limite superato (chiavi di LimitiCorpo).
  String _testoLimite(String chiave, String lang) {
    switch (chiave) {
      case 'limit_height':
        return Translations.get(lang, 'Altezza ammessa fra 100 e 230 cm.');
      case 'limit_weight':
        return Translations.get(lang, 'limit_weight');
      case 'limit_target_bmi':
        return Translations.get(lang, 'limit_target_bmi');
      default:
        return Translations.get(lang, 'limit_target');
    }
  }

  Widget _buildStep1() {
    final lang = ref.watch(appSettingsProvider).language;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Nutri.surfaceSoft,
                backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                child: _imageFile == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(Translations.get(lang, 'Parlaci di te'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Text(Translations.get(lang, 'Genere'), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _buildGenderSelector(),
        const SizedBox(height: 24),
        _input(Translations.get(lang, 'Nome'), _nameCtrl, Icons.person_outline),
        _input(Translations.get(lang, 'Cognome'), _surnameCtrl, Icons.person_outline),
        
        // Data di Nascita
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: LimitiCorpo.dataInizialeCalendario(_selectedBirthDate),
              firstDate: LimitiCorpo.nascitaPiuLontana(),
              lastDate: LimitiCorpo.nascitaPiuRecente(),
            );
            if (date != null) setState(() => _selectedBirthDate = date);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Nutri.fieldBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_outlined, color: Colors.green),
                const SizedBox(width: 12),
                Text(
                  _selectedBirthDate == null 
                    ? Translations.get(lang, 'Data di nascita')
                    : DateFormat('dd/MM/yyyy').format(_selectedBirthDate!),
                  style: TextStyle(
                    color: _selectedBirthDate == null ? Nutri.hint : Nutri.ink,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),

        _input(Translations.get(lang, 'Altezza (cm)'), _heightCtrl, Icons.height,
            isNumber: true, limite: LimitiCorpo.erroreAltezza),
        _input(Translations.get(lang, 'Peso attuale'), _weightCtrl, Icons.fitness_center,
            isNumber: true, limite: LimitiCorpo.errorePeso),
        _input(Translations.get(lang, 'Obiettivo peso'), _targetWeightCtrl, Icons.flag_outlined,
            isNumber: true,
            limite: (kg) => LimitiCorpo.erroreObiettivo(kg, altezzaCm: LimitiCorpo.numero(_heightCtrl.text))),
        const Divider(height: 40),
        SwitchListTile(
          title: Text(Translations.get(lang, 'Piano Personalizzato'), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(Translations.get(lang, 'Imposta manualmente calorie e tutti i nutrienti')),
          value: _usePersonalPlan,
          activeColor: Colors.green,
          onChanged: (v) => setState(() => _usePersonalPlan = v),
        ),
        if (_usePersonalPlan)
          CheckboxListTile(
            title: Text(Translations.get(lang, 'Configura i nutrienti ora')),
            value: _setLimitsNow,
            activeColor: Colors.green,
            onChanged: (v) => setState(() => _setLimitsNow = v ?? false),
          ),
      ],
    );
  }

  Widget _buildNutrientStep() {
    final lang = ref.watch(appSettingsProvider).language;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Translations.get(lang, 'Personalizza i tuoi obiettivi'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(Translations.get(lang, 'Imposta i limiti per ogni categoria di nutriente.'), style: TextStyle(color: Nutri.body)),
        const SizedBox(height: 24),
        _buildSection(
          title: Translations.get(lang, 'Macronutrienti'),
          icon: Icons.restaurant,
          configs: [
            _manager.getConfig('calorie_goal', label: Translations.get(lang, 'Goal Calorie'), suffix: UnitFormat.eSigla),
            _manager.getConfig('carb_goal', label: Translations.get(lang, 'Carboidrati'), suffix: UnitFormat.pSigla),
            _manager.getConfig('protein_goal', label: Translations.get(lang, 'Proteine'), suffix: UnitFormat.pSigla),
            _manager.getConfig('fat_goal', label: Translations.get(lang, 'Grassi'), suffix: UnitFormat.pSigla),
          ],
        ),
        _buildSection(
          title: Translations.get(lang, 'Dettagli Macro'),
          icon: Icons.pie_chart_outline,
          configs: [
            _manager.getConfig('fiber_goal', label: Translations.get(lang, 'Fibre'), suffix: UnitFormat.pSigla),
            _manager.getConfig('sugar_max', label: Translations.get(lang, 'Zuccheri max'), suffix: UnitFormat.pSigla),
            _manager.getConfig('saturated_fats_goal', label: Translations.get(lang, 'Grassi saturi'), suffix: UnitFormat.pSigla),
            _manager.getConfig('cholesterol_max', label: Translations.get(lang, 'Colesterolo max'), suffix: 'mg'),
          ],
        ),
        _buildSection(
          title: Translations.get(lang, 'Vitamine'),
          icon: Icons.health_and_safety_outlined,
          configs: _getVitaminConfigs(),
        ),
        _buildSection(
          title: Translations.get(lang, 'Minerali'),
          icon: Icons.category_outlined,
          configs: _getMineralConfigs(),
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required IconData icon, required List<NutrientFieldConfig> configs}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Nutri.divider)),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: NutrientGroup(title: '', configs: configs),
          ),
        ],
      ),
    );
  }

  /// [limite] riceve il numero scritto (o null se non e' un numero) e
  /// restituisce la chiave di un limite superato: vedi LimitiCorpo.
  Widget _input(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    bool isNumber = false,
    String? Function(double?)? limite,
  }) {
    final lang = ref.watch(appSettingsProvider).language;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        // Con la virgola: "72,5" e' il modo italiano di scrivere un peso.
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.green),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.green, width: 2)),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return Translations.get(lang, 'Obbligatorio');
          final chiave = limite?.call(LimitiCorpo.numero(v));
          return chiave == null ? null : _testoLimite(chiave, lang);
        },
      ),
    );
  }

  Widget _buildGenderSelector() {
    final lang = ref.watch(appSettingsProvider).language;
    return Row(
      children: ['Donna', 'Uomo'].map((g) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _selectedGender = g),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: _selectedGender == g ? Nutri.greenFill : Nutri.surfaceSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(Translations.get(lang, g), textAlign: TextAlign.center, 
              style: TextStyle(color: _selectedGender == g ? Colors.white : Nutri.ink, fontWeight: FontWeight.bold)),
          ),
        ),
      )).toList(),
    );
  }

  List<NutrientFieldConfig> _getVitaminConfigs() {
    final lang = ref.watch(appSettingsProvider).language;
    final Map<String, (String, String)> vitamins = {
      'vit_a_goal': ('Vitamina A', 'µg'), 'vit_b1_goal': ('Vitamina B1', 'mg'),
      'vit_b2_goal': ('Vitamina B2', 'mg'), 'vit_b3_goal': ('Vitamina B3', 'mg'),
      'vit_b5_goal': ('Vitamina B5', 'mg'), 'vit_b6_goal': ('Vitamina B6', 'mg'),
      'vit_b7_goal': ('Vitamina B7', 'µg'), 'vit_b9_goal': ('Vitamina B9', 'µg'),
      'vit_b11_goal': ('Vitamina B11', 'µg'), 'vit_b12_goal': ('Vitamina B12', 'µg'),
      'vit_c_goal': ('Vitamina C', 'mg'), 'vit_d_goal': ('Vitamina D', 'µg'),
      'vit_e_goal': ('Vitamina E', 'mg'), 'vit_k_goal': ('Vitamina K', 'µg'),
      'biotin_goal': ('Biotina', 'µg'),
    };
    return vitamins.entries.map((e) => _manager.getConfig(e.key, label: Translations.get(lang, e.value.$1), suffix: e.value.$2)).toList();
  }

  List<NutrientFieldConfig> _getMineralConfigs() {
    final lang = ref.watch(appSettingsProvider).language;
    final Map<String, (String, String)> minerals = {
      'sodium_max': ('Sodio (max)', 'mg'), 'arsenic_goal': ('Arsenico', 'µg'),
      'boron_goal': ('Boro', 'mg'), 'calcium_goal': ('Calcio', 'mg'),
      'chloride_goal': ('Cloruro', 'mg'), 'choline_goal': ('Colina', 'mg'),
      'chromium_goal': ('Cromo', 'µg'), 'cobalt_goal': ('Cobalto', 'µg'),
      'copper_goal': ('Rame', 'mg'), 'fluoride_goal': ('Fluoruro', 'mg'),
      'fluorine_goal': ('Fluoro', 'mg'), 'iodine_goal': ('Iodio', 'µg'),
      'iron_goal': ('Ferro', 'mg'), 'magnesium_goal': ('Magnesio', 'mg'),
      'manganese_goal': ('Manganese', 'mg'), 'molybdenum_goal': ('Molibdeno', 'µg'),
      'phosphorus_goal': ('Fosforo', 'mg'), 'potassium_goal': ('Potassio', 'mg'),
      'selenium_goal': ('Selenio', 'µg'), 'silicon_goal': ('Silicio', 'mg'),
      'sulfur_goal': ('Zolfo', 'mg'), 'tin_goal': ('Stagno', 'mg'),
      'vanadium_goal': ('Vanadio', 'µg'), 'zinc_goal': ('Zinco', 'mg'),
    };
    return minerals.entries.map((e) => _manager.getConfig(e.key, label: Translations.get(lang, e.value.$1), suffix: e.value.$2)).toList();
  }
}
