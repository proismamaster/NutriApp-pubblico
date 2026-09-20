import 'package:flutter/material.dart';

import '../widgets/day_selector.dart';
import '../services/api_services.dart';
import '../models/daily_summary.dart';
import '../models/food_entry.dart';
import '../widgets/nutrient_progress_bar.dart';
import 'entry_menu_page.dart';
import '../widgets/riga_alimento_diario.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user_provider.dart';
import '../widgets/micronutrient_expansion_panels.dart';
import '../widgets/nutri_select.dart';
import '../dictionary/translations.dart';
import '../widgets/state_message.dart';
import '../providers/locale_provider.dart';

class DailyDetailPage extends ConsumerStatefulWidget {
  final String? initialMeal;
  final DateTime? initialDate;

  const DailyDetailPage({super.key, this.initialMeal, this.initialDate});

  @override
  ConsumerState<DailyDetailPage> createState() => DailyDetailPageState();
}

class DailyDetailPageState extends ConsumerState<DailyDetailPage> {
  bool _loading = true;
  bool _erroreRete = false;

  late DateTime _selectedDate;
  late String _currentMeal;

  DailySummary? _dailySummary;
  DailySummary? _mealSummary;

  // Elenco dei singoli alimenti per il pasto scelto
  List<FoodEntry> _mealEntries = [];

  /// Tutte le voci del giorno mostrato: cambiando pasto si filtra questa
  /// lista invece di richiederla di nuovo al server (20/09).
  List<FoodEntry> _vociGiorno = [];

  String _micronScope = 'Giornaliero';

  /// Contatore delle richieste in corso (fix 2026-07-24). Ogni caricamento
  /// incrementa il contatore e, quando la risposta arriva, la scarta se nel
  /// frattempo ne è partita un'altra. Senza questo, cambiando giorno in
  /// fretta (o cambiando giorno mentre il caricamento precedente è ancora in
  /// volo) la risposta VECCHIA poteva arrivare per ultima e sovrascrivere
  /// quella nuova: a schermo restavano i dati del giorno sbagliato, cioè
  /// esattamente il sintomo "cambio giorno e non cambia niente".
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _currentMeal = widget.initialMeal ?? 'Colazione';
    _loadEntriesForDay(mealType: _currentMeal);
  }

  /// Carica quello che serve per il giorno e il pasto mostrati.
  ///
  /// Con [soloPasto] a true cambia soltanto il pasto: il giorno e' lo stesso,
  /// quindi il riepilogo giornaliero e le voci del giorno restano quelli che
  /// abbiamo gia' e parte UNA sola richiesta (i totali di quel pasto) invece
  /// di tre. Prima passare da Colazione a Pranzo ricaricava l'intera giornata
  /// e la pagina sbiancava (richiesta di Ismail, 20/09).
  Future<void> _loadEntriesForDay({String? mealType, bool soloPasto = false}) async {
    final type = (mealType ?? _currentMeal);
    // La data viene "congelata" qui: se l'utente la cambia mentre la
    // richiesta è in volo, questa risposta verrà comunque scartata dal
    // controllo sul token, ma intanto filtriamo sulla data giusta.
    final DateTime requestedDate = _selectedDate;
    final int token = ++_loadToken;

    final userEmail = ref.read(userProvider)?.email ?? '';
    if (userEmail.isEmpty) return; // Blocca tutto se non sei loggato

    // Cambiando pasto le voci ci sono gia': si mostrano subito quelle, senza
    // far sparire la pagina dietro una rotella.
    if (soloPasto) {
      setState(() => _mealEntries = _vociDelPasto(type, requestedDate));
    } else {
      setState(() => _loading = true);
    }

    try {
      // Il riepilogo del pasto cambia sempre: e' l'unica cosa che serve
      // davvero quando si passa da un pasto all'altro.
      final mealSummary = await ApiServices.getDailySummary(
        userEmail,
        type,
        requestedDate,
      );

      DailySummary? daySummary = _dailySummary;
      List<FoodEntry> vociGiorno = _vociGiorno;
      if (!soloPasto) {
        daySummary = await ApiServices.getDailySummary(
          userEmail,
          'day',
          requestedDate,
        );
        vociGiorno = await ApiServices.fetchFoodEntries(
          userEmail,
          da: requestedDate,
          a: requestedDate,
        );
      }

      // Risposta obsoleta (ne è partita un'altra nel frattempo) o pagina
      // già chiusa: non tocchiamo lo stato.
      if (!mounted || token != _loadToken) return;

      setState(() {
        _mealSummary = mealSummary;
        _dailySummary = daySummary;
        _vociGiorno = vociGiorno;
        _mealEntries = _vociDelPasto(type, requestedDate);
        // Server irraggiungibile: senza questo la pagina mostrava zeri come
        // se la giornata fosse vuota (test di release 19/09).
        _erroreRete = mealSummary == null && daySummary == null;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Errore caricamento dettagli: $e");
      if (!mounted || token != _loadToken) return;
      setState(() {
        _erroreRete = true;
        _loading = false;
      });
    }
  }

  /// Le voci di quel pasto in quel giorno, prese da quelle gia' scaricate.
  List<FoodEntry> _vociDelPasto(String pasto, DateTime giorno) {
    return _vociGiorno
        .where((e) =>
            e.entry_date.year == giorno.year &&
            e.entry_date.month == giorno.month &&
            e.entry_date.day == giorno.day &&
            e.meal_type == pasto)
        .toList();
  }

  // Funzione per rimuovere un alimento
  Future<void> _eliminaPasto(int? id) async {
    final lang = ref.read(appSettingsProvider).language;
    final userEmail = ref.read(userProvider)?.email ?? '';
    if (userEmail.isEmpty) return; // Blocca tutto se non sei loggato
    if (id == null) return;

    bool confermato = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Translations.get(lang, "Conferma")),
        content: Text(Translations.get(lang, "Vuoi davvero eliminare questo alimento?")),
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

    if (confermato) {
      setState(() => _loading = true);
      bool success = await ApiServices.deleteFoodEntries(userEmail, id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Translations.get(lang, "Alimento eliminato")),
            backgroundColor: Colors.green,
          ),
        );
        _loadEntriesForDay(); // Ricarica dati e grafici
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Translations.get(lang, "Errore durante l'eliminazione")),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Riga del singolo alimento: la stessa del dettaglio del pasto (17/09).
  Widget _buildAlimentoItem(FoodEntry entry, String lang) => RigaAlimentoDiario(
        voce: entry,
        lang: lang,
        onCambiata: _loadEntriesForDay,
        onElimina: () => _eliminaPasto(entry.id),
      );

  /// "+" del pasto scelto (17/09): la ricerca, sul giorno che si sta guardando.
  Future<void> _aggiungiAlimento() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryMenuPage(
          initialMealType: _currentMeal,
          comeSchermata: true,
          dataVoce: _selectedDate,
        ),
      ),
    );
    if (mounted) _loadEntriesForDay();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    final user = ref.watch(userProvider);
    
    // Daily Goals
    final dailyCalorieGoal = user?.calorieGoal ?? 2000.0;
    final dailyCarbGoal = user?.carbGoal ?? 250.0;
    final dailyProteinGoal = user?.proteinGoal ?? 80.0;
    final dailyFatGoal = user?.fatGoal ?? 70.0;

    // Meal Goals Distribution
    double mealFactor = 0.25; // Colazione
    if (_currentMeal == 'Pranzo') {
      mealFactor = 0.35;
    } else if (_currentMeal == 'Cena') {
      mealFactor = 0.30;
    } else if (_currentMeal == 'Snack') {
      mealFactor = 0.10;
    }

    final mealCalorieGoal = dailyCalorieGoal * mealFactor;
    final mealCarbGoal = dailyCarbGoal * mealFactor;
    final mealProteinGoal = dailyProteinGoal * mealFactor;
    final mealFatGoal = dailyFatGoal * mealFactor;

    final mealMacro = _mealSummary?.totalMacro;
    final totals = {
      'calories': mealMacro?.calories ?? 0.0,
      'carbs': mealMacro?.carbs ?? 0.0,
      'proteins': mealMacro?.proteins ?? 0.0,
      'fats': mealMacro?.fats ?? 0.0,
    };

    final dayMacro = _dailySummary?.totalMacro;
    final dayTotals = {
      'calories': dayMacro?.calories ?? 0.0,
      'carbs': dayMacro?.carbs ?? 0.0,
      'proteins': dayMacro?.proteins ?? 0.0,
      'fats': dayMacro?.fats ?? 0.0,
    };

    final mealButtons = <Map<String, dynamic>>[
      {'label': 'Colazione', 'enabled': true},
      {'label': 'Pranzo', 'enabled': true},
      {'label': 'Cena', 'enabled': true},
      {'label': 'Snack', 'enabled': true},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          Translations.get(lang, 'Dettaglio Giornaliero'),
          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DaySelector(
              date: _selectedDate,
              onDateChanged: (newDate) {
                setState(() => _selectedDate = newDate);
                _loadEntriesForDay();
              },
            ),
            const SizedBox(height: 16),

            if (_loading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                ),
              ),

            // Niente rete: si dice, invece di mostrare una giornata a zero.
            if (!_loading && _erroreRete)
              StateMessage(
                icon: Icons.wifi_off_rounded,
                title: Translations.get(lang, 'Errore di connessione'),
                actionLabel: Translations.get(lang, 'Riprova'),
                onPressed: _loadEntriesForDay,
              ),

            if (!_loading && !_erroreRete) ...[
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Translations.get(lang, 'OBIETTIVO GIORNALIERO'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      NutrientProgressBar(
                        label: Translations.get(lang, 'Calorie'),
                        currentValue: dayTotals['calories'] ?? 0.0,
                        goalValue: dailyCalorieGoal,
                        // Verde come nel dettaglio del pasto: il rosso fisso
                        // faceva sembrare sforato anche un giorno sotto
                        // obiettivo (test di release 19/09). Il rosso lo mette
                        // gia' la barra quando si supera l'obiettivo.
                        color: Theme.of(context).colorScheme.primary,
                        unit: 'kcal',
                      ),
                      NutrientProgressBar(
                        label: Translations.get(lang, 'Carboidrati'),
                        currentValue: dayTotals['carbs'] ?? 0.0,
                        goalValue: dailyCarbGoal,
                        color: Colors.orange,
                        unit: 'g',
                      ),
                      NutrientProgressBar(
                        label: Translations.get(lang, 'Proteine'),
                        currentValue: dayTotals['proteins'] ?? 0.0,
                        goalValue: dailyProteinGoal,
                        color: Colors.green,
                        unit: 'g',
                      ),
                      NutrientProgressBar(
                        label: Translations.get(lang, 'Grassi'),
                        currentValue: dayTotals['fats'] ?? 0.0,
                        goalValue: dailyFatGoal,
                        color: Colors.brown,
                        unit: 'g',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: mealButtons.map((btn) {
                          final label = btn['label'] as String;
                          final isSelected = _currentMeal == label;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2.0,
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  foregroundColor: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                  elevation: isSelected ? 2 : 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() => _currentMeal = label);
                                  _loadEntriesForDay(mealType: label, soloPasto: true);
                                },
                                child: Text(
                                  Translations.get(lang, label),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      NutrientProgressBar(
                        label: Translations.get(lang, 'Calorie'),
                        currentValue: totals['calories'] ?? 0.0,
                        goalValue: mealCalorieGoal,
                        color: Colors.red,
                        unit: 'kcal',
                      ),
                      NutrientProgressBar(
                        label: Translations.get(lang, 'Carboidrati'),
                        currentValue: totals['carbs'] ?? 0.0,
                        goalValue: mealCarbGoal,
                        color: Colors.orange,
                        unit: 'g',
                      ),
                      NutrientProgressBar(
                        label: Translations.get(lang, 'Proteine'),
                        currentValue: totals['proteins'] ?? 0.0,
                        goalValue: mealProteinGoal,
                        color: Colors.green,
                        unit: 'g',
                      ),
                      NutrientProgressBar(
                        label: Translations.get(lang, 'Grassi'),
                        currentValue: totals['fats'] ?? 0.0,
                        goalValue: mealFatGoal,
                        color: Colors.brown,
                        unit: 'g',
                      ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),

                      // REQUISITO: Header Lista + Scritta "Colazione Completa"
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              Translations.get(lang, 'Alimenti consumati'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (_mealEntries.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                // Una frase sola con il nome del pasto dentro:
                                // "Colazione completa" era costruita in
                                // italiano nel codice e restava tale nelle
                                // altre lingue (test di release 19/09).
                                Translations.get(lang, 'meal_logged_badge')
                                    .replaceAll('{pasto}', Translations.get(lang, _currentMeal)),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          // Aggiungere a questo pasto di questo giorno (17/09).
                          IconButton.filledTonal(
                            tooltip: Translations.get(lang, 'Aggiungi alimento'),
                            icon: const Icon(Icons.add),
                            onPressed: _aggiungiAlimento,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // LISTA DEGLI ALIMENTI (Visualizza, Modifica, Elimina)
                      if (_mealEntries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              Translations.get(lang, "Nessun alimento inserito per questo pasto."),
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      else
                        ..._mealEntries.map(
                          (entry) => _buildAlimentoItem(entry, lang),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SEZIONE MICRONUTRIENTI MANTENUTA UGUALE
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    Translations.get(lang, 'Micronutrienti'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  // Scelta compatta: il campo intero starebbe stretto accanto
                  // al titolo, ma le voci si aprono nello stesso foglio dal
                  // basso degli altri select (18/09).
                  TextButton.icon(
                    onPressed: () async {
                      final v = await mostraSceltaNutri<String>(
                        context,
                        titolo: Translations.get(lang, 'Micronutrienti'),
                        selezionato: _micronScope,
                        opzioni: [
                          for (final s in ['Giornaliero', 'Colazione', 'Pranzo', 'Cena', 'Snack'])
                            NutriOpzione(s, Translations.get(lang, s)),
                        ],
                      );
                      if (v == null) return;
                      setState(() {
                        _micronScope = v;
                        if (v != 'Giornaliero') _currentMeal = v;
                      });
                      if (v != 'Giornaliero') _loadEntriesForDay(mealType: v, soloPasto: true);
                    },
                    icon: Text(
                      Translations.get(lang, _micronScope),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    label: Icon(Icons.expand_more, color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Builder(
                    builder: (context) {
                      final sourceSummary = (_micronScope == 'Giornaliero')
                          ? _dailySummary
                          : _mealSummary;

                      final factor = (_micronScope == 'Giornaliero') ? 1.0 : mealFactor;

                      return MicronutrientExpansionPanels(
                        user: user,
                        sourceSummary: sourceSummary,
                        factor: factor,
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
