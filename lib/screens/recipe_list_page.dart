import 'package:flutter/material.dart';

import '../logic/unit_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutriapp/domain/user_provider.dart';
import '../models/recipe.dart';
import '../services/api_services.dart';
import 'add_recipe.dart';
import 'detail_of_ricetta.dart';
import '../widgets/paragrafo_ricetta.dart';
import '../dictionary/translations.dart';
import '../providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logic/pasto_attuale.dart';
import '../widgets/auth_style.dart';
import '../widgets/categorie_ricetta.dart';
import '../widgets/copia_ricetta_pubblica.dart';
import '../widgets/segnala_ricetta.dart';
import '../widgets/stato_condivisione.dart';

// Pagina per gestire le ricette salvate dell'utente
class RecipeListaPage extends ConsumerStatefulWidget {
  const RecipeListaPage({super.key});

  @override
  ConsumerState<RecipeListaPage> createState() => RecipeListaPageState();
}

class RecipeListaPageState extends ConsumerState<RecipeListaPage> with SingleTickerProviderStateMixin {
  List<Recipe> _recipes = [];

  /// Ricette pubbliche degli altri utenti — scheda "Consigliate"
  /// (2026-09-12, punto 3 della collaborazione).
  List<Recipe> _publicRecipes = [];
  bool _publicLoading = false;
  bool _publicFailed = false;

  /// Come ordinare Consigliate (15/09): per_te · piaciute · nuove. La scelta
  /// si ricorda fra un avvio e l'altro: e' una preferenza, non un filtro del
  /// momento.
  String _modoPubbliche = 'per_te';
  String? _filtroPasto;
  String? _filtroPortata;
  String? _filtroDieta;
  static const String _chiaveModo = 'consigliate_modo';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  // Serve solo per colorare il badge conteggio della tab attiva (mockup
  // Recipes: pillBg/pillFg cambiano tono sulla tab selezionata) — TabBar da
  // sola non espone quale child e' selezionato ai suoi Tab custom.
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _loadRecipes(); // Carichiamo le ricette all'avvio
    _ripristinaModo().then((_) {
      if (mounted) _loadPublicRecipes();
    });
    _searchController.addListener(_onSearchChanged);
    _tabController = TabController(length: 3, vsync: this)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  // Carica le ricette dal database
  Future<void> _loadRecipes() async {
    final userEmail = ref.read(userProvider)?.email ?? '';
    final loadedRecipes = await ApiServices.fetchRecipes(userEmail);
    setState(() {
      _recipes = loadedRecipes;
    });
  }

  // Naviga alla creazione di una nuova ricetta
  void _addRecipe() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreaRicettaPage()),
    );

    // Ricarichiamo se la ricetta è stata salvata
    if (result == true) {
      _loadRecipes();
    }
  }

  Future<void> _ripristinaModo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salvato = prefs.getString(_chiaveModo);
      if (salvato != null && const ['per_te', 'piaciute', 'nuove'].contains(salvato) && mounted) {
        setState(() => _modoPubbliche = salvato);
      }
    } catch (_) {
      // Senza preferenze salvate (o nei test) resta "Per te".
    }
  }

  Future<void> _cambiaModo(String modo) async {
    if (modo == _modoPubbliche) return;
    setState(() => _modoPubbliche = modo);
    _loadPublicRecipes();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chiaveModo, modo);
    } catch (_) {}
  }

  Future<void> _apriFiltri() async {
    final lang = ref.read(appSettingsProvider).language;
    final scelta = await scegliFiltriRicette(
      context,
      lang: lang,
      pasto: _filtroPasto,
      portata: _filtroPortata,
      dieta: _filtroDieta,
    );
    if (scelta == null || !mounted) return;
    setState(() {
      _filtroPasto = scelta.pasto;
      _filtroPortata = scelta.portata;
      _filtroDieta = scelta.dieta;
    });
    _loadPublicRecipes();
  }

  /// Like a una ricetta pubblica (15/09): il cuore cambia subito e torna
  /// com'era se il server rifiuta.
  Future<void> _toggleLike(Recipe recipe) async {
    final email = ref.read(userProvider)?.email ?? '';
    if (email.isEmpty || recipe.id == null) return;
    final (primaLike, primaConto) = (recipe.likedByMe, recipe.likesCount);
    final metti = !primaLike;
    setState(() {
      recipe.likedByMe = metti;
      recipe.likesCount = primaConto + (metti ? 1 : -1);
    });
    final esito = await ApiServices.toggleRecipeLike(userEmail: email, recipeId: recipe.id!, like: metti);
    if (!mounted) return;
    setState(() {
      if (esito['status'] == 'success') {
        recipe.likesCount = int.tryParse('${esito['likes_count']}') ?? recipe.likesCount;
      } else {
        recipe.likedByMe = primaLike;
        recipe.likesCount = primaConto;
      }
    });
  }

  // Modifica una ricetta esistente
  Future<void> _editRecipe(int index) async {
    final Recipe original = _recipes[index];
    // Una ricetta approvata e' del database e non si riscrive (15/09), ma da
    // oggi non e' piu' un vicolo cieco: se ne fa una copia privata con le
    // modifiche, e quella pubblica resta com'e' (richiesta di Ismail, 21/09).
    if (original.sharedStatus == 'approved') {
      await _copiaRicettaPubblica(original);
      return;
    }

    // Togliamo l'attesa rigida di <Recipe> e aspettiamo un risultato generico
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => CreaRicettaPage(initialRecipe: original.copy()),
      ),
    );

    // Ricarichiamo dopo la modifica
    if (result == true) {
      _loadRecipes();
    }
  }

  /// Copia privata di una ricetta pubblica: il popup e la copia stanno in
  /// [copiaRicettaPubblica], qui resta solo cosa farne dopo (ricaricare
  /// l'elenco e dirlo). La stessa strada parte anche dal dettaglio ricetta.
  Future<void> _copiaRicettaPubblica(Recipe pubblica) async {
    final lang = ref.read(appSettingsProvider).language;
    final salvata = await copiaRicettaPubblica(context, ricetta: pubblica, lang: lang);
    if (!salvata || !mounted) return;
    _loadRecipes();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(Translations.get(lang, 'recipe_public_copy_done'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildSearchAndList(),
      floatingActionButton: SizedBox(
        width: 60,
        height: 60,
        child: FloatingActionButton(
          onPressed: _addRecipe,
          backgroundColor: Theme.of(context).colorScheme.primary,
          // Mockup: quadrato con angoli arrotondati (20px), non un cerchio.
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.add, size: 30, color: Theme.of(context).colorScheme.onPrimary),
        ),
      ),
    );
  }

  Future<void> _toggleRecipeFav(Recipe recipe) async {
    final userEmail = ref.read(userProvider)?.email;
    if (userEmail == null || recipe.id == null) return;

    final newStatus = !recipe.isFavorite;
    final success = await ApiServices.toggleRecipeFavorite(
      userEmail,
      recipe.id!,
      newStatus,
    );
    if (success && mounted) {
      setState(() {
        recipe.isFavorite = newStatus;
      });
    }
  }


  /// Propone o ritira UNA ricetta per la sezione "Consigliate"
  /// (2026-09-12, punto 3 della collaborazione).
  ///
  /// Nessun consenso generale come per gli alimenti: una ricetta e' un testo
  /// scritto dalla persona, con un nome e delle note sue, e si propone una per
  /// una di proposito. Ritirarne una gia' pubblica chiede conferma: sparisce
  /// da "Consigliate" per tutti.
  Future<void> _cambiaCondivisioneRicetta(Recipe recipe) async {
    final lang = ref.read(appSettingsProvider).language;
    final email = ref.read(userProvider)?.email;
    if (email == null || email.isEmpty || recipe.id == null) return;

    final stato = recipe.sharedStatus;
    // Approvata = del database (15/09): non si ritira piu', si spiega perche'.
    if (stato == 'approved') {
      await mostraContenutoBloccato(context, lang);
      return;
    }
    final vuoleCondividere = stato != 'pending';

    // Proporre chiede le categorie: "Per te" consiglia in base al pasto, e una
    // ricetta senza pasto non comparirebbe mai fra quelle del momento.
    CategorieRicetta? categorie;
    if (vuoleCondividere) {
      categorie = await chiediCategorieRicetta(
        context,
        lang: lang,
        iniziali: (
          pasti: recipe.mealTypes,
          portata: recipe.course.isEmpty ? null : recipe.course,
          diete: recipe.dietTags,
        ),
      );
      if (categorie == null || !mounted) return;
    }

    final esito = await ApiServices.shareRecipe(
      userEmail: email,
      id: recipe.id!,
      share: vuoleCondividere,
      mealTypes: categorie?.pasti ?? const [],
      course: categorie?.portata,
      dietTags: categorie?.diete ?? const [],
    );
    if (!mounted) return;

    if (esito['status'] != 'success') {
      if (esito['reason'] == 'locked') {
        setState(() => recipe.sharedStatus = 'approved');
        await mostraContenutoBloccato(context, lang);
        return;
      }
      // Il caso "senza ingredienti" ha un messaggio suo: non e' un guasto, e'
      // una cosa che l'utente puo' sistemare aggiungendo un ingrediente.
      final senzaIngredienti = esito['reason'] == 'no_ingredients';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: senzaIngredienti ? null : Theme.of(context).colorScheme.error,
          content: Text(
            senzaIngredienti
                ? Translations.get(lang, 'share_no_ingredients')
                : '${Translations.get(lang, 'share_failed')} ${esito['message'] ?? ''}'.trim(),
          ),
        ),
      );
      return;
    }

    final nuovo = (esito['shared_status'] ?? stato).toString();
    setState(() {
      recipe.sharedStatus = nuovo;
      if (categorie != null) {
        recipe.mealTypes = categorie.pasti;
        recipe.course = categorie.portata ?? '';
        recipe.dietTags = categorie.diete;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          Translations.get(
            lang,
            nuovo == 'pending'
                ? 'share_recipe_proposed'
                : nuovo == 'approved'
                    ? 'share_state_approved'
                    : 'share_recipe_withdrawn',
          ),
        ),
      ),
    );
    // Una ricetta ritirata deve sparire anche dall'elenco pubblico che stiamo
    // mostrando, senza aspettare il prossimo avvio.
    if (nuovo != 'approved') _loadPublicRecipes();
  }

  /// Le ricette pubbliche degli altri.
  ///
  /// `_publicFailed` distingue "non ce ne sono ancora" da "non sono riuscito a
  /// chiedere": il primo caso e' la normalita' finche' nessuno ha approvato
  /// niente, il secondo e' un guasto, e mostrarli con lo stesso schermo vuoto
  /// nasconderebbe il secondo dietro il primo.
  Future<void> _loadPublicRecipes() async {
    final email = ref.read(userProvider)?.email ?? '';
    setState(() => _publicLoading = true);
    final lista = await ApiServices.fetchPublicRecipes(
      email,
      mode: _modoPubbliche,
      nowMeal: pastoDellOra(DateTime.now()),
      meal: _filtroPasto,
      course: _filtroPortata,
      diet: _filtroDieta,
    );
    if (!mounted) return;
    setState(() {
      _publicLoading = false;
      _publicFailed = lista == null;
      _publicRecipes = lista ?? [];
    });
  }

  /// Scheda Consigliate (15/09): in cima le tre modalita' e i filtri, sotto
  /// l'elenco.
  Widget _buildPublicList() {
    final lang = ref.watch(appSettingsProvider).language;
    return Column(
      children: [
        _intestazionePubbliche(lang),
        Expanded(child: _elencoPubbliche(lang)),
      ],
    );
  }

  Widget _intestazionePubbliche(String lang) {
    final scheme = Theme.of(context).colorScheme;
    final filtriAttivi = [_filtroPasto, _filtroPortata, _filtroDieta].where((f) => f != null).length;
    final modi = {
      'per_te': Translations.get(lang, 'public_mode_for_you'),
      'piaciute': Translations.get(lang, 'public_mode_liked'),
      'nuove': Translations.get(lang, 'public_mode_new'),
    };
    final filtri = Translations.get(lang, 'public_filters');
    final pasto = Translations.get(lang, 'meal_${pastoDellOra(DateTime.now())}').toLowerCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final m in modi.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: NutriChip(
                            height: 36,
                            label: m.value,
                            selected: _modoPubbliche == m.key,
                            onTap: () => _cambiaModo(m.key),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: scheme.primary,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: _apriFiltri,
                icon: const Icon(Icons.tune, size: 18),
                label: Text(filtriAttivi == 0 ? filtri : '$filtri ($filtriAttivi)'),
              ),
            ],
          ),
          if (_modoPubbliche == 'per_te')
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Text(
                Translations.get(lang, 'public_for_you_caption').replaceAll('{pasto}', pasto),
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _elencoPubbliche(String lang) {
    final scheme = Theme.of(context).colorScheme;

    if (_publicLoading && _publicRecipes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtrate = _publicRecipes
        .where((r) => r.name.toLowerCase().contains(_searchQuery))
        .toList();

    if (filtrate.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _publicFailed ? Icons.cloud_off : Icons.groups_outlined,
                size: 44,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                Translations.get(
                  lang,
                  _publicFailed
                      ? 'public_recipes_error'
                      : _searchQuery.isNotEmpty
                          ? 'search_not_found'
                          : 'public_recipes_empty',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
              ),
              if (_publicFailed) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loadPublicRecipes,
                  child: Text(Translations.get(lang, 'Riprova')),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPublicRecipes,
      child: ListView.separated(
        // In fondo lo spazio del tasto +, che copriva like e stella
        // dell'ultima ricetta (test di release 19/09).
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 96),
        itemCount: filtrate.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final recipe = filtrate[index];
          return ParagrafoRicetta(
            title: recipe.name,
            imageUrl: recipe.imageUrl,
            subtitle:
                _sottotitolo(recipe, lang),
            footnote: recipe.isMine
                ? Translations.get(lang, 'public_recipe_yours')
                : recipe.authorName.isEmpty
                ? null
                : '${Translations.get(lang, 'public_recipe_by')} ${recipe.authorName}'
                    '${recipe.course.isEmpty ? '' : ', ${Translations.get(lang, 'course_${recipe.course}').toLowerCase()}'}',
            kcalLabel: _kcalLabel(recipe, lang),
            // Niente stella, matita o cestino: la ricetta e' di un altro.
            // Passare i gestori a null e' cio' che li fa sparire del tutto,
            // invece di mostrarli spenti come prima. Il cuore si' (15/09),
            // anche sulle proprie (18/09): il voto dell'autore si conta nel
            // numero ma non nel punteggio di "Per te".
            onLike: () => _toggleLike(recipe),
            likesCount: recipe.likesCount,
            likedByMe: recipe.likedByMe,
            likeTooltip: recipe.likedByMe
                ? Translations.get(lang, 'like_remove')
                : Translations.get(lang, 'like_add'),
            // Matita anche qui (21/09): non modifica la ricetta pubblica,
            // ne fa una copia privata — il popup lo dice prima di aprirla.
            onCopy: () => _copiaRicettaPubblica(recipe),
            copyTooltip: Translations.get(lang, 'recipe_public_copy_action'),
            // Segnalare ha senso solo su quelle degli altri: la propria si
            // modifica o si ritira.
            onReport: recipe.isMine ? null : () => mostraSegnalaRicetta(context, recipe: recipe),
            reportTooltip: recipe.isMine ? null : Translations.get(lang, 'report_recipe_action'),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecipeDetailPage(recipe: recipe),
                ),
              );
              // Il like messo nel dettaglio deve vedersi anche qui.
              if (mounted) setState(() {});
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchAndList() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titolo e conteggio incolonnati (richiesta di Ismail,
                // 21/09): affiancati sulla stessa riga erano due testi che si
                // contendevano lo spazio — il titolo grosso a sinistra e un
                // numero appeso a destra, che su schermi stretti si
                // accorciava con i puntini. Ora il conteggio sta sotto, dove
                // si legge come una didascalia del titolo e non come una
                // seconda intestazione.
                Text(
                  Translations.get(
                    ref.watch(appSettingsProvider).language,
                    'Le Tue Ricette',
                  ),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                    letterSpacing: -0.4,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.bookmark_outline,
                      size: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    // Singolare e plurale restano distinti: con una sola
                    // ricetta diceva "1 ricette salvate".
                    Flexible(
                      child: Text(
                        '${_recipes.length} ${Translations.get(ref.watch(appSettingsProvider).language, _recipes.length == 1 ? 'ricetta salvata' : 'ricette salvate')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    // Mockup: il bordo c'e' sempre (grigio-verde), diventa
                    // solo un filo piu' verde quando c'e' una query — prima
                    // era invisibile a riposo.
                    border: Border.all(
                      color: _searchQuery.isNotEmpty
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.35)
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: Translations.get(
                        ref.watch(appSettingsProvider).language,
                        'Cerca tra le tue ricette...',
                      ),
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.cancel, size: 20),
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              onPressed: () {
                                _searchController.clear();
                              },
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(
                child: _tabWithCount(
                  Translations.get(ref.watch(appSettingsProvider).language, 'Tutti'),
                  _recipes.length,
                  active: _tabController.index == 0,
                ),
              ),
              Tab(
                child: _tabWithCount(
                  Translations.get(ref.watch(appSettingsProvider).language, 'Preferiti'),
                  _recipes.where((r) => r.isFavorite).length,
                  active: _tabController.index == 1,
                ),
              ),
              Tab(
                child: _tabWithCount(
                  Translations.get(ref.watch(appSettingsProvider).language, 'recipes_tab_public'),
                  _publicRecipes.length,
                  active: _tabController.index == 2,
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecipeList(_recipes, isFavoritesTab: false),
                _buildRecipeList(
                  _recipes.where((r) => r.isFavorite).toList(),
                  isFavoritesTab: true,
                ),
                _buildPublicList(),
              ],
            ),
          ),
        ],
      );
  }

  Widget _tabWithCount(String label, int count, {required bool active}) {
    final scheme = Theme.of(context).colorScheme;
    // Mockup: il badge conteggio e' a due toni, verde sulla tab attiva.
    final Color pillBg = active ? scheme.primaryContainer.withValues(alpha: .6) : scheme.surfaceContainerHighest;
    final Color pillFg = active ? scheme.primary : scheme.onSurfaceVariant;
    // Su 320 px "Consigliate 4" non ci sta: si rimpicciolisce invece di
    // sforare (test di release 19/09).
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: pillFg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Porzioni e ingredienti (17/09): senza porzioni la riga non dice piu'
  /// "Porzione:  — 2 ingredienti".
  String _sottotitolo(Recipe recipe, String lang) {
    final porzione = recipe.portion.trim();
    final ingredienti = '${recipe.ingredients.length} ${Translations.get(lang, 'ingredienti')}';
    return porzione.isEmpty ? ingredienti : '${Translations.get(lang, 'Porzione')}: $porzione, $ingredienti';
  }

  /// "N kcal a porzione" quando la porzione e' un numero valido, altrimenti
  /// "N kcal totali" — il campo porzione e' testo libero (es. "4 persone"),
  /// non si puo' sempre dividere in modo affidabile.
  String _kcalLabel(Recipe recipe, String lang) {
    final totalKcal = recipe.calories;
    final portionCount = double.tryParse(recipe.portion.trim());
    if (portionCount != null && portionCount > 0) {
      return '${UnitFormat.e(totalKcal / portionCount)} ${Translations.get(lang, 'recipe_kcal_portion')}';
    }
    return '${UnitFormat.e(totalKcal)} ${Translations.get(lang, 'recipe_kcal_total')}';
  }

  Widget _buildRecipeList(List<Recipe> recipes, {required bool isFavoritesTab}) {
    final lang = ref.watch(appSettingsProvider).language;
    final filteredRecipes = recipes
        .where((r) => r.name.toLowerCase().contains(_searchQuery))
        .toList();

    if (filteredRecipes.isEmpty) {
      return _buildEmptyState(isFavoritesTab: isFavoritesTab);
    }

    return ListView.separated(
      // In fondo lo spazio del tasto +, che copriva stella e cestino
      // dell'ultima ricetta (test di release 19/09).
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 96),
      itemCount: filteredRecipes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final recipe = filteredRecipes[index];
        final originalIndex = _recipes.indexOf(recipe);
        return ParagrafoRicetta(
          title: recipe.name,
          imageUrl: recipe.imageUrl,
          subtitle:
              _sottotitolo(recipe, lang),
          kcalLabel: _kcalLabel(recipe, lang),
          isFavorite: recipe.isFavorite,
          onFavorite: () => _toggleRecipeFav(recipe),
          sharedStatus: recipe.sharedStatus,
          onShare: () => _cambiaCondivisioneRicetta(recipe),
          onEdit: () => _editRecipe(originalIndex),
          onDelete: () => _confermaEliminazione(context, recipe),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeDetailPage(
                recipe: recipe,
                conAggiuntaAlDiario: false,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Stato vuoto differenziato: ricerca senza risultati, tab preferiti senza
  /// ricette salvate come tali, o nessuna ricetta salvata affatto — ognuno
  /// con un messaggio pertinente invece di uno generico sempre uguale.
  Widget _buildEmptyState({required bool isFavoritesTab}) {
    final lang = ref.watch(appSettingsProvider).language;
    final scheme = Theme.of(context).colorScheme;

    final bool isSearching = _searchQuery.isNotEmpty;
    final IconData icon = isSearching
        ? Icons.search_off
        : isFavoritesTab
            ? Icons.star_border
            : Icons.menu_book_outlined;
    final String title = isSearching
        ? Translations.get(lang, 'recipe_search_empty_title')
        : isFavoritesTab
            ? Translations.get(lang, 'recipe_fav_empty_title')
            : Translations.get(lang, 'Lista Ricette');
    final String body = isSearching
        ? Translations.get(lang, 'recipe_search_empty_body')
        : isFavoritesTab
            ? Translations.get(lang, 'recipe_fav_empty_body')
            : Translations.get(lang, 'Qui potrai vedere le ricette salvate');

    return Center(
      child: GestureDetector(
        onTap: isSearching ? null : _addRecipe,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scheme.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confermaEliminazione(BuildContext context, Recipe recipe) {
    final lang = ref.read(appSettingsProvider).language;
    final userEmail = ref.read(userProvider)?.email ?? '';
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            Translations.get(lang, "Conferma eliminazione"),
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          content: Text(
            "${Translations.get(lang, 'Sei sicuro di voler eliminare la ricetta')} '${recipe.name}'?"
            "${recipe.sharedStatus == 'approved' ? '\n\n${Translations.get(lang, 'delete_public_warning')}' : ''}",
          ),
          actions: [
            TextButton(
              child: Text(
                Translations.get(lang, "Annulla"),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: Text(
                Translations.get(lang, "Elimina"),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext); // Chiude il popup subito

                final esito = await ApiServices.deleteRecipeDetailed(
                  userEmail,
                  recipe.id!,
                );
                final success = esito.ok;

                if (success) {
                  _loadRecipes();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        // Approvata = del database (15/09): va detto che resta.
                        content: Text(
                          esito.keptPublic
                              ? Translations.get(lang, 'delete_kept_public')
                              : Translations.get(lang, 'Ricetta eliminata!'),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          Translations.get(
                            lang,
                            "Errore durante l'eliminazione",
                          ),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
