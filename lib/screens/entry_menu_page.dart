import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/auth_style.dart';

import '../logic/unit_format.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:nutriapp/domain/user_provider.dart';
import 'package:nutriapp/domain/app_providers.dart';
import 'manual_entry_page.dart';
import 'add_recipe.dart';
import 'detail_of_ricetta.dart';
import '../models/recipe.dart';
import '../services/api_services.dart';
import '../services/local_food_cache.dart';
import '../providers/locale_provider.dart';
import '../dictionary/translations.dart';
import '../widgets/stato_condivisione.dart';
import '../widgets/immagine_zoomabile.dart';

class EntryMenuPage extends ConsumerStatefulWidget {
  final String? initialMealType;
  final bool returnAsIngredient;

  /// Vero quando questa pagina e' stata aperta SOPRA un'altra schermata
  /// (il "+" di un pasto in Home, il dettaglio di un pasto) invece di essere
  /// la tab "Aggiungi" di MainLayout.
  ///
  /// PERCHE' UN PARAMETRO E NON UNA DEDUZIONE (2026-09-12): prima lo si
  /// deduceva da `initialMealType == null`, cioe' "senza pasto di partenza
  /// sono la tab". Regge per caso finche' ogni apertura come schermata porta
  /// con se' un pasto, e si rompe in silenzio alla prima che non lo fa —
  /// proprio il caso che ora serve, dato che dalla ricerca generale il pasto
  /// non e' piu' preselezionato. Da chi apre la pagina si sa con certezza,
  /// qui non si indovina piu'.
  final bool comeSchermata;

  /// Il giorno su cui registrare (17/09): quello che si stava guardando nel
  /// diario. `null` = oggi.
  final DateTime? dataVoce;

  const EntryMenuPage({
    super.key,
    this.initialMealType,
    this.returnAsIngredient = false,
    this.comeSchermata = false,
    this.dataVoce,
  });

  @override
  ConsumerState<EntryMenuPage> createState() => _EntryMenuPageState();
}

class _EntryMenuPageState extends ConsumerState<EntryMenuPage>
    with SingleTickerProviderStateMixin {
  bool _isSearching = false;
  bool _searchHadNetworkError = false;
  // True mentre alcune fonti hanno già risposto (risultati già visibili) ma
  // altre sono ancora in corso: mostra un indicatore leggero invece dello
  // spinner a piena pagina, che si vedrebbe solo quando non c'è ancora nulla.
  bool _isSearchRefining = false;

  List<Recipe> _recipes = [];
  List<Map<String, dynamic>> _customFoods = [];

  /// true quando la libreria mostrata viene dalla copia sul telefono perche'
  /// il server non ha risposto: serve a spiegarlo nel messaggio di "nessun
  /// risultato", altrimenti sembra che la ricerca sia solo andata male.
  bool _libreriaDaCopiaLocale = false;
  List<Map<String, dynamic>> _searchResults = [];

  // Filtro "in quale supermercato l'ho visto" (na_product_retailer, vedi
  // ApiServices.fetchInsegne). Set vuoto = nessun filtro, tutte le fonti.
  // _insegneDisponibili vuota finche' non risponde il server o se non c'e'
  // ancora nulla da filtrare: il pulsante Filtro semplicemente non compare,
  // niente da gestire in piu'. Multi-selezione dal 2026-08-23 (prima era
  // una sola insegna alla volta).
  List<({String insegna, int nProdotti})> _insegneDisponibili = [];
  final Set<String> _insegneSelezionate = {};
  // Filtri sui tre punteggi standard OpenFoodFacts (Nutri-Score/NOVA/
  // Eco-Score), richiesta 2026-08-23 — vedi mockup "App mobile con filtri e
  // ordinamento" fatto da Ismail su claude.ai/design.
  final Set<String> _nutriscoreSelezionati = {}; // 'a'..'e'
  final Set<int> _novaSelezionati = {}; // 1..4
  final Set<String> _ecoscoreSelezionati = {}; // 'a'..'e'
  SearchSortMode _sortMode = SearchSortMode.relevance;

  int get _filterCount =>
      _insegneSelezionate.length +
      _nutriscoreSelezionati.length +
      _novaSelezionati.length +
      _ecoscoreSelezionati.length;
  bool get _hasAnyFilter => _filterCount > 0;

  // Palette dei tre punteggi OpenFoodFacts: stessa fonte del mockup, gia'
  // ufficiale per Nutri-Score (era gia' hardcoded in _buildNutriScoreBadge,
  // qui condivisa anche col filtro invece di duplicarla). NOVA/Eco-Score non
  // hanno un colore ufficiale altrettanto standard: presi dal mockup.
  static const Map<String, Color> _nutriScoreColors = {
    'a': Color(0xFF038141),
    'b': Color(0xFF85BB2F),
    'c': Color(0xFFFECB02),
    'd': Color(0xFFEE8100),
    'e': Color(0xFFE63E11),
  };
  static const Map<int, Color> _novaColors = {
    1: Color(0xFF2E7D32),
    2: Color(0xFF8BC34A),
    3: Color(0xFFF5A623),
    4: Color(0xFFD8452E),
  };
  static const Map<String, Color> _ecoScoreColors = {
    'a': Color(0xFF0F7A3D),
    'b': Color(0xFF6FAF2F),
    'c': Color(0xFFE8B10C),
    'd': Color(0xFFE07A16),
    'e': Color(0xFFD8412A),
  };
  // Colori troppo chiari per il testo bianco: serve testo scuro sopra.
  static const List<Color> _lightScoreColors = [
    Color(0xFF85BB2F),
    Color(0xFFFECB02),
    Color(0xFF8BC34A),
    Color(0xFFF5A623),
    Color(0xFF6FAF2F),
    Color(0xFFE8B10C),
  ];
  static Color _fgOnScore(Color bg) =>
      _lightScoreColors.contains(bg) ? const Color(0xFF1F2A1C) : Colors.white;

  final TextEditingController _searchGlobalController = TextEditingController();
  final TextEditingController _searchRecipeController = TextEditingController();
  final TextEditingController _searchFoodController = TextEditingController();

  String _searchRecipeQuery = '';
  String _searchFoodQuery = '';

  // Debounce per la ricerca "live": la ricerca vera e propria parte solo
  // quando l'utente smette di digitare per qualche centinaio di ms, invece
  // di richiedere sempre l'invio esplicito. Un unico Timer sostituisce
  // quello precedente ad ogni nuova battuta, cancellando la ricerca in coda.
  Timer? _searchDebounce;
  static const _searchDebounceDelay = Duration(milliseconds: 450);

  // Contatore usato per scartare risultati di ricerche ormai superate se
  // arrivano fuori ordine (es. una ricerca precedente più lenta che risponde
  // dopo quella più recente).
  int _searchRequestId = 0;

  // Sottoscrizione alla ricerca "live": ogni fonte (CREA, cache OFF locale,
  // OFF live, USDA) emette il proprio aggiornamento non appena risponde,
  // invece di aspettare che rispondano tutte prima di mostrare qualcosa.
  StreamSubscription<SearchUpdate>? _searchSubscription;

  /// Controller delle tre sotto-sezioni ("Aggiungi alimento", "Ricette
  /// salvate", "Alimenti salvati"). Esplicito invece di DefaultTabController
  /// perche' serve poterlo riportare a 0 dall'esterno quando l'utente preme
  /// "indietro" mentre e' in una delle altre due.
  late final TabController _tabController;

  /// Vero solo per l'istanza che sta DENTRO la tab "Aggiungi" di MainLayout.
  /// Le altre due (ingrediente di una ricetta, scorciatoia dalla Home) sono
  /// schermate vere e proprie: li' l'indietro deve chiuderle, non riportare
  /// la sotto-sezione a 0.
  bool get _dentroAllaTab =>
      !widget.comeSchermata && !widget.returnAsIngredient;

  /// Riferimento al provider tenuto da parte al momento della registrazione.
  ///
  /// In dispose() `ref` non si puo' piu' usare (il widget e' gia' staccato
  /// dall'albero) — e' esattamente cio' che il test visivo ha fatto emergere.
  /// Il controller di uno StateProvider di radice vive quanto l'app, quindi
  /// tenerselo qui e' sicuro.
  StateController<bool Function()?>? _registroIndietro;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.returnAsIngredient ? 2 : 3,
      vsync: this,
    );
    if (_dentroAllaTab) {
      // Registrato dopo il primo frame: durante initState il provider non si
      // puo' ancora modificare senza far ricostruire un widget in costruzione.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final registro = ref.read(gestoreIndietroProvider.notifier);
        registro.state = _indietroInterno;
        _registroIndietro = registro;
      });
    }
    _loadData();
    _loadInsegne();
    _searchGlobalController.addListener(_onSearchTextChanged);
    _searchRecipeController.addListener(
      () => setState(
        () => _searchRecipeQuery = _searchRecipeController.text.toLowerCase(),
      ),
    );
    _searchFoodController.addListener(
      () => setState(
        () => _searchFoodQuery = _searchFoodController.text.toLowerCase(),
      ),
    );
  }

  /// "Indietro" dentro la tab Aggiungi: prima riporta alla sotto-sezione
  /// principale, e solo da li' lascia che MainLayout torni alla Home.
  ///
  /// Chi e' in "Ricette salvate" e preme indietro si aspetta di uscire da
  /// quell'elenco, non di trovarsi sulla Home due passi piu' in la'.
  bool _indietroInterno() {
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    // Solo se e' ancora il nostro: se un'altra schermata l'ha nel frattempo
    // sostituito, cancellarlo la lascerebbe senza gestore.
    //
    // Dopo il frame, non qui dentro: scrivere in un provider mentre l'albero
    // si sta smontando fa "Tried to modify a provider while the widget tree
    // was building" a ogni uscita dalla tab Aggiungi (test di release 19/09).
    final registro = _registroIndietro;
    final mio = _indietroInterno;
    if (registro != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (registro.mounted && registro.state == mio) registro.state = null;
      });
    }
    _tabController.dispose();
    _searchDebounce?.cancel();
    _searchSubscription?.cancel();
    _searchGlobalController.dispose();
    _searchRecipeController.dispose();
    _searchFoodController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    setState(() {}); // aggiorna subito la UI (es. pulsante "clear")

    _searchDebounce?.cancel();
    final query = _searchGlobalController.text;
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchHadNetworkError = false;
      });
      return;
    }
    _searchDebounce = Timer(_searchDebounceDelay, () => _performSearch(query));
  }

  void _performSearch(String query) {
    final cleanQuery = query.trim().toLowerCase();
    // Query vuota ammessa solo se c'e' almeno un filtro attivo: "sfoglia"
    // col tap sul filtro, senza aver scritto nulla.
    if (cleanQuery.isEmpty && !_hasAnyFilter) return;

    final requestId = ++_searchRequestId;
    _searchSubscription?.cancel();

    setState(() {
      _isSearching = true;
      _isSearchRefining = false;
      _searchHadNetworkError = false;
    });

    // Cerchiamo subito nei nostri alimenti salvati localmente (istantaneo,
    // sono già in memoria) mentre le fonti esterne rispondono in background.
    // Stessa normalizzazione (accenti, ordine parole) usata per le fonti
    // server: prima confrontava la query grezza contro il nome grezzo come
    // un unico blocco, perdendo qualunque alimento personale con un accento
    // (es. "purè") o le parole in un ordine diverso da come sono state
    // salvate — proprio i casi che le fonti server invece già gestivano.
    final normalizedQuery = ApiServices.normalizeForSearch(cleanQuery);
    final queryWords = normalizedQuery
        .split(' ')
        .where((w) => w.length > 2)
        .toList();
    // Query vuota (sfoglia per insegna): i nostri alimenti personali non
    // hanno un'insegna, "contains('')" sarebbe sempre vero e li mostrerebbe
    // tutti mescolati ai risultati del supermercato — niente localMatches qui.
    String nomeDi(Map<String, dynamic> f) =>
        ApiServices.normalizeForSearch((f['food_name'] ?? '').toString());

    final localMatches = cleanQuery.isEmpty ? <Map<String, dynamic>>[] : _customFoods.where((f) {
      final name = nomeDi(f);
      if (queryWords.isEmpty) return name.contains(normalizedQuery);
      return queryWords.every((w) => name.contains(w));
    }).toList();

    // Rete larga sulla libreria personale, da usare SOLO se le fonti esterne
    // non hanno trovato niente (2026-09-05). La ricerca stretta qui sopra
    // pretende che TUTTE le parole digitate compaiano nel nome: giusto quando
    // ci sono migliaia di risultati fra cui scegliere, sbagliato quando non
    // c'e' niente e l'unica cosa che l'utente potrebbe volere e' un alimento
    // suo che ha chiamato in modo un po' diverso ("riso basmati integrale"
    // cercato come "riso integrale basmati" lo trova gia', ma "basmati
    // cotto" no). Basta una parola in comune.
    final localMatchesLarghi = cleanQuery.isEmpty || queryWords.isEmpty
        ? <Map<String, dynamic>>[]
        : _customFoods.where((f) {
            final name = nomeDi(f);
            return queryWords.any((w) => name.contains(w));
          }).toList();

    // Ricerca "live": mostriamo il primo aggiornamento non appena la fonte
    // più veloce (di solito CREA o la cache OFF locale, entrambe sul nostro
    // DB) risponde, invece di aspettare anche OFF live/USDA che possono
    // metterci diversi secondi in più. Gli aggiornamenti successivi
    // arricchiscono/riordinano silenziosamente la lista già visibile.
    _searchSubscription = ApiServices.searchProductsStream(
      cleanQuery,
      insegne: _insegneSelezionate.isEmpty ? null : _insegneSelezionate.toList(),
      scoreFilters: (
        nutriscore: _nutriscoreSelezionati,
        nova: _novaSelezionati,
        ecoscore: _ecoscoreSelezionati,
      ),
      sortMode: _sortMode,
    ).listen(
      (update) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          // Uniamo i risultati mettendo i nostri locali per primi
          // Un alimento personale approvato torna anche dalla fonte della
          // comunita': qui c'e' gia' come alimento dell'utente, e due righe
          // uguali sembrerebbero un doppione (14/09).
          final idPersonali = _customFoods.map((f) => (f['id'] ?? '').toString()).toSet();
          final esterni = update.results.where((r) =>
              r['source'] != 'community' ||
              !idPersonali.contains((r['community_id'] ?? '').toString()));
          final uniti = [...localMatches, ...esterni];
          // Ricerca finita e sacco vuoto: meglio la libreria personale presa
          // alla larga che una schermata che dice "nessun risultato" mentre
          // l'alimento e' li', salvato dall'utente stesso.
          _searchResults = (uniti.isEmpty && update.isDone)
              ? localMatchesLarghi
              : uniti;
          _searchHadNetworkError =
              _searchResults.isEmpty && update.networkError;
          _isSearching = false;
          _isSearchRefining = !update.isDone;
        });
      },
      onError: (_) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _isSearching = false;
          _isSearchRefining = false;
          _searchHadNetworkError = _searchResults.isEmpty;
        });
      },
    );
  }

  Future<void> _loadInsegne() async {
    final insegne = await ApiServices.fetchInsegne();
    if (mounted) setState(() => _insegneDisponibili = insegne);
  }

  /// Applica il nuovo stato di tutti i filtri insieme (dal bottom sheet) e
  /// rifa' la ricerca corrente, o "sfoglia" se non c'era ancora nessuna
  /// query digitata.
  void _applyFilters({
    required Set<String> insegne,
    required Set<String> nutriscore,
    required Set<int> nova,
    required Set<String> ecoscore,
  }) {
    setState(() {
      _insegneSelezionate
        ..clear()
        ..addAll(insegne);
      _nutriscoreSelezionati
        ..clear()
        ..addAll(nutriscore);
      _novaSelezionati
        ..clear()
        ..addAll(nova);
      _ecoscoreSelezionati
        ..clear()
        ..addAll(ecoscore);
    });
    _searchDebounce?.cancel();
    final query = _searchGlobalController.text;
    if (query.trim().isNotEmpty) {
      _performSearch(query);
    } else if (_hasAnyFilter) {
      _performSearch('');
    } else {
      setState(() => _searchResults = []);
    }
  }

  /// Rimuove un solo filtro attivo (tap sulla "x" di una chip) e riapplica.
  void _removeOneFilter({
    String? insegna,
    String? nutriscore,
    int? nova,
    String? ecoscore,
  }) {
    final nuoveInsegne = Set<String>.from(_insegneSelezionate)..remove(insegna);
    final nuoviNutri = Set<String>.from(_nutriscoreSelezionati)..remove(nutriscore);
    final nuoviNova = Set<int>.from(_novaSelezionati)..remove(nova);
    final nuoviEco = Set<String>.from(_ecoscoreSelezionati)..remove(ecoscore);
    _applyFilters(insegne: nuoveInsegne, nutriscore: nuoviNutri, nova: nuoviNova, ecoscore: nuoviEco);
  }

  void _onSortChanged(SearchSortMode mode) {
    setState(() => _sortMode = mode);
    final query = _searchGlobalController.text;
    if (query.trim().isNotEmpty || _hasAnyFilter) {
      _searchDebounce?.cancel();
      _performSearch(query);
    }
  }

  String _sortLabel(String lang, SearchSortMode mode) {
    switch (mode) {
      case SearchSortMode.relevance:
        return Translations.get(lang, 'sort_relevance');
      case SearchSortMode.popularity:
        return Translations.get(lang, 'sort_popularity');
      case SearchSortMode.nameAsc:
        return Translations.get(lang, 'sort_name_az');
      case SearchSortMode.nameDesc:
        return Translations.get(lang, 'sort_name_za');
      case SearchSortMode.nutriscore:
        return Translations.get(lang, 'sort_nutriscore');
      case SearchSortMode.nova:
        return Translations.get(lang, 'sort_nova');
      case SearchSortMode.ecoscore:
        return Translations.get(lang, 'sort_ecoscore');
    }
  }

  Future<void> _openSortSheet() async {
    final lang = ref.read(appSettingsProvider).language;
    // Il badge "NUOVO" su NOVA/Eco-Score e' stato tolto il 2026-08-29: le due
    // opzioni sono in app dal 23/08, non sono piu' una novita' da segnalare.
    // Mockup: selezionare un'opzione la applica subito (la lista sotto si
    // riordina live) ma il foglio resta aperto finche' non si preme "Fatto"
    // — prima invece un tap chiudeva subito il foglio, impedendo di
    // confrontare piu' ordinamenti uno via l'altro senza riaprirlo ogni volta.
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.swap_vert, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(
                      Translations.get(lang, 'search_sort_title'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              for (final mode in SearchSortMode.values)
                ListTile(
                  leading: Icon(
                    mode == _sortMode ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: mode == _sortMode
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  title: Text(_sortLabel(lang, mode)),
                  onTap: () {
                    _onSortChanged(mode);
                    setSheetState(() {});
                  },
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(Translations.get(lang, 'search_sort_done')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(subtitle,
                style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _scoreBox({required String label, required bool selected, required Color color, required VoidCallback onTap}) {
    final fg = selected ? _fgOnScore(color) : color;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: selected ? color : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : Theme.of(context).colorScheme.outlineVariant, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: fg)),
        ),
      ),
    );
  }

  Widget _novaBox({required String label, required String sub, required bool selected, required Color color, required VoidCallback onTap}) {
    final fg = selected ? _fgOnScore(color) : color;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : Theme.of(context).colorScheme.outlineVariant, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // I box sono ora tutti alti quanto il piu' alto (_spacedRow): senza
            // questo il contenuto dei box con sottotitolo su una riga sola
            // resterebbe incollato in alto invece di stare centrato.
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: fg)),
              const SizedBox(height: 3),
              Text(
                sub,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.15,
                  color: selected ? fg.withValues(alpha: .85) : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Riga di box punteggio equidistanti e **della stessa altezza**.
  ///
  /// Il sottotitolo di _novaBox puo' occupare 1 o 2 righe a seconda della
  /// lingua (maxLines: 2), e con la sola `Column(mainAxisSize: min)` i quattro
  /// box NOVA venivano fuori di altezze diverse. `IntrinsicHeight` + `stretch`
  /// li allinea al piu' alto: vale anche per la riga Eco-Score, che usa questa
  /// stessa funzione. Corretto il 2026-08-29.
  Widget _spacedRow(List<Widget> boxes) {
    final children = <Widget>[];
    for (var i = 0; i < boxes.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 9));
      children.add(boxes[i]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _marketRow({required String name, required String count, required bool selected, required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer.withValues(alpha: .35) : Colors.transparent,
          border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6))),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: selected ? scheme.primary : scheme.outline, width: 2),
                color: selected ? scheme.primary : Colors.transparent,
              ),
              child: selected ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5)),
            ),
            if (count.isNotEmpty)
              Text(count, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final lang = ref.read(appSettingsProvider).language;
    final tempInsegne = Set<String>.from(_insegneSelezionate);
    final tempNutri = Set<String>.from(_nutriscoreSelezionati);
    final tempNova = Set<int>.from(_novaSelezionati);
    final tempEco = Set<String>.from(_ecoscoreSelezionati);
    final searchCtrl = TextEditingController();

    final applicato = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtro = searchCtrl.text.trim().toLowerCase();
          final visibili = filtro.isEmpty
              ? _insegneDisponibili
              : _insegneDisponibili.where((e) => e.insegna.toLowerCase().contains(filtro)).toList();
          final tempCount = tempInsegne.length + tempNutri.length + tempNova.length + tempEco.length;

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: DraggableScrollableSheet(
                initialChildSize: 0.82,
                minChildSize: 0.5,
                maxChildSize: 0.94,
                expand: false,
                builder: (ctx, scrollController) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Row(
                        children: [
                          Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              Translations.get(lang, 'search_filter_title'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          TextButton(
                            onPressed: tempCount == 0
                                ? null
                                : () => setSheetState(() {
                                    tempInsegne.clear();
                                    tempNutri.clear();
                                    tempNova.clear();
                                    tempEco.clear();
                                  }),
                            child: Text(Translations.get(lang, 'search_filter_clear')),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        children: [
                          _sectionHeader(
                            Translations.get(lang, 'filter_nutriscore_title'),
                            Translations.get(lang, 'filter_nutriscore_subtitle'),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 22),
                            child: _spacedRow([
                              for (final v in ['a', 'b', 'c', 'd', 'e'])
                                _scoreBox(
                                  label: v.toUpperCase(),
                                  selected: tempNutri.contains(v),
                                  color: _nutriScoreColors[v]!,
                                  onTap: () => setSheetState(() {
                                    tempNutri.contains(v) ? tempNutri.remove(v) : tempNutri.add(v);
                                  }),
                                ),
                            ]),
                          ),
                          _sectionHeader(
                            Translations.get(lang, 'filter_nova_title'),
                            Translations.get(lang, 'filter_nova_subtitle'),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 22),
                            child: _spacedRow([
                              for (final v in [1, 2, 3, 4])
                                _novaBox(
                                  label: '$v',
                                  sub: Translations.get(lang, 'nova_short_$v'),
                                  selected: tempNova.contains(v),
                                  color: _novaColors[v]!,
                                  onTap: () => setSheetState(() {
                                    tempNova.contains(v) ? tempNova.remove(v) : tempNova.add(v);
                                  }),
                                ),
                            ]),
                          ),
                          _sectionHeader(
                            Translations.get(lang, 'filter_ecoscore_title'),
                            Translations.get(lang, 'filter_ecoscore_subtitle'),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 22),
                            child: _spacedRow([
                              for (final v in ['a', 'b', 'c', 'd', 'e'])
                                _scoreBox(
                                  label: v.toUpperCase(),
                                  selected: tempEco.contains(v),
                                  color: _ecoScoreColors[v]!,
                                  onTap: () => setSheetState(() {
                                    tempEco.contains(v) ? tempEco.remove(v) : tempEco.add(v);
                                  }),
                                ),
                            ]),
                          ),
                          if (_insegneDisponibili.isNotEmpty) ...[
                            _sectionHeader(
                              Translations.get(lang, 'filter_supermarkets_title'),
                              tempInsegne.isEmpty
                                  ? '${Translations.get(lang, 'filter_supermarkets_all_short')} · ${_insegneDisponibili.length} ${Translations.get(lang, 'filter_supermarkets_chains_suffix')}'
                                  : '${tempInsegne.length} ${Translations.get(lang, 'filter_supermarkets_selected_suffix')}',
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: TextField(
                                controller: searchCtrl,
                                onChanged: (_) => setSheetState(() {}),
                                decoration: InputDecoration(
                                  hintText: Translations.get(lang, 'search_filter_search_hint'),
                                  prefixIcon: Icon(Icons.search, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _marketRow(
                                    name: Translations.get(lang, 'search_filter_apply_all'),
                                    count: '',
                                    selected: tempInsegne.isEmpty,
                                    onTap: () => setSheetState(tempInsegne.clear),
                                  ),
                                  if (visibili.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        Translations.get(lang, 'search_not_found'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                    )
                                  else
                                    for (final ins in visibili)
                                      _marketRow(
                                        name: _capitalizeSimple(ins.insegna),
                                        count: '(${ins.nProdotti})',
                                        selected: tempInsegne.contains(ins.insegna),
                                        onTap: () => setSheetState(() {
                                          tempInsegne.contains(ins.insegna)
                                              ? tempInsegne.remove(ins.insegna)
                                              : tempInsegne.add(ins.insegna);
                                        }),
                                      ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            tempCount == 0
                                ? Translations.get(lang, 'search_filter_apply_all')
                                : '${Translations.get(lang, 'search_filter_apply')} ($tempCount)',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (applicato == true) {
      _applyFilters(insegne: tempInsegne, nutriscore: tempNutri, nova: tempNova, ecoscore: tempEco);
    }
  }

  /// Riga di chip rimovibili per i filtri attivi (mockup: "activeChips" +
  /// "Clear all"), sotto le pillole Filtro/Ordina. Compare solo se c'e'
  /// almeno un filtro, cosi' non occupa spazio quando non serve.
  Widget _buildActiveFiltersRow(String lang) {
    final chips = <({String label, Color bg, Color fg, VoidCallback onRemove})>[
      for (final v in _nutriscoreSelezionati)
        (
          label: 'Nutri ${v.toUpperCase()}',
          bg: _nutriScoreColors[v]!,
          fg: _fgOnScore(_nutriScoreColors[v]!),
          onRemove: () => _removeOneFilter(nutriscore: v),
        ),
      for (final v in _novaSelezionati)
        (
          label: 'NOVA $v',
          bg: _novaColors[v]!,
          fg: _fgOnScore(_novaColors[v]!),
          onRemove: () => _removeOneFilter(nova: v),
        ),
      for (final v in _ecoscoreSelezionati)
        (
          label: 'Eco ${v.toUpperCase()}',
          bg: _ecoScoreColors[v]!,
          fg: _fgOnScore(_ecoScoreColors[v]!),
          onRemove: () => _removeOneFilter(ecoscore: v),
        ),
      for (final v in _insegneSelezionate)
        (
          label: _capitalizeSimple(v),
          bg: Theme.of(context).colorScheme.primaryContainer,
          fg: Theme.of(context).colorScheme.onPrimaryContainer,
          onRemove: () => _removeOneFilter(insegna: v),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final c in chips)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: c.onRemove,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: c.fg)),
                      const SizedBox(width: 6),
                      Icon(Icons.close, size: 16, color: c.fg.withValues(alpha: .75)),
                    ],
                  ),
                ),
              ),
            ),
          InkWell(
            onTap: () => _applyFilters(insegne: {}, nutriscore: {}, nova: {}, ecoscore: {}),
            borderRadius: BorderRadius.circular(15),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Theme.of(context).colorScheme.outline, style: BorderStyle.solid),
              ),
              child: Text(
                Translations.get(lang, 'filter_clear_all'),
                style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Carica la libreria personale, tenendone una copia sul telefono.
  ///
  /// PERCHE' LA COPIA (2026-09-05): la ricerca testuale mescola gia' gli
  /// alimenti dell'utente ai risultati esterni, ma quella lista arrivava solo
  /// dal server. Senza rete era vuota, e cercare un alimento creato da lui
  /// stesso non trovava niente — la cosa che dovrebbe esserci sempre, perche'
  /// e' sua. Ora se il server non risponde si riparte dall'ultima copia.
  ///
  /// La copia si aggiorna SOLO quando il server ha davvero risposto: una
  /// risposta valida ma vuota (l'utente ha cancellato tutto) svuota anche la
  /// copia, cosi' un alimento eliminato non torna a galla.
  Future<void> _loadData() async {
    final userEmail = ref.read(userProvider)?.email;
    if (userEmail == null) return;

    final recipes = await ApiServices.fetchRecipesOrNull(userEmail);
    final customFoods = await ApiServices.fetchCustomFoodsOrNull(userEmail);

    if (recipes != null) {
      await LocalFoodCache.salvaRicette(userEmail, recipes);
    }
    if (customFoods != null) {
      await LocalFoodCache.salvaAlimenti(userEmail, customFoods);
    }

    final ricetteDaMostrare =
        recipes ?? await LocalFoodCache.leggiRicette(userEmail);
    final alimentiDaMostrare =
        customFoods ?? await LocalFoodCache.leggiAlimenti(userEmail);
    _libreriaDaCopiaLocale = recipes == null || customFoods == null;

    if (mounted) {
      setState(() {
        _recipes = ricetteDaMostrare;
        _customFoods = alimentiDaMostrare;
      });
    }
  }

  /// Dove si va dopo aver registrato qualcosa nel diario.
  ///
  /// PERCHE' NON SEMPRE LA HOME (2026-09-12): questa funzione si chiamava
  /// `_resetAndGoHome` e portava SEMPRE alla tab Home. Va bene quando siamo
  /// la tab "Aggiungi", che non ha nessuna schermata sotto; ma aperta dal "+"
  /// di un pasto o dal dettaglio di un pasto, cambiava la tab sotto lasciando
  /// questa pagina in cima: chiudendola l'utente si trovava sulla Home invece
  /// che sul pasto da cui era partito. Segnalato da Ismail.
  void _dopoLAggiunta() {
    if (!mounted) return;
    if (widget.comeSchermata) {
      // `true` = "ho aggiunto qualcosa": chi ci ha aperti ricarica i suoi
      // dati (vedi home_page.dart e meal_detail_page.dart).
      Navigator.pop(context, true);
      return;
    }
    ref.read(initialMealTypeProvider.notifier).state = null;
    ref.read(currentTabIndexProvider.notifier).state = 0;
  }

  Future<void> _scanBarcode(String? mealType) async {
    try {
      final scanResult = await BarcodeScanner.scan();
      if (scanResult.type == ResultType.Barcode) {

        final currentLang = ref.read(appSettingsProvider).language;
        final product = await ApiServices.fetchProductByBarcode(
          scanResult.rawContent,
          lang: currentLang,
          userMail: ref.read(userProvider)?.email ?? '',
        );

        if (product != null && mounted) {
          final navigator = Navigator.of(context);
          
          // Se il prodotto ha 0 calorie, potrebbe essere un errore del database o acqua.
          // Invece di bloccare, chiediamo all'utente se vuole procedere manualmente.
          if ((product['calories'] as num?) == 0 && 
              (product['proteins'] as num?) == 0 && 
              (product['carbs'] as num?) == 0) {
            
            final proceed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(Translations.get(currentLang, 'Dati incompleti')),
                content: Text(Translations.get(currentLang, 'barcode_data_missing_msg')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(Translations.get(currentLang, 'Annulla')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(Translations.get(currentLang, 'Procedi comunque')),
                  ),
                ],
              ),
            );
            
            if (proceed != true) return;
          }

          final navResult = await navigator.push(
            MaterialPageRoute(
              builder: (context) => ManualEntryPage(
                dataVoce: widget.dataVoce,
                prefillData: product,
                initialMealType: mealType,
                returnAsIngredient: widget.returnAsIngredient,
                isAddingFromLibrary: true,
              ),
            ),
          );

          if (navResult != null && mounted) {
            if (widget.returnAsIngredient) {
              navigator.pop(navResult);
            } else if (navResult == true) {
              _dopoLAggiunta();
            }
          }
        } else if (mounted) {
          final currentLang = ref.read(appSettingsProvider).language;
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
            final navResult = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ManualEntryPage(
                  dataVoce: widget.dataVoce,
                  barcode: scanResult.rawContent,
                  initialMealType: mealType,
                  returnAsIngredient: widget.returnAsIngredient,
                ),
              ),
            );
            if (navResult != null && mounted) {
              if (widget.returnAsIngredient) {
                Navigator.pop(context, navResult);
              } else if (navResult == true) {
                _dopoLAggiunta();
              }
            }
          }
        }
      }
    } catch (e) {
      // Fotocamera negata, non un errore qualsiasi, e in lingua: il messaggio
      // era fisso in italiano (test di release 19/09).
      final lang = ref.read(appSettingsProvider).language;
      final negata = e is PlatformException && e.code == BarcodeScanner.cameraAccessDenied;
      _showError(Translations.get(lang, negata ? 'camera_permission_denied' : 'scan_error'));
    } finally {
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
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

  Future<void> _toggleFoodFav(Map<String, dynamic> food) async {
    final userEmail = ref.read(userProvider)?.email;
    if (userEmail == null || food['id'] == null) return;

    final currentStatus =
        (food['is_favorite'] == 1 || food['is_favorite'] == true);
    final newStatus = !currentStatus;

    final success = await ApiServices.toggleCustomFoodFavorite(
      userEmail,
      int.parse(food['id'].toString()),
      newStatus,
    );
    if (success && mounted) {
      setState(() {
        food['is_favorite'] = newStatus ? 1 : 0;
      });
    }
  }

  /// Propone o ritira UN alimento personale (2026-09-12, punto 2 della
  /// collaborazione).
  ///
  /// Il consenso generale nelle impostazioni muove tutti gli alimenti in
  /// blocco; questo serve all'eccezione: "tutti tranne questo", che e'
  /// esattamente cio' che chiede la ROADMAP. Un alimento gia' pubblico si
  /// ritira solo da qui, e solo dopo una conferma: sparisce dal database che
  /// gli altri vedono, e non e' una cosa da fare con un tocco distratto.
  Future<void> _cambiaCondivisioneAlimento(Map<String, dynamic> food) async {
    final lang = ref.read(appSettingsProvider).language;
    final email = ref.read(userProvider)?.email;
    if (email == null || email.isEmpty || food['id'] == null) return;

    final stato = (food['shared_status'] ?? 'private').toString();
    // Approvato = del database (15/09): non si ritira piu', si spiega perche'.
    if (stato == 'approved') {
      await mostraContenutoBloccato(context, lang);
      return;
    }
    final vuoleCondividere = stato != 'pending';

    final esito = await ApiServices.shareCustomFood(
      userEmail: email,
      id: int.parse(food['id'].toString()),
      share: vuoleCondividere,
    );
    if (!mounted) return;

    if (esito['status'] != 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('${Translations.get(lang, 'share_failed')} ${esito['message'] ?? ''}'.trim()),
        ),
      );
      return;
    }

    // Lo stato scritto e' quello che risponde il SERVER, non quello che
    // avevamo chiesto: riproporre un alimento gia' approvato, per esempio,
    // non lo rimette in coda, e l'icona deve dire cio' che e' vero la'.
    final nuovo = (esito['shared_status'] ?? stato).toString();
    setState(() => food['shared_status'] = nuovo);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          Translations.get(
            lang,
            nuovo == 'pending'
                ? 'share_food_proposed'
                : nuovo == 'approved'
                    ? 'share_state_approved'
                    : 'share_food_withdrawn',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mealType =
        widget.initialMealType ?? ref.watch(initialMealTypeProvider);

    // Barra col titolo e la freccia indietro in TUTTI i casi in cui questa
    // non e' la tab "Aggiungi" ma una schermata aperta sopra un'altra
    // (2026-09-12): prima l'aveva solo la scelta dell'ingrediente, quindi
    // arrivando qui dal "+" di un pasto in Home o dal dettaglio di un pasto
    // l'unico modo per tornare indietro era il gesto di sistema — nessun
    // pulsante visibile. Dentro la tab invece la freccia non ci va: non c'e'
    // nessuna schermata sotto da cui si sia arrivati, ci pensa MainLayout.
    final lang = ref.watch(appSettingsProvider).language;
    final bool conBarra = !_dentroAllaTab;
    final String titoloBarra = widget.returnAsIngredient
        ? Translations.get(lang, 'search_add_ingredient')
        : mealType != null
            ? Translations.get(lang, mealType)
            : Translations.get(lang, 'search_add_food');

    return Scaffold(
        appBar: AppBar(
          toolbarHeight: conBarra ? 56 : 0,
          elevation: 0,
          title: conBarra
              ? Text(
                  titoloBarra,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
          centerTitle: true,
          leading: conBarra
              ? IconButton(
                  icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
                  tooltip: Translations.get(lang, 'Indietro'),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          bottom: TabBar(
            controller: _tabController,
            isScrollable: false,
            labelPadding: EdgeInsets.zero,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: [
              Tab(text: Translations.get(ref.watch(appSettingsProvider).language, 'search_add_food')),
              if (!widget.returnAsIngredient)
                Tab(text: Translations.get(ref.watch(appSettingsProvider).language, 'search_saved_recipes')),
              Tab(text: Translations.get(ref.watch(appSettingsProvider).language, 'search_saved_foods')),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAddElementTab(mealType),
            if (!widget.returnAsIngredient) _buildRecipeTab(mealType),
            _buildMyFoodsTab(mealType),
          ],
        ),
    );
  }

  // Metadati extra 2026-07-24 (Nutri-Score, foto, marca): presenti solo per
  // i prodotti che vengono da na_off_products (fonte 'off_local_it'), le
  // altre fonti (CREA/USDA) non li hanno e i widget qui sotto degradano
  // semplicemente a icona/nessun badge senza errori.

  String _capitalizeSimple(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _buildFoodAvatar(Map<String, dynamic> product) {
    final String imageUrl = (product['image_url'] ?? '').toString();
    final fallback = CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(
        Icons.search_outlined,
        color: Theme.of(context).colorScheme.primary,
        size: 18,
      ),
    );
    if (imageUrl.isEmpty) return fallback;
    // Toccando la miniatura si apre la foto intera (21/09): in un elenco di
    // risultati e' spesso l'unico modo per capire se il prodotto e' proprio
    // quello che si ha in mano.
    return ImmagineZoomabile(
      immagine: nutriImageProvider(imageUrl),
      titolo: (product['food_name'] ?? '').toString(),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: 40,
              height: 40,
              child: fallback,
            );
          },
        ),
      ),
    );
  }

  /// Riga dei tre badge punteggio (Nutri-Score/NOVA/Eco-Score) sotto il nome
  /// nei risultati di ricerca, stessa composizione del mockup "Add Food".
  /// Ogni badge compare solo se il dato e' davvero presente sulla riga (niente
  /// NOVA/Eco per gli alimenti personali, che non hanno l'environmental score):
  /// niente e' inventato quando la fonte non lo fornisce.
  Widget _scoreChip({required String label, required Color bg, required Color fg}) {
    return Container(
      margin: const EdgeInsets.only(right: 5),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildScoreBadgesRow(Map<String, dynamic> product) {
    final chips = <Widget>[];
    final nutri = (product['nutriscore_grade'] ?? '').toString().toLowerCase().trim();
    final nutriColor = _nutriScoreColors[nutri];
    if (nutriColor != null) {
      chips.add(_scoreChip(label: nutri.toUpperCase(), bg: nutriColor, fg: _fgOnScore(nutriColor)));
    }
    final novaRaw = product['nova_group'];
    final nova = novaRaw == null ? 0 : int.tryParse(novaRaw.toString()) ?? 0;
    final novaColor = _novaColors[nova];
    if (novaColor != null) {
      chips.add(_scoreChip(label: 'NOVA $nova', bg: novaColor, fg: _fgOnScore(novaColor)));
    }
    final eco = (product['environmental_score_grade'] ?? '').toString().toLowerCase().trim();
    final ecoColor = _ecoScoreColors[eco];
    if (ecoColor != null) {
      chips.add(_scoreChip(label: 'ECO ${eco.toUpperCase()}', bg: ecoColor, fg: _fgOnScore(ecoColor)));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: chips),
    );
  }

  /// Riga risultato di ricerca (tab "Add Food" e "Saved Foods", stessa
  /// composizione per coerenza): nome + marca/unita' + badge punteggio a
  /// sinistra, kcal/proteine a destra, pulsante "+" per aggiungere subito.
  /// Il tap sul "+" apre la stessa pagina di inserimento del tap sulla riga
  /// (serve comunque scegliere la quantita'): e' un'affordance visiva in piu',
  /// non un salvataggio "alla cieca" di una porzione indovinata.
  Widget _buildSearchResultRow({
    required Map<String, dynamic> product,
    required VoidCallback onTap,
    Widget? trailingExtra,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final String brandLabel = _capitalizeSimple((product['brand'] ?? '').toString());
    final num? servingQuantity = product['serving_quantity'] as num?;
    // "Porzione" e "per" erano scritti in italiano nel codice e restavano
    // tali in inglese, cinese e arabo (test di release 19/09).
    final lingua = ref.read(appSettingsProvider).language;
    final String quanto = (servingQuantity != null && servingQuantity > 0)
        ? '${Translations.get(lingua, 'Porzione')} ${UnitFormat.p(servingQuantity)}'
        : '${Translations.get(lingua, 'search_result_per')} ${UnitFormat.p(double.tryParse('${product['base_weight_g'] ?? 100}') ?? 100)}';
    final String metaLine = brandLabel.isNotEmpty ? '$brandLabel · $quanto' : quanto;
    final num? kcal = product['calories'] as num?;
    final num? protein = product['proteins'] as num?;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildFoodAvatar(product),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['food_name'] ?? 'Senza nome',
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(metaLine, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  _buildScoreBadgesRow(product),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (kcal != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(UnitFormat.e(kcal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  if (protein != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        '${UnitFormat.pNutriente(protein)} prot.',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            const SizedBox(width: 8),
            trailingExtra ??
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                    child: Icon(Icons.add, color: scheme.primary, size: 22),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddElementTab(String? mealType) {
    final lang = ref.watch(appSettingsProvider).language;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
          width: double.infinity,
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  Translations.get(lang, 'search_info_banner'),
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchGlobalController,
              textInputAction: TextInputAction.search,
              onSubmitted: (val) {
                // Invio esplicito: salta il debounce e cerca subito.
                _searchDebounce?.cancel();
                _performSearch(val);
              },
              decoration: InputDecoration(
                hintText: Translations.get(ref.watch(appSettingsProvider).language, 'search_hint_food'),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchGlobalController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchDebounce?.cancel();
                          _searchSubscription?.cancel();
                          _searchGlobalController.clear();
                          setState(() {
                            _searchResults = [];
                            _isSearching = false;
                            _isSearchRefining = false;
                            _searchHadNetworkError = false;
                          });
                        },
                      ),
                    IconButton(
                      icon: Icon(
                        CupertinoIcons.barcode,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () => _scanBarcode(mealType),
                    ),
                  ],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Barra Filtro/Ordina (ridisegnata 2026-08-23, prima erano chip di
        // sole insegne a selezione singola). Il pulsante Filtro compare solo
        // se il server ha davvero delle insegne da offrire (na_product_retailer
        // importata e popolata) — prima di allora niente da filtrare, "Ordina
        // per" invece ha sempre senso (si applica anche a CREA/USDA).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _FilterSortPill(
                  icon: Icons.tune,
                  label: Translations.get(lang, 'search_filter_title'),
                  highlighted: _hasAnyFilter,
                  badgeCount: _hasAnyFilter ? _filterCount : null,
                  onTap: _openFilterSheet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FilterSortPill(
                  icon: Icons.swap_vert,
                  // Mockup: il pulsante Ordina non ha mai lo stile "attivo" del
                  // pulsante Filtri (resta bianco/bordato anche con un
                  // ordinamento diverso da Rilevanza) — solo l'etichetta cambia.
                  label: _sortLabel(lang, _sortMode),
                  highlighted: false,
                  badgeCount: null,
                  onTap: _openSortSheet,
                ),
              ),
            ],
          ),
        ),
        _buildActiveFiltersRow(lang),

        // Indicatore leggero: alcune fonti hanno già risposto (i risultati
        // sotto sono già visibili e utilizzabili) ma altre sono ancora in
        // corso e potrebbero aggiungerne/riordinarli a breve. Niente
        // spinner a piena pagina qui: quello si vede solo mentre non c'è
        // ancora nessun risultato da mostrare (_isSearching sotto).
        if (_isSearchRefining && !_isSearching)
          LinearProgressIndicator(
            minHeight: 2,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Colors.transparent,
          ),

        Expanded(
          child: (_isSearching || (_searchResults.isEmpty && _isSearchRefining))
              ? Center(
                  child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                )
              : _searchResults.isNotEmpty
              ? Column(
                  children: [
                    // Riga "N alimenti" / "Ordinati per: ..." sopra la lista
                    // (mockup: resultCountLabel + sortLabel), mancava del
                    // tutto prima — l'utente non aveva modo di sapere quanti
                    // risultati stesse guardando ne' con quale ordinamento.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_searchResults.length} ${Translations.get(lang, 'search_result_count_unit')}',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          Text(
                            '${Translations.get(lang, 'search_sorted_by_prefix')} ${_sortLabel(lang, _sortMode)}',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = _searchResults[index];
                          return _buildSearchResultRow(
                            product: product,
                            onTap: () async {
                              final navigator = Navigator.of(context);
                              final result = await navigator.push(
                                MaterialPageRoute(
                                  builder: (context) => ManualEntryPage(
                                    dataVoce: widget.dataVoce,
                                    prefillData: product,
                                    initialMealType: widget.initialMealType,
                                    returnAsIngredient: widget.returnAsIngredient,
                                    isAddingFromLibrary: true,
                                  ),
                                ),
                              );
                              if (result != null && mounted) {
                                if (widget.returnAsIngredient) {
                                  navigator.pop(result);
                                } else if (result == true) {
                                  _dopoLAggiunta();
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                )
              : _searchHadNetworkError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          color: Nutri.muted,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _libreriaDaCopiaLocale
                              ? '${Translations.get(lang, 'search_error_network')}\n'
                                  '${Translations.get(lang, 'search_offline_library')}'
                              : Translations.get(lang, 'search_error_network'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () =>
                              _performSearch(_searchGlobalController.text),
                          child: Text(Translations.get(lang, 'search_retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    _searchGlobalController.text.isEmpty
                        ? Translations.get(lang, 'search_start')
                        : Translations.get(lang, 'search_not_found'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
        ),

        _buildManualLink(mealType),
      ],
    );
  }

  /// Etichetta di tab con badge conteggio — stesso linguaggio visivo del
  /// filtro/ordina in _buildAddElementTab (richiesta 2026-08-23: coerenza fra
  /// le tab "Aggiungi"/"Ricette salvate"/"Alimenti salvati" di questa stessa
  /// schermata, prima erano rimaste al vecchio stile senza conteggio).
  Widget _tabLabelWithCount(String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeTab(String? mealType) {
    final lang = ref.watch(appSettingsProvider).language;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _buildSearchField(
            _searchRecipeController,
            Translations.get(lang, 'search_hint_recipe'),
            Theme.of(context).colorScheme.primary,
          ),
          TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(child: _tabLabelWithCount(Translations.get(lang, 'search_all'), _recipes.length)),
              Tab(
                child: _tabLabelWithCount(
                  Translations.get(lang, 'search_favorites'),
                  _recipes.where((r) => r.isFavorite).length,
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRecipeList(mealType, _recipes, _searchRecipeQuery),
                _buildRecipeList(
                  mealType,
                  _recipes.where((r) => r.isFavorite).toList(),
                  _searchRecipeQuery,
                ),
              ],
            ),
          ),
          _buildNewRecipeLink(),
        ],
      ),
    );
  }

  Widget _buildRecipeList(
    String? mealType,
    List<Recipe> recipes,
    String query,
  ) {
    final filtered = recipes
        .where((r) => r.name.toLowerCase().contains(query))
        .toList();
    return filtered.isEmpty
        ? Center(child: Text(Translations.get(ref.watch(appSettingsProvider).language, 'search_not_found')))
        : ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final recipe = filtered[index];
              // La foto della ricetta anche qui (2026-09-09): questa lista
              // mostrava sempre la stessa icona generica, mentre l'elenco
              // Ricette mostra gia' la foto. Stessa ricetta, due aspetti
              // diversi a seconda da dove ci si arriva.
              final fotoRicetta = nutriImageProvider(recipe.imageUrl);
              return ListTile(
                leading: ImmagineZoomabile(
                  immagine: fotoRicetta,
                  titolo: recipe.name,
                  child: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: fotoRicetta,
                    onBackgroundImageError:
                        fotoRicetta == null ? null : (_, _) {},
                    child: fotoRicetta != null
                        ? null
                        : Icon(
                            Icons.restaurant_menu,
                            color: Theme.of(context).colorScheme.primary,
                            size: 18,
                          ),
                  ),
                ),
                title: Text(
                  recipe.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  '${UnitFormat.e(recipe.calories)} ${Translations.get(ref.watch(appSettingsProvider).language, 'totali')}',
                ),
                trailing: IconButton(
                  icon: Icon(
                    recipe.isFavorite ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () => _toggleRecipeFav(recipe),
                ),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailPage(
                        recipe: recipe,
                        dataVoce: widget.dataVoce,
                        initialMealType: mealType,
                      ),
                    ),
                  );
                  if (result == true) _dopoLAggiunta();
                },
              );
            },
          );
  }

  Widget _buildMyFoodsTab(String? mealType) {
    final lang = ref.watch(appSettingsProvider).language;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _buildSearchField(
            _searchFoodController,
            Translations.get(lang, 'search_hint_my_foods'),
            Theme.of(context).colorScheme.primary,
          ),
          TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(child: _tabLabelWithCount(Translations.get(lang, 'search_all'), _customFoods.length)),
              Tab(
                child: _tabLabelWithCount(
                  Translations.get(lang, 'search_favorites'),
                  _customFoods.where((f) => f['is_favorite'] == 1 || f['is_favorite'] == true).length,
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFoodList(mealType, _customFoods, _searchFoodQuery),
                _buildFoodList(
                  mealType,
                  _customFoods
                      .where(
                        (f) =>
                            f['is_favorite'] == 1 || f['is_favorite'] == true,
                      )
                      .toList(),
                  _searchFoodQuery,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodList(
    String? mealType,
    List<Map<String, dynamic>> foods,
    String query,
  ) {
    final filtered = foods
        .where((f) => (f['food_name'] ?? '').toLowerCase().contains(query))
        .toList();
    return filtered.isEmpty
        ? Center(child: Text(Translations.get(ref.watch(appSettingsProvider).language, 'search_not_found')))
        : ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final food = filtered[index];
              final isFav =
                  (food['is_favorite'] == 1 || food['is_favorite'] == true);
              void onTap() async {
                final navigator = Navigator.of(context);
                final result = await navigator.push(
                  MaterialPageRoute(
                    builder: (context) => ManualEntryPage(
                      dataVoce: widget.dataVoce,
                      prefillData: food,
                      isAddingFromLibrary: true,
                      initialMealType: mealType,
                      returnAsIngredient: widget.returnAsIngredient,
                      // Questo alimento arriva davvero dalla libreria
                      // personale (21/09): salvandolo di nuovo si aggiorna
                      // questa riga invece di aggiungerne una uguale.
                      idLibreria: int.tryParse('${food['id']}'),
                    ),
                  ),
                );

                if (result != null && mounted) {
                  if (widget.returnAsIngredient) {
                    navigator.pop(result);
                  } else if (result == true) {
                    _dopoLAggiunta();
                  }
                }
              }

              return _buildSearchResultRow(
                product: food,
                onTap: onTap,
                trailingExtra: widget.returnAsIngredient
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isFav ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            ),
                            onPressed: () => _toggleFoodFav(food),
                          ),
                          InkWell(
                            onTap: onTap,
                            borderRadius: BorderRadius.circular(20),
                            child: const Icon(Icons.add_circle_outline, color: Colors.green),
                          ),
                        ],
                      )
                    // Quattro azioni al posto di tre, ma piu' strette
                    // (2026-09-12): con tre IconButton a densita' piena
                    // (48 px ciascuno) aggiungerne un quarto avrebbe rubato
                    // lo spazio al nome dell'alimento su un telefono
                    // stretto. A densita' compatta i quattro occupano meno
                    // dei tre di prima.
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              isFav ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            ),
                            onPressed: () => _toggleFoodFav(food),
                          ),
                          Builder(
                            builder: (context) {
                              final stato = (food['shared_status'] ?? 'private').toString();
                              final segnale = segnaleCondivisione(
                                stato,
                                Theme.of(context).colorScheme,
                              );
                              return IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: Translations.get(
                                  ref.read(appSettingsProvider).language,
                                  segnale.chiave,
                                ),
                                icon: Icon(segnale.icona, color: segnale.colore, size: 20),
                                onPressed: () => _cambiaCondivisioneAlimento(food),
                              );
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.edit_note,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () async {
                              // Un alimento approvato non si modifica piu' (15/09).
                              if ((food['shared_status'] ?? '') == 'approved') {
                                await mostraContenutoBloccato(
                                  context,
                                  ref.read(appSettingsProvider).language,
                                );
                                return;
                              }
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ManualEntryPage(
                                    prefillData: food,
                                    isEditingMaster: true,
                                  ),
                                ),
                              );
                              if (updated == true && mounted) _loadData();
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _confirmDelete(food),
                          ),
                        ],
                      ),
              );
            },
          );
  }

  Widget _buildSearchField(
    TextEditingController controller,
    String hint,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(Icons.search, color: iconColor),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildManualLink(String? mealType) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ManualEntryPage(
                dataVoce: widget.dataVoce,
                initialMealType: mealType,
                returnAsIngredient: widget.returnAsIngredient,
              ),
            ),
          );

          if (result != null && mounted) {
            if (widget.returnAsIngredient) {
              Navigator.pop(context, result);
            } else if (result == true) {
              _dopoLAggiunta();
            }
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Translations.get(ref.watch(appSettingsProvider).language, 'search_manual_link_1'),
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
            ),
            NutriLinkTesto(
              testo: Translations.get(ref.watch(appSettingsProvider).language, 'search_manual_link_2'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewRecipeLink() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: InkWell(
        onTap: () async {
          final success = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreaRicettaPage()),
          );
          if (success == true && mounted) _loadData();
        },
        child: NutriLinkTesto(
          testo: Translations.get(ref.watch(appSettingsProvider).language, 'search_new_recipe'),
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> food) {
    final lang = ref.read(appSettingsProvider).language;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.get(lang, 'Elimina')),
        content: Text(
          '${Translations.get(lang, 'Eliminare permanentemente')} ${food['food_name']}?'
          '${food['shared_status'] == 'approved' ? '\n\n${Translations.get(lang, 'delete_public_warning')}' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Translations.get(lang, 'Annulla')),
          ),
          TextButton(
            onPressed: () async {
              final userEmail = ref.read(userProvider)?.email;
              final navigator = Navigator.of(ctx);
              if (userEmail != null && food['id'] != null) {
                final esito = await ApiServices.deleteCustomFoodDetailed(
                  userEmail,
                  int.parse(food['id'].toString()),
                );
                if (esito.ok && mounted) {
                  _loadData();
                  // Approvato = del database (15/09): va detto che resta.
                  if (esito.keptPublic) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(Translations.get(lang, 'delete_kept_public'))),
                    );
                  }
                }
              }
              if (mounted) navigator.pop();
            },
            child: Text(Translations.get(lang, 'Elimina'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Pulsante a pillola per "Filtro"/"Ordina per" sotto la barra di ricerca.
/// [highlighted] (filtro attivo o ordinamento diverso dal default) cambia
/// colore invece di lasciare il pulsante uguale a se stesso indipendentemente
/// da cosa e' selezionato — l'utente deve vedere a colpo d'occhio se un
/// filtro/ordinamento e' in corso.
class _FilterSortPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlighted;
  final int? badgeCount;
  final VoidCallback onTap;

  const _FilterSortPill({
    required this.icon,
    required this.label,
    required this.highlighted,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Mockup: icona/testo sono sempre verde primario, cambiano solo sfondo e
    // bordo del pillolo quando ci sono filtri attivi — non un chip "pieno" in
    // stile Material di default (che avrebbe reso il testo grigio a riposo).
    final Color bg = highlighted ? scheme.primaryContainer.withValues(alpha: .55) : scheme.surface;
    final Color border = highlighted ? scheme.primary : scheme.outlineVariant;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (badgeCount != null && badgeCount! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(color: scheme.onPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
