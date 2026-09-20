import 'package:flutter/material.dart';

import '../widgets/auth_style.dart';

import '../logic/unit_format.dart';
import '../models/recipe.dart';
import '../models/recipe_ingredient.dart';
import '../models/food_entry.dart';
import '../models/macronutrients.dart';
import '../models/fats.dart';
import '../models/vitamins.dart';
import '../models/minerals.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user_provider.dart';
import '../services/api_services.dart';
import '../dictionary/translations.dart';
import '../providers/locale_provider.dart';
import '../models/macro_analysis.dart';
import '../models/macro_totals.dart';
import '../widgets/nutri_select.dart';
import '../widgets/ripartizione_macro.dart';

/// Pagina della ricetta: la stessa sia per guardarla sia per registrarla nel
/// diario.
///
/// PERCHE' UNA SOLA (2026-09-09): ce n'erano DUE. `RecipeViewPage` si apriva
/// dalla scheda Ricette, questa dalla scheda Aggiungi, e mostravano gli stessi
/// dati con due aspetti diversi — Ismail se n'e' accorto subito ("sono per
/// caso due pagine diverse? ha senso questa scelta?"). Due copie della stessa
/// schermata divergono sempre, ed erano gia' divergenti: una era stata
/// adattata al tema scuro e l'altra no, una mostrava le vitamine dell'intera
/// ricetta e l'altra no, e nessuna delle due mostrava la foto.
///
/// Cio' che cambia davvero fra i due usi e' una cosa sola — poter scegliere
/// pasto e quantita' e premere "aggiungi al diario" — ed e' un pezzo in piu',
/// non una schermata in piu': [conAggiuntaAlDiario].
class RecipeDetailPage extends ConsumerStatefulWidget {
  final Recipe recipe;
  final String? initialMealType;

  /// Mostra il blocco pasto/quantita' e il pulsante di registrazione.
  /// false quando la ricetta si sta solo guardando (scheda Ricette).
  final bool conAggiuntaAlDiario;

  /// Il giorno su cui registrare (17/09). `null` = oggi.
  final DateTime? dataVoce;

  const RecipeDetailPage({
    super.key,
    required this.recipe,
    this.initialMealType,
    this.conAggiuntaAlDiario = true,
    this.dataVoce,
  });

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  /// Pasto scelto, `null` finche' l'utente non ne sceglie uno — stessa
  /// scelta fatta in `manual_entry_page.dart` il 2026-09-12: qui valeva
  /// `initialMealType ?? 'Colazione'`, quindi una ricetta aperta dalla
  /// ricerca generale si registrava a colazione per conto proprio.
  String? _selectedMealType;
  bool _mealMissing = false;
  late final TextEditingController _weightController;
  late double _currentWeight;

  /// Peso totale della ricetta = somma dei pesi degli ingredienti.
  ///
  /// E' il denominatore giusto per scalare i valori quando se ne registra una
  /// parte: vedi [_addRecipeToDiary] per il bug che questo campo corregge.
  double get _pesoTotale =>
      widget.recipe.ingredients.fold(0.0, (s, i) => s + i.weight_g);

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.initialMealType;
    // Si parte dalla ricetta intera, non da 100 g fissi: e' la quantita' che
    // l'utente ha davvero davanti, e con un peso totale di 250 g partire da
    // 100 significava proporgli di registrarne due quinti senza motivo.
    _currentWeight = _pesoTotale > 0 ? _pesoTotale : 100.0;
    _weightController = TextEditingController(
      text: UnitFormat.pValore(_currentWeight),
    );
    _weightController.addListener(() {
      final digitato =
          double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 0.0;
      setState(() => _currentWeight = UnitFormat.aGrammi(digitato));
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    final foto = nutriImageProvider(widget.recipe.imageUrl);

    return Scaffold(
      backgroundColor: Nutri.bg,
      appBar: AppBar(
        title: Text(widget.recipe.name,
            style: TextStyle(color: Nutri.green, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Nutri.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Nutri.green),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Like sulle ricette pubbliche (15/09), comprese le proprie (18/09):
          // il nome dell'autore arriva solo con quelle pubbliche.
          if (widget.recipe.authorName.isNotEmpty)
            IconButton(
              tooltip: widget.recipe.likedByMe
                  ? Translations.get(lang, 'like_remove')
                  : Translations.get(lang, 'like_add'),
              icon: Icon(
                widget.recipe.likedByMe ? Icons.favorite : Icons.favorite_border,
                color: widget.recipe.likedByMe ? Theme.of(context).colorScheme.error : Nutri.green,
              ),
              onPressed: _toggleLike,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // La foto della ricetta, che nessuna delle due vecchie
                  // pagine mostrava pur essendo salvata dal 30/08.
                  if (foto != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image(
                        image: foto,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  _buildMacroSummary(lang),
                  const SizedBox(height: 24),

                  _titoloSezione(
                      Icons.notes, Translations.get(lang, 'Note della Ricetta')),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Nutri.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Nutri.fieldBorder),
                    ),
                    child: Text(
                      widget.recipe.notes.isNotEmpty
                          ? widget.recipe.notes
                          : Translations.get(
                              lang, "Nessuna nota presente per questa ricetta."),
                      style:
                          TextStyle(fontSize: 14, color: Nutri.ink, height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (widget.conAggiuntaAlDiario) ...[
                    _bloccoPastoEQuantita(lang),
                    _scorciatoiePorzioni(lang),
                    const SizedBox(height: 24),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _titoloSezione(Icons.shopping_basket_outlined,
                          Translations.get(lang, 'Ingredienti')),
                      Text(
                        '${widget.recipe.ingredients.length} ${Translations.get(lang, 'totali')}',
                        style: TextStyle(color: Nutri.muted, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.recipe.ingredients.length,
                    itemBuilder: (context, index) => _buildIngredientCard(
                        widget.recipe.ingredients[index], lang),
                  ),
                  const SizedBox(height: 24),

                  // Vitamine e minerali dell'INTERA ricetta: c'erano solo
                  // nella pagina di sola lettura, e sparivano arrivando qui
                  // dalla scheda Aggiungi.
                  _riepilogoMicro(Translations.get(lang, 'Dettaglio Vitamine'),
                      widget.recipe.vitamins),
                  const SizedBox(height: 10),
                  _riepilogoMicro(Translations.get(lang, 'Dettaglio Minerali'),
                      widget.recipe.minerals),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          if (widget.conAggiuntaAlDiario) _barraAggiungi(lang),
        ],
      ),
    );
  }

  /// Mette o toglie il like (15/09). Il cuore cambia subito e torna com'era se
  /// il server rifiuta: aspettare la rete per un tocco lo farebbe sembrare rotto.
  Future<void> _toggleLike() async {
    final email = ref.read(userProvider)?.email ?? '';
    final ricetta = widget.recipe;
    if (email.isEmpty || ricetta.id == null) return;
    final (primaLike, primaConto) = (ricetta.likedByMe, ricetta.likesCount);
    final metti = !primaLike;
    setState(() {
      ricetta.likedByMe = metti;
      ricetta.likesCount = primaConto + (metti ? 1 : -1);
    });
    final esito = await ApiServices.toggleRecipeLike(userEmail: email, recipeId: ricetta.id!, like: metti);
    if (!mounted) return;
    setState(() {
      if (esito['status'] == 'success') {
        ricetta.likesCount = int.tryParse('${esito['likes_count']}') ?? ricetta.likesCount;
      } else {
        ricetta.likedByMe = primaLike;
        ricetta.likesCount = primaConto;
      }
    });
  }

  Widget _titoloSezione(IconData icona, String testo) {
    return Row(
      children: [
        Icon(icona, color: Nutri.green, size: 20),
        const SizedBox(width: 8),
        Text(testo,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Nutri.ink)),
      ],
    );
  }

  Widget _bloccoPastoEQuantita(String lang) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Nutri.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Nutri.fieldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Translations.get(lang, 'Pasto'),
                    style:
                        TextStyle(fontWeight: FontWeight.bold, color: Nutri.ink)),
                const SizedBox(height: 6),
                _buildMealTypeDropdown(lang),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Translations.get(lang, 'Peso')} (${UnitFormat.pSigla})',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: Nutri.ink),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: Nutri.ink),
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Nutri.card,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Porzioni pronte: una ricetta si registra "a porzioni", non a grammi.
  /// Prima si poteva solo scrivere il peso e calcolarsi a mente quanto pesa
  /// una fetta (test di release 19/09).
  Widget _scorciatoiePorzioni(String lang) {
    final quante = int.tryParse(widget.recipe.portion.trim()) ?? 0;
    if (quante < 1 || _pesoTotale <= 0) return const SizedBox.shrink();
    final pesoPorzione = _pesoTotale / quante;
    final scelte = <int>{1, 2, quante}.where((n) => n >= 1 && n <= quante).toList()..sort();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final n in scelte)
            NutriChip(
              height: 34,
              label: n == quante && quante > 1
                  ? Translations.get(lang, 'recipe_all_portions')
                  : '$n ${Translations.get(lang, n == 1 ? 'recipe_portion_one' : 'recipe_portion_many')}',
              selected: (_currentWeight - pesoPorzione * n).abs() < 0.5,
              onTap: () => _weightController.text = UnitFormat.pValore(pesoPorzione * n),
            ),
        ],
      ),
    );
  }

  Widget _barraAggiungi(String lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Nutri.card,
        border: Border(top: BorderSide(color: Nutri.fieldBorder)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Nutri.greenFill,
              foregroundColor: Nutri.onGreenFill,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: () => _addRecipeToDiary(lang),
            child: Text(Translations.get(lang, 'AGGIUNGI AL DIARIO'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  /// Card verde con i totali della ricetta.
  ///
  /// L'etichetta dice "totali" e non piu' "valori per 100 g": i numeri sono la
  /// SOMMA degli ingredienti, cioe' la ricetta intera. Le due vecchie pagine
  /// mostravano gli stessi identici numeri con due etichette opposte, e quella
  /// sbagliata era anche quella su cui si basava il calcolo di quanto
  /// registrare nel diario (vedi [_addRecipeToDiary]).
  /// Valori della ricetta intera (17/09). Prima: un riquadro verde sfumato
  /// con quattro icone e numeri in bianco ("sa di AI slop", Ismail). Ora: le
  /// calorie come numero grande, le porzioni accanto, e sotto la stessa
  /// ripartizione dei macro della pagina Grafici, con grammi e quota di energia.
  Widget _buildMacroSummary(String lang) {
    final peso = _pesoTotale;
    final r = widget.recipe;
    final porzioni = r.portion.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Nutri.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Nutri.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: UnitFormat.eValore(r.calories),
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, height: 1.1, color: Nutri.ink),
                    children: [
                      TextSpan(
                        text: ' ${UnitFormat.eSigla}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Nutri.muted),
                      ),
                    ],
                  ),
                ),
              ),
              if (porzioni.isNotEmpty)
                Text(
                  '${Translations.get(lang, 'Porzioni')}: $porzioni',
                  style: TextStyle(fontSize: 13, color: Nutri.muted),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            peso > 0
                ? '${Translations.get(lang, 'Valori Nutrizionali Totali')}, ${UnitFormat.p(peso)}'
                : Translations.get(lang, 'Valori Nutrizionali Totali'),
            style: TextStyle(fontSize: 12.5, color: Nutri.muted),
          ),
          const SizedBox(height: 16),
          RipartizioneMacro(
            analisi: MacroAnalysis(carbs: r.carbs, proteins: r.proteins, fats: r.fats, loggedCalories: r.calories),
            totali: MacroTotals(carbs: r.carbs, proteins: r.proteins, fats: r.fats),
            lang: lang,
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeDropdown(String lang) {
    return NutriSelect<String>(
      titolo: Translations.get(lang, 'Seleziona Pasto'),
      valore: _selectedMealType,
      segnaposto: Translations.get(lang, 'meal_pick_hint'),
      errore: _mealMissing ? Translations.get(lang, 'meal_pick_required') : null,
      opzioni: [
        for (final m in ['Colazione', 'Pranzo', 'Cena', 'Snack'])
          NutriOpzione(m, Translations.get(lang, m), icona: _iconaPasto(m)),
      ],
      onCambiato: (v) => setState(() {
        _selectedMealType = v;
        _mealMissing = false;
      }),
    );
  }

  /// Stessa mappa gia' stabilita in home_page, meal_detail_page e
  /// manual_entry_page.
  IconData _iconaPasto(String pasto) {
    switch (pasto) {
      case 'Pranzo':
        return Icons.dinner_dining;
      case 'Cena':
        return Icons.ramen_dining;
      case 'Snack':
        return Icons.cookie;
      default:
        return Icons.coffee;
    }
  }

  Widget _buildIngredientCard(RecipeIngredient ing, String lang) {
    final foto = nutriImageProvider(ing.imageUrl);
    // Material e non Container decorato: ListTile disegna sfondo e onda del
    // tocco sul Material piu' vicino, e un Container colorato in mezzo li
    // copre — Flutter lo segnala come errore in fase di disegno.
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Nutri.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Nutri.fieldBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              color: Nutri.surfaceSoft, borderRadius: BorderRadius.circular(10)),
          child: foto != null
              ? Image(
                  image: foto,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.restaurant, color: Nutri.green, size: 20),
                )
              : Icon(Icons.restaurant, color: Nutri.green, size: 20),
        ),
        title: Text(ing.name,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: Nutri.ink)),
        // Prima qui finiva `ing.unit`, cioe' la SIGLA: la riga diceva
        // "Peso: g" senza nessun numero. Il peso vero e' `weight_g`.
        subtitle: Text(
          '${UnitFormat.p(ing.weight_g)} · ${UnitFormat.e(ing.macro.calories)}',
          style: TextStyle(color: Nutri.muted, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: Nutri.hint),
        onTap: () => _showIngredientInfo(ing, lang),
        ),
      ),
    );
  }

  /// Vitamine/minerali dell'intera ricetta, in due colonne dentro un pannello
  /// che si apre.
  Widget _riepilogoMicro(String titolo, List<Map<String, String>> dati) {
    // Colore e bordo li mette ExpansionTile con i suoi parametri, non un
    // Container attorno: quello coprirebbe l'onda del tocco del ListTile che
    // ha dentro (Flutter lo segnala come errore in fase di disegno).
    final forma = RoundedRectangleBorder(
      side: BorderSide(color: Nutri.fieldBorder),
      borderRadius: BorderRadius.circular(16),
    );
    return Theme(
      // Il divisore predefinito di ExpansionTile taglia in due il riquadro
      // e sul fondo scuro si legge come un errore di disegno.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
          backgroundColor: Nutri.card,
          collapsedBackgroundColor: Nutri.card,
          shape: forma,
          collapsedShape: forma,
          clipBehavior: Clip.antiAlias,
          title: Text(titolo,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: Nutri.ink)),
          leading: Icon(Icons.analytics_outlined, color: Nutri.green),
          collapsedIconColor: Nutri.muted,
          iconColor: Nutri.green,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.8,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 8,
                ),
                itemCount: dati.length,
                itemBuilder: (context, index) {
                  final item = dati[index];
                  return Container(
                    padding: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom:
                              BorderSide(color: Nutri.divider, width: 0.6)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(item['name']!,
                              style:
                                  TextStyle(fontSize: 12, color: Nutri.muted),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 4),
                        Text('${item['value']} ${item['unit']}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Nutri.ink)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
      ),
    );
  }

  void _showIngredientInfo(RecipeIngredient ing, String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Nutri.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Nutri.divider, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(ing.name,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Nutri.green)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildNutrientSection(
                        Translations.get(lang, 'Macronutrienti'), [
                      _row(Translations.get(lang, 'Calorie'),
                          UnitFormat.e(ing.macro.calories)),
                      _row(Translations.get(lang, 'Proteine'),
                          UnitFormat.pNutriente(ing.macro.proteins)),
                      _row(Translations.get(lang, 'Carboidrati'),
                          UnitFormat.pNutriente(ing.macro.carbs)),
                      _row(Translations.get(lang, 'Grassi'),
                          UnitFormat.pNutriente(ing.macro.fats)),
                      _row(Translations.get(lang, 'Fibre'),
                          UnitFormat.pNutriente(ing.macro.fibers)),
                      _row(Translations.get(lang, 'Zuccheri'),
                          UnitFormat.pNutriente(ing.macro.sugars)),
                    ]),
                    _buildNutrientSection(
                        Translations.get(lang, 'Dettaglio Grassi'), [
                      _row(Translations.get(lang, 'Saturi'),
                          UnitFormat.pNutriente(ing.fats.saturated)),
                      _row(Translations.get(lang, 'Monoinsaturi'),
                          UnitFormat.pNutriente(ing.fats.monounsaturated)),
                      _row(Translations.get(lang, 'Polinsaturi'),
                          UnitFormat.pNutriente(ing.fats.polyunsaturated)),
                      _row(Translations.get(lang, 'Trans'),
                          UnitFormat.pNutriente(ing.fats.trans)),
                      _row(Translations.get(lang, 'Colesterolo'),
                          '${ing.fats.cholesterol} mg'),
                    ]),
                    _buildNutrientSection(Translations.get(lang, 'Vitamine'),
                        _buildVitaminRows(ing, lang)),
                    _buildNutrientSection(Translations.get(lang, 'Minerali'),
                        _buildMineralRows(ing, lang)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildVitaminRows(RecipeIngredient ing, String lang) {
    final v = ing.vitamins;
    return [
      _row(Translations.get(lang, 'Vitamina A'), '${v.a} µg'),
      _row(Translations.get(lang, 'Vitamina B1'), '${v.b1} mg'),
      _row(Translations.get(lang, 'Vitamina B2'), '${v.b2} mg'),
      _row(Translations.get(lang, 'Vitamina B3'), '${v.b3} mg'),
      _row(Translations.get(lang, 'Vitamina B5'), '${v.b5} mg'),
      _row(Translations.get(lang, 'Vitamina B6'), '${v.b6} mg'),
      _row(Translations.get(lang, 'Vitamina B7'), '${v.b7} µg'),
      _row(Translations.get(lang, 'Vitamina B9'), '${v.b9} µg'),
      _row(Translations.get(lang, 'Vitamina B11'), '${v.b11} µg'),
      _row(Translations.get(lang, 'Vitamina B12'), '${v.b12} µg'),
      _row(Translations.get(lang, 'Vitamina C'), '${v.c} mg'),
      _row(Translations.get(lang, 'Vitamina D'), '${v.d} µg'),
      _row(Translations.get(lang, 'Vitamina E'), '${v.e} mg'),
      _row(Translations.get(lang, 'Vitamina K'), '${v.k} µg'),
      _row(Translations.get(lang, 'Biotina'), '${v.biotin} µg'),
    ];
  }

  List<Widget> _buildMineralRows(RecipeIngredient ing, String lang) {
    final m = ing.minerals;
    final Map<String, List<dynamic>> data = {
      Translations.get(lang, 'Sodio'): [m.sodium, 'mg'],
      Translations.get(lang, 'Arsenico'): [m.arsenic, 'µg'],
      Translations.get(lang, 'Boro'): [m.boron, 'mg'],
      Translations.get(lang, 'Calcio'): [m.calcium, 'mg'],
      Translations.get(lang, 'Cloruro'): [m.chloride, 'mg'],
      Translations.get(lang, 'Colina'): [m.choline, 'mg'],
      Translations.get(lang, 'Cromo'): [m.chromium, 'µg'],
      Translations.get(lang, 'Cobalto'): [m.cobalt, 'µg'],
      Translations.get(lang, 'Rame'): [m.copper, 'mg'],
      Translations.get(lang, 'Fluoruro'): [m.fluoride, 'mg'],
      Translations.get(lang, 'Fluoro'): [m.fluorine, 'mg'],
      Translations.get(lang, 'Iodio'): [m.iodine, 'µg'],
      Translations.get(lang, 'Ferro'): [m.iron, 'mg'],
      Translations.get(lang, 'Magnesio'): [m.magnesium, 'mg'],
      Translations.get(lang, 'Manganese'): [m.manganese, 'mg'],
      Translations.get(lang, 'Molibdeno'): [m.molybdenum, 'µg'],
      Translations.get(lang, 'Fosforo'): [m.phosphorus, 'mg'],
      Translations.get(lang, 'Potassio'): [m.potassium, 'mg'],
      Translations.get(lang, 'Selenio'): [m.selenium, 'µg'],
      Translations.get(lang, 'Silicio'): [m.silicon, 'mg'],
      Translations.get(lang, 'Zolfo'): [m.sulfur, 'mg'],
      Translations.get(lang, 'Stagno'): [m.tin, 'mg'],
      Translations.get(lang, 'Vanadio'): [m.vanadium, 'µg'],
      Translations.get(lang, 'Zinco'): [m.zinc, 'mg'],
    };
    return data.entries
        .map((e) => _row(e.key, '${e.value[0]} ${e.value[1]}'))
        .toList();
  }

  Widget _buildNutrientSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Nutri.green)),
        ),
        ...children,
        Divider(color: Nutri.divider),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: TextStyle(color: Nutri.body),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: Nutri.ink)),
        ],
      ),
    );
  }

  Future<void> _addRecipeToDiary(String lang) async {
    final user = ref.read(userProvider);
    if (user == null) return;

    // Senza pasto scelto non si registra niente: il campo si colora e lo
    // dice, invece di far finire la ricetta in un pasto deciso dall'app.
    final meal = _selectedMealType;
    if (meal == null) {
      setState(() => _mealMissing = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Translations.get(lang, 'meal_pick_required'))),
      );
      return;
    }

    // QUANTO SI STA REGISTRANDO, e perche' il denominatore e' questo.
    //
    // Prima era `_currentWeight / 100.0`, come se i valori della ricetta
    // fossero espressi per 100 g. Non lo sono: sono la SOMMA degli
    // ingredienti, cioe' la ricetta intera. Con una ricetta da 250 g,
    // registrarne 250 g scriveva nel diario due volte e mezza le sue calorie.
    // Il denominatore giusto e' il peso totale.
    //
    // Se gli ingredienti non hanno pesi (peso totale 0) non c'e' niente su cui
    // scalare: si registra la ricetta intera, l'unica lettura sensata.
    final peso = _pesoTotale;
    final double ratio = peso > 0 ? _currentWeight / peso : 1.0;

    // I dettagli (grassi, vitamine, minerali) sommati dagli ingredienti.
    // Prima si mandavano `const Fats()`, `const Vitamins()` e
    // `const Minerals()`: registrare una ricetta buttava via TUTTI i
    // micronutrienti, in silenzio, mentre lo stesso alimento inserito a mano
    // li conservava.
    final ingredienti = widget.recipe.ingredients;
    double somma(double Function(RecipeIngredient) prendi) =>
        ingredienti.fold(0.0, (s, i) => s + prendi(i)) * ratio;

    final entry = FoodEntry(
      user_mail: user.email,
      food_name: widget.recipe.name,
      weight_g: peso > 0 ? _currentWeight : 0,
      meal_type: meal,
      entry_date: momentoVoce(widget.dataVoce),
      macro: Macronutrients(
        calories: widget.recipe.calories * ratio,
        proteins: widget.recipe.proteins * ratio,
        carbs: widget.recipe.carbs * ratio,
        fats: widget.recipe.fats * ratio,
        fibers: widget.recipe.fiber * ratio,
        sugars: widget.recipe.sugars * ratio,
        water: somma((i) => i.macro.water),
      ),
      fats: Fats(
        saturated: somma((i) => i.fats.saturated),
        monounsaturated: somma((i) => i.fats.monounsaturated),
        polyunsaturated: somma((i) => i.fats.polyunsaturated),
        trans: somma((i) => i.fats.trans),
        cholesterol: somma((i) => i.fats.cholesterol),
      ),
      vitamins: Vitamins(
        a: somma((i) => i.vitamins.a),
        b1: somma((i) => i.vitamins.b1),
        b2: somma((i) => i.vitamins.b2),
        b3: somma((i) => i.vitamins.b3),
        b5: somma((i) => i.vitamins.b5),
        b6: somma((i) => i.vitamins.b6),
        b7: somma((i) => i.vitamins.b7),
        b9: somma((i) => i.vitamins.b9),
        b11: somma((i) => i.vitamins.b11),
        b12: somma((i) => i.vitamins.b12),
        c: somma((i) => i.vitamins.c),
        d: somma((i) => i.vitamins.d),
        e: somma((i) => i.vitamins.e),
        k: somma((i) => i.vitamins.k),
        biotin: somma((i) => i.vitamins.biotin),
      ),
      minerals: Minerals(
        sodium: somma((i) => i.minerals.sodium),
        arsenic: somma((i) => i.minerals.arsenic),
        boron: somma((i) => i.minerals.boron),
        calcium: somma((i) => i.minerals.calcium),
        chloride: somma((i) => i.minerals.chloride),
        choline: somma((i) => i.minerals.choline),
        chromium: somma((i) => i.minerals.chromium),
        cobalt: somma((i) => i.minerals.cobalt),
        copper: somma((i) => i.minerals.copper),
        fluoride: somma((i) => i.minerals.fluoride),
        fluorine: somma((i) => i.minerals.fluorine),
        iodine: somma((i) => i.minerals.iodine),
        iron: somma((i) => i.minerals.iron),
        magnesium: somma((i) => i.minerals.magnesium),
        manganese: somma((i) => i.minerals.manganese),
        molybdenum: somma((i) => i.minerals.molybdenum),
        phosphorus: somma((i) => i.minerals.phosphorus),
        potassium: somma((i) => i.minerals.potassium),
        selenium: somma((i) => i.minerals.selenium),
        silicon: somma((i) => i.minerals.silicon),
        sulfur: somma((i) => i.minerals.sulfur),
        tin: somma((i) => i.minerals.tin),
        vanadium: somma((i) => i.minerals.vanadium),
        zinc: somma((i) => i.minerals.zinc),
      ),
    );

    final success = await ApiServices.sendFoodEntry(entry);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Translations.get(lang, 'Ricetta aggiunta al diario!'))));
      Navigator.pop(context, true);
    } else {
      // Prima il fallimento era silenzioso: la schermata restava li' e
      // l'utente non sapeva se avesse funzionato.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Translations.get(lang, 'Errore salvataggio')),
        backgroundColor: Nutri.danger,
      ));
    }
  }
}
