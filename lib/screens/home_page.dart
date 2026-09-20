import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

import '../logic/limiti_corpo.dart';
import '../logic/unit_format.dart';
import 'package:nutriapp/models/daily_summary.dart';
import 'package:nutriapp/models/food_entry.dart';
import 'package:nutriapp/models/physical_measurement.dart';
import 'daily_detail_page.dart';
import 'manual_entry_page.dart';
import 'entry_menu_page.dart';
import 'meal_detail_page.dart';
import '../widgets/day_selector.dart';
import '../widgets/calorie_ring.dart';
import '../widgets/meal_tile.dart';
import '../widgets/day_quality_row.dart';
import '../services/api_services.dart';
import 'calendar_page.dart';
import 'graphic_page.dart';
import 'recipe_list_page.dart';
import '../widgets/nutrient_progress_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user_provider.dart';
import '../providers/locale_provider.dart';
import '../dictionary/translations.dart';
import '../widgets/modern_loader.dart';

// Quota % dell'obiettivo calorico giornaliero per pasto — nessun target
// per-pasto reale esiste nel profilo utente. STESSA convenzione gia'
// stabilita in meal_detail_page.dart (non quella del mockup Home Final,
// che aveva assunto 30/35/25/10 senza sapere che l'app ne aveva gia' una).
const Map<String, double> _mealShare = {
  'Colazione': 0.25,
  'Pranzo': 0.35,
  'Cena': 0.30,
  'Snack': 0.10,
};
const Map<String, IconData> _mealIcons = {
  'Colazione': Icons.coffee,
  'Pranzo': Icons.dinner_dining,
  'Cena': Icons.ramen_dining,
  'Snack': Icons.cookie,
};

// Schermata principale dell'app
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  final int _selectedTabIndex = 0;
  bool _isLoading = true;
  bool _senzaRete = false;
  int _loadToken = 0;

  double carbs = 0.0;
  double proteins = 0.0;
  double fats = 0.0;
  double totalCalories = 0.0;
  DateTime _selectedDate = DateTime.now();

  DailySummary? _summary;
  List<FoodEntry> _allEntries = [];
  List<PhysicalMeasurement> _weightHistory = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll({bool silent = false}) async {
    final user = ref.read(userProvider);
    if (user == null) return;
    if (!silent) setState(() => _isLoading = true);
    // Come nel dettaglio giornaliero: cambiando giorno in fretta la risposta
    // vecchia poteva arrivare per ultima e rimettere i totali del giorno
    // sbagliato (test di release 19/09).
    final int token = ++_loadToken;

    final results = await Future.wait([
      ApiServices.getDailySummary(user.email, "", _selectedDate),
      // Solo il giorno mostrato: la Home usa le voci per i riquadri dei
      // pasti, non per lo storico (test di release 19/09).
      ApiServices.fetchFoodEntries(user.email, da: _selectedDate, a: _selectedDate),
      ApiServices.fetchPhysicalMeasurements(user.email),
    ]);

    if (!mounted || token != _loadToken) return;
    final summary = results[0] as DailySummary?;
    setState(() {
      // Server irraggiungibile: la Home mostrava "0 kcal assunte" come se non
      // si fosse mangiato niente (test di release 19/09).
      _senzaRete = summary == null;
      _summary = summary;
      _allEntries = results[1] as List<FoodEntry>;
      _weightHistory = results[2] as List<PhysicalMeasurement>;
      if (summary != null) {
        carbs = summary.totalMacro.carbs;
        proteins = summary.totalMacro.proteins;
        fats = summary.totalMacro.fats;
        totalCalories = summary.totalMacro.calories;
      }
      _isLoading = false;
    });
  }

  List<FoodEntry> _entriesForSelectedMeal(String mealType) {
    return _allEntries.where((e) {
      return e.entry_date.year == _selectedDate.year &&
          e.entry_date.month == _selectedDate.month &&
          e.entry_date.day == _selectedDate.day &&
          e.meal_type == mealType;
    }).toList();
  }

  double _kcalForMeal(String mealType) {
    return _entriesForSelectedMeal(
      mealType,
    ).fold(0.0, (sum, e) => sum + e.macro.calories);
  }

  int get _mealsLoggedTodayCount => _allEntries
      .where(
        (e) =>
            e.entry_date.year == _selectedDate.year &&
            e.entry_date.month == _selectedDate.month &&
            e.entry_date.day == _selectedDate.day,
      )
      .length;

  Future<void> _updateWeight(double delta) async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final newWeight = double.parse(
      (user.currentWeight + delta).toStringAsFixed(1),
    );
    // Fuori dai limiti non si chiede nemmeno al server: il pulsante +/- non
    // deve portare il peso dove la registrazione non lo ammetterebbe.
    final limite = LimitiCorpo.errorePeso(newWeight);
    if (limite != null) {
      final lang = ref.read(appSettingsProvider).language;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Translations.get(lang, limite)), backgroundColor: Colors.red),
      );
      return;
    }

    // Solo il peso (15/09): con updateGoals partivano anche gli obiettivi, e
    // un peso obiettivo vecchio fuori limite faceva rifiutare tutto.
    final error = await ref.read(userProvider.notifier).updateWeight(newWeight);

    // Oltre allo scalare sul profilo (sopra, invariato), registriamo anche
    // una misurazione datata: senza uno storico il trend a 7 giorni non è
    // calcolabile. fetchPhysicalMeasurements/savePhysicalMeasurement
    // esistevano già in ApiServices ma non erano mai stati collegati a
    // nessuna UI (richiesta 2026-08-23, mockup Home Final).
    if (error == null) {
      await ApiServices.savePhysicalMeasurement(
        PhysicalMeasurement(date: DateTime.now(), weight: newWeight),
        user.email,
      );
    }
    final history = await ApiServices.fetchPhysicalMeasurements(user.email);

    if (!mounted) return;
    setState(() => _weightHistory = history);

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  static bool _stessoGiorno(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Il peso che valeva nel giorno mostrato: l'ultima pesata registrata fino a
  /// quel giorno compreso. Senza pesate di quel periodo resta [diProfilo].
  ///
  /// Prima qui c'era sempre il peso di oggi, quindi cambiarlo riscriveva anche
  /// i giorni gia' passati (richiesta di Ismail, 20/09).
  double _pesoDelGiorno(double diProfilo) {
    final giorno = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    double? trovato;
    DateTime? quando;
    for (final m in _weightHistory) {
      final d = DateTime(m.date.year, m.date.month, m.date.day);
      if (d.isAfter(giorno)) continue;
      if (quando == null || d.isAfter(quando)) {
        quando = d;
        trovato = m.weight;
      }
    }
    return trovato ?? diProfilo;
  }

  /// Differenza di peso fra oggi e la misurazione più vicina a 7 giorni fa.
  /// null se non c'è abbastanza storico (serve almeno una misurazione
  /// precedente) — mostrare un trend inventato è peggio che non mostrarlo.
  double? _weightTrendKg(double currentWeight) {
    if (_weightHistory.isEmpty) return null;
    final target = DateTime.now().subtract(const Duration(days: 7));
    PhysicalMeasurement? closest;
    Duration? bestDiff;
    for (final m in _weightHistory) {
      if (!m.date.isBefore(target.subtract(const Duration(days: 1)))) continue;
      final diff = m.date.difference(target).abs();
      if (bestDiff == null || diff < bestDiff) {
        bestDiff = diff;
        closest = m;
      }
    }
    if (closest == null) return null;
    return double.parse((currentWeight - closest.weight).toStringAsFixed(1));
  }

  Future<void> _scanBarcode() async {
    try {
      final scanResult = await BarcodeScanner.scan();
      if (scanResult.type != ResultType.Barcode || !mounted) return;

      final currentLang = ref.read(appSettingsProvider).language;
      final product = await ApiServices.fetchProductByBarcode(
        scanResult.rawContent,
        lang: currentLang,
        userMail: ref.read(userProvider)?.email ?? '',
      );
      if (!mounted) return;

      if (product != null) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ManualEntryPage(
              prefillData: product,
              isAddingFromLibrary: true,
            ),
          ),
        );
        if (result == true && mounted) _loadAll(silent: true);
      } else {
        final register = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(Translations.get(currentLang, 'search_not_found')),
            content: Text(Translations.get(currentLang, 'barcode_not_found_msg')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(Translations.get(currentLang, 'Annulla')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(Translations.get(currentLang, 'search_manual_link_2')),
              ),
            ],
          ),
        );
        if (register == true && mounted) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ManualEntryPage(barcode: scanResult.rawContent),
            ),
          );
          if (result == true && mounted) _loadAll(silent: true);
        }
      }
    } catch (e) {
      if (mounted) {
        // Fotocamera negata e rete assente sono due problemi diversi: prima
        // chi negava il permesso leggeva "Controlla la rete" (19/09).
        final negata = e is PlatformException && e.code == BarcodeScanner.cameraAccessDenied;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Translations.get(
              ref.read(appSettingsProvider).language,
              negata ? 'camera_permission_denied' : 'search_error_network',
            )),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _getSelectedPage() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const CalendarioPage();
      case 2:
        return const GraphicPage();
      case 3:
        return const RecipeListaPage();
      default:
        return _buildHomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userProvider, (previous, next) {
      if (previous != next) {
        _loadAll(silent: true);
      }
    });

    return Scaffold(
      body: _isLoading ? const ModernLoader() : _getSelectedPage(),
    );
  }

  Widget _buildHomeContent() {
    final user = ref.watch(userProvider);
    final lang = ref.watch(appSettingsProvider).language;
    final scheme = Theme.of(context).colorScheme;

    final double calorieGoal = user?.calorieGoal ?? 2000;
    final double currentRemainingCalories = calorieGoal - totalCalories;
    final double calorieFraction = (calorieGoal > 0)
        ? (totalCalories / calorieGoal)
        : 0;
    final bool isOverGoal = totalCalories > calorieGoal;

    // Il peso DI QUEL GIORNO, non quello di oggi: cambiando il peso oggi si
    // riscriveva anche il passato, e un giorno gia' chiuso deve restare com'e'
    // (richiesta di Ismail, 20/09). Si tocca solo il peso di oggi.
    final double currentWeight = _pesoDelGiorno(user?.currentWeight ?? 70.0);
    final bool pesoModificabile = _stessoGiorno(_selectedDate, DateTime.now());
    final double? trend = _weightTrendKg(currentWeight);
    final bool trendDown = (trend ?? 0) <= 0;

    final contenuto = Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saluto rimosso il 2026-08-30 su richiesta di Ismail (punto 12 del
            // backlog): occupava una riga intera piu' 16px di margine per
            // ripetere un nome che l'utente conosce gia', spingendo i pasti
            // sotto la piega. Lo spazio recuperato serve a far stare tutto a
            // schermo senza scorrere.
            // Il giorno che si sta guardando e' un comando, non contenuto:
            // staccato dal resto da una superficie sua e da un filo d'ombra,
            // perche' attaccato al cerchio delle calorie sembrava tutt'uno
            // (richiesta di Ismail, 20/09).
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: .6)),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: .06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DaySelector(
                date: _selectedDate,
                onDateChanged: (newDate) {
                  setState(() => _selectedDate = newDate);
                  _loadAll(silent: true);
                },
              ),
            ),
            ..._respiro(16),

            // Senza rete i numeri qui sotto sono quelli dell'ultimo
            // caricamento riuscito, o zeri: va detto.
            if (_senzaRete) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 18, color: scheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        Translations.get(lang, 'offline_banner'),
                        style: TextStyle(fontSize: 12.5, color: scheme.onErrorContainer),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _loadAll(),
                      child: Text(Translations.get(lang, 'Riprova')),
                    ),
                  ],
                ),
              ),
              ..._respiro(12),
            ],

            // ========== CALORIE E MACRONUTRIENTI ==========
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CalorieRing(
                  fraction: calorieFraction.toDouble(),
                  isOverGoal: isOverGoal,
                  centerValue: UnitFormat.eValore(currentRemainingCalories.abs()),
                  // Sigla nel testo tradotto (18/09): prima diceva sempre
                  // "kcal", anche sotto un numero in kJ.
                  centerLabel: UnitFormat.conUnita(isOverGoal
                      ? Translations.get(lang, 'home_eccesso')
                      : Translations.get(lang, 'home_rimanenti')),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${UnitFormat.eValore(totalCalories)} ${UnitFormat.conUnita(Translations.get(lang, 'home_assunte'))}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      NutrientProgressBar(
                        label: Translations.get(lang, 'Carboidrati'),
                        currentValue: carbs,
                        goalValue: user?.carbGoal ?? 0,
                        color: Colors.orange,
                        unit: 'g',
                      ),
                      NutrientProgressBar(
                        label: Translations.get(lang, 'Proteine'),
                        currentValue: proteins,
                        goalValue: user?.proteinGoal ?? 0,
                        color: Colors.green,
                        unit: 'g',
                      ),
                      NutrientProgressBar(
                        label: Translations.get(lang, 'Grassi'),
                        currentValue: fats,
                        goalValue: user?.fatGoal ?? 0,
                        color: Colors.brown,
                        unit: 'g',
                      ),
                      // Mockup Home Final: il link "Dettagli" vive qui, sotto
                      // le barre macro (non accanto al selettore di giorno,
                      // dov'era prima).
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    DailyDetailPage(initialDate: _selectedDate),
                              ),
                            );
                            // Dal dettaglio si eliminano e si modificano voci:
                            // tornando indietro la Home mostrava i totali di
                            // prima (test di release 19/09).
                            if (mounted) _loadAll(silent: true);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  Translations.get(lang, 'home_details_link'),
                                  style: TextStyle(
                                    color: scheme.primary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Icon(Icons.chevron_right, size: 16, color: scheme.primary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ..._respiro(12),

            DayQualityRow(summary: _summary),
            ..._respiro(18, flex: 2),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Translations.get(lang, 'home_add_food'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  _mealsLoggedTodayCount == 0
                      ? Translations.get(lang, 'home_meals_summary_empty')
                      : '$_mealsLoggedTodayCount ${Translations.get(lang, _mealsLoggedTodayCount == 1 ? 'home_items_logged_one' : 'home_items_logged_many')}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            ..._respiro(10),
            // Due righe da due al posto di GridView (14/09): una GridView non
            // sa dire quanto e' alta senza essere disegnata, e la Home ora
            // deve misurarsi per riempire lo schermo (vedi _RiempiSchermo).
            _righeDaDue(
              key: const Key('home_pasti'),
              tessere: _mealShare.entries.map((share) {
                final mealKey = share.key;
                final eaten = _kcalForMeal(mealKey);
                final target = calorieGoal * share.value;
                return MealTile(
                  label: Translations.get(lang, mealKey),
                  icon: _mealIcons[mealKey]!,
                  eatenKcal: eaten,
                  targetKcal: target,
                  hasEntries: eaten > 0,
                  // Punto 17 + decisione D1 (2026-08-30): il dettaglio di un
                  // pasto apre MealDetailPage, che era ridisegnata sui mockup
                  // dal 23/08 ma IRRAGGIUNGIBILE — nessuna riga di lib/ la
                  // apriva. Ha gia' in fondo il pulsante di scansione barcode
                  // chiesto al punto 17, quindi collegarla chiude entrambi i
                  // punti senza scrivere UI nuova. DailyDetailPage resta
                  // raggiungibile dal calendario, dove mostra il giorno intero.
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MealDetailPage(
                          mealType: mealKey,
                          date: _selectedDate,
                        ),
                      ),
                    );
                    // Ricarica SEMPRE, non solo se la pagina del pasto
                    // restituisce true (2026-09-12): da li' si esce anche
                    // con la freccia o col gesto di sistema, che non
                    // restituiscono niente, e la Home restava coi numeri di
                    // prima dopo aver aggiunto o cancellato un alimento.
                    if (mounted) _loadAll(silent: true);
                  },
                  // Punto 16 del backlog: il "+" apre la RICERCA, non
                  // l'inserimento manuale. Scrivere un alimento da zero e'
                  // l'eccezione, non il caso normale — e EntryMenuPage accetta
                  // gia' il pasto di partenza.
                  onAdd: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EntryMenuPage(
                          initialMealType: mealKey,
                          comeSchermata: true,
                          dataVoce: _selectedDate,
                        ),
                      ),
                    );
                    if (mounted) _loadAll(silent: true);
                  },
                );
              }).toList(),
            ),
            ..._respiro(10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _scanBarcode,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: .4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner, size: 20, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        Translations.get(lang, 'home_scan_barcode'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ..._respiro(18, flex: 2),

            // ========== PESO ATTUALE ==========
            Container(
              key: const Key('home_peso'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  _weightRoundButton(
                    context,
                    Icons.remove,
                    () => _updateWeight(-0.1),
                    filled: false,
                    attivo: pesoModificabile,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              currentWeight.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                                letterSpacing: -.7,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              // Sigla dal dizionario: in cinese e arabo
                              // restava "kg" (test di release 19/09).
                              Translations.get(lang, 'kg'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (trend != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: trendDown
                                  ? scheme.primary.withValues(alpha: .12)
                                  : scheme.error.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  trendDown ? Icons.trending_down : Icons.trending_up,
                                  size: 15,
                                  color: trendDown ? scheme.primary : scheme.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${trend.abs().toStringAsFixed(1)} ${Translations.get(lang, 'kg')} · ${Translations.get(lang, 'home_weight_period')}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: trendDown ? scheme.primary : scheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  _weightRoundButton(
                    context,
                    Icons.add,
                    () => _updateWeight(0.1),
                    filled: true,
                    attivo: pesoModificabile,
                  ),
                ],
              ),
            ),
          ],
      ),
    );

    // Home a tutto schermo (punto 12 del backlog, rifatto il 14/09).
    //
    // Due difetti di fila con la stessa causa: la Home si ADATTAVA in un verso
    // solo. `FittedBox(scaleDown)` su uno schermo corto rimpiccioliva tutto in
    // proporzione — quindi si stringeva anche in larghezza e lasciava due
    // fasce vuote ai lati — e su uno schermo alto restava a misura naturale
    // con un vuoto in fondo. Ismail: "dovrebbe riempire tutto lo schermo
    // adattandosi al telefono, altrimenti non e' in linea con le altre
    // schermate", senza mai dover scorrere.
    //
    // Ora [_RiempiSchermo] misura l'altezza naturale del contenuto. Se ci sta,
    // gli da' tutta l'altezza e lo spazio in piu' va nei respiri fra le sezioni
    // ([_respiro]). Se non ci sta, lo rimpicciolisce MA gli da' una larghezza
    // maggiorata della stessa proporzione: una volta ridotto torna a coprire
    // tutta la larghezza. Lo scorrimento resta solo per il gesto di ricarica.
    return RefreshIndicator(
      onRefresh: () => _loadAll(silent: true),
      child: LayoutBuilder(
        builder: (context, vincoli) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          // Larghezza e altezza esplicite: dentro lo scroll l'altezza sarebbe
          // illimitata, e RefreshIndicator passa vincoli larghi (il difetto
          // del 12/09 sul telefono di un amico).
          child: SizedBox(
            width: vincoli.maxWidth,
            height: vincoli.maxHeight,
            child: _RiempiSchermo(child: contenuto),
          ),
        ),
      ),
    );
  }

  /// Spazio fra due sezioni della Home: almeno [minimo], di piu' se lo schermo
  /// avanza. Lo `Spacer` non conta nell'altezza naturale misurata da
  /// [_RiempiSchermo], quindi su uno schermo corto resta solo il minimo.
  List<Widget> _respiro(double minimo, {int flex = 1}) => [
        SizedBox(height: minimo),
        Spacer(flex: flex),
      ];

  /// Le tessere dei pasti due per riga, alte uguali.
  Widget _righeDaDue({Key? key, required List<Widget> tessere}) {
    Widget tessera(Widget figlio) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 104),
          child: figlio,
        );
    return Column(
      key: key,
      children: [
        for (var i = 0; i < tessere.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tessera(tessere[i])),
                const SizedBox(width: 10),
                Expanded(child: i + 1 < tessere.length ? tessera(tessere[i + 1]) : const SizedBox()),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _weightRoundButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap, {
    required bool filled,
    bool attivo = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: attivo && filled ? scheme.primaryContainer : Colors.transparent,
      shape: CircleBorder(
        side: BorderSide(
          color: !attivo
              ? scheme.outlineVariant.withValues(alpha: .5)
              : filled
                  ? scheme.primary.withValues(alpha: .4)
                  : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: attivo ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(
            icon,
            size: 20,
            color: !attivo
                ? scheme.onSurfaceVariant.withValues(alpha: .4)
                : filled
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Fa riempire alla Home esattamente il riquadro che riceve (14/09).
///
/// Se l'altezza naturale del contenuto ci sta, il contenuto riceve tutto il
/// riquadro e i suoi `Spacer` si allargano. Se non ci sta, viene disegnato
/// rimpicciolito di `altezza / naturale`, ma impaginato in un riquadro piu'
/// GRANDE della stessa proporzione: ridotto, copre di nuovo larghezza e
/// altezza. Un `FittedBox` fa solo la prima meta' (rimpicciolire), e lasciava
/// le fasce vuote ai lati.
class _RiempiSchermo extends SingleChildRenderObjectWidget {
  const _RiempiSchermo({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderRiempiSchermo();
}

class _RenderRiempiSchermo extends RenderProxyBox {
  double _scala = 1;

  Matrix4 get _trasformazione => Matrix4.diagonal3Values(_scala, _scala, 1);

  @override
  void performLayout() {
    size = constraints.biggest;
    final figlio = child;
    if (figlio == null) return;
    final naturale = figlio.getMaxIntrinsicHeight(size.width);
    _scala = naturale <= size.height || naturale <= 0 ? 1 : size.height / naturale;
    figlio.layout(BoxConstraints.tightFor(width: size.width / _scala, height: size.height / _scala));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (_scala == 1) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _trasformazione,
      super.paint,
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final figlio = child;
    if (figlio == null) return false;
    return result.addWithPaintTransform(
      transform: _trasformazione,
      position: position,
      hitTest: (risultato, punto) => figlio.hitTest(risultato, position: punto),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_trasformazione);
  }
}
