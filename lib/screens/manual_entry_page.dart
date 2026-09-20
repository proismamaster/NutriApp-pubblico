import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:nutriapp/models/custom_food.dart';
import '../domain/user_provider.dart';
import '../models/food_entry.dart';
import '../models/recipe_ingredient.dart';
import '../widgets/nutrient_input_field.dart';
import '../services/api_services.dart';
import '../logic/nutrient_controller_manager.dart';
import '../widgets/nutrient_group.dart';
import '../models/nutrient_field_config.dart';
import '../dictionary/translations.dart';
import '../logic/unit_format.dart';
import '../providers/locale_provider.dart';
import '../widgets/modern_loader.dart';
import '../widgets/product_info_sheet.dart';
import '../widgets/segnala_alimento.dart';
import '../widgets/auth_style.dart';
import '../widgets/category_picker.dart';
import '../widgets/nutri_select.dart';
import '../widgets/translated_text.dart';
import '../logic/portion_parser.dart';

class ManualEntryPage extends ConsumerStatefulWidget {
  final String? initialMealType;
  final Map<String, dynamic>? prefillData;
  final FoodEntry? foodEntry;
  final bool returnAsIngredient;
  final bool isAddingFromLibrary;
  final bool isEditingMaster;
  final String? barcode;

  /// Il giorno su cui registrare la voce (17/09): quello che si stava
  /// guardando nel diario, non per forza oggi.
  final DateTime? dataVoce;

  /// Scheda di una voce del diario in sola lettura (17/09): niente pasto,
  /// peso, matita ne' pulsante per salvare.
  final bool soloLettura;

  const ManualEntryPage({
    super.key,
    this.initialMealType,
    this.prefillData,
    this.foodEntry,
    this.returnAsIngredient = false,
    this.isAddingFromLibrary = false,
    this.isEditingMaster = false,
    this.barcode,
    this.dataVoce,
    this.soloLettura = false,
  });

  @override
  ConsumerState<ManualEntryPage> createState() => ManualEntryPageState();
}

class ManualEntryPageState extends ConsumerState<ManualEntryPage> {
  final _formKey = GlobalKey<FormState>();

  /// Il campo del nome: ci si torna quando il salvataggio lo boccia.
  final _nomeKey = GlobalKey();
  final NutrientControllerManager _manager = NutrientControllerManager();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  /// Quanto pesa UNA porzione dell'etichetta, con i valori "per porzione".
  final TextEditingController _portionWeightController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  // Foto e descrizione personalizzabili in modalità modifica (2026-07-24):
  // l'immagine arriva da OpenFoodFacts ma può mancare o essere sbagliata, e
  // la descrizione è una nota libera dell'utente (non esiste in OFF).
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Campi aggiunti il 2026-08-30 (mockup "New product" + richiesta di Ismail:
  // creare o modificare un alimento potendo compilare TUTTO cio' che la
  // ricerca restituisce). Le colonne corrispondenti arrivano dalla migrazione
  // 2026-08-29_alimenti_personali_completi.sql.
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _netQtyController = TextEditingController();
  final TextEditingController _servingsController = TextEditingController();
  final TextEditingController _originController = TextEditingController();

  String _selectedCategory = '';
  String _packaging = '';
  DateTime? _bestBefore;

  /// Voto e gruppo scelti a mano dall'utente. Vuoto/0 = "non dichiarato":
  /// restano distinti dalla stima calcolata dai valori, che non viene mai
  /// salvata come se fosse un dato certo.
  String _manualNutri = '';
  int _manualNova = 0;

  /// Indice in _palmOptions. 0 = sconosciuto.
  int _palmIndex = 0;

  final Set<String> _additiveFamilies = {};

  static const List<String> _palmOptions = [
    'Sconosciuto', 'Senza olio di palma', 'Può contenerlo', 'Lo contiene',
  ];
  static const List<String> _additiveOptions = [
    'Coloranti', 'Conservanti', 'Dolcificanti', 'Aromi', 'Emulsionanti', 'Nessuno dichiarato',
  ];
  static const List<String> _packagingOptions = [
    'Plastica', 'Vetro', 'Metallo', 'Cartone', 'Carta', 'Compostabile',
  ];

  /// Pasto scelto dall'utente, `null` finche' non ne ha scelto uno.
  ///
  /// PERCHE' NULLABILE (2026-09-12): prima valeva `initialMealType ??
  /// 'Colazione'`, quindi chi cercava un alimento senza partire da un pasto
  /// trovava "Colazione" gia' scritto e, se non ci faceva caso, si ritrovava
  /// la cena registrata a colazione. Un valore inventato dall'app ha la
  /// stessa faccia di una scelta dell'utente: ora il campo resta vuoto e il
  /// salvataggio chiede dove va.
  String? _selectedMealType;

  /// Vero dopo un tentativo di salvataggio senza pasto scelto: serve solo a
  /// colorare di rosso il campo, come fanno i validator degli altri campi.
  bool _mealMissing = false;

  /// Il pasto si chiede solo quando si sta registrando qualcosa nel diario:
  /// un ingrediente di ricetta o un alimento di libreria non ne ha uno.
  /// Stessa condizione che decide se mostrare il campo (vedi build).
  bool get _mealRequired =>
      !widget.isEditingMaster && !widget.returnAsIngredient;
  bool _saveToLibrary = false;
  bool _isSaving = false;

  /// L'alimento e' stato registrato ma la copia nella libreria personale no.
  /// Serve a dirlo, invece di far credere che sia andato tutto bene.
  bool _libreriaFallita = false;
  bool _isDataIncomplete = false;

  // Stato per la schermata "Prodotto Trovato" (design 2026-07-24): allergeni
  // ed etichette dietetiche vengono precompilati da OpenFoodFacts ma sono
  // modificabili localmente (chip rimovibili + aggiunta manuale), perché i
  // dati OFF possono essere incompleti o sbagliati per il prodotto reale.
  final List<String> _allergenChips = [];
  final List<String> _dietLabelChips = [];

  /// Etichette del prodotto diverse da vegano/vegetariano: non hanno un chip
  /// dedicato ma vanno conservate, altrimenti il salvataggio (che ricostruisce
  /// le etichette dai chip) le cancellerebbe.
  final List<String> _otherLabels = [];

  // Modalità modifica (richiesta 2026-07-24): di default i "parametri" del
  // prodotto (nome, macro, dettagli grassi/vitamine/minerali) sono in sola
  // lettura e i campi vuoti/zero restano nascosti — l'utente attiva la
  // modifica con la matita in alto, che sblocca ogni campo (compresi quelli
  // nascosti) e mostra tutte le sezioni anche se vuote, per poterle
  // compilare. Peso, pasto e codice a barre restano sempre modificabili: non
  // sono "parametri del cibo", sono dati della singola voce che si sta
  // aggiungendo.
  bool _isEditMode = false;

  // Base di riferimento dei valori nutrizionali inseriti a mano nel form
  // classico (mockup Manual Entry): "per 100g" richiede di scalare per il
  // peso della porzione al salvataggio, "per porzione" salva i valori cosi'
  // come scritti — comportamento di default invariato rispetto a prima.
  // Non si applica alla vista "Prodotto Trovato": lì i valori arrivano gia'
  // per 100g da OpenFoodFacts e vengono riproporzionati da _updateProportions.
  String _nutritionBasis = 'portion';

  double get _basisScale {
    final weight = _pesoGrammi;
    if (_nutritionBasis == '100g') return weight > 0 ? weight / 100 : 1.0;
    // Per porzione (15/09): i valori sono quelli di UNA porzione
    // dell'etichetta, che pesa [_pesoPorzioneGrammi]; si scalano su quanto se
    // ne mangia. Prima la porzione era per forza il peso mangiato ("devi poter
    // inserire il peso della porzione, se no non ha senso"). Senza peso della
    // porzione i valori restano quelli scritti, come prima.
    final porzione = _pesoPorzioneGrammi;
    return porzione > 0 && weight > 0 ? weight / porzione : 1.0;
  }

  double get _pesoPorzioneGrammi => UnitFormat.aGrammi(
        double.tryParse(_portionWeightController.text.replaceAll(',', '.')) ?? 0,
      );

  /// Peso digitato, SEMPRE in grammi.
  ///
  /// PERCHE' (2026-09-05): con le once selezionate nel campo c'e' "3.5", non
  /// "100". Tutto cio' che sta a valle — la scala per-100g, il ricalcolo
  /// proporzionale, la colonna weight_g — ragiona in grammi, quindi la
  /// conversione va fatta qui, appena il testo diventa numero, e non sparsa
  /// nei sette punti che leggono questo campo.
  double get _pesoGrammi => UnitFormat.aGrammi(
        double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 0,
      );

  /// Scrive nel campo un peso espresso in grammi, nell'unita' scelta.
  void _scriviPeso(double grammi) =>
      _weightController.text = UnitFormat.pValore(grammi);

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.initialMealType;
    _initManager();
    _initializeData();
    _checkDataCompleteness();
    _initProductChips();
  }

  void _initProductChips() {
    final data = widget.prefillData;
    if (data == null) return;
    final String allergensRaw = (data['allergens'] ?? '').toString();
    if (allergensRaw.trim().isNotEmpty) {
      _allergenChips.addAll(splitOffTags(allergensRaw));
    }
    // Delle etichette mostriamo come chip solo quella dietetica
    // (vegano/vegetariano). Tutte le altre ("biologico", "senza glutine", …)
    // vengono comunque conservate qui: senza, il salvataggio le
    // cancellerebbe, perché le etichette salvate vengono ricostruite dai
    // chip visibili.
    final String labelsRaw = (data['labels'] ?? '').toString();
    for (final tag in splitOffTags(labelsRaw)) {
      final lower = tag.toLowerCase();
      if (lower.contains('vegan')) {
        if (!_dietLabelChips.contains('vegan')) _dietLabelChips.add('vegan');
      } else if (lower.contains('vegetarian')) {
        if (!_dietLabelChips.contains('vegetarian')) {
          _dietLabelChips.add('vegetarian');
        }
      } else {
        _otherLabels.add(tag);
      }
    }
  }

  void _checkDataCompleteness() {
    final values = _manager.getValues();
    final double kcal = double.tryParse(values['calories']?.toString() ?? '0') ?? 0;
    // (Rimosse due variabili 'prot' e 'carb' che venivano calcolate ma mai
    // usate: producevano solo warning in flutter analyze.)

    // Se le calorie sono a zero, i dati sono quasi certamente incompleti (o è acqua).
    // In questi casi sblocchiamo i campi per permettere la correzione.
    if (kcal <= 0) {
      setState(() {
        _isDataIncomplete = true;
        _saveToLibrary = true; // Consigliamo il salvataggio per correggere il database
      });
    }
  }

  void _initManager() {
    _manager.init([
      'calories',
      'proteins',
      'carbs',
      'fats',
      'water',
      'fibers',
      'sugars',
      'saturated_fats',
      'monounsaturated_fats',
      'polyunsaturated_fats',
      'trans_fats',
      'cholesterol',
      'vit_a',
      'vit_b1',
      'vit_b2',
      'vit_b3',
      'vit_b5',
      'vit_b6',
      'vit_b7',
      'vit_b9',
      'vit_b11',
      'vit_b12',
      'vit_c',
      'vit_d',
      'vit_e',
      'vit_k',
      'biotin',
      'sodium',
      'arsenic',
      'boron',
      'calcium',
      'chloride',
      'choline',
      'chromium',
      'cobalt',
      'copper',
      'fluoride',
      'fluorine',
      'iodine',
      'iron',
      'magnesium',
      'manganese',
      'molybdenum',
      'phosphorus',
      'potassium',
      'selenium',
      'silicon',
      'sulfur',
      'tin',
      'vanadium',
      'zinc',
    ]);

    // Riscontro live "le calorie dichiarate coincidono coi macro inseriti?"
    // (mockup Manual Entry, richiesta 2026-08-23): serve solo un rebuild, il
    // calcolo si rifa' ogni volta da _manager in _macroCheckNote.
    for (final key in ['calories', 'carbs', 'proteins', 'fats']) {
      _manager.controllers[key]?.addListener(_refreshLiveFeedback);
    }
    // Il peso serve anche a scalare l'anteprima "per 100g" e l'etichetta del
    // pulsante AGGIUNGI dal vivo (vedi _basisScale/_saveButtonLabel), non
    // solo a riproporzionare la vista "Prodotto Trovato".
    _weightController.addListener(_refreshLiveFeedback);
  }

  void _refreshLiveFeedback() {
    if (mounted) setState(() {});
  }

  /// "Aggiungi X kcal a [pasto]" quando le calorie sono gia' compilate
  /// (mockup Manual Entry) — altrimenti resta la semplice etichetta
  /// SALVA/CONFERMA/AGGIUNGI di prima, non un placeholder vuoto.
  String _saveButtonLabel(String lang, bool isIng) {
    if (widget.isEditingMaster) return Translations.get(lang, 'SALVA');
    if (widget.foodEntry != null) return Translations.get(lang, 'SALVA');
    if (isIng) return Translations.get(lang, 'CONFERMA');

    final kcal = _manager.valore('calories');
    if (kcal <= 0) return Translations.get(lang, 'AGGIUNGI');
    // Con base "per 100g" l'etichetta mostra le kcal della porzione pesata,
    // non il valore per-100g digitato — cosi' l'utente vede subito cosa
    // sta davvero per registrare (mockup Manual Entry: portionKcal).
    final portionKcal = kcal * _basisScale;
    final meal = _selectedMealType;
    // Senza pasto scelto l'etichetta resta senza la sua coda: prima
    // `Translations.get` riceveva il pasto inventato dall'app e il pulsante
    // annunciava "aggiungi a colazione" una scelta che nessuno aveva fatto.
    if (meal == null) {
      return '${Translations.get(lang, 'AGGIUNGI')} ${UnitFormat.e(portionKcal)}';
    }
    final mealLabel = Translations.get(lang, meal).toLowerCase();
    return '${Translations.get(lang, 'AGGIUNGI')} ${UnitFormat.e(portionKcal)} · $mealLabel';
  }

  /// Card informativa: calorie dai macro (4/4/9) confrontate con le kcal
  /// dichiarate, con tolleranza (15 kcal o 10%, il piu' alto) prima di
  /// segnalare un'incoerenza — stessa soglia usata nel mockup. Nessun blocco
  /// al salvataggio: e' un avviso per far ricontrollare l'etichetta, non una
  /// regola che impedisce di procedere (i dati di un'etichetta reale a volte
  /// arrotondano diversamente).
  Widget _macroCheckNote(String lang) {
    double v(String key) => _manager.valore(key);
    final carbs = v('carbs'), protein = v('proteins'), fat = v('fats');
    final stated = v('calories');
    final fromMacros = (carbs * 4 + protein * 4 + fat * 9).round();
    final hasMacros = (carbs + protein + fat) > 0;
    if (!hasMacros || stated <= 0) return const SizedBox.shrink();

    final tolerance = (stated * 0.1).clamp(15, double.infinity);
    final bool off = (fromMacros - stated).abs() > tolerance;
    final scheme = Theme.of(context).colorScheme;
    final Color color = off ? scheme.error : scheme.primary;

    final String note = off
        ? '${Translations.get(lang, 'macro_check_carbs_protein_fat')} ${UnitFormat.e(fromMacros)}, '
            '${Translations.get(lang, 'macro_check_but_entered')} ${UnitFormat.e(stated)}. '
            '${Translations.get(lang, 'macro_check_review_label')}'
        : Translations.get(lang, 'macro_check_ok');

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(off ? Icons.error_outline : Icons.info_outline, size: 18, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Text(note, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }

  void _initializeData() {
    if (widget.foodEntry != null && widget.prefillData == null) {
      final entry = widget.foodEntry!;
      _selectedMealType = entry.meal_type;
      _nameController.text = entry.food_name;
      _scriviPeso(entry.weight_g);
      _manager.setValues(entry.toJson());
    } else if (widget.prefillData != null) {
      final data = widget.prefillData!;
      _nameController.text = data['food_name'] ?? '';
      // FIX 2026-07-24 (secondo tentativo — il primo non funzionava):
      // 'base_weight_g' NON è la porzione, è la base su cui sono espressi i
      // nutrienti, e per i prodotti OpenFoodFacts vale SEMPRE 100 (i valori
      // OFF sono per 100 g). Il tentativo precedente lo usava anche come
      // candidato porzione, quindi trovava sempre 100 e non arrivava mai a
      // leggere la porzione vera. Ora i due concetti sono separati:
      // la porzione arriva SOLO da serving_quantity o da serving_size.
      final double portion = productPortionGrams(data);
      _scriviPeso(widget.isEditingMaster
          // Modifica di un alimento di libreria: lì base_weight_g è il peso
          // base scelto dall'utente, ed è giusto ripartire da quello.
          ? (double.tryParse(data['base_weight_g']?.toString() ?? '') ?? 100)
          : (portion > 0 ? portion : 100));
      _manager.setValues(data);
      _barcodeController.text = data['barcode']?.toString() ?? widget.barcode ?? '';
      _imageUrlController.text = (data['image_url'] ?? '').toString();
      _descriptionController.text = (data['description'] ?? '').toString();
      _brandController.text = (data['brand'] ?? '').toString();
      _quantityController.text = (data['quantity'] ?? '').toString();
      _ingredientsController.text = (data['ingredients'] ?? '').toString();
      _originController.text = (data['manufacturing_places'] ?? '').toString();
      _netQtyController.text = (data['net_quantity_g'] ?? '').toString().replaceAll('null', '');
      _servingsController.text = (data['servings'] ?? '').toString().replaceAll('null', '');
      _packaging = (data['packaging'] ?? '').toString();
      // Le famiglie di additivi salvate tornano spuntate (15/09): prima si
      // scrivevano e non si rileggevano, e riaprendo l'alimento il numero
      // tornava "—".
      _additiveFamilies
        ..clear()
        ..addAll((data['additives_tags'] ?? '')
            .toString()
            .split(',')
            .map((a) => a.trim())
            .where(_additiveOptions.contains));
      _selectedCategory = (data['categories'] ?? '').toString().split(',').first.trim();
      _manualNutri = (data['nutriscore_grade'] ?? '').toString().toLowerCase().trim();
      _manualNova = int.tryParse((data['nova_group'] ?? '').toString()) ?? 0;
      final bb = (data['best_before'] ?? '').toString();
      _bestBefore = bb.isEmpty ? null : DateTime.tryParse(bb);
      // Voce del diario aperta dalla matita (17/09): la scheda del prodotto
      // riparte dal pasto e dal peso gia' registrati.
      final voce = widget.foodEntry;
      if (voce != null) {
        _selectedMealType = voce.meal_type;
        _scriviPeso(voce.weight_g);
      }
      if (widget.isAddingFromLibrary) _updateProportions();
    } else if (widget.barcode != null) {
      _barcodeController.text = widget.barcode!;
    }
  }

  /// Peso a cui corrispondono i valori attualmente mostrati. Serve a
  /// riproporzionare partendo da quello che c'è a schermo invece che dai
  /// valori originali del prodotto (vedi _updateProportions).
  double _lastAppliedWeight = 0;

  void _updateProportions() {
    if (!widget.isAddingFromLibrary || widget.prefillData == null || _isDataIncomplete) return;

    final double currentWeight = _pesoGrammi;
    // Campo peso vuoto o a metà digitazione: non azzerare tutti i valori.
    if (currentWeight <= 0) return;

    // FIX 2026-07-24: prima si ricalcolava SEMPRE da widget.prefillData, cioè
    // dai valori originali del prodotto. Da quando i campi sono modificabili
    // questo cancellava in silenzio le correzioni dell'utente: bastava
    // correggere le calorie e poi toccare il peso per veder tornare il valore
    // sbagliato di prima. Ora si riproporziona da quello che è a schermo,
    // usando come riferimento il peso a cui quei valori corrispondono.
    final double previousWeight = _lastAppliedWeight > 0
        ? _lastAppliedWeight
        : _parseDouble(widget.prefillData!['base_weight_g'] ?? 100.0);
    if (previousWeight <= 0) return;

    final double ratio = currentWeight / previousWeight;
    if (ratio == 1.0) {
      _lastAppliedWeight = currentWeight;
      return;
    }

    setState(() {
      final values = _manager.getValues();
      final newValues = <String, dynamic>{};
      values.forEach((key, value) {
        newValues[key] = (value * ratio).toStringAsFixed(2);
      });
      _manager.setValues(newValues);
      _lastAppliedWeight = currentWeight;
    });
  }

  @override
  void dispose() {
    _manager.dispose();
    _nameController.dispose();
    _weightController.dispose();
    _portionWeightController.dispose();
    _barcodeController.dispose();
    _imageUrlController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _quantityController.dispose();
    _ingredientsController.dispose();
    _netQtyController.dispose();
    _servingsController.dispose();
    _originController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    final bool isIng = widget.returnAsIngredient;

    final bool ro = widget.isAddingFromLibrary && !_isDataIncomplete;

    // Schermata "Prodotto Trovato" (design condiviso 2026-07-24, opzione
    // "2a", rifinita in seguito lo stesso giorno): usata solo quando
    // arriviamo da una ricerca/scan con dati pre-compilati validi e non
    // stiamo modificando la libreria. I parametri del prodotto sono in sola
    // lettura di default (con campi/sezioni vuoti nascosti); la matita in
    // AppBar sblocca la modifica completa. Le altre modalità (inserimento
    // vuoto, modifica libreria, dati incompleti) restano sul form classico
    // sotto, più adatto alla scrittura libera da zero.
    // Con la matita si passa al form COMPLETO, non si sbloccano i campi al
    // loro posto: la vista "Prodotto Trovato" e' pensata per leggere e
    // aggiungere in fretta, e mostra solo una parte dei campi. Chi vuole
    // correggere un prodotto deve poter toccare tutto — categoria, foto,
    // confezione, micronutrienti — ed e' esattamente cio' che il form
    // classico offre, gia' compilato con i dati trovati.
    if (widget.prefillData != null &&
        widget.isAddingFromLibrary &&
        !widget.isEditingMaster &&
        !_isDataIncomplete &&
        !_isEditMode) {
      return _buildProductFoundView(context, lang, isIng);
    }

    return Stack(
      children: [
        Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditingMaster
              ? Translations.get(lang, 'Modifica Libreria')
              : (isIng ? Translations.get(lang, 'Ingrediente') : Translations.get(lang, 'Manuale')),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
          onPressed: () => Navigator.pop(context, false),
        ),
        // Info prodotto (Nutri-Score, NOVA, allergeni, ecc.): solo se ci sono
        // dati extra da mostrare, cioè solo per alimenti da na_off_products
        // (CREA/USDA/personali non hanno questi campi). Vale sia per il
        // diario alimentare sia per gli ingredienti di una ricetta: entrambi
        // i flussi passano da questa pagina con lo stesso prefillData.
        actions: [
          if (productHasExtraInfo(widget.prefillData))
            IconButton(
              icon: Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              tooltip: Translations.get(lang, 'product_info'),
              onPressed: () => showProductInfoSheet(
                context,
                product: widget.prefillData!,
                lang: lang,
              ),
            ),
          // Segnala un errore nei dati (2026-09-14). Prima ci si arrivava solo
          // dal fondo della scheda info, che esiste solo per i prodotti
          // OpenFoodFacts con dati extra: per CREA, USDA e i prodotti senza
          // foto il tasto non c'era proprio. Qui il form classico si apre con
          // dati trovati incompleti o per correggere un prodotto — proprio i
          // casi da segnalare. Non nella modifica della propria libreria, dove
          // l'errore si corregge e basta.
          if (widget.prefillData != null && !widget.isEditingMaster)
            IconButton(
              icon: Icon(Icons.flag_outlined, color: Theme.of(context).colorScheme.primary),
              tooltip: Translations.get(lang, 'report_food_action'),
              onPressed: () => mostraSegnalaAlimento(context, product: widget.prefillData!),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          // Rivalida ad ogni modifica dopo la prima interazione
          // (2026-09-12). Senza questo, un campo bocciato da `validate()`
          // tiene il messaggio rosso finche' non si ritenta il salvataggio:
          // l'utente corregge il valore, vede ancora l'errore di prima e
          // crede che l'app non accetti nemmeno quello giusto. E' lo stesso
          // difetto segnalato sull'altezza in "Il mio profilo", qui nella
          // versione dei Form con validator.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ordine del mockup "New product": prima si dice CHE COSA e',
              // poi quanto pesa e in che pasto va. Prima il pasto veniva
              // chiesto per primo, cioe' un dato del diario prima ancora di
              // sapere di quale alimento si stia parlando.
              _photoDropzone(lang),
              const SizedBox(height: 16),
              _nameAndBrand(lang),
              const SizedBox(height: 12),
              _categoryChips(lang),
              const SizedBox(height: 14),
              _calorieRingCard(lang),
              const SizedBox(height: 10),
              _qualityEditorCard(lang),
              const SizedBox(height: 20),
              if (!widget.isEditingMaster && !isIng) ...[
                _buildLabel(Translations.get(lang, 'Seleziona Pasto')),
                _mealTypeField(context, lang),
                const SizedBox(height: 20),
              ],
              // Foto e descrizione anche qui (2026-07-24): erano state
              // aggiunte solo alla schermata "Prodotto Trovato", ma questo è
              // il layout usato per modificare un alimento della libreria —
              // cioè proprio il caso in cui ha più senso poterle cambiare.
              // Per l'inserimento manuale da zero non ha senso mostrarle:
              // niente foto di un alimento che non esiste ancora.
              if (widget.isEditingMaster) ...[
                const SizedBox(height: 16),
                _buildLabel(Translations.get(lang, 'edit_image_title')),
                NutrientInputField(
                  label: Translations.get(lang, 'edit_image_title'),
                  hint: Translations.get(lang, 'edit_image_hint'),
                  suffix: '',
                  controller: _imageUrlController,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                _buildLabel(Translations.get(lang, 'description_label')),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: Translations.get(lang, 'description_hint'),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildLabel(
                '${Translations.get(lang, widget.isEditingMaster ? 'Peso Base' : 'Peso alimento')} (${UnitFormat.pSigla})',
              ),
              NutrientInputField(
                label: Translations.get(lang, 'Peso'),
                hint: UnitFormat.pValore(100),
                suffix: UnitFormat.pSigla,
                controller: _weightController,
                onChanged: (_) => _updateProportions(),
              ),
              const SizedBox(height: 16),
              _buildLabel(Translations.get(lang, 'Codice a Barre (opzionale)')),
              Row(
                children: [
                  Expanded(
                    child: NutrientInputField(
                      label: Translations.get(lang, 'Codice a Barre'),
                      hint: '800... ',
                      suffix: '',
                      controller: _barcodeController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Calorie da sole, in evidenza (mockup Manual Entry: campo
              // grande e separato) — poi Carbo/Proteine/Grassi/Fibre/
              // Zuccheri/Acqua in griglia 2 colonne, la stessa gia' usata
              // nella vista "Prodotto Trovato" (_buildMacroGrid): prima qui
              // erano invece 7 righe verticali una sotto l'altra, diverse
              // dall'altro layout della stessa pagina.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Icon(Icons.restaurant, color: Theme.of(context).colorScheme.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      Translations.get(lang, 'Macronutrienti'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (widget.prefillData == null && !widget.isEditingMaster) ...[
                _buildNutritionBasisToggle(lang),
                if (_nutritionBasis == 'portion') _campoPesoPorzione(lang),
                const SizedBox(height: 12),
              ],
              NutrientGroup(title: '', outlined: true, configs: [
                _manager.getConfig(
                  'calories',
                  label: Translations.get(lang, 'Calorie'),
                  suffix: UnitFormat.eSigla,
                  readOnly: ro,
                ),
              ]),
              const SizedBox(height: 4),
              _buildClassicMacroGrid(lang, readOnly: ro),
              _macroCheckNote(lang),
              _buildExpandableSection(
                Translations.get(lang, 'Dettagli Grassi'),
                Icons.local_fire_department,
                Colors.red,
                [
                  _manager.getConfig(
                    'saturated_fats',
                    label: Translations.get(lang, 'Saturi'),
                    suffix: 'g',
                    readOnly: ro,
                  ),
                  _manager.getConfig(
                    'monounsaturated_fats',
                    label: Translations.get(lang, 'Monoinsaturi'),
                    suffix: 'g',
                    readOnly: ro,
                  ),
                  _manager.getConfig(
                    'polyunsaturated_fats',
                    label: Translations.get(lang, 'Polinsaturi'),
                    suffix: 'g',
                    readOnly: ro,
                  ),
                  _manager.getConfig(
                    'trans_fats',
                    label: Translations.get(lang, 'Trans'),
                    suffix: 'g',
                    readOnly: ro,
                  ),
                  _manager.getConfig(
                    'cholesterol',
                    label: Translations.get(lang, 'Colesterolo'),
                    suffix: 'mg',
                    readOnly: ro,
                  ),
                ],
              ),
              _buildExpandableSection(
                Translations.get(lang, 'Vitamine'),
                Icons.health_and_safety,
                Colors.green,
                _getVitaminConfigs(lang),
              ),
              _buildExpandableSection(
                Translations.get(lang, 'Minerali'),
                Icons.category,
                Colors.blue,
                _getMineralConfigs(),
              ),
              _ingredientsGroup(lang),
              _packageGroup(lang),
              const SizedBox(height: 32),
              if (!widget.isEditingMaster && !isIng)
                SwitchListTile(
                  title: Text(
                    Translations.get(lang, 'Salva nella mia libreria'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // Didascalia dinamica (mockup Manual Entry): spiega la
                  // conseguenza reale del toggle, non solo il suo stato.
                  subtitle: Text(
                    Translations.get(
                      lang,
                      _saveToLibrary
                          ? 'Riusalo senza doverlo riscrivere'
                          : 'Registralo una volta, senza conservarlo',
                    ),
                  ),
                  value: _saveToLibrary,
                  activeTrackColor: Nutri.green.withValues(alpha: 0.5),
                  activeThumbColor: Nutri.green,
                  onChanged: (v) => setState(() => _saveToLibrary = v),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Nutri.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _handleSave,
                  child: Text(
                    _saveButtonLabel(lang, isIng),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
        if(_isSaving)
          VeloDiCaricamento(messaggio: Translations.get(lang, 'Salvataggio in corso...')),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // "Prodotto Trovato" (design condiviso 2026-07-24, opzione "2a"): tutti i
  // metodi qui sotto costruiscono la vista alternativa usata solo quando
  // arriviamo da una ricerca/scan con dati pre-compilati validi. Riusano lo
  // stesso _manager / _weightController / _handleSave / _updateProportions
  // del layout classico sopra: cambia solo la presentazione, non la logica
  // di salvataggio sottostante.
  // ---------------------------------------------------------------------

  Widget _buildProductFoundView(BuildContext context, String lang, bool isIng) {
    final data = widget.prefillData!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          Translations.get(lang, 'product_found_title'),
          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          if (productHasExtraInfo(data))
            IconButton(
              icon: Icon(Icons.info_outline, color: theme.colorScheme.primary),
              tooltip: Translations.get(lang, 'product_info'),
              onPressed: () => showProductInfoSheet(context, product: data, lang: lang),
            ),
          // Segnala un errore nei dati (2026-09-14): visibile per ogni fonte,
          // non piu' nascosto in fondo alla scheda info (vedi il form classico).
          IconButton(
            icon: Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
            tooltip: Translations.get(lang, 'report_food_action'),
            onPressed: () => mostraSegnalaAlimento(context, product: data),
          ),
          // Matita modalità modifica (richiesta 2026-07-24): di default i
          // parametri del prodotto sono in sola lettura e i campi vuoti
          // nascosti; qui si sblocca tutto per correggere/completare.
          if (!widget.soloLettura)
          IconButton(
            icon: Icon(
              _isEditMode ? Icons.check : Icons.edit_outlined,
              color: theme.colorScheme.primary,
            ),
            tooltip: Translations.get(lang, _isEditMode ? 'Conferma' : 'Modifica'),
            onPressed: () => setState(() => _isEditMode = !_isEditMode),
          ),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            // Vedi il commento sull'altro Form di questo file.
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _buildProductHeader(context, lang, data),
                const SizedBox(height: 18),
                _buildCalorieCard(context, lang),
                const SizedBox(height: 14),
                if (productHasExtraInfo(data)) _buildQualityCard(context, lang, data),
                const SizedBox(height: 14),
                if (!widget.soloLettura) ...[
                  _buildPortionPicker(context, lang, data),
                  const SizedBox(height: 18),
                ],
                if (!widget.isEditingMaster && !isIng && !widget.soloLettura) ...[
                  _buildLabel(Translations.get(lang, 'Seleziona Pasto')),
                  _mealTypeField(context, lang),
                  const SizedBox(height: 20),
                ],
                _buildLabel(Translations.get(lang, 'Nome Alimento')),
                NutrientInputField(
                  key: _nomeKey,
                  label: Translations.get(lang, 'Nome'),
                  hint: Translations.get(lang, 'Es. Mela'),
                  suffix: '',
                  controller: _nameController,
                  readOnly: !_isEditMode,
                  validator: (v) =>
                      v == null || v.isEmpty ? Translations.get(lang, 'Inserisci un nome') : null,
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),
                // Codice a barre: spostato qui sotto il nome (richiesta
                // 2026-07-24, prima era in cima vicino a foto/marca). Sempre
                // modificabile: non è un "parametro" del cibo, è il dato
                // della singola voce.
                _buildLabel(Translations.get(lang, 'Codice a Barre (opzionale)')),
                Row(
                  children: [
                    Expanded(
                      child: NutrientInputField(
                        label: Translations.get(lang, 'Codice a Barre'),
                        hint: '800...',
                        suffix: '',
                        controller: _barcodeController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _scanBarcode,
                      icon: const Icon(Icons.qr_code_scanner),
                    ),
                  ],
                ),
                // Descrizione/nota libera (2026-07-24): non esiste in
                // OpenFoodFacts, la scrive l'utente. Mostrata solo se c'è
                // qualcosa da leggere o se si sta modificando.
                if (_isEditMode || _descriptionController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildLabel(Translations.get(lang, 'description_label')),
                  TextFormField(
                    controller: _descriptionController,
                    readOnly: !_isEditMode,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: Translations.get(lang, 'description_hint'),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _buildLabel(Translations.get(lang, 'Macronutrienti')),
                _buildMacroGrid(context),
                _macroCheckNote(lang),
                const SizedBox(height: 16),
                _buildFilteredSection(
                  Translations.get(lang, 'Dettagli Grassi'),
                  Icons.local_fire_department,
                  Colors.red,
                  [
                    _manager.getConfig('saturated_fats', label: Translations.get(lang, 'Saturi'), suffix: 'g', readOnly: !_isEditMode),
                    _manager.getConfig('monounsaturated_fats', label: Translations.get(lang, 'Monoinsaturi'), suffix: 'g', readOnly: !_isEditMode),
                    _manager.getConfig('polyunsaturated_fats', label: Translations.get(lang, 'Polinsaturi'), suffix: 'g', readOnly: !_isEditMode),
                    _manager.getConfig('trans_fats', label: Translations.get(lang, 'Trans'), suffix: 'g', readOnly: !_isEditMode),
                    _manager.getConfig('cholesterol', label: Translations.get(lang, 'Colesterolo'), suffix: 'mg', readOnly: !_isEditMode),
                  ],
                ),
                _buildFilteredSection(
                  Translations.get(lang, 'Vitamine'),
                  Icons.health_and_safety,
                  Colors.green,
                  _getVitaminConfigs(lang, readOnlyOverride: !_isEditMode),
                ),
                _buildFilteredSection(
                  Translations.get(lang, 'Minerali'),
                  Icons.category,
                  Colors.blue,
                  _getMineralConfigs(readOnlyOverride: !_isEditMode),
                ),
                // Ingredienti: sezione di sola visualizzazione (testo
                // libero da OpenFoodFacts, non c'è un campo dati da salvare
                // per un valore modificato), quindi non si "sblocca" con la
                // matita come le altre — semplicemente non esiste se il
                // prodotto non ha questo dato.
                if ((data['ingredients'] ?? '').toString().trim().isNotEmpty)
                  _buildIngredientsSection(lang, data),
                const SizedBox(height: 20),
                if (!widget.isEditingMaster && !isIng)
                  SwitchListTile(
                    title: Text(
                      Translations.get(lang, 'Salva nella mia libreria'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    value: _saveToLibrary,
                    activeTrackColor: Nutri.green.withValues(alpha: 0.5),
                    activeThumbColor: Nutri.green,
                    onChanged: (v) => setState(() => _saveToLibrary = v),
                  ),
                const SizedBox(height: 90),
              ],
            ),
          ),
          if (_isSaving)
            VeloDiCaricamento(messaggio: Translations.get(lang, 'Salvataggio in corso...')),
        ],
      ),
      bottomNavigationBar: widget.soloLettura ? null : _buildFixedBottomBar(context, lang, isIng),
    );
  }

  Widget _buildProductHeader(BuildContext context, String lang, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    // In modalità modifica l'immagine mostrata è quella del campo editabile
    // (così la si vede cambiare in tempo reale mentre la si sostituisce),
    // altrimenti quella originale del prodotto.
    final String imageUrl = _imageUrlController.text.trim().isNotEmpty
        ? _imageUrlController.text.trim()
        : (data['image_url'] ?? '').toString().trim();
    final String name = (data['food_name'] ?? '').toString();
    final String brand = _capitalizeSimple((data['brand'] ?? '').toString());
    final String categoriesRaw = (data['categories'] ?? '').toString();
    final List<String> categoryTags = categoriesRaw.trim().isEmpty ? [] : splitOffTags(categoriesRaw);
    final String source = (data['source'] ?? '').toString();
    // Pastiglia del PAESE solo se il prodotto dice da dove viene. Prima qui
    // usciva "Italia" per ogni dato preso dagli archivi italiani, anche su
    // prodotti americani: sembrava l'origine e non lo era (test di release
    // 19/09). La fonte italiana, quando non c'e' l'origine, si dice per
    // quello che e': un archivio.
    final String origine = (data['manufacturing_places'] ?? '').toString().trim();
    final bool fonteItaliana = source == 'off_local_it' || source == 'crea_it';
    final String? etichettaPaese = origine.isNotEmpty
        ? origine
        : (fonteItaliana ? Translations.get(lang, 'source_italian_db') : null);
    final bool showItaly = etichettaPaese != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl.isEmpty
                  ? Center(
                      child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 32),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400, size: 32),
                      ),
                    ),
            ),
            // In modalità modifica si può cambiare/aggiungere la foto anche
            // quando il prodotto non ne ha una (richiesta 2026-07-24).
            if (_isEditMode)
              Positioned(
                right: 8,
                bottom: 8,
                child: Material(
                  color: theme.colorScheme.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _showEditImageDialog(context, lang),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.photo_camera_outlined, size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        if (brand.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              brand,
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            ),
          ),
        if (categoryTags.isNotEmpty || showItaly) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (categoryTags.isNotEmpty) _plainChip(categoryTags.first),
              if (etichettaPaese != null) _plainChip(etichettaPaese),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCalorieCard(BuildContext context, String lang) {
    final double kcal = _manager.valore('calories');
    final double pct = (kcal / 2000).clamp(0.0, 1.0);
    final double weight = _pesoGrammi;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 4,
                    backgroundColor: Nutri.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(Nutri.green),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(UnitFormat.eValore(kcal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(UnitFormat.eSigla, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Translations.get(lang, 'calories_per_portion'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  '${UnitFormat.p(weight)} · ${(pct * 100).toStringAsFixed(0)}% ${Translations.get(lang, 'of_2000_kcal_daily').replaceAll('{n}', UnitFormat.e(2000))}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityCard(BuildContext context, String lang, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final String nutriscore = (data['nutriscore_grade'] ?? '').toString().toLowerCase().trim();
    final int nova = _asInt(data['nova_group']);
    final int additives = _asInt(data['additives_n']);
    final int palmOil = _asInt(data['palm_oil_n']);
    final int palmOilMaybe = _asInt(data['palm_oil_maybe_n']);

    // FIX 2026-08-29: `isNotEmpty` non basta — OpenFoodFacts scrive 'unknown' o
    // 'not-applicable' invece di lasciare vuoto (62,4% dei prodotti nel dump del
    // 22/08), e _nutriscoreBadge quei valori li disegnava come bollino grigio
    // senza significato. nutriscoreColor() torna null per tutto cio' che non e'
    // a-e: e' lo stesso criterio gia' usato da product_info_sheet.dart.
    final bool hasNutriscore = nutriscoreColor(nutriscore) != null;
    final bool hasStats = hasNutriscore || nova > 0 || additives > 0;
    final bool hasPalm = palmOil > 0 || palmOilMaybe > 0;

    // FIX 2026-09-05: senza niente da mostrare la card veniva disegnata lo
    // stesso, e sotto "Calorie per porzione" restava un riquadro vuoto.
    // productHasExtraInfo() (che decide se costruirla) e' vero anche per campi
    // che questa card NON mostra — per esempio il solo luogo di produzione,
    // che compare gia' come pillola piu' in alto. Il controllo giusto e' se
    // c'e' contenuto QUI dentro.
    if (!hasStats && !hasPalm) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Nutri.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Nutri.green.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasStats)
            Row(
              children: [
                if (hasNutriscore)
                  Expanded(child: _statColumn(_nutriscoreBadge(nutriscore), 'Nutri-Score')),
                if (nova > 0)
                  Expanded(
                    child: _statColumn(
                      InkWell(
                        onTap: () => _showNovaInfoDialog(nova),
                        borderRadius: BorderRadius.circular(17),
                        child: _novaBadge(nova),
                      ),
                      'NOVA',
                    ),
                  ),
                if (additives > 0)
                  Expanded(
                    child: _statColumn(
                      Text('$additives', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Translations.get(lang, 'info_additives'),
                    ),
                  ),
              ],
            ),
          if (hasStats) const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          if (hasPalm)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Text('🌴', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      Translations.get(lang, 'info_palm_oil'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      palmOil > 0
                          ? Translations.get(lang, 'info_palm_oil_yes')
                          : Translations.get(lang, 'info_palm_oil_maybe'),
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          if (_allergenChips.isNotEmpty || _dietLabelChips.isNotEmpty || _isEditMode)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Le "×" per togliere un allergene/etichetta e il "+" per
                // aggiungerne uno compaiono solo in modalità modifica
                // (richiesta 2026-07-24): normalmente sono chip di sola
                // lettura, si modificano solo con la matita attiva.
                ..._allergenChips.map(
                  (a) => _isEditMode
                      ? _removableChip(
                          label: a,
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orange.shade800,
                          onRemove: () => setState(() => _allergenChips.remove(a)),
                        )
                      : _staticChip(
                          label: a,
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orange.shade800,
                        ),
                ),
                ..._dietLabelChips.map(
                  (d) {
                    final label = d == 'vegan'
                        ? Translations.get(lang, 'vegan_label')
                        : Translations.get(lang, 'vegetarian_label');
                    return _isEditMode
                        ? _removableChip(
                            label: label,
                            icon: Icons.check_circle_outline,
                            color: Nutri.green,
                            onRemove: () => setState(() => _dietLabelChips.remove(d)),
                          )
                        : _staticChip(
                            label: label,
                            icon: Icons.check_circle_outline,
                            color: Nutri.green,
                          );
                  },
                ),
                if (_isEditMode)
                  InkWell(
                    onTap: () => _showAddTagDialog(context, lang),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Icon(Icons.add, size: 18, color: theme.colorScheme.primary),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statColumn(Widget badge, String label) {
    return Column(
      children: [
        badge,
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _nutriscoreBadge(String grade) {
    final color = nutriscoreColor(grade) ?? Colors.grey;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        grade.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _novaBadge(int group) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _novaColor(group), shape: BoxShape.circle),
      child: Text(
        '$group',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Color _novaColor(int group) {
    switch (group) {
      case 1:
        return Nutri.green;
      case 2:
        return const Color(0xFFF2B705);
      case 3:
        return const Color(0xFFEE8100);
      case 4:
        return const Color(0xFFE63E11);
      default:
        return Colors.grey;
    }
  }

  /// Come _removableChip ma senza la "×": usata fuori dalla modalità
  /// modifica, dove i chip sono di sola lettura.
  Widget _staticChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Nutri.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _removableChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Nutri.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: color),
          ),
        ],
      ),
    );
  }

  Widget _plainChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      // Colori del tema (15/09): con `Colors.grey.shade200` fisso, in scuro il
      // testo `Nutri.ink` (chiaro) finiva su un fondo quasi bianco.
      decoration: BoxDecoration(
        color: Nutri.surfaceSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: Nutri.ink)),
    );
  }

  /// Dialog per cambiare la foto del prodotto in modalità modifica
  /// (richiesta 2026-07-24). Si incolla un indirizzo immagine: non c'è
  /// upload dalla galleria/fotocamera perché richiederebbe un plugin nativo
  /// (image_picker) e uno spazio di storage lato server, entrambi non
  /// ancora presenti nel progetto — vedi ROADMAP per il seguito.
  Future<void> _showEditImageDialog(BuildContext context, String lang) async {
    final controller = TextEditingController(text: _imageUrlController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(Translations.get(lang, 'edit_image_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(hintText: Translations.get(lang, 'edit_image_hint')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(Translations.get(lang, 'Annulla')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(Translations.get(lang, 'Conferma')),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _imageUrlController.text = result);
    }
  }

  Future<void> _showAddTagDialog(BuildContext context, String lang) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(Translations.get(lang, 'add_tag_dialog_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: Translations.get(lang, 'add_tag_dialog_hint')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(Translations.get(lang, 'Annulla')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(Translations.get(lang, 'Conferma')),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _allergenChips.add(result));
    }
  }


  /// Picker delle porzioni (richiesta 2026-07-24): al posto del singolo
  /// pill "usa porzione suggerita", un chip per ogni porzione disponibile
  /// (100g + eventuale porzione reale dal DB), sempre affiancato dalla
  /// possibilità di scrivere il peso a mano nel campo sotto (mai disattivata).
  Widget _buildPortionPicker(BuildContext context, String lang, Map<String, dynamic> data) {
    final portions = availablePortions(data);
    if (portions.length <= 1) return const SizedBox.shrink();
    final double current = _pesoGrammi;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: portions.map((p) {
        final bool isActive = (current - p).abs() < 0.01;
        final String label = p == 100.0
            ? UnitFormat.p(100)
            : '${Translations.get(lang, 'use_suggested_portion')} ${UnitFormat.p(p)}';
        return InkWell(
          onTap: () {
            setState(() => _scriviPeso(p));
            _updateProportions();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? Nutri.green
                  : Nutri.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.check_circle_outline,
                  size: 16,
                  color: isActive ? Colors.white : Nutri.green,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Nutri.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Griglia 2 colonne Carbs/Proteine/Grassi/Fibre/Zuccheri/Acqua (mockup
  /// Manual Entry: stessa griglia sia nella vista "Prodotto Trovato" — dov'era
  /// gia' presente — sia nel form classico da zero, che prima usava invece
  /// un elenco verticale (NutrientGroup), incoerente fra le due viste.
  /// [readOnlyOverride]/[hideEmptyWhenNotEditing] permettono al form classico
  /// di riusarla senza ereditare la logica "sola lettura fuori da _isEditMode"
  /// pensata solo per la vista Prodotto Trovato/modifica libreria.
  Widget _buildMacroGrid(
    BuildContext context, {
    bool? readOnlyOverride,
    bool hideEmptyWhenNotEditing = true,
  }) {
    final lang = ref.watch(appSettingsProvider).language;
    final List<List<String>> allPairs = [
      ['carbs', Translations.get(lang, 'Carboidrati'), 'g'],
      ['proteins', Translations.get(lang, 'Proteine'), 'g'],
      ['fats', Translations.get(lang, 'Grassi'), 'g'],
      ['fibers', Translations.get(lang, 'Fibre'), 'g'],
      ['sugars', Translations.get(lang, 'Zuccheri'), 'g'],
      ['water', Translations.get(lang, 'Acqua'), 'g'],
    ];
    // Fuori dalla modalità modifica, i macro a 0 restano nascosti (richiesta
    // 2026-07-24); in modifica tornano tutti visibili per poterli compilare.
    final pairs = (_isEditMode || !hideEmptyWhenNotEditing)
        ? allPairs
        : allPairs.where((p) => _hasNutrientValue(p[0])).toList();
    if (pairs.isEmpty) return const SizedBox.shrink();

    final List<Widget> rows = [];
    for (int i = 0; i < pairs.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(child: _macroBox(context, pairs[i][1], pairs[i][0], pairs[i][2], readOnlyOverride: readOnlyOverride)),
              const SizedBox(width: 12),
              if (i + 1 < pairs.length)
                Expanded(child: _macroBox(context, pairs[i + 1][1], pairs[i + 1][0], pairs[i + 1][2], readOnlyOverride: readOnlyOverride))
              else
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  /// Griglia macro 2 colonne del form classico (mockup Manual Entry): campi
  /// bordati con etichetta fluttuante e pallino colore-coerente, come tutti
  /// gli altri campi della pagina — diversa apposta dalla griglia "a
  /// tessera" di _buildMacroGrid/_macroBox usata invece nella vista
  /// "Prodotto Trovato" (design 2026-07-24, fuori dallo scope di questo
  /// mockup), che resta invariata.
  Widget _buildClassicMacroGrid(String lang, {required bool readOnly}) {
    final fields = <(String key, String label, String suffix, Color color)>[
      ('carbs', Translations.get(lang, 'Carboidrati'), 'g', const Color(0xFF1B7A33)),
      ('proteins', Translations.get(lang, 'Proteine'), 'g', const Color(0xFF4E9A6B)),
      ('fats', Translations.get(lang, 'Grassi'), 'g', const Color(0xFFE0A81E)),
      ('fibers', Translations.get(lang, 'Fibre'), 'g', const Color(0xFF8FA98A)),
      ('sugars', Translations.get(lang, 'Zuccheri'), 'g', const Color(0xFFC99A09)),
      ('water', Translations.get(lang, 'Acqua'), 'ml', const Color(0xFF3C86B4)),
    ];

    final rows = <Widget>[];
    for (var i = 0; i < fields.length; i += 2) {
      final second = i + 1 < fields.length ? fields[i + 1] : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _classicMacroField(fields[i], readOnly)),
            const SizedBox(width: 12),
            Expanded(child: second == null ? const SizedBox.shrink() : _classicMacroField(second, readOnly)),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _classicMacroField((String key, String label, String suffix, Color color) field, bool readOnly) {
    final controller = _manager.controllers[field.$1];
    if (controller == null) return const SizedBox.shrink();
    return NutrientInputField(
      label: field.$2,
      hint: '0',
      suffix: field.$3,
      controller: controller,
      readOnly: readOnly,
      dotColor: field.$4,
      outlined: true,
    );
  }

  Widget _macroBox(BuildContext context, String label, String key, String suffix, {bool? readOnlyOverride}) {
    final controller = _manager.controllers[key];
    if (controller == null) return const SizedBox.shrink();
    final bool ro = readOnlyOverride ?? !_isEditMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  readOnly: ro,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Text(' $suffix', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection(String lang, Map<String, dynamic> data) {
    final String ingredients = (data['ingredients'] ?? '').toString().trim();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ExpansionTile(
        leading: const Icon(Icons.receipt_long, color: Colors.brown),
        title: Text(Translations.get(lang, 'Ingredienti'), style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TranslatedText(
                text: ingredients,
                displayLanguage: lang,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedBottomBar(BuildContext context, String lang, bool isIng) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: NutrientInputField(
                label: Translations.get(lang, 'Peso'),
                hint: UnitFormat.pValore(100),
                suffix: UnitFormat.pSigla,
                controller: _weightController,
                onChanged: (_) => _updateProportions(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Nutri.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _handleSave,
                  child: Text(
                    _saveButtonLabel(lang, isIng),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? (double.tryParse(value.toString())?.toInt() ?? 0);
  }

  String _capitalizeSimple(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  /// True se il controller del nutriente [key] ha un valore non-zero. Usato
  /// per nascondere i campi vuoti quando la modalità modifica è spenta.
  bool _hasNutrientValue(String key) {
    final text = _manager.controllers[key]?.text ?? '';
    final v = double.tryParse(text.replaceAll(',', '.').trim());
    return v != null && v != 0;
  }

  bool _configHasValue(NutrientFieldConfig c) {
    final v = double.tryParse(c.controller.text.replaceAll(',', '.').trim());
    return v != null && v != 0;
  }

  /// Filtra i campi vuoti/zero quando non si è in modalità modifica. In
  /// modalità modifica torna tutto invariato (anche i campi vuoti, cosi'
  /// l'utente puo' compilarli).
  List<NutrientFieldConfig> _visibleConfigs(List<NutrientFieldConfig> configs) {
    if (_isEditMode) return configs;
    return configs.where(_configHasValue).toList();
  }

  // La logica di interpretazione delle porzioni vive in
  // lib/logic/portion_parser.dart: è pura, non ha nulla di grafico, ed è il
  // punto in cui si è già annidato due volte lo stesso bug — lì è coperta
  // dai test (test/portion_parser_test.dart).

  /// Popup di conferma "salva in libreria?" mostrato quando si salva dopo
  /// aver personalizzato i valori senza aver attivato lo switch libreria.
  Future<bool?> _askSaveToLibrary() async {
    final lang = ref.read(appSettingsProvider).language;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(Translations.get(lang, 'save_library_nudge_title')),
        content: Text(Translations.get(lang, 'save_library_nudge_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(Translations.get(lang, 'No')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(Translations.get(lang, 'Sì')),
          ),
        ],
      ),
    );
  }

  /// Popup informativo mostrato al tap sul badge NOVA: spiega cos'è NOVA e
  /// cosa significano i 4 livelli.
  Future<void> _showNovaInfoDialog(int currentGroup) async {
    final lang = ref.read(appSettingsProvider).language;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(Translations.get(lang, 'nova_info_title')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Translations.get(lang, 'nova_info_intro')),
              const SizedBox(height: 14),
              for (int g = 1; g <= 4; g++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(top: 1),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _novaColor(g),
                          shape: BoxShape.circle,
                          border: g == currentGroup
                              ? Border.all(color: Nutri.ink, width: 2)
                              : null,
                        ),
                        child: Text(
                          '$g',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(Translations.get(lang, 'nova_group_$g'))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(Translations.get(lang, 'Conferma')),
          ),
        ],
      ),
    );
  }

  // ============ mockup "NutriApp Manual Entry / New product" (30/08) ============

  /// Riquadro tratteggiato per le foto del prodotto.
  ///
  /// LIMITE DICHIARATO: oggi apre il campo "indirizzo immagine", non la
  /// galleria. Il caricamento vero di una foto richiede un endpoint di upload
  /// e una cartella sul server che non esistono ancora (punto 7 dei prossimi
  /// passi in ROADMAP) — meglio un campo onesto che un pulsante che finge.
  Widget _photoDropzone(String lang) {
    final urlPresente = _imageUrlController.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: () => _chiediUrlImmagine(lang),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: Nutri.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC9D4C1), width: 1.5),
          image: urlPresente
              ? DecorationImage(
                  image: NetworkImage(_imageUrlController.text.trim()),
                  fit: BoxFit.cover,
                  onError: (_, __) {},
                )
              : null,
        ),
        child: urlPresente
            ? null
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 28, color: Nutri.green),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Translations.get(lang, 'Aggiungi foto del prodotto'),
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Nutri.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        Translations.get(lang, 'Fronte, tabella nutrizionale, ingredienti'),
                        style: TextStyle(fontSize: 12.5, color: Nutri.muted),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  /// Foto del prodotto: SOLO dalla galleria (2026-09-05).
  ///
  /// La richiesta di un indirizzo web e' stata tolta: era un ripiego di quando
  /// non esisteva un endpoint di caricamento. Ora esiste (upload_image.php) e
  /// il file finisce sul server, con `image_url` che torna a contenere un
  /// indirizzo corto.
  Future<void> _chiediUrlImmagine(String lang) async {
    if (_imageUrlController.text.trim().isNotEmpty) {
      final azione = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Nutri.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: Nutri.green),
                title: Text(Translations.get(lang, 'Cambia foto')),
                onTap: () => Navigator.pop(ctx, 'cambia'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFB4553C)),
                title: Text(
                  Translations.get(lang, 'Rimuovi foto'),
                  style: const TextStyle(color: Color(0xFFB4553C)),
                ),
                onTap: () => Navigator.pop(ctx, 'rimuovi'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (!mounted || azione == null) return;
      if (azione == 'rimuovi') {
        setState(() => _imageUrlController.text = '');
        return;
      }
    }

    final scelta = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
    if (scelta == null || !mounted) return;

    setState(() => _isSaving = true);
    final esito = await ApiServices.uploadImage(
      userMail: ref.read(userProvider)?.email ?? '',
      file: File(scelta.path),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (esito.url != null) {
      setState(() {
        _imageUrlController.text = esito.url!;
        // La foto descrive l'ALIMENTO, non la singola voce di diario: vive su
        // na_custom_foods, che e' la libreria personale. na_nutri_entries non
        // ha (e non deve avere) una colonna immagine, altrimenti la stessa
        // foto verrebbe duplicata a ogni volta che registri quel cibo.
        //
        // Quindi senza la libreria attiva la foto verrebbe scartata in
        // silenzio: chi la aggiunge sta dicendo "questo alimento mi serve
        // ancora", e l'interruttore si accende da solo invece di far sparire
        // il lavoro appena fatto.
        if (!_saveToLibrary && !widget.isEditingMaster) _saveToLibrary = true;
      });
      if (!widget.isEditingMaster) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Translations.get(lang, 'Foto aggiunta: questo alimento viene salvato nella tua libreria, così la ritrovi quando lo riusi.')),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${Translations.get(lang, 'Foto non caricata')}: ${esito.errore}'),
        backgroundColor: const Color(0xFFB4553C),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// Nome grande + marca, con la sottolineatura che si accende quando il nome
  /// è compilato (mockup).
  Widget _nameAndBrand(String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Etichette vere sopra i due campi (2026-09-05). Prima il nome del
        // campo esisteva solo come testo segnaposto DENTRO il campo: appena si
        // iniziava a scrivere spariva, e con il campo pieno non si capiva piu'
        // quale fosse il nome e quale la marca — restavano due righe di testo
        // grande senza intestazione.
        NutriFieldLabel(Translations.get(lang, 'Nome prodotto')),
        Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _nameController.text.trim().isEmpty
                    ? Nutri.hairline
                    : const Color(0xFFC3D8BA),
                width: 2,
              ),
            ),
          ),
          child: TextFormField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Nutri.ink,
              letterSpacing: -0.5,
            ),
            validator: (v) =>
                v == null || v.isEmpty ? Translations.get(lang, 'Inserisci un nome') : null,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              errorStyle: const TextStyle(height: 0.8),
              hintText: Translations.get(lang, 'Nome prodotto'),
              hintStyle: TextStyle(
                color: Nutri.hint,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Nutri.hairline, width: 1.5)),
          ),
          child: TextField(
            controller: _brandController,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Nutri.green),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: Translations.get(lang, 'Marca'),
              hintStyle: TextStyle(color: Nutri.hint, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  /// Selettore di categoria: una riga che apre la ricerca sul catalogo.
  ///
  /// PRIMA erano sette pillole fisse scritte nel codice. Poche, e soprattutto
  /// scollegate dalle categorie vere che il resto dell'app usa per ordinare la
  /// ricerca (i tag OpenFoodFacts in na_off_products): un alimento creato a
  /// mano finiva in un mondo a parte.
  Widget _categoryChips(String lang) {
    final scelta = _selectedCategory.trim();
    final etichetta = scelta.isEmpty
        ? Translations.get(lang, 'Scegli una categoria')
        : _etichettaCategoria(scelta);

    return GestureDetector(
      onTap: () => _apriCategorie(lang),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Nutri.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Nutri.fieldBorder, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.local_offer_outlined, size: 19, color: Nutri.green),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                etichetta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: scelta.isEmpty ? Nutri.hint : Nutri.ink,
                ),
              ),
            ),
            if (scelta.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _selectedCategory = ''),
                child: Icon(Icons.close, size: 18, color: Nutri.mutedSoft),
              )
            else
              Icon(Icons.search, size: 19, color: Nutri.mutedSoft),
          ],
        ),
      ),
    );
  }

  /// Da `en:breakfast-cereals` a "Breakfast cereals". Una categoria scritta a
  /// mano dall'utente non ha il prefisso e resta com'e'.
  String _etichettaCategoria(String tag) {
    final nudo = tag.contains(':') ? tag.substring(tag.indexOf(':') + 1) : tag;
    final testo = nudo.replaceAll('-', ' ').replaceAll('_', ' ').trim();
    if (testo.isEmpty) return tag;
    return testo[0].toUpperCase() + testo.substring(1);
  }

  Future<void> _apriCategorie(String lang) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Nutri.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => CategoryPicker(
        lang: lang,
        iniziale: _etichettaCategoria(_selectedCategory),
        onScelta: (tag) {
          Navigator.pop(ctx);
          setState(() => _selectedCategory = tag);
        },
      ),
    );
  }

  /// Anello con le calorie della porzione e la quota sui 2000 kcal.
  Widget _calorieRingCard(String lang) {
    final kcal100 = _manager.valore('calories');
    final peso = _pesoGrammi;
    final kcalPorzione =
        (_nutritionBasis == '100g' ? kcal100 * peso / 100 : kcal100 * _basisScale).round();
    final quota = kcalPorzione > 0 ? ((kcalPorzione / 2000) * 100).round() : 0;
    final unitaE = ref.watch(appSettingsProvider).energyUnit;
    final unitaP = ref.watch(appSettingsProvider).weightUnit;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Nutri.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: (quota / 100).clamp(0.0, 1.0),
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                    backgroundColor: const Color(0xFFDDE4D3),
                    valueColor: AlwaysStoppedAnimation(
                      Nutri.nutriScore[_gradoEffettivo()] ?? const Color(0xFFB0B8AC),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      kcalPorzione > 0
                          ? UnitFormat.energyValue(kcalPorzione.toDouble(), unitaE)
                          : '—',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Nutri.ink,
                        height: 1,
                      ),
                    ),
                    Text(UnitFormat.eSigla, style: TextStyle(fontSize: 9, color: Nutri.mutedSoft)),
                  ],
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
                  Translations.get(lang, 'Calorie per porzione'),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Nutri.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  kcalPorzione > 0
                      ? '${UnitFormat.weight(peso, unitaP)} · $quota% ${Translations.get(lang, 'of_2000_kcal_daily').replaceAll('{n}', UnitFormat.e(2000))}'
                      : Translations.get(lang, 'Inserisci calorie e peso della porzione'),
                  style: TextStyle(fontSize: 12.5, color: Nutri.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Voto usato per colorare l'anello: quello scelto a mano se c'è, altrimenti
  /// la stima. Serve solo al colore, mai salvato come dato certo.
  String _gradoEffettivo() {
    if (_manualNutri.isNotEmpty) return _manualNutri;
    return _stimaNutri();
  }

  /// Stima indicativa dai valori inseriti, stessa formula del mockup.
  /// NON è l'algoritmo ufficiale Nutri-Score: per questo, dove compare, è
  /// sempre etichettata "stimato".
  String _stimaNutri() {
    double v(String k) => _manager.valore(k);
    final kcal = v('calories');
    if (kcal <= 0) return '';
    var p = 0;
    p += kcal > 350 ? 3 : kcal > 175 ? 2 : kcal > 80 ? 1 : 0;
    p += v('sugars') > 22 ? 3 : v('sugars') > 9 ? 2 : v('sugars') > 4.5 ? 1 : 0;
    p += v('sodium') > 1.6 ? 3 : v('sodium') > 0.8 ? 2 : v('sodium') > 0.3 ? 1 : 0;
    p -= v('fibers') >= 4.7 ? 2 : v('fibers') >= 2.8 ? 1 : 0;
    p -= v('proteins') >= 8 ? 2 : v('proteins') >= 4.8 ? 1 : 0;
    return p <= -1 ? 'a' : p <= 2 ? 'b' : p <= 6 ? 'c' : p <= 10 ? 'd' : 'e';
  }

  /// Card qualità modificabile: Nutri-Score, NOVA, additivi, olio di palma,
  /// allergeni. Tocca il bollino per cambiarlo.
  Widget _qualityEditorCard(String lang) {
    final stima = _stimaNutri();
    final grado = _manualNutri.isNotEmpty ? _manualNutri : stima;
    final coloreGrado = Nutri.nutriScore[grado];
    final impostatoAMano = _manualNutri.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Nutri.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _qualityTile(
                  label: 'Nutri-Score',
                  onTap: () {
                    const ordine = ['', 'a', 'b', 'c', 'd', 'e'];
                    setState(() => _manualNutri =
                        ordine[(ordine.indexOf(_manualNutri) + 1) % ordine.length]);
                  },
                  // Un voto solo STIMATO non prende il colore ufficiale: resta
                  // grigio, cosi' non si confonde con un dato dichiarato.
                  bg: impostatoAMano && coloreGrado != null ? coloreGrado : Nutri.divider,
                  fg: impostatoAMano && coloreGrado != null
                      ? Nutri.fgOnScore(coloreGrado)
                      : Nutri.mutedSoft,
                  testo: grado.isEmpty ? '?' : grado.toUpperCase(),
                ),
              ),
              Expanded(
                child: _qualityTile(
                  label: 'NOVA',
                  onTap: () => setState(() => _manualNova = (_manualNova + 1) % 5),
                  bg: _manualNova == 0
                      ? Nutri.divider
                      : const [
                          Color(0xFF038141),
                          Color(0xFF7FA92B),
                          Color(0xFFEE8100),
                          Color(0xFFE63E11),
                        ][_manualNova - 1],
                  fg: _manualNova == 0
                      ? Nutri.mutedSoft
                      : (_manualNova == 2 ? Nutri.ink : Colors.white),
                  testo: _manualNova == 0 ? '?' : '$_manualNova',
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 34,
                      child: Center(
                        child: Text(
                          key: const Key('conteggio_additivi'),
                          _additiveFamilies.contains('Nessuno dichiarato')
                              ? '0'
                              : _additiveFamilies.isEmpty
                                  ? '—'
                                  : '${_additiveFamilies.length}',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Nutri.ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Translations.get(lang, 'Additivi'),
                      style: TextStyle(fontSize: 11, color: Nutri.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 26, thickness: 1, color: Color(0xFFDDE4D3)),
          Row(
            children: [
              Icon(Icons.park_outlined, size: 19, color: Nutri.body),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  Translations.get(lang, 'Olio di palma'),
                  style: TextStyle(fontSize: 13.5, color: Nutri.ink),
                ),
              ),
              GestureDetector(
                onTap: () => setState(
                  () => _palmIndex = (_palmIndex + 1) % _palmOptions.length,
                ),
                child: Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    // Erano quattro tinte chiarissime fisse: in modalita'
                    // scura restavano tali, con sopra un testo scuro — la
                    // pastiglia "Sconosciuto" quasi bianca segnalata da
                    // Ismail. Ora le due neutre vengono dal tema e le due di
                    // avviso hanno la loro variante cupa.
                    color: [
                      Nutri.disabledBg,
                      Nutri.scuro ? const Color(0xFF1E2E1C) : const Color(0xFFDCEDD6),
                      Nutri.scuro ? const Color(0xFF33201A) : const Color(0xFFFBE3DD),
                      Nutri.scuro ? const Color(0xFF41231B) : const Color(0xFFF6D3CB),
                    ][_palmIndex],
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    Translations.get(lang, _palmOptions[_palmIndex]),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: [
                        Nutri.body,
                        Nutri.green,
                        Nutri.danger,
                        Nutri.scuro ? const Color(0xFFEF9C82) : const Color(0xFF9E3F27),
                      ][_palmIndex],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final a in const ['Glutine', 'Latte', 'Uova', 'Frutta a guscio', 'Soia', 'Sesamo'])
                NutriChip(
                  height: 28,
                  label: Translations.get(lang, a),
                  selected: _allergenChips.contains(a),
                  leading: _allergenChips.contains(a) ? Icons.warning_amber_rounded : null,
                  onTap: () => setState(() {
                    if (!_allergenChips.remove(a)) _allergenChips.add(a);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            impostatoAMano
                ? Translations.get(lang, 'Nutri-Score impostato a mano.')
                : stima.isNotEmpty
                    ? '${Translations.get(lang, 'Nutri-Score')} ${stima.toUpperCase()} ${Translations.get(lang, 'stimato dai valori qui sotto: toccalo per impostarlo tu.')}'
                    : Translations.get(lang, 'Tocca Nutri-Score e NOVA per impostarli, o compila i valori per una stima.'),
            style: TextStyle(fontSize: 11.5, color: Nutri.mutedSoft, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _qualityTile({
    required String label,
    required VoidCallback onTap,
    required Color bg,
    required Color fg,
    required String testo,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Text(
              testo,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: fg),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: Nutri.muted)),
        ],
      ),
    );
  }

  /// Ingredienti in chiaro + famiglie di additivi.
  Widget _ingredientsGroup(String lang) {
    final n = _ingredientsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .length;
    return Container(
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: Nutri.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, size: 20, color: Nutri.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  Translations.get(lang, 'Ingredienti'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Nutri.ink),
                ),
              ),
              Text(
                n > 0 ? '$n' : '—',
                style: TextStyle(fontSize: 12, color: Nutri.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(color: Nutri.card, borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _ingredientsController,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 14, height: 1.5, color: Nutri.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: Translations.get(lang, 'Come stampati in etichetta, separati da virgole…'),
                hintStyle: TextStyle(color: Nutri.hint, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            Translations.get(lang, 'FAMIGLIE DI ADDITIVI'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Nutri.muted,
              letterSpacing: 0.72,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final a in _additiveOptions)
                NutriChip(
                  height: 30,
                  label: Translations.get(lang, a),
                  selected: _additiveFamilies.contains(a),
                  onTap: () => setState(() {
                    if (_additiveFamilies.contains(a)) {
                      _additiveFamilies.remove(a);
                    } else {
                      // "Nessuno dichiarato" e una famiglia scelta non possono
                      // convivere: sono affermazioni opposte sulla stessa cosa.
                      if (a == 'Nessuno dichiarato') {
                        _additiveFamilies.clear();
                      } else {
                        _additiveFamilies.remove('Nessuno dichiarato');
                      }
                      _additiveFamilies.add(a);
                    }
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Dati della confezione: quantità netta, porzioni, scadenza, origine, tipo.
  Widget _packageGroup(String lang) {
    final netto = double.tryParse(_netQtyController.text.replaceAll(',', '.')) ?? 0;
    final porzioni = int.tryParse(_servingsController.text.trim()) ?? 0;

    return Container(
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: Nutri.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 20, color: Nutri.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  Translations.get(lang, 'Confezione'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Nutri.ink),
                ),
              ),
              Text(
                netto > 0 ? UnitFormat.p(netto) : '—',
                style: TextStyle(fontSize: 12, color: Nutri.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _packField(
                  lang,
                  Translations.get(lang, 'Quantità netta'),
                  _netQtyController,
                  suffix: 'g',
                  numerico: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _packField(
                  lang,
                  Translations.get(lang, 'Porzioni'),
                  _servingsController,
                  numerico: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _bestBefore ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _bestBefore = d);
                  },
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: Nutri.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          Translations.get(lang, 'Da consumarsi entro'),
                          style: TextStyle(fontSize: 10.5, color: Nutri.muted),
                        ),
                        Text(
                          _bestBefore == null
                              ? '—'
                              : '${_bestBefore!.day.toString().padLeft(2, '0')}/${_bestBefore!.month.toString().padLeft(2, '0')}/${_bestBefore!.year}',
                          style: TextStyle(
                            fontSize: 14,
                            color: _bestBefore == null ? Nutri.hint : Nutri.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _packField(lang, Translations.get(lang, 'Origine'), _originController),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            Translations.get(lang, 'TIPO DI CONFEZIONE'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Nutri.muted,
              letterSpacing: 0.72,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final p in _packagingOptions)
                NutriChip(
                  height: 30,
                  label: Translations.get(lang, p),
                  selected: _packaging == p,
                  onTap: () => setState(() => _packaging = _packaging == p ? '' : p),
                ),
            ],
          ),
          if (netto > 0 && porzioni > 0) ...[
            const SizedBox(height: 11),
            Text(
              '${Translations.get(lang, 'Una porzione è')} ${UnitFormat.p(netto / porzioni)}',
              style: TextStyle(fontSize: 12, color: Nutri.body, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }

  Widget _packField(
    String lang,
    String label,
    TextEditingController ctrl, {
    String? suffix,
    bool numerico = false,
  }) {
    return Container(
      height: 54,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: Nutri.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: Nutri.muted)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  onChanged: (_) => setState(() {}),
                  keyboardType: numerico
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  style: TextStyle(fontSize: 15, color: Nutri.ink),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (suffix != null)
                Text(suffix, style: TextStyle(fontSize: 12.5, color: Nutri.muted)),
            ],
          ),
        ],
      ),
    );
  }

  /// Selettore del pasto, condiviso dai due layout della pagina (form classico
  /// e "Prodotto Trovato"): prima erano due copie separate dello stesso widget,
  /// gia' divergenti fra loro (una aveva l'icona, l'altra no).
  ///
  /// 18/09: foglio dal basso (`NutriSelect`) come tutti gli altri select
  /// dell'app. Prima era un `DropdownMenu`, e prima ancora un
  /// `DropdownButtonFormField` che apriva il menu ancorato alla voce
  /// selezionata invece che al campo. Un foglio non copre mai il campo toccato.
  ///
  /// I valori restano in italiano anche quando l'etichetta e' tradotta:
  /// `meal_type` in na_nutri_entries e' un enum('Colazione','Pranzo','Cena',
  /// 'Snack') e qualsiasi altra stringa verrebbe rifiutata dal database.
  Widget _mealTypeField(BuildContext context, String lang) {
    const meals = ['Colazione', 'Pranzo', 'Cena', 'Snack'];
    return NutriSelect<String>(
      titolo: Translations.get(lang, 'Seleziona Pasto'),
      valore: _selectedMealType,
      segnaposto: Translations.get(lang, 'meal_pick_hint'),
      icona: _mealTypeIcon(_selectedMealType),
      // Il messaggio compare solo dopo un tentativo di salvataggio, come per
      // gli altri campi obbligatori di questo Form.
      errore: _mealMissing ? Translations.get(lang, 'meal_pick_required') : null,
      opzioni: [
        for (final m in meals) NutriOpzione(m, Translations.get(lang, m), icona: _mealTypeIcon(m)),
      ],
      onCambiato: (v) => setState(() {
        _selectedMealType = v;
        _mealMissing = false;
      }),
    );
  }

  /// Stessa mappa icona/pasto gia' stabilita in home_page.dart e
  /// meal_detail_page.dart (Colazione/Pranzo/Cena/Snack).
  IconData _mealTypeIcon(String? mealType) {
    switch (mealType) {
      case 'Colazione':
        return Icons.coffee;
      case 'Pranzo':
        return Icons.dinner_dining;
      case 'Cena':
        return Icons.ramen_dining;
      case 'Snack':
        return Icons.cookie;
      default:
        return Icons.restaurant;
    }
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  /// Segmentato "Per 100 g / Per porzione" (mockup Manual Entry): stabilisce
  /// a cosa si riferiscono i valori digitati sotto — quelli letti da
  /// un'etichetta reale sono quasi sempre per 100 g, non per la porzione
  /// pesata. Al salvataggio (_handleSave) i valori "per 100g" vengono scalati
  /// per il peso della porzione; "per porzione" restano quelli scritti,
  /// comportamento identico a prima dell'introduzione del toggle.
  /// "Una porzione pesa ___ g" sotto il selettore, con i valori per porzione
  /// (15/09). Il peso mangiato resta nel suo campo: se questo e' ancora vuoto,
  /// si riempie con la porzione, che e' il caso piu' comune.
  Widget _campoPesoPorzione(String lang) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NutrientInputField(
            key: const Key('peso_porzione'),
            label: Translations.get(lang, 'portion_weight_label'),
            hint: UnitFormat.pValore(30),
            suffix: UnitFormat.pSigla,
            controller: _portionWeightController,
            outlined: true,
            onChanged: (testo) => setState(() {
              if (_weightController.text.trim().isEmpty) _weightController.text = testo;
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              Translations.get(lang, 'portion_weight_help'),
              style: TextStyle(fontSize: 12, color: Nutri.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionBasisToggle(String lang) {
    final scheme = Theme.of(context).colorScheme;
    Widget segment(String key, String label) {
      final bool active = _nutritionBasis == key;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _nutritionBasis = key),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          segment('100g', Translations.get(lang, 'nutrition_basis_100g')),
          const SizedBox(width: 4),
          segment('portion', Translations.get(lang, 'nutrition_basis_portion')),
        ],
      ),
    );
  }

  Widget _buildExpandableSection(
    String title,
    IconData icon,
    Color color,
    List<NutrientFieldConfig> configs,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: NutrientGroup(title: '', configs: configs, outlined: true),
          ),
        ],
      ),
    );
  }

  /// Come _buildExpandableSection, ma per la vista "Prodotto Trovato": nasconde
  /// l'intera sezione se, fuori dalla modalità modifica, nessuno dei suoi
  /// campi ha un valore diverso da zero (richiesta 2026-07-24 — "nascondere
  /// eventualmente anche intere sezioni se tutto a 0"). In modalità modifica
  /// mostra sempre tutto, campi vuoti compresi, per poterli compilare.
  Widget _buildFilteredSection(
    String title,
    IconData icon,
    Color color,
    List<NutrientFieldConfig> configs,
  ) {
    final visible = _visibleConfigs(configs);
    if (visible.isEmpty) return const SizedBox.shrink();
    return _buildExpandableSection(title, icon, color, visible);
  }

  List<NutrientFieldConfig> _getVitaminConfigs(String lang, {bool? readOnlyOverride}) {
    final bool ro = readOnlyOverride ?? (widget.isAddingFromLibrary && !_isDataIncomplete);
    return [
      _manager.getConfig(
        'vit_a',
        label: Translations.get(lang, 'Vitamina A'),
        suffix: 'µg',
        readOnly: ro,
      ),
      _manager.getConfig(
        'vit_b1',
        label: Translations.get(lang, 'Vitamina B1'),
        suffix: 'mg',
        readOnly: ro,
      ),
      _manager.getConfig(
        'vit_b2',
        label: Translations.get(lang, 'Vitamina B2'),
        suffix: 'mg',
        readOnly: ro,
      ),
      _manager.getConfig(
        'vit_b3',
        label: Translations.get(lang, 'Vitamina B3'),
        suffix: 'mg',
        readOnly: ro,
      ),
      _manager.getConfig(
        'vit_b5',
        label: Translations.get(lang, 'Vitamina B5'),
        suffix: 'mg',
        readOnly: ro,
      ),
      _manager.getConfig(
        'vit_b6',
        label: Translations.get(lang, 'Vitamina B6'),
        suffix: 'mg',
        readOnly: ro,
      ),
      _manager.getConfig(
        'vit_b7',
        label: Translations.get(lang, 'Vitamina B7'),
        suffix: 'µg',
        readOnly: ro,
      ),
      _manager.getConfig(
        'vit_b9',
        label: Translations.get(lang, 'Vitamina B9'),
        suffix: 'µg',
        readOnly: ro,
      ),
      _manager.getConfig(
        'vit_b11',
        label: Translations.get(lang, 'Vitamina B11'),
        suffix: 'µg',
        readOnly: ro,
      ),
      _manager.getConfig(
        'vit_b12',
        label: Translations.get(lang, 'Vitamina B12'),
        suffix: 'µg',
        readOnly: ro,
      ),
      _manager.getConfig(
        'vit_c',
        label: Translations.get(lang, 'Vitamina C'),
        suffix: 'mg',
        readOnly: ro,
      ),
      _manager.getConfig(
        'vit_d',
        label: Translations.get(lang, 'Vitamina D'),
        suffix: 'µg',
        readOnly: ro,
      ),
      _manager.getConfig(
        'vit_e',
        label: Translations.get(lang, 'Vitamina E'),
        suffix: 'mg',
        readOnly: ro,
      ),
      _manager.getConfig(
        'vit_k',
        label: Translations.get(lang, 'Vitamina K'),
        suffix: 'µg',
        readOnly: ro,
      ),
      _manager.getConfig(
        'biotin',
        label: Translations.get(lang, 'Biotina'),
        suffix: 'µg',
        readOnly: ro,
      ),
    ];
  }

  List<NutrientFieldConfig> _getMineralConfigs({bool? readOnlyOverride}) {
    final lang = ref.watch(appSettingsProvider).language;
    final bool ro = readOnlyOverride ?? (widget.isAddingFromLibrary && !_isDataIncomplete);
    const microKeys = {'arsenic', 'chromium', 'cobalt', 'iodine', 'molybdenum', 'selenium', 'vanadium'};
    // Mappa chiave API → chiave di traduzione italiana
    const labelMap = {
      'sodium': 'Sodio',
      'arsenic': 'Arsenico',
      'boron': 'Boro',
      'calcium': 'Calcio',
      'chloride': 'Cloruro',
      'choline': 'Colina',
      'chromium': 'Cromo',
      'cobalt': 'Cobalto',
      'copper': 'Rame',
      'fluoride': 'Fluoruro',
      'fluorine': 'Fluoro',
      'iodine': 'Iodio',
      'iron': 'Ferro',
      'magnesium': 'Magnesio',
      'manganese': 'Manganese',
      'molybdenum': 'Molibdeno',
      'phosphorus': 'Fosforo',
      'potassium': 'Potassio',
      'selenium': 'Selenio',
      'silicon': 'Silicio',
      'sulfur': 'Zolfo',
      'tin': 'Stagno',
      'vanadium': 'Vanadio',
      'zinc': 'Zinco',
    };
    return labelMap.entries
        .map(
          (e) => _manager.getConfig(
            e.key,
            label: Translations.get(lang, e.value),
            suffix: microKeys.contains(e.key) ? 'µg' : 'mg',
            readOnly: ro,
          ),
        )
        .toList();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      // Il campo bocciato e' quasi sempre il nome, in cima, mentre si salva
      // dal fondo della pagina: senza riportarcisi sembrava che il pulsante
      // non facesse niente (test di release 19/09).
      final campo = _nomeKey.currentContext;
      if (campo != null) {
        await Scrollable.ensureVisible(campo,
            duration: const Duration(milliseconds: 300), alignment: 0.2);
      }
      return;
    }

    // Il pasto non e' un campo del Form (e' un DropdownMenu, non un
    // TextFormField), quindi `validate()` non lo vede: va controllato qui.
    if (_mealRequired && _selectedMealType == null) {
      final lang = ref.read(appSettingsProvider).language;
      setState(() => _mealMissing = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Translations.get(lang, 'meal_pick_required'))),
      );
      return;
    }

    // Nudge 2026-07-24: se l'utente ha attivato la modalità modifica (quindi
    // ha potenzialmente personalizzato i valori) ma non ha attivato "salva
    // libreria", chiediamo prima di procedere se vuole comunque salvarlo per
    // ritrovarlo più tardi. Non ha senso chiederlo se si sta già modificando
    // direttamente un alimento di libreria (isEditingMaster).
    if (_isEditMode && !_saveToLibrary && !widget.isEditingMaster && mounted) {
      final wantsSave = await _askSaveToLibrary();
      if (wantsSave == true && mounted) {
        setState(() => _saveToLibrary = true);
      }
    }

    final user = ref.read(userProvider);
    if (user == null) return;

    setState(() => _isSaving = true);

    final Map<String, dynamic> data = Map<String, dynamic>.from(
      _manager.getValues(),
    );
    // Se i valori sono stati digitati "per 100g" (toggle sopra il campo
    // Calorie), li scaliamo qui al peso reale della porzione prima di
    // salvare — l'etichetta di un prodotto reale e' quasi sempre per 100g,
    // ma na_nutri_entries registra sempre il totale della porzione.
    final scale = _basisScale;
    if (scale != 1.0) {
      data.updateAll((key, value) => value is num ? value * scale : value);
    }
    data['food_name'] = _nameController.text;
    data['weight_g'] = _pesoGrammi;
    data['user_mail'] = user.email;
    data['meal_type'] = _selectedMealType;
    data['barcode'] = _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim();
    data['entry_date'] = (widget.foodEntry?.entry_date ?? momentoVoce(widget.dataVoce))
        .toIso8601String();
    // FIX 2026-07-24: _manager.getValues() ha solo i nutrienti numerici. Se
    // il prodotto arriva da na_off_products, senza questo merge i metadati
    // (Nutri-Score, NOVA, allergeni, ecc.) andavano persi non appena
    // diventava un ingrediente di ricetta o un CustomFood — mai arrivavano
    // nemmeno a RecipeIngredient.fromJson/CustomFood.fromJson qui sotto.
    if (widget.prefillData != null) {
      const offMetaKeys = [
        'nutriscore_grade', 'nova_group', 'environmental_score_grade',
        'additives_n', 'allergens', 'labels',
        'palm_oil_n', 'palm_oil_maybe_n', 'image_url', 'serving_size',
        'categories', 'manufacturing_places', 'ingredients',
        'alcohol_percent', 'caffeine',
      ];
      for (final key in offMetaKeys) {
        if (widget.prefillData!.containsKey(key)) {
          data[key] = widget.prefillData![key];
        }
      }
    }
    // Personalizzazioni dell'utente: scritte DOPO il merge dei metadati OFF,
    // così vincono su quelle originali del prodotto invece di essere
    // sovrascritte.
    data['image_url'] = _imageUrlController.text.trim();
    data['description'] = _descriptionController.text.trim();
    // Allergeni ed etichette vengono ricostruiti dai chip mostrati a schermo
    // (fix 2026-07-24): prima il merge qui sopra rimetteva i valori originali
    // del prodotto, quindi togliere o aggiungere un allergene sembrava
    // funzionare ma la modifica andava persa al salvataggio, in silenzio.
    // `_otherLabels` conserva le etichette senza chip (es. "biologico"),
    // altrimenti sparirebbero.
    data['allergens'] = _allergenChips.join(', ');
    data['labels'] = [..._dietLabelChips, ..._otherLabels].join(', ');
    // Campi nuovi del 2026-08-30. Scritti DOPO il merge dei metadati OFF, come
    // allergeni ed etichette: cio' che l'utente ha digitato vince su cio' che
    // arrivava dal prodotto originale.
    data['brand'] = _brandController.text.trim();
    data['quantity'] = _quantityController.text.trim();
    data['ingredients'] = _ingredientsController.text.trim();
    data['manufacturing_places'] = _originController.text.trim();
    data['packaging'] = _packaging;
    data['additives_tags'] = _additiveFamilies.join(', ');
    // Il numero degli additivi segue le famiglie scelte (15/09): prima restava
    // quello del prodotto di partenza (o 0), e l'alimento salvato mostrava "—"
    // anche con tre famiglie spuntate.
    if (_additiveFamilies.isNotEmpty) {
      data['additives_n'] = _additiveFamilies.where((a) => a != 'Nessuno dichiarato').length;
    }
    if (_selectedCategory.isNotEmpty) data['categories'] = _selectedCategory;
    if (_manualNutri.isNotEmpty) data['nutriscore_grade'] = _manualNutri;
    if (_manualNova > 0) data['nova_group'] = _manualNova;
    // Olio di palma: le due colonne di OpenFoodFacts sono conteggi, non un
    // enum, quindi la scelta a tre stati va tradotta in quella coppia.
    data['palm_oil_n'] = _palmIndex == 3 ? 1 : 0;
    data['palm_oil_maybe_n'] = _palmIndex == 2 ? 1 : 0;
    // Vuoti come null, non come 0: 0 porzioni non vuol dire "non lo so".
    final netto = double.tryParse(_netQtyController.text.replaceAll(',', '.'));
    final porzioni = int.tryParse(_servingsController.text.trim());
    data['net_quantity_g'] = netto;
    data['servings'] = porzioni;
    data['best_before'] = _bestBefore == null
        ? null
        : '${_bestBefore!.year.toString().padLeft(4, '0')}-${_bestBefore!.month.toString().padLeft(2, '0')}-${_bestBefore!.day.toString().padLeft(2, '0')}';
    if (widget.returnAsIngredient) {
      final ingredient = RecipeIngredient.fromJson(data);
      if (_saveToLibrary) {
        if (mounted) {
          final customFood = CustomFood.fromJson({
            ...data,
            'base_weight_g': data['weight_g'],
          });
          _libreriaFallita = !await ApiServices.saveCustomFood(customFood);
        }
      }
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context, ingredient);
      }
      return;
    }

    bool success;
    if (widget.isEditingMaster) {
      data['id'] = widget.prefillData?['id'];
      data['base_weight_g'] = data['weight_g'];
      final customFood = CustomFood.fromJson(data);
      success = await ApiServices.saveCustomFood(customFood);
    } else {
      // FIX 2026-08-29: in modifica la mappa non ha MAI avuto 'id'
      // (_manager.getValues() restituisce solo i nutrienti numerici, e nessuno
      // lo aggiungeva dopo). FoodEntry.toJson() scrive l'id solo se non nullo,
      // quindi la richiesta partiva senza e update_entry.php rispondeva "Dati o
      // ID mancanti": nessuna modifica di una voce di diario e' mai stata
      // salvata — il sintomo riportato ("non riesco a cambiare il pasto") era
      // solo il campo su cui ce ne si e' accorti. Stesso schema del ramo
      // isEditingMaster qui sopra, che l'id lo passava gia'.
      if (widget.foodEntry?.id != null) data['id'] = widget.foodEntry!.id;
      final entry = FoodEntry.fromJson(data);
      success = widget.foodEntry != null
          ? await ApiServices.updateFoodEntry(entry)
          : await ApiServices.sendFoodEntry(entry);
          
      if (success && _saveToLibrary && widget.foodEntry == null) {
        data['base_weight_g'] = data['weight_g'];
        final customFood = CustomFood.fromJson(data);
        // L'esito non si butta piu' via (2026-09-09): la voce di diario puo'
        // riuscire e la copia in libreria no, e prima l'utente vedeva solo
        // "salvato" per poi non ritrovare l'alimento fra i suoi. Due
        // operazioni, due esiti: vanno detti tutti e due.
        _libreriaFallita = !await ApiServices.saveCustomFood(customFood);
      }
    }
    
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        if (_libreriaFallita) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(Translations.get(
                ref.read(appSettingsProvider).language, 'library_save_failed')),
            backgroundColor: Nutri.danger,
            duration: const Duration(seconds: 5),
          ));
        }
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Translations.get(ref.read(appSettingsProvider).language, 'Errore durante il salvataggio')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scanBarcode() async {
    try {
      final result = await BarcodeScanner.scan();
      if (result.type == ResultType.Barcode) {
        setState(() {
          _barcodeController.text = result.rawContent;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Translations.get(ref.read(appSettingsProvider).language, 'Errore durante la scansione'))),
        );
      }
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }
}
