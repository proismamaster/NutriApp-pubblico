import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/material.dart';

import '../widgets/auth_style.dart';

import '../logic/unit_format.dart';
import '../services/api_services.dart';
import '../models/daily_summary.dart';
import '../widgets/nutrient_progress_bar.dart';
import 'entry_menu_page.dart';
import 'manual_entry_page.dart';
import '../models/food_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user_provider.dart';
import '../widgets/micronutrient_expansion_panels.dart';
import '../dictionary/translations.dart';
import '../providers/locale_provider.dart';
import '../widgets/modern_loader.dart';
import '../widgets/riga_alimento_diario.dart';
import '../utils/date_labels.dart';

// Stessa convenzione gia' stabilita per la quota % dell'obiettivo calorico
// giornaliero per pasto, condivisa con home_page.dart (_mealShare).
const Map<String, double> _mealFactorByType = {
  'Colazione': 0.25,
  'Pranzo': 0.35,
  'Cena': 0.30,
  'Snack': 0.10,
};
/// Colori per tipo di pasto.
///
/// PERCHE' NON PIU' `Colors.orange`/`Colors.amber` (2026-09-07): erano le
/// tinte Material pure, al massimo della saturazione. Sopra un fondo scuro e
/// spente il giusto dal gradiente diventavano una fascia arancione fluo che,
/// come ha detto Ismail, "stona un sacco con il tema". Queste sono le stesse
/// famiglie di colore (mattino caldo, mezzogiorno verde, sera blu, spuntino
/// ambra) portate al livello di saturazione del resto dell'app.
const Map<String, Color> _mealColorsChiaro = {
  'Colazione': Color(0xFFC97B2E),
  'Pranzo': Color(0xFF3E8E4A),
  'Cena': Color(0xFF3F5C93),
  'Snack': Color(0xFFB98A2E),
};
const Map<String, Color> _mealColorsScuro = {
  'Colazione': Color(0xFF8A5624),
  'Pranzo': Color(0xFF2C6B37),
  'Cena': Color(0xFF32456B),
  'Snack': Color(0xFF806023),
};
Map<String, Color> get _mealColors =>
    Nutri.scuro ? _mealColorsScuro : _mealColorsChiaro;
const Map<String, IconData> _mealIcons = {
  'Colazione': Icons.coffee,
  'Pranzo': Icons.dinner_dining,
  'Cena': Icons.ramen_dining,
  'Snack': Icons.cookie,
};
// Pagina per visualizzare i dettagli di un singolo pasto (Colazione, Pranzo, ecc.)
// Permette di vedere i macronutrienti totali e la lista dei cibi inseriti.
// Ridisegnata 2026-08-23 sul mockup "Meal Detail v2".
class MealDetailPage extends ConsumerStatefulWidget {
  /// Tipo di pasto obbligatorio (Colazione, Pranzo, Cena, Snack)
  final String mealType;

  /// Data opzionale. Default: oggi
  final DateTime? date;

  const MealDetailPage({super.key, required this.mealType, this.date});

  @override
  ConsumerState<MealDetailPage> createState() => MealDetailPageState();
}

class MealDetailPageState extends ConsumerState<MealDetailPage> {
  bool _loading = true;
  List<FoodEntry> _mealEntries = [];
  String? _errorMessage;
  late DateTime _selectedDate;
  DailySummary? _mealSummary;

  /// Vedi la stessa nota in daily_detail_page.dart (fix 2026-07-24): serve a
  /// scartare le risposte obsolete quando si cambia giorno mentre una
  /// richiesta precedente è ancora in volo, altrimenti la risposta vecchia
  /// può arrivare per ultima e rimettere a schermo il giorno sbagliato.
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date ?? DateTime.now();
    _loadMealData();
  }

  Future<void> _loadMealData() async {
    final userEmail = ref.read(userProvider)?.email ?? '';
    if (userEmail.isEmpty) return;
    final DateTime requestedDate = _selectedDate;
    final int token = ++_loadToken;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final summary = await ApiServices.getDailySummary(
        userEmail,
        widget.mealType,
        requestedDate,
      );

      final allEntries = await ApiServices.fetchFoodEntries(
        userEmail,
        da: requestedDate,
        a: requestedDate,
      );
      final filteredEntries = allEntries.where((e) {
        return e.entry_date.year == requestedDate.year &&
            e.entry_date.month == requestedDate.month &&
            e.entry_date.day == requestedDate.day &&
            e.meal_type == widget.mealType;
      }).toList();

      if (!mounted || token != _loadToken) return;

      setState(() {
        _mealSummary = summary;
        _mealEntries = filteredEntries;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Errore caricamento pasto: $e');
      if (!mounted || token != _loadToken) return;
      setState(() {
        _errorMessage = Translations.get(ref.read(appSettingsProvider).language, 'Impossibile caricare i dati. Verifica la rete e riprova.');
        _loading = false;
      });
    }
  }

  Future<void> _eliminaAlimento(int? id) async {
    final lang = ref.read(appSettingsProvider).language;
    final userEmail = ref.read(userProvider)?.email ?? '';
    if (userEmail.isEmpty) return;
    if (id == null) return;
    bool? confermato = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Translations.get(lang, "Elimina")),
        content: Text(Translations.get(lang, "Vuoi eliminare questo alimento?")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(Translations.get(lang, "Annulla")),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(Translations.get(lang, "Elimina"), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confermato == true) {
      setState(() => _loading = true);
      if (await ApiServices.deleteFoodEntries(userEmail, id)) {
        _loadMealData();
      } else {
        setState(() => _loading = false);
      }
    }
  }

  /// Apre la RICERCA, non l'inserimento manuale (2026-09-12).
  ///
  /// Scrivere un alimento da zero e' l'eccezione: la strada normale e'
  /// cercarlo, prenderlo dalle ricette o dai propri alimenti, o scansionare
  /// il codice a barre — tutte cose che stanno in EntryMenuPage, che da li'
  /// porta all'inserimento manuale quando serve davvero. E' la stessa
  /// correzione gia' fatta al "+" dei pasti in Home (punto 16 del backlog),
  /// che qui era rimasta fuori. `comeSchermata: true` fa comparire la freccia
  /// indietro: chiudendo la ricerca si torna al pasto, non alla Home.
  Future<void> _goToAddFood() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryMenuPage(
          initialMealType: widget.mealType,
          comeSchermata: true,
          // Il giorno che si sta guardando, non per forza oggi (17/09).
          dataVoce: _selectedDate,
        ),
      ),
    );
    if (result == true && mounted) _loadMealData();
  }

  Future<void> _scanBarcode() async {
    final lang = ref.read(appSettingsProvider).language;
    try {
      final scanResult = await BarcodeScanner.scan();
      if (scanResult.type != ResultType.Barcode || !mounted) return;

      final product = await ApiServices.fetchProductByBarcode(scanResult.rawContent, lang: lang);
      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => product != null
              ? ManualEntryPage(
                  prefillData: product,
                  initialMealType: widget.mealType,
                  isAddingFromLibrary: true,
                  dataVoce: _selectedDate,
                )
              : ManualEntryPage(
                  barcode: scanResult.rawContent,
                  initialMealType: widget.mealType,
                  dataVoce: _selectedDate,
                ),
        ),
      );
      if (result == true && mounted) _loadMealData();
    } catch (_) {
      // Scansione annullata o fallita: nessun errore da mostrare, l'utente
      // ha semplicemente chiuso lo scanner.
    }
  }

  void _changeDate(DateTime newDate) {
    setState(() => _selectedDate = newDate);
    _loadMealData();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final lang = ref.watch(appSettingsProvider).language;
    final scheme = Theme.of(context).colorScheme;

    final dailyCalorieGoal = user?.calorieGoal ?? 2000.0;
    final dailyCarbGoal = user?.carbGoal ?? 250.0;
    final dailyProteinGoal = user?.proteinGoal ?? 80.0;
    final dailyFatGoal = user?.fatGoal ?? 70.0;

    final mealFactor = _mealFactorByType[widget.mealType] ?? 0.25;
    final mealGoals = {
      'calories': dailyCalorieGoal * mealFactor,
      'carbs': dailyCarbGoal * mealFactor,
      'proteins': dailyProteinGoal * mealFactor,
      'fats': dailyFatGoal * mealFactor,
    };

    final mealMacro = _mealSummary?.totalMacro;
    final totals = {
      'calories': mealMacro?.calories ?? 0.0,
      'carbs': mealMacro?.carbs ?? 0.0,
      'proteins': mealMacro?.proteins ?? 0.0,
      'fats': mealMacro?.fats ?? 0.0,
    };

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          Translations.get(lang, widget.mealType),
          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMealHeader(totals['calories'] ?? 0, mealGoals['calories'] ?? 0),
                  const SizedBox(height: 6),
                  _buildDateNavigator(lang),
                  const SizedBox(height: 10),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: ModernLoader(),
                    )
                  else if (_errorMessage != null)
                    _buildErrorWidget()
                  else
                    _buildMealContent(totals, mealGoals, mealFactor),
                ],
              ),
            ),
          ),
          _buildBottomBar(lang, scheme),
        ],
      ),
    );
  }

  Widget _buildDateNavigator(String lang) {
    final today = DateTime.now();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _chevronButton(Icons.chevron_left, () => _changeDate(_selectedDate.subtract(const Duration(days: 1)))),
        SizedBox(
          width: 160,
          child: Column(
            children: [
              Text(
                shortDateLabel(lang, _selectedDate),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                relativeDayLabel(lang, _selectedDate, today),
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        _chevronButton(Icons.chevron_right, () => _changeDate(_selectedDate.add(const Duration(days: 1)))),
      ],
    );
  }

  Widget _chevronButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Nutri.body),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text(Translations.get(ref.watch(appSettingsProvider).language, 'Riprova')),
            onPressed: _loadMealData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Nutri.greenFill,
              foregroundColor: Nutri.onGreenFill,
            ),
          ),
        ],
      ),
    );
  }

  /// Card colorata in cima con icona/nome/conteggio a sinistra e kcal/target
  /// a destra — sostituisce il vecchio header a icona centrata. Colore per
  /// tipo di pasto gia' stabilito altrove nell'app (home_page.dart),
  /// mantenuto qui invece del gradiente unico e fisso del mockup.
  Widget _buildMealHeader(double kcal, double kcalTarget) {
    final lang = ref.watch(appSettingsProvider).language;
    final bgColor = _mealColors[widget.mealType] ??
        (Nutri.scuro ? const Color(0xFF3A4450) : const Color(0xFF5B6875));
    final mealIcon = _mealIcons[widget.mealType] ?? Icons.restaurant;
    final count = _mealSummary?.intakeCount ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // Alpha piu' alta di prima: le tinte sono gia' spente in partenza,
          // sbiadirle ancora le faceva sparire nel fondo invece di calmarle.
          colors: [bgColor, Color.alphaBlend(Nutri.bg.withValues(alpha: .35), bgColor)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .24),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(mealIcon, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Translations.get(lang, widget.mealType),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -.3),
                ),
                const SizedBox(height: 3),
                Text(
                  count == 0
                      ? Translations.get(lang, 'Nessun alimento inserito.')
                      : '$count ${Translations.get(lang, 'alimenti')}',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                UnitFormat.eValore(kcal),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -.8),
              ),
              Text(
                '/ ${UnitFormat.e(kcalTarget)}',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealContent(Map<String, double> totals, Map<String, double> mealGoals, double mealFactor) {
    final lang = ref.watch(appSettingsProvider).language;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  Translations.get(lang, 'Alimenti'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Material(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _goToAddFood,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 7, 15, 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 19, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          Translations.get(lang, 'nav_add'),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_mealEntries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant, width: 1.5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Icon(Icons.restaurant, size: 30, color: scheme.outline),
                  const SizedBox(height: 8),
                  Text(
                    Translations.get(lang, 'Nessun alimento inserito.'),
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  // Mockup: l'invito riprende le kcal previste per QUESTO
                  // pasto, non un testo generico uguale ovunque.
                  Text(
                    '${Translations.get(lang, 'meal_empty_hint_prefix')} '
                    '${UnitFormat.e(mealGoals['calories'] ?? 0)} '
                    '${Translations.get(lang, 'meal_empty_hint_suffix')} '
                    '${Translations.get(lang, widget.mealType).toLowerCase()}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant.withValues(alpha: .8)),
                  ),
                ],
              ),
            )
          else
            ..._mealEntries.map((e) => _buildFoodRow(e, scheme)),
          const SizedBox(height: 24),

          Text(
            Translations.get(lang, 'Riepilogo Nutrizionale'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NutrientProgressBar(
                  label: Translations.get(lang, 'Calorie'),
                  currentValue: totals['calories'] ?? 0.0,
                  goalValue: mealGoals['calories'] ?? 500,
                  color: scheme.primary,
                  unit: 'kcal',
                ),
                NutrientProgressBar(
                  label: Translations.get(lang, 'Carboidrati'),
                  currentValue: totals['carbs'] ?? 0.0,
                  goalValue: mealGoals['carbs'] ?? 100,
                  color: Colors.orange,
                ),
                NutrientProgressBar(
                  label: Translations.get(lang, 'Proteine'),
                  currentValue: totals['proteins'] ?? 0.0,
                  goalValue: mealGoals['proteins'] ?? 30,
                  color: Colors.green,
                ),
                NutrientProgressBar(
                  label: Translations.get(lang, 'Grassi'),
                  currentValue: totals['fats'] ?? 0.0,
                  goalValue: mealGoals['fats'] ?? 20,
                  color: Colors.brown,
                ),
              ],
            ),
          ),

          if (_mealSummary != null) ...[
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: .4),
                borderRadius: BorderRadius.circular(18),
              ),
              child: MicronutrientExpansionPanels(
                user: ref.watch(userProvider),
                sourceSummary: _mealSummary,
                factor: mealFactor,
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // La stessa riga del dettaglio del giorno (17/09): tocco per vedere, matita
  // per modificare pasto e peso nella scheda del prodotto, cestino.
  Widget _buildFoodRow(FoodEntry entry, ColorScheme scheme) => RigaAlimentoDiario(
        voce: entry,
        lang: ref.read(appSettingsProvider).language,
        onCambiata: _loadMealData,
        onElimina: () => _eliminaAlimento(entry.id),
      );

  Widget _buildBottomBar(String lang, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _goToAddFood,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, size: 22, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        Translations.get(lang, 'meal_add_food'),
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _scanBarcode,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.primary.withValues(alpha: .4), width: 1.5),
                ),
                child: Icon(Icons.qr_code_scanner, size: 23, color: scheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
