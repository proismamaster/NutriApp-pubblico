import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutriapp/domain/user_provider.dart';
import 'package:nutriapp/screens/manual_entry_page.dart';
import '../models/recipe.dart';
import '../models/fats.dart';
import '../models/macronutrients.dart';
import '../models/recipe_ingredient.dart';
import 'entry_menu_page.dart';
import '../services/api_services.dart';
import '../dictionary/translations.dart';
import '../logic/portion_parser.dart';
import '../logic/unit_format.dart';
import '../providers/locale_provider.dart';
import 'dart:io';

import 'package:image_picker/image_picker.dart';

import '../widgets/auth_style.dart';
import '../widgets/modern_loader.dart';

class CreaRicettaPage extends ConsumerStatefulWidget {
  final Recipe? initialRecipe;
  const CreaRicettaPage({super.key, this.initialRecipe});

  @override
  ConsumerState<CreaRicettaPage> createState() => CreaRicettaPageState();
}

class CreaRicettaPageState extends ConsumerState<CreaRicettaPage> {
  late TextEditingController _nameController;
  late TextEditingController _portionController;
  late TextEditingController _notesController;
  /// Foto della ricetta (2026-08-30, punto 13 del backlog).
  late TextEditingController _imageController;
  List<RecipeIngredient> _ingredients = [];
  bool _isSaving = false;

  /// Motivo dell'ultimo salvataggio fallito, come lo racconta il server.
  String? _ultimoErrore;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialRecipe?.name ?? '',
    );
    _portionController = TextEditingController(
      text: widget.initialRecipe?.portion ?? '',
    );
    _notesController = TextEditingController(
      text: widget.initialRecipe?.notes ?? '',
    );
    _imageController = TextEditingController(
      text: widget.initialRecipe?.imageUrl ?? '',
    );
    if (widget.initialRecipe != null) {
      _ingredients = List.from(widget.initialRecipe!.ingredients);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _portionController.dispose();
    _notesController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  void _navigateAndAddIngredient() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EntryMenuPage(returnAsIngredient: true),
      ),
    );
    if (result != null && result is RecipeIngredient) {
      setState(() {
        _ingredients.add(result);
      });
    }
  }

  Future<void> _saveRecipe(String lang) async {
    final userEmail = ref.read(userProvider)?.email ?? '';
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Translations.get(lang, 'Inserisci il nome della ricetta'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    final newRecipe = Recipe(
      id: widget.initialRecipe?.id,
      name: _nameController.text,
      portion: _portionController.text,
      notes: _notesController.text,
      ingredients: _ingredients,
      imageUrl: _imageController.text.trim(),
      // La stella non si tocca da qui: senza questo, salvare una modifica
      // toglieva la ricetta dai preferiti (test di release 19/09).
      isFavorite: widget.initialRecipe?.isFavorite ?? false,
    );

    bool success;
    if (widget.initialRecipe != null) {
      final esito = await ApiServices.updateRecipeDetailed(userEmail, newRecipe);
      success = esito.ok;
      _ultimoErrore = esito.errore;
    } else {
      final esito = await ApiServices.saveRecipeDetailed(newRecipe, userEmail);
      success = esito.ok;
      _ultimoErrore = esito.errore;
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        // Il messaggio del server dice quale colonna o quale vincolo ha
        // fallito: mostrarlo com'e' vale piu' di un generico "errore", che
        // costringe a indovinare.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _ultimoErrore == null
                  ? Translations.get(lang, 'Errore salvataggio ricetta')
                  : '${Translations.get(lang, 'Errore salvataggio ricetta')}: $_ultimoErrore',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFB4553C),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  Future<void> _showEditDialog(int index, RecipeIngredient current) async {
    // FIX 2026-07-24: prima si ricostruiva prefillData a mano campo per
    // campo (e con un bug proprio: 'base_weight_g' veniva letto da
    // current.unit, che è 'g'/'ml', non un peso), perdendo ogni metadato
    // OpenFoodFacts (Nutri-Score, allergeni, ecc.) alla riapertura per
    // modificare un ingrediente già aggiunto. Ora si riusa current.toJson(),
    // che è già completo e resta sincronizzato automaticamente se
    // RecipeIngredient guadagna altri campi in futuro.
    final Map<String, dynamic> prefillData = {
      ...current.toJson(),
      'base_weight_g': current.weight_g,
    };

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManualEntryPage(
          prefillData: prefillData,
          returnAsIngredient: true,
          isAddingFromLibrary: true,
        ),
      ),
    );

    if (result != null && result is RecipeIngredient) {
      setState(() {
        _ingredients[index] = result;
      });
    }
  }

  // ===================== mockup "NutriApp Edit Recipe" (30/08) =====================

  /// Indice dell'ingrediente con il pannello peso aperto, -1 se nessuno.
  int _editingIngredient = -1;

  /// Un ingrediente e' "generico" quando non porta valori nutrizionali: nessun
  /// peso e nessuna caloria.
  ///
  /// PERCHE' COSI' E NON CON UN CAMPO NUOVO: e' esattamente cio' che
  /// l'ingrediente E', non un'etichetta appiccicata sopra — e non richiede una
  /// colonna in piu' su na_recipe_ingredients ne' una migrazione. Un
  /// ingrediente con valori veri non puo' finire qui per sbaglio: basta una
  /// caloria o un grammo per uscirne.
  static bool _eGenerico(RecipeIngredient i) => i.weight_g <= 0;

  /// Generico a cui l'utente ha dato una stima: entra nei totali, ma va
  /// mostrato come stima e non come dato letto da un'etichetta.
  static bool _eStimato(RecipeIngredient i) =>
      _eGenerico(i) && i.macro.calories > 0;

  int get _portions {
    final n = int.tryParse(_portionController.text.trim());
    return (n == null || n < 1) ? 1 : n;
  }

  void _setPortions(int v) {
    setState(() => _portionController.text = v.clamp(1, 24).toString());
  }

  double get _totalKcal =>
      _ingredients.fold<double>(0, (a, i) => a + i.macro.calories);
  double get _totalCarbs =>
      _ingredients.fold<double>(0, (a, i) => a + i.macro.carbs);
  double get _totalProteins =>
      _ingredients.fold<double>(0, (a, i) => a + i.macro.proteins);
  double get _totalFats =>
      _ingredients.fold<double>(0, (a, i) => a + i.macro.fats);

  /// Quota energetica dei tre macro, usata sia dalla barra sia dalle
  /// percentuali. Il denominatore sono le kcal RICAVATE dai macro (4/4/9), non
  /// quelle dichiarate: sommare percentuali su una base diversa da quella che
  /// le genera darebbe barre che non arrivano al 100%.
  double get _macroKcal {
    final k = _totalCarbs * 4 + _totalProteins * 4 + _totalFats * 9;
    return k <= 0 ? 1 : k;
  }

  /// Cambia il peso di un ingrediente riproporzionando i suoi valori.
  ///
  /// I nutrienti di un RecipeIngredient sono gia' il TOTALE per il peso
  /// indicato (li scala manual_entry_page al momento del salvataggio), quindi
  /// per cambiare il peso vanno riscalati tutti insieme: senza, la card
  /// mostrerebbe 250 g con le calorie dei 100 g di prima.
  void _setIngredientWeight(int index, double nuovoPeso) {
    final ing = _ingredients[index];
    final vecchio = ing.weight_g;
    if (vecchio <= 0 || nuovoPeso <= 0) return;
    final k = nuovoPeso / vecchio;
    final j = ing.toJson();
    for (final chiave in j.keys.toList()) {
      final v = j[chiave];
      if (v is num && chiave != 'weight_g') j[chiave] = v * k;
    }
    j['weight_g'] = nuovoPeso;
    setState(() => _ingredients[index] = RecipeIngredient.fromJson(j));
  }

  Widget _buildRecipeHeader(String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Nutri.green, size: 25),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: Text(
              widget.initialRecipe == null
                  ? Translations.get(lang, 'Crea Ricetta')
                  : Translations.get(lang, 'Modifica Ricetta'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Nutri.green,
                letterSpacing: -0.2,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: widget.initialRecipe == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFB4553C), size: 22),
                    onPressed: _confirmDelete,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final lang = ref.read(appSettingsProvider).language;
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.get(lang, 'Elimina ricetta')),
        content: Text(Translations.get(lang, 'La ricetta verrà eliminata definitivamente.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Translations.get(lang, 'Annulla')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              Translations.get(lang, 'Elimina'),
              style: const TextStyle(color: Color(0xFFB4553C)),
            ),
          ),
        ],
      ),
    );
    if (conferma != true || !mounted) return;
    setState(() => _isSaving = true);
    final ok = await ApiServices.deleteRecipe(
      ref.read(userProvider)?.email ?? '',
      widget.initialRecipe!.id ?? '',
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Translations.get(lang, 'Errore salvataggio ricetta')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Card di un ingrediente, con il pannello peso che si apre sotto.
  Widget _buildIngredientCard(int index, String lang) {
    final unitaE = ref.watch(appSettingsProvider).energyUnit;
    final unitaP = ref.watch(appSettingsProvider).weightUnit;
    final ing = _ingredients[index];
    final aperto = _editingIngredient == index;
    final grade = ing.nutriscoreGrade.toLowerCase().trim();
    final nutriColor = Nutri.nutriScore[grade];
    final generico = _eGenerico(ing);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Nutri.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Nutri.fieldBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ing.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Nutri.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Il bollino compare solo per un voto vero (a-e):
                        // OpenFoodFacts scrive 'unknown' invece di lasciare
                        // vuoto, e disegnarlo darebbe un bollino senza senso.
                        if (nutriColor != null) ...[
                          Container(
                            height: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: nutriColor,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              grade.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Nutri.fgOnScore(nutriColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            generico && !_eStimato(ing)
                                ? Translations.get(lang, 'Generico, non conteggiato')
                                // Nomi per esteso invece delle sole iniziali:
                                // "54 C · 6 P · 21 G" non si legge, e la
                                // stessa lettera cambia significato da lingua
                                // a lingua (in inglese Fats, in italiano
                                // Grassi).
                                : '${UnitFormat.p(ing.macro.carbs)} ${Translations.get(lang, 'Carboidrati')} · '
                                    '${UnitFormat.p(ing.macro.proteins)} ${Translations.get(lang, 'Proteine')} · '
                                    '${UnitFormat.p(ing.macro.fats)} ${Translations.get(lang, 'Grassi')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    generico && !_eStimato(ing)
                        ? '—'
                        : UnitFormat.energy(ing.macro.calories, unitaE),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: (generico && !_eStimato(ing)) ? Nutri.hint : Nutri.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    generico
                        ? (_eStimato(ing)
                            ? '${ing.unit} · ${Translations.get(lang, 'stimato')}'
                            : ing.unit)
                        : UnitFormat.weight(ing.weight_g, unitaP),
                    style: TextStyle(fontSize: 11.5, color: Nutri.mutedSoft),
                  ),
                ],
              ),
              // Su un generico non c'e' un peso da riproporzionare: aprire il
              // pannello mostrerebbe campi che non fanno niente.
              if (!generico)
                IconButton(
                  icon: Icon(
                    aperto ? Icons.expand_less : Icons.edit_outlined,
                    size: 19,
                    color: Nutri.green,
                  ),
                  onPressed: () => setState(
                    () => _editingIngredient = aperto ? -1 : index,
                  ),
                ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: Nutri.hint),
                onPressed: () => setState(() {
                  _ingredients.removeAt(index);
                  _editingIngredient = -1;
                }),
              ),
            ],
          ),
          if (aperto && !generico) ...[
            Divider(height: 24, thickness: 1, color: Nutri.divider),
            Row(
              children: [
                Text(
                  Translations.get(lang, 'Peso'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Nutri.body,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Nutri.fieldBorder, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: ValueKey('peso_$index${ing.weight_g}'),
                            controller: TextEditingController(
                              text: UnitFormat.pValore(ing.weight_g),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Nutri.ink,
                            ),
                            decoration: const InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                            ),
                            onSubmitted: (v) {
                              final p = double.tryParse(v.replaceAll(',', '.'));
                              if (p != null) _setIngredientWeight(index, UnitFormat.aGrammi(p));
                            },
                          ),
                        ),
                        Text(UnitFormat.pSigla, style: TextStyle(fontSize: 13, color: Nutri.mutedSoft)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                for (final p in const [50.0, 100.0, 250.0]) ...[
                  GestureDetector(
                    onTap: () => _setIngredientWeight(index, p),
                    child: Container(
                      height: 38,
                      margin: const EdgeInsets.only(left: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FBF6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Nutri.fieldBorder),
                      ),
                      child: Text(
                        UnitFormat.p(p),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Nutri.green,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _showEditDialog(index, ing),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  Translations.get(lang, 'Modifica tutti i valori'),
                  style: TextStyle(fontSize: 12.5, color: Nutri.green),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Riepilogo della ricetta intera: kcal totali, barra dei macro e voto
  /// nutrizionale STIMATO.
  Widget _buildRecipeSummary(String lang) {
    final unitaE = ref.watch(appSettingsProvider).energyUnit;
    final shares = [
      (
        label: Translations.get(lang, 'Carboidrati'),
        grams: _totalCarbs,
        quota: (_totalCarbs * 4) / _macroKcal,
        color: const Color(0xFF1B7A33),
      ),
      (
        label: Translations.get(lang, 'Proteine'),
        grams: _totalProteins,
        quota: (_totalProteins * 4) / _macroKcal,
        color: const Color(0xFF4E9A6B),
      ),
      (
        label: Translations.get(lang, 'Grassi'),
        grams: _totalFats,
        quota: (_totalFats * 9) / _macroKcal,
        color: const Color(0xFFE0A81E),
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Nutri.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Nutri.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  Translations.get(lang, 'Ricetta intera'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Nutri.ink),
                ),
              ),
              Text(
                UnitFormat.energy(_totalKcal, unitaE),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Nutri.ink),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (final s in shares)
                    Expanded(
                      flex: (s.quota * 1000).round().clamp(0, 1000),
                      child: Container(color: s.color),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final s in shares)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              s.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: Nutri.mutedSoft),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        UnitFormat.p(s.grams),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Nutri.ink),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Divider(height: 26, thickness: 1, color: Nutri.divider),
          // STIMA, non un voto ufficiale: il mockup disegna un bollino
          // identico a quello vero, ma la regola del progetto (DATA-QUALITY-PLAN
          // §5-bis) e' che una predizione non si mostra mai come dato certo.
          // Qui resta grigio con la parola "stimato" davanti.
          Row(
            children: [
              Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Nutri.divider,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${Translations.get(lang, 'stimato')} ${_estimatedGrade()}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Nutri.body),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  Translations.get(lang, 'Calcolato dagli ingredienti che hai elencato, non è un Nutri-Score ufficiale.'),
                  style: TextStyle(fontSize: 12.5, color: Nutri.muted, height: 1.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Voto indicativo A-E dalla quota di grassi e dalle proteine, stessa
  /// formula del mockup. Non e' l'algoritmo ufficiale Nutri-Score: per questo
  /// e' etichettato "stimato" e disegnato in grigio.
  String _estimatedGrade() {
    if (_totalKcal <= 0) return '—';
    final quotaGrassi = (_totalFats * 9) / _macroKcal;
    if (quotaGrassi > 0.45) return 'D';
    if (quotaGrassi > 0.32) return 'C';
    return _totalProteins / (_totalKcal / 100) > 4 ? 'A' : 'B';
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    final vuota = _ingredients.isEmpty;
    final perPorzione = vuota ? null : (_totalKcal / _portions).round();
    final puoSalvare = _nameController.text.trim().isNotEmpty && !vuota;
    final unitaE = ref.watch(appSettingsProvider).energyUnit;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Nutri.bg,
          body: SafeArea(
            child: Column(
              children: [
                _buildRecipeHeader(lang),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _fotoRicetta(lang),
                        const SizedBox(height: 16),
                        NutriFieldLabel(Translations.get(lang, 'Nome ricetta')),
                        NutriField(
                          controller: _nameController,
                          icon: Icons.restaurant,
                          hint: Translations.get(lang, 'Es. Zuppa di lenticchie'),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  NutriFieldLabel(Translations.get(lang, 'Porzioni')),
                                  Container(
                                    height: 52,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Nutri.card,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Nutri.fieldBorder, width: 1.5),
                                    ),
                                    child: Row(
                                      children: [
                                        _portionButton(Icons.remove, () => _setPortions(_portions - 1)),
                                        Expanded(
                                          child: Text(
                                            '$_portions',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: Nutri.ink,
                                            ),
                                          ),
                                        ),
                                        _portionButton(Icons.add, () => _setPortions(_portions + 1)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  NutriFieldLabel(Translations.get(lang, 'Per porzione')),
                                  Container(
                                    height: 52,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Nutri.surfaceSoft,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Color(0xFFE2E9DA), width: 1.5),
                                    ),
                                    child: Text(
                                      perPorzione == null
                                          ? '—'
                                          : UnitFormat.energy(perPorzione.toDouble(), unitaE),
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: perPorzione == null ? Nutri.hint : Nutri.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        NutriFieldLabel(
                          Translations.get(lang, 'Procedimento / Note'),
                          trailing: Translations.get(lang, '(facoltativo)'),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Nutri.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Nutri.fieldBorder, width: 1.5),
                          ),
                          child: TextField(
                            controller: _notesController,
                            minLines: 3,
                            maxLines: 6,
                            style: TextStyle(fontSize: 15, height: 1.5, color: Nutri.ink),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: Translations.get(lang, 'Passaggi, tempi di cottura, note…'),
                              hintStyle: TextStyle(color: Nutri.hint, fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                Translations.get(lang, 'Ingredienti'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Nutri.ink,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            // Due strade per aggiungere: un alimento vero
                            // (con i suoi valori) oppure un ingrediente
                            // generico, per quando la ricetta non richiede
                            // proprio quel prodotto specifico.
                            GestureDetector(
                              onTap: _aggiungiGenerico,
                              child: Container(
                                height: 34,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Nutri.card,
                                  borderRadius: BorderRadius.circular(17),
                                  border: Border.all(color: const Color(0xFFC3D8BA), width: 1.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.eco_outlined, size: 17, color: Nutri.green),
                                    const SizedBox(width: 5),
                                    Text(
                                      Translations.get(lang, 'Generico'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Nutri.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _navigateAndAddIngredient,
                              child: Container(
                                height: 34,
                                padding: const EdgeInsets.fromLTRB(10, 0, 13, 0),
                                decoration: BoxDecoration(
                                  color: Nutri.greenFill,
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 19, color: Nutri.onGreenFill),
                                    const SizedBox(width: 6),
                                    Text(
                                      Translations.get(lang, 'Aggiungi'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Nutri.card,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (vuota)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFD5DECC), width: 1.5),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.shopping_basket_outlined, size: 30, color: Color(0xFFBAC4B4)),
                                const SizedBox(height: 10),
                                Text(
                                  Translations.get(lang, 'Nessun ingrediente ancora aggiunto'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Nutri.label,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  Translations.get(lang, 'Aggiungi gli ingredienti con il loro peso: calorie e macro per porzione li calcola NutriApp.'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft, height: 1.5),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          for (var i = 0; i < _ingredients.length; i++) _buildIngredientCard(i, lang),
                          _buildRecipeSummary(lang),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  decoration: BoxDecoration(
                    color: Nutri.bg,
                    border: Border(top: BorderSide(color: Nutri.disabledBg)),
                  ),
                  child: NutriPrimaryButton(
                    label: puoSalvare
                        ? Translations.get(lang, 'Salva')
                        : Translations.get(lang, 'Aggiungi nome e ingredienti'),
                    icon: puoSalvare ? Icons.save : Icons.info_outline,
                    iconFirst: true,
                    height: 52,
                    enabled: puoSalvare,
                    onTap: () {
                      if (puoSalvare) _saveRecipe(lang);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isSaving)
          VeloDiCaricamento(messaggio: Translations.get(lang, 'Salvataggio in corso...')),
      ],
    );
  }

  /// Controller dei valori stimati, tenuti vivi finche' il foglio e' aperto.
  final Map<String, TextEditingController> _stima = {};

  /// Campi proposti per la stima: macro prima, dettaglio dopo. Stessi nomi e
  /// stesse unita' dell'inserimento manuale, cosi' chi ha gia' compilato
  /// quella schermata ritrova le stesse etichette.
  static const List<(String, String, String)> _definizioneStima = [
    ('calories', 'Calorie', 'kcal'),
    ('carbs', 'Carboidrati', 'g'),
    ('proteins', 'Proteine', 'g'),
    ('fats', 'Grassi', 'g'),
    ('fibers', 'Fibre', 'g'),
    ('sugars', 'Zuccheri', 'g'),
    ('water', 'Acqua', 'g'),
    ('saturated_fats', 'Saturi', 'g'),
    ('monounsaturated_fats', 'Monoinsaturi', 'g'),
    ('polyunsaturated_fats', 'Polinsaturi', 'g'),
  ];

  void _preparaCampiStima() {
    for (final c in _stima.values) {
      c.dispose();
    }
    _stima.clear();
    for (final (chiave, _, _) in _definizioneStima) {
      _stima[chiave] = TextEditingController();
    }
  }

  List<({String etichetta, String unita, TextEditingController controller})>
      _campiStima(String lang) => [
            for (final (chiave, etichetta, unita) in _definizioneStima)
              (
                etichetta: Translations.get(lang, etichetta),
                unita: chiave == 'calories'
                    ? UnitFormat.eSigla
                    : (unita == 'g' ? UnitFormat.pSigla : unita),
                controller: _stima[chiave]!,
              ),
          ];

  /// Ingrediente generico: un nome, una quantita' a parole e — se l'utente
  /// vuole — una stima dei valori nutrizionali.
  ///
  /// PERCHE' LA STIMA E' OPZIONALE E DICHIARATA (2026-09-05, richiesta di
  /// Ismail): senza valori la ricetta non puo' dire quante calorie ha, e per
  /// molte ricette gli ingredienti generici sono la maggior parte. Ma un
  /// numero inventato dall'app sarebbe peggio del vuoto. La via di mezzo e'
  /// che il numero lo metta l'UTENTE, sapendo che e' una sua stima: entra nei
  /// totali, e ovunque compaia e' marcato come stimato.
  Future<void> _aggiungiGenerico() async {
    final lang = ref.read(appSettingsProvider).language;
    final nomeCtrl = TextEditingController();
    final qtaCtrl = TextEditingController();
    var conStima = false;
    // Gli stessi gruppi dell'inserimento manuale: macro, poi il resto. Chi
    // stima "verdura mista" di solito conosce solo le calorie, ma chi ha
    // l'etichetta in mano puo' compilare tutto.
    _preparaCampiStima();

    final aggiunto = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Nutri.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Nutri.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  Translations.get(lang, 'Ingrediente generico'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Nutri.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  Translations.get(lang, 'Per quando la ricetta non richiede un prodotto preciso.'),
                  style: TextStyle(fontSize: 12.5, color: Nutri.muted, height: 1.45),
                ),
                const SizedBox(height: 16),
                NutriFieldLabel(Translations.get(lang, 'Nome')),
                NutriField(
                  controller: nomeCtrl,
                  icon: Icons.eco_outlined,
                  hint: Translations.get(lang, 'Es. Verdura mista'),
                  onChanged: (_) => setSheet(() {}),
                ),
                const SizedBox(height: 16),
                NutriFieldLabel(
                  Translations.get(lang, 'Quantità'),
                  trailing: Translations.get(lang, '(facoltativo)'),
                ),
                NutriField(
                  controller: qtaCtrl,
                  hint: Translations.get(lang, 'Es. q.b., 2 cucchiai, un mazzetto'),
                ),
                const SizedBox(height: 18),
                NutriCheckbox(
                  value: conStima,
                  onChanged: (v) => setSheet(() => conStima = v),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Translations.get(lang, 'Stimo io i valori'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Nutri.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Translations.get(lang, 'Entrano nei totali della ricetta, marcati come stima.'),
                        style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft, height: 1.35),
                      ),
                    ],
                  ),
                ),
                if (conStima) ...[
                  const SizedBox(height: 14),
                  // Campi con il NOME PER ESTESO, come nell'inserimento
                  // manuale: "C", "P", "G" non si leggono, e la stessa lettera
                  // vuole dire cose diverse a seconda della lingua (Fats in
                  // inglese, Grassi in italiano).
                  for (final campo in _campiStima(lang)) ...[
                    NutriFieldLabel(campo.etichetta),
                    NutriField(
                      controller: campo.controller,
                      keyboard: const TextInputType.numberWithOptions(decimal: true),
                      suffixText: campo.unita,
                      hint: '0',
                      onChanged: (_) => setSheet(() {}),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: 20),
                NutriPrimaryButton(
                  label: Translations.get(lang, 'Aggiungi'),
                  icon: Icons.add,
                  iconFirst: true,
                  height: 50,
                  enabled: nomeCtrl.text.trim().isNotEmpty,
                  onTap: () {
                    if (nomeCtrl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (aggiunto != true || !mounted) return;
    double v(String chiave) {
      if (!conStima) return 0;
      final n = double.tryParse(_stima[chiave]!.text.replaceAll(',', '.').trim()) ?? 0;
      // Il campo delle calorie mostra cio' che l'utente ha scelto (kcal o kJ),
      // ma nel modello ci vanno sempre kcal.
      if (chiave == 'calories' && UnitFormat.unitaEnergia == 'kj') return n / 4.184;
      // I grammi della stima si scrivono nell'unita' scelta (once comprese).
      if (_definizioneStima.any((d) => d.$1 == chiave && d.$3 == 'g')) return UnitFormat.aGrammi(n);
      return n;
    }
    // Quantita' scritta in grammi ("250 g") su un generico STIMATO: quei
    // grammi entrano nel peso della ricetta. Senza, il peso totale era solo
    // quello degli ingredienti pesati e le calorie per grammo uscivano
    // gonfiate — 137 g di torta valevano 456 kcal invece di 249 (test di
    // release 19/09). Un generico senza stima resta a peso zero: e' quello
    // che lo rende "generico".
    final grammiScritti = conStima ? (parseServingGrams(qtaCtrl.text) ?? 0) : 0.0;
    setState(() {
      _ingredients.add(
        RecipeIngredient(
          name: nomeCtrl.text.trim(),
          weight_g: grammiScritti,
          // `unit` porta la quantita' a parole: e' il campo che il database ha
          // gia' per questo, e resta leggibile anche fuori dall'app.
          unit: qtaCtrl.text.trim().isEmpty
              ? Translations.get(lang, 'q.b.')
              : qtaCtrl.text.trim(),
          macro: Macronutrients(
            calories: v('calories'),
            carbs: v('carbs'),
            proteins: v('proteins'),
            fats: v('fats'),
            fibers: v('fibers'),
            sugars: v('sugars'),
            water: v('water'),
          ),
          fats: Fats(
            saturated: v('saturated_fats'),
            monounsaturated: v('monounsaturated_fats'),
            polyunsaturated: v('polyunsaturated_fats'),
          ),
        ),
      );
    });
  }

  /// Foto della ricetta: si vede se c'e', altrimenti invita ad aggiungerla.
  ///
  /// Come per gli alimenti, chiede un indirizzo immagine e non apre la
  /// galleria: il caricamento di un file richiede un endpoint di upload che
  /// non esiste ancora sul server.
  Widget _fotoRicetta(String lang) {
    final url = _imageController.text.trim();
    return GestureDetector(
      onTap: () => _chiediFoto(lang),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Nutri.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC9D4C1), width: 1.5),
          image: nutriImageProvider(url) == null
              ? null
              : DecorationImage(
                  image: nutriImageProvider(url)!,
                  fit: BoxFit.cover,
                  onError: (_, __) {},
                ),
        ),
        child: nutriImageProvider(url) != null
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
                        Translations.get(lang, 'Aggiungi una foto'),
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Nutri.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        Translations.get(lang, 'Si vedra nella lista delle ricette'),
                        style: TextStyle(fontSize: 12.5, color: Nutri.muted),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  /// Scelta della foto della ricetta: SOLO dalla galleria.
  ///
  /// La richiesta di un indirizzo web e' stata tolta il 2026-09-05: nessuno ha
  /// la foto del proprio piatto gia' pubblicata da qualche parte, e chiederlo
  /// era un ripiego dovuto al fatto che non esisteva un endpoint di
  /// caricamento. Ora esiste (upload_image.php).
  Future<void> _chiediFoto(String lang) async {
    final haFoto = _imageController.text.trim().isNotEmpty;

    if (haFoto) {
      final azione = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
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
        setState(() => _imageController.text = '');
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
      setState(() => _imageController.text = esito.url!);
      return;
    }
    // Il motivo vero, non un generico "non ha funzionato": e' quasi sempre la
    // cartella uploads/ mancante o senza permessi di scrittura.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${Translations.get(lang, 'Foto non caricata')}: ${esito.errore}'),
        backgroundColor: const Color(0xFFB4553C),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// Tondo -/+ dello stepper porzioni.
  Widget _portionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: Nutri.green),
      ),
    );
  }
}
