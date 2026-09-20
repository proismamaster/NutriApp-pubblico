import 'package:flutter/material.dart';
import '../logic/limiti_corpo.dart';

import '../widgets/auth_style.dart';

import '../logic/unit_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user_provider.dart';
import '../models/user_model.dart';
import '../models/nutrient_field_config.dart';
import '../logic/nutrient_controller_manager.dart';
import '../widgets/nutrient_group.dart';
import '../dictionary/translations.dart';
import '../providers/locale_provider.dart';
import '../widgets/modern_loader.dart';


class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => GoalsPageState();
}

class GoalsPageState extends ConsumerState<GoalsPage> {
  final NutrientControllerManager _manager = NutrientControllerManager();

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _manager.init([
      'current_weight', 'target_weight', 'calorie_goal', 'protein_goal',
      'fat_goal', 'carb_goal', 'fiber_goal', 'sugar_max',
      'saturated_fats_goal', 'monounsaturated_fats_goal', 'polyunsaturated_fats_goal',
      'trans_fats_max', 'cholesterol_max', 'sodium_max',
      'vit_a_goal', 'vit_b1_goal', 'vit_b2_goal', 'vit_b3_goal', 'vit_b5_goal',
      'vit_b6_goal', 'vit_b7_goal', 'vit_b9_goal', 'vit_b11_goal', 'vit_b12_goal',
      'vit_c_goal', 'vit_d_goal', 'vit_e_goal', 'vit_k_goal', 'biotin_goal',
      'arsenic_goal', 'boron_goal', 'calcium_goal', 'chloride_goal', 'choline_goal',
      'chromium_goal', 'cobalt_goal', 'copper_goal', 'fluoride_goal', 'fluorine_goal',
      'iodine_goal', 'iron_goal', 'magnesium_goal', 'manganese_goal', 'molybdenum_goal',
      'phosphorus_goal', 'potassium_goal', 'selenium_goal', 'silicon_goal',
      'sulfur_goal', 'tin_goal', 'vanadium_goal', 'zinc_goal',
    ]);

    final currentUser = ref.read(userProvider);
    if (currentUser != null) {
      _manager.setValues(currentUser.toJson());
    }

    // Aggiunta dei listener per la sincronizzazione delle calorie
    _manager.controllers['carb_goal']?.addListener(_updateCalorieGoal);
    _manager.controllers['protein_goal']?.addListener(_updateCalorieGoal);
    _manager.controllers['fat_goal']?.addListener(_updateCalorieGoal);
    // Rimosso listener su calorie_goal per permettere la cancellazione manuale

    // Ricalcolo live della barra "energia dai macro" e della riga peso —
    // richiede solo un rebuild, i valori si leggono gia' dai controller in
    // build(). Su calorie_goal serve un listener separato (non e' negli
    // ascoltatori sopra: quelli aggiornano calorie_goal, non lo leggono).
    for (final key in ['carb_goal', 'protein_goal', 'fat_goal', 'calorie_goal', 'current_weight', 'target_weight']) {
      _manager.controllers[key]?.addListener(_refreshLiveFeedback);
    }
    // Mockup Goals: l'avviso "hai modificato i macro a mano" compare solo
    // dopo una modifica manuale di uno dei tre campi, e sparisce di nuovo se
    // si usa Auto-balance — _isAutoBalancing distingue le due sorgenti dello
    // stesso listener (l'utente che digita vs. il testo scritto dal bottone).
    for (final key in ['carb_goal', 'protein_goal', 'fat_goal']) {
      _manager.controllers[key]?.addListener(_onMacroFieldEdited);
    }
    // Mockup: il pulsante "Salva" in fondo riflette lo stato (non ancora
    // toccato / modificato e valido / modificato ma non valido) invece di
    // essere un semplice pulsante statico sempre uguale a se stesso.
    for (final controller in _manager.controllers.values) {
      controller.addListener(_markDirty);
    }
  }

  bool _dirty = false;
  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  void _refreshLiveFeedback() {
    if (mounted) setState(() {});
  }

  bool _manualMacroEdit = false;
  bool _isAutoBalancing = false;

  void _onMacroFieldEdited() {
    if (_isAutoBalancing || _manualMacroEdit) return;
    if (mounted) setState(() => _manualMacroEdit = true);
  }

  /// Ripartizione 45/25/30 (carb/proteine/grassi) dell'obiettivo calorico —
  /// stessa proporzione standard proposta nel mockup Goals, in assenza di un
  /// piano nutrizionale personalizzato da cui derivarla diversamente.
  void _autoBalanceMacros() {
    final goal = _manager.valore('calorie_goal');
    if (goal <= 0) return;
    _isAutoBalancing = true;
    setState(() {
      // Arrotondando tutti e tre i grammi la somma poteva superare
      // l'obiettivo (8379 kJ contro 8368) e "Salva obiettivi" rifiutava
      // proprio la ripartizione appena proposta. I grassi prendono cio' che
      // resta, arrotondato per difetto: la somma non supera mai l'obiettivo
      // (test di release 19/09).
      final carb = ((goal * 0.45) / 4).roundToDouble();
      final prot = ((goal * 0.25) / 4).roundToDouble();
      final restoKcal = goal - carb * 4 - prot * 4;
      _manager.scrivi('carb_goal', carb);
      _manager.scrivi('protein_goal', prot);
      _manager.scrivi('fat_goal', (restoKcal / 9).floorToDouble().clamp(0, double.infinity));
      _manualMacroEdit = false;
    });
    _isAutoBalancing = false;
  }

  /// Valore di un campo in kcal e grammi, qualunque unita' ci sia scritta
  /// (18/09: i macro possono essere in once).
  double _controllerValue(String key) => _manager.valore(key);

  void _updateCalorieGoal() {
    final carbs = _manager.valore('carb_goal');
    final proteins = _manager.valore('protein_goal');
    final fats = _manager.valore('fat_goal');

    final minCalories = (carbs * 4) + (proteins * 4) + (fats * 9);
    
    if ((_manager.controllers['calorie_goal']?.text ?? '').isEmpty) {
      // Se il campo calorie è vuoto lo riempiamo con il minimo dai macro.
      // Ma lasciamo che l'utente possa cancellare per riscrivere.
      _manager.scrivi('calorie_goal', minCalories);
    }
  }

  double _getMinRequiredCalories() {
    final carbs = _manager.valore('carb_goal');
    final proteins = _manager.valore('protein_goal');
    final fats = _manager.valore('fat_goal');
    return (carbs * 4) + (proteins * 4) + (fats * 9);
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  Future<void> _saveGoals() async {
    final currentUser = ref.read(userProvider);
    if (currentUser == null) return;

    // VALIDAZIONE COERENZA FISICA
    final minReq = _getMinRequiredCalories();
    final currentCal = _manager.valore('calorie_goal');

    if (currentCal < minReq) {
      final lang = ref.read(appSettingsProvider).language;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Translations.get(lang, 'Calorie min macro')} ${UnitFormat.e(minReq)}.'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: Translations.get(lang, 'CORREGGI'),
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                _manager.scrivi('calorie_goal', minReq);
              });
            },
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final values = _manager.getValues();
    // Creiamo una mappa temporanea con i dati esistenti e sovrascriviamo con i nuovi valori
    final json = currentUser.toJson();
    values.forEach((key, value) {
      json[key] = value;
    });

    final updatedUser = UserModel.fromJson(json);
    final error = await ref.read(userProvider.notifier).updateGoals(updatedUser);

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (error == null) _dirty = false;
      });
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Translations.get(ref.read(appSettingsProvider).language, 'Obiettivi salvati con successo!')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
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
          appBar: AppBar(
            title: Text(
              Translations.get(lang, 'I miei obiettivi'),
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  title: Translations.get(lang, 'Peso'),
                  icon: Icons.monitor_weight,
                  configs: [
                    _manager.getConfig('current_weight', label: Translations.get(lang, 'Peso attuale'), suffix: Translations.get(lang, 'kg')),
                    _manager.getConfig('target_weight', label: Translations.get(lang, 'Obiettivo peso'), suffix: Translations.get(lang, 'kg')),
                  ],
                ),
                _buildWeightDeltaLine(lang),
                // Titolo e pulsante sulla STESSA riga, senza potersi
                // sovrapporre (2026-09-07, seconda passata su richiesta di
                // Ismail: la prima li aveva messi su due righe).
                //
                // Le due cose insieme lo garantiscono: `Expanded` sul titolo
                // gli da' esattamente lo spazio che avanza — se non basta si
                // accorcia con i puntini invece di invadere il pulsante — e
                // il pulsante e' compatto (etichetta di una parola,
                // spaziatura ridotta) perche' quel caso non capiti quasi mai.
                // Prima il titolo non aveva ne' vincolo ne' ellissi, quindi
                // continuava a disegnarsi SOTTO al pulsante.
                // Stessa aria sopra e sotto delle altre intestazioni di
                // sezione (2026-09-08): NutrientGroup usa
                // `EdgeInsets.symmetric(vertical: 16)` attorno al proprio
                // titolo, e questa intestazione — scritta a mano perche' deve
                // ospitare anche il pulsante — non ce l'aveva. Il risultato
                // era che "Macronutrienti" stava appiccicato alla riga dei kg
                // sopra e al primo campo sotto, mentre "Peso" respirava: due
                // sezioni sorelle con due spaziature diverse.
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Icon(Icons.restaurant, color: Nutri.green, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          Translations.get(lang, 'Macronutrienti'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _autoBalanceMacros,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Nutri.green,
                          side: BorderSide(color: Nutri.fieldBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 38),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: Text(
                          Translations.get(lang, 'goal_auto_balance'),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                NutrientGroup(
                  title: '',
                  outlined: true,
                  configs: [
                    _manager.getConfig('calorie_goal', label: Translations.get(lang, 'Goal calorie'), suffix: UnitFormat.eSigla),
                    _manager.getConfig(
                      'carb_goal',
                      label: Translations.get(lang, 'Carboidrati'),
                      suffix: UnitFormat.pSigla,
                      dotColor: const Color(0xFF1B7A33),
                      trailingHint: UnitFormat.e(_controllerValue('carb_goal') * 4),
                    ),
                    _manager.getConfig(
                      'protein_goal',
                      label: Translations.get(lang, 'Proteine'),
                      suffix: UnitFormat.pSigla,
                      dotColor: const Color(0xFF4E9A6B),
                      trailingHint: UnitFormat.e(_controllerValue('protein_goal') * 4),
                    ),
                    _manager.getConfig(
                      'fat_goal',
                      label: Translations.get(lang, 'Grassi'),
                      suffix: UnitFormat.pSigla,
                      dotColor: const Color(0xFFE0A81E),
                      trailingHint: UnitFormat.e(_controllerValue('fat_goal') * 9),
                    ),
                  ],
                ),
                _buildEnergyFromMacrosCard(lang),
                if (_manualMacroEdit) _buildManualEditWarning(lang),
                const SizedBox(height: 12),
                 _buildExpansionSection(
                  title: Translations.get(lang, 'Dettagli Macro'),
                  icon: Icons.details,
                  configs: [
                    _manager.getConfig('fiber_goal', label: Translations.get(lang, 'Fibre'), suffix: UnitFormat.pSigla),
                    _manager.getConfig('sugar_max', label: Translations.get(lang, 'Zuccheri max'), suffix: UnitFormat.pSigla),
                    _manager.getConfig('saturated_fats_goal', label: Translations.get(lang, 'Grassi saturi'), suffix: UnitFormat.pSigla),
                    _manager.getConfig('cholesterol_max', label: Translations.get(lang, 'Colesterolo max'), suffix: 'mg'),
                  ],
                ),
                _buildExpansionSection(
                  title: Translations.get(lang, 'Vitamine'),
                  icon: Icons.health_and_safety,
                  configs: _getVitaminConfigs(),
                ),
                _buildExpansionSection(
                  title: Translations.get(lang, 'Minerali'),
                  icon: Icons.category,
                  configs: _getMineralConfigs(),
                ),
                const SizedBox(height: 30),
                _buildSaveButton(lang),
              ],
            ),
          ),
        ),
        if (_isSaving)
          VeloDiCaricamento(messaggio: Translations.get(lang, 'Salvataggio in corso...')),
      ],
    );
  }

  Widget _buildSection({required String title, required IconData icon, required List<NutrientFieldConfig> configs}) {
    return NutrientGroup(title: title, icon: icon, configs: configs, outlined: true);
  }

  /// "X kg da perdere/guadagnare" fra peso attuale e obiettivo — solo la
  /// direzione reale, nessuna stima di tempo: l'app non ha un ritmo
  /// settimanale di riferimento da cui derivarla (a differenza delle quote
  /// calorie/pasto, che sono gia' una convenzione stabilita altrove).
  Widget _buildWeightDeltaLine(String lang) {
    final current = _controllerValue('current_weight');
    final target = _controllerValue('target_weight');
    if (current <= 0 || target <= 0) return const SizedBox.shrink();

    final delta = ((current - target) * 10).round() / 10;
    final IconData icon;
    final String label;
    if (delta > 0) {
      icon = Icons.trending_down;
      label = '${delta.toStringAsFixed(1)} ${Translations.get(lang, 'goal_weight_lose')}';
    } else if (delta < 0) {
      icon = Icons.trending_up;
      label = '${delta.abs().toStringAsFixed(1)} ${Translations.get(lang, 'goal_weight_gain')}';
    } else {
      icon = Icons.check_circle;
      label = Translations.get(lang, 'goal_weight_at_target');
    }
    // Mockup: solo a target il colore diventa quello primario, altrimenti resta neutro.
    final color = delta == 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontSize: 12.5, color: color)),
        ],
      ),
    );
  }

  /// Barra "energia dai macro" — quanto kcal producono davvero i grammi
  /// inseriti (4/4/9 per carb/proteine/grassi) confrontato con l'obiettivo
  /// calorico, con avviso live se il disallineamento supera una piccola
  /// tolleranza. Stessa soglia gia' avvertita solo al salvataggio
  /// (_getMinRequiredCalories/_saveGoals): qui e' visibile subito, in
  /// entrambe le direzioni, non solo quando le kcal sono insufficienti.
  Widget _buildEnergyFromMacrosCard(String lang) {
    const carbColor = Color(0xFF1B7A33);
    const proteinColor = Color(0xFF4E9A6B);
    const fatColor = Color(0xFFE0A81E);

    final carbs = _controllerValue('carb_goal');
    final protein = _controllerValue('protein_goal');
    final fat = _controllerValue('fat_goal');
    final goal = _controllerValue('calorie_goal');

    final macroKcal = carbs * 4 + protein * 4 + fat * 9;
    if (macroKcal <= 0) return const SizedBox.shrink();

    final diff = macroKcal - goal;
    final tolerance = goal > 0 ? (goal * 0.03).clamp(20, double.infinity) : 20;
    final bool off = goal > 0 && diff.abs() > tolerance;
    final Color balanceColor = off ? const Color(0xFFB77A15) : carbColor;

    final shares = [
      (label: Translations.get(lang, 'Carboidrati'), value: carbs * 4, color: carbColor),
      (label: Translations.get(lang, 'Proteine'), value: protein * 4, color: proteinColor),
      (label: Translations.get(lang, 'Grassi'), value: fat * 9, color: fatColor),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Translations.get(lang, 'goal_energy_from_macros'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                UnitFormat.e(macroKcal),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: balanceColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Row(
                children: shares.map((s) {
                  final frac = macroKcal > 0 ? s.value / macroKcal : 0.0;
                  return Expanded(flex: (frac * 1000).round().clamp(0, 1000000), child: Container(color: s.color));
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            children: shares.map((s) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(s.label, style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              );
            }).toList(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(off ? Icons.info_outline : Icons.check_circle, size: 16, color: balanceColor),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    off
                        ? (diff > 0
                            ? '${UnitFormat.eValore(diff)} ${UnitFormat.conUnita(Translations.get(lang, 'goal_macros_above'))}'
                            : '${UnitFormat.eValore(diff.abs())} ${UnitFormat.conUnita(Translations.get(lang, 'goal_macros_below'))}')
                        : Translations.get(lang, 'goal_macros_match'),
                    style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Avviso "hai modificato i macro a mano" — mockup Goals: compare solo
  /// dopo un tocco diretto su carboidrati/proteine/grassi, sparisce di nuovo
  /// con Auto-balance (vedi _onMacroFieldEdited/_autoBalanceMacros). Prima
  /// questo stesso testo era un banner fisso in cima alla pagina, sempre
  /// visibile anche a pagina appena aperta senza alcuna modifica.
  Widget _buildManualEditWarning(String lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.amber.shade900.withOpacity(0.2) : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.amber.shade700 : Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 19, color: isDark ? Colors.amber.shade400 : Colors.amber.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              Translations.get(lang, 'diet_warning'),
              style: TextStyle(
                color: isDark ? Colors.amber.shade100 : Colors.amber.shade900,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pulsante "Salva" a 3 stati (mockup Goals): non toccato dall'utente →
  /// "Tutti gli obiettivi salvati" (grigio, inerte); toccato e valido →
  /// "Salva obiettivi" (verde, attivo); toccato ma non valido (calorie/pesi
  /// mancanti) → "Controlla i valori sopra" (grigio, inerte).
  Widget _buildSaveButton(String lang) {
    final calorieGoal = _manager.valore('calorie_goal');
    final current = _controllerValue('current_weight');
    final target = _controllerValue('target_weight');
    final motivo = _motivoBlocco(lang, calorieGoal, current, target);
    final canSave = _dirty && motivo == null;

    final String label;
    final IconData icon;
    if (canSave) {
      label = Translations.get(lang, 'goal_save_action');
      icon = Icons.check;
    } else if (!_dirty) {
      label = Translations.get(lang, 'goal_save_all_saved');
      icon = Icons.cloud_done;
    } else {
      label = Translations.get(lang, 'goal_save_check_values');
      icon = Icons.error_outline;
    }

    final scheme = Theme.of(context).colorScheme;
    final pulsante = SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: canSave ? _saveGoals : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canSave ? scheme.primary : scheme.surfaceContainerHighest,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: canSave ? scheme.onPrimary : scheme.onSurfaceVariant,
          disabledForegroundColor: scheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: Icon(icon, size: 21),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
    // Il motivo sotto al pulsante (14/09): con i limiti nuovi i modi di
    // sbagliare sono diversi, e "Controlla i valori sopra" da solo fa cercare
    // a caso quale campo non va.
    if (!_dirty || motivo == null) return pulsante;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pulsante,
        const SizedBox(height: 8),
        Text(
          motivo,
          key: const Key('obiettivi_motivo'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.error),
        ),
      ],
    );
  }

  /// Il primo limite superato, gia' tradotto, o null se si puo' salvare.
  String? _motivoBlocco(String lang, double calorie, double peso, double obiettivo) {
    if (LimitiCorpo.errorePeso(peso) != null) return Translations.get(lang, 'limit_weight');
    final errore = LimitiCorpo.erroreObiettivo(obiettivo, altezzaCm: ref.read(userProvider)?.height);
    if (errore == 'limit_target_bmi') return Translations.get(lang, 'limit_target_bmi');
    if (errore != null) return Translations.get(lang, 'limit_target');
    if (LimitiCorpo.erroreCalorie(calorie) != null) {
      return Translations.get(lang, 'limit_calories')
          .replaceAll('{min}', UnitFormat.e(LimitiCorpo.calorieMin))
          .replaceAll('{max}', UnitFormat.e(LimitiCorpo.calorieMax));
    }
    return null;
  }

  Widget _buildExpansionSection({required String title, required IconData icon, required List<NutrientFieldConfig> configs}) {
     return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(title),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: NutrientGroup(title: '', configs: configs, outlined: true),
          ),
        ],
      ),
    );
  }

  List<NutrientFieldConfig> _getVitaminConfigs() {
    final lang = ref.watch(appSettingsProvider).language;
    return [
      _manager.getConfig('vit_a_goal', label: Translations.get(lang, 'Vitamina A'), suffix: 'µg'),
      _manager.getConfig('vit_b1_goal', label: Translations.get(lang, 'Vitamina B1'), suffix: 'mg'),
      _manager.getConfig('vit_b2_goal', label: Translations.get(lang, 'Vitamina B2'), suffix: 'mg'),
      _manager.getConfig('vit_b3_goal', label: Translations.get(lang, 'Vitamina B3'), suffix: 'mg'),
      _manager.getConfig('vit_b5_goal', label: Translations.get(lang, 'Vitamina B5'), suffix: 'mg'),
      _manager.getConfig('vit_b6_goal', label: Translations.get(lang, 'Vitamina B6'), suffix: 'mg'),
      _manager.getConfig('vit_b7_goal', label: Translations.get(lang, 'Vitamina B7'), suffix: 'µg'),
      _manager.getConfig('vit_b9_goal', label: Translations.get(lang, 'Vitamina B9'), suffix: 'µg'),
      _manager.getConfig('vit_b11_goal', label: Translations.get(lang, 'Vitamina B11'), suffix: 'µg'),
      _manager.getConfig('vit_b12_goal', label: Translations.get(lang, 'Vitamina B12'), suffix: 'µg'),
      _manager.getConfig('vit_c_goal', label: Translations.get(lang, 'Vitamina C'), suffix: 'mg'),
      _manager.getConfig('vit_d_goal', label: Translations.get(lang, 'Vitamina D'), suffix: 'µg'),
      _manager.getConfig('vit_e_goal', label: Translations.get(lang, 'Vitamina E'), suffix: 'mg'),
      _manager.getConfig('vit_k_goal', label: Translations.get(lang, 'Vitamina K'), suffix: 'µg'),
      _manager.getConfig('biotin_goal', label: Translations.get(lang, 'Biotina'), suffix: 'µg'),
    ];
  }

  List<NutrientFieldConfig> _getMineralConfigs() {
    final lang = ref.watch(appSettingsProvider).language;
    return [
      _manager.getConfig('sodium_max', label: Translations.get(lang, 'Sodio'), suffix: 'mg'),
      _manager.getConfig('arsenic_goal', label: Translations.get(lang, 'Arsenico'), suffix: 'µg'),
      _manager.getConfig('boron_goal', label: Translations.get(lang, 'Boro'), suffix: 'mg'),
      _manager.getConfig('calcium_goal', label: Translations.get(lang, 'Calcio'), suffix: 'mg'),
      _manager.getConfig('chloride_goal', label: Translations.get(lang, 'Cloruro'), suffix: 'mg'),
      _manager.getConfig('choline_goal', label: Translations.get(lang, 'Colina'), suffix: 'mg'),
      _manager.getConfig('chromium_goal', label: Translations.get(lang, 'Cromo'), suffix: 'µg'),
      _manager.getConfig('cobalt_goal', label: Translations.get(lang, 'Cobalto'), suffix: 'µg'),
      _manager.getConfig('copper_goal', label: Translations.get(lang, 'Rame'), suffix: 'mg'),
      _manager.getConfig('fluoride_goal', label: Translations.get(lang, 'Fluoruro'), suffix: 'mg'),
      _manager.getConfig('fluorine_goal', label: Translations.get(lang, 'Fluoro'), suffix: 'mg'),
      _manager.getConfig('iodine_goal', label: Translations.get(lang, 'Iodio'), suffix: 'µg'),
      _manager.getConfig('iron_goal', label: Translations.get(lang, 'Ferro'), suffix: 'mg'),
      _manager.getConfig('magnesium_goal', label: Translations.get(lang, 'Magnesio'), suffix: 'mg'),
      _manager.getConfig('manganese_goal', label: Translations.get(lang, 'Manganese'), suffix: 'mg'),
      _manager.getConfig('molybdenum_goal', label: Translations.get(lang, 'Molibdeno'), suffix: 'µg'),
      _manager.getConfig('phosphorus_goal', label: Translations.get(lang, 'Fosforo'), suffix: 'mg'),
      _manager.getConfig('potassium_goal', label: Translations.get(lang, 'Potassio'), suffix: 'mg'),
      _manager.getConfig('selenium_goal', label: Translations.get(lang, 'Selenio'), suffix: 'µg'),
      _manager.getConfig('silicon_goal', label: Translations.get(lang, 'Silicio'), suffix: 'mg'),
      _manager.getConfig('sulfur_goal', label: Translations.get(lang, 'Zolfo'), suffix: 'mg'),
      _manager.getConfig('tin_goal', label: Translations.get(lang, 'Stagno'), suffix: 'mg'),
      _manager.getConfig('vanadium_goal', label: Translations.get(lang, 'Vanadio'), suffix: 'µg'),
      _manager.getConfig('zinc_goal', label: Translations.get(lang, 'Zinco'), suffix: 'mg'),
    ];
  }
}
