import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dictionary/translations.dart';
import '../domain/user_provider.dart';
import '../models/food_entry.dart';
import '../logic/unit_format.dart';
import '../providers/locale_provider.dart';
import '../services/api_services.dart';
import '../widgets/auth_style.dart';
import '../widgets/modern_loader.dart';
import '../widgets/state_message.dart';
import 'daily_detail_page.dart';

/// Calendario ridisegnato sul mockup "NutriApp Calendar" (2026-08-30).
///
/// Prima mostrava solo pallini verdi/rossi: giorno registrato oppure no. Il
/// mockup chiede di leggere il mese a colpo d'occhio — quanto si è mangiato
/// rispetto all'obiettivo, quali pasti mancano, che striscia si sta tenendo —
/// quindi ora tiene in memoria le voci vere e non solo l'insieme dei giorni.
class CalendarioPage extends ConsumerStatefulWidget {
  const CalendarioPage({super.key});

  @override
  ConsumerState<CalendarioPage> createState() => CalendarioPageState();
}

/// Riepilogo di un giorno: kcal totali, kcal per pasto, numero di voci.
typedef _Giorno = ({double kcal, Map<String, double> perPasto, int voci});

class CalendarioPageState extends ConsumerState<CalendarioPage> {
  static const List<String> _pasti = ['Colazione', 'Pranzo', 'Cena', 'Snack'];
  static const Map<String, IconData> _iconePasto = {
    'Colazione': Icons.coffee,
    'Pranzo': Icons.dinner_dining,
    'Cena': Icons.ramen_dining,
    'Snack': Icons.cookie,
  };

  // Tinte delle celle, dal mockup: sopra obiettivo in ambra, in linea in verde
  // pieno, sotto in verde chiaro, nessun pasto in grigio.
  //
  // In modalita' scura la TINTA resta la stessa — e' quella a portare il
  // significato, ed e' spiegata dalla legenda sotto la griglia — ma la
  // luminosita' si abbassa: i verdi chiari del tema chiaro, su fondo scuro,
  // diventavano macchie accese che davano piu' peso ai giorni vuoti che a
  // quelli registrati, cioe' il contrario di quello che devono dire.
  static Color get _cellaSopra => Nutri.scuro ? const Color(0xFF4A3A22) : const Color(0xFFF3D8B4);
  static Color get _cellaInLinea => Nutri.scuro ? const Color(0xFF2F5A2C) : const Color(0xFFB9DFAB);
  static Color get _cellaMedia => Nutri.scuro ? const Color(0xFF27452A) : const Color(0xFFD6EBCC);
  static Color get _cellaBassa => Nutri.scuro ? const Color(0xFF1F3320) : const Color(0xFFEAF4E6);
  static Color get _cellaVuota => Nutri.scuro ? const Color(0xFF20261F) : const Color(0xFFF1F4EC);
  static Color get _cellaFutura => Nutri.scuro ? const Color(0xFF171C16) : const Color(0xFFF7FAF5);
  static Color get _selezione => Nutri.scuro ? const Color(0xFF8FD494) : const Color(0xFF16532B);

  late DateTime _meseMostrato;
  late DateTime _selezionato;
  bool _isLoading = true;
  String? _errorMessage;

  /// Riepilogo per giorno normalizzato. Assente = giorno senza voci.
  Map<DateTime, _Giorno> _perGiorno = {};

  @override
  void initState() {
    super.initState();
    final oggi = DateTime.now();
    _meseMostrato = DateTime(oggi.year, oggi.month);
    _selezionato = _soloData(oggi);
    _loadEntries();
  }

  static DateTime _soloData(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadEntries() async {
    final userEmail = ref.read(userProvider)?.email;
    if (userEmail == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Il calendario guarda un anno indietro: piu' in la' non lo mostra,
      // e lo storico intero pesava a ogni apertura (19/09).
      final List<FoodEntry> entries = await ApiServices.fetchFoodEntries(
        userEmail,
        da: DateTime.now().subtract(const Duration(days: 366)),
      );
      final mappa = <DateTime, _Giorno>{};
      for (final e in entries) {
        final g = _soloData(e.entry_date);
        final prec = mappa[g] ?? (kcal: 0.0, perPasto: <String, double>{}, voci: 0);
        final perPasto = Map<String, double>.from(prec.perPasto);
        perPasto[e.meal_type] = (perPasto[e.meal_type] ?? 0) + e.macro.calories;
        mappa[g] = (
          kcal: prec.kcal + e.macro.calories,
          perPasto: perPasto,
          voci: prec.voci + 1,
        );
      }
      if (mounted) {
        setState(() {
          _perGiorno = mappa;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Celle della griglia: i giorni del mese più il riempimento per far
  /// quadrare le settimane da lunedì a domenica.
  List<DateTime> _celleDelMese(DateTime mese) {
    final primo = DateTime(mese.year, mese.month, 1);
    final ultimo = DateTime(mese.year, mese.month + 1, 0);
    final prima = primo.weekday - 1;
    final dopo = 7 - ultimo.weekday;
    return List.generate(
      prima + ultimo.day + dopo,
      (i) => primo.subtract(Duration(days: prima - i)),
    );
  }

  void _cambiaMese(int offset) {
    setState(() {
      _meseMostrato = DateTime(_meseMostrato.year, _meseMostrato.month + offset);
      // Selezione al primo del mese, come nel mockup: tenere selezionato un
      // giorno non più a schermo lascerebbe la scheda sotto scollegata da
      // quello che si sta guardando.
      _selezionato = DateTime(_meseMostrato.year, _meseMostrato.month, 1);
    });
  }

  double get _obiettivo {
    final g = ref.read(userProvider)?.calorieGoal ?? 0;
    return g > 0 ? g : 2000;
  }

  Color _coloreCella(DateTime giorno, bool futuro) {
    if (futuro) return _cellaFutura;
    final d = _perGiorno[giorno];
    if (d == null || d.voci == 0) return _cellaVuota;
    final r = d.kcal / _obiettivo;
    if (r > 1.12) return _cellaSopra;
    if (r > 0.75) return _cellaInLinea;
    if (r > 0.40) return _cellaMedia;
    return _cellaBassa;
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;

    return Scaffold(
      backgroundColor: Nutri.bg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: ModernLoader())
            : _errorMessage != null
                ? StateMessage(
                    icon: Icons.wifi_off_rounded,
                    title: Translations.get(lang, 'Errore di connessione'),
                    actionLabel: Translations.get(lang, 'Riprova'),
                    onPressed: _loadEntries,
                  )
                : RefreshIndicator(
                    color: Nutri.green,
                    onRefresh: _loadEntries,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        _navigatoreMese(lang),
                        const SizedBox(height: 12),
                        _statistiche(lang),
                        const SizedBox(height: 12),
                        _grigliaMese(lang),
                        const SizedBox(height: 12),
                        _schedaGiorno(lang),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _navigatoreMese(String lang) {
    final celle = _celleDelMese(_meseMostrato);
    final oggi = _soloData(DateTime.now());
    var conVoci = 0;
    var passati = 0;
    for (final g in celle) {
      if (g.month != _meseMostrato.month || g.isAfter(oggi)) continue;
      passati++;
      if ((_perGiorno[g]?.voci ?? 0) > 0) conVoci++;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        children: [
          _tondo(Icons.chevron_left, () => _cambiaMese(-1)),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${Translations.get(lang, _nomeMese(_meseMostrato.month))} ${_meseMostrato.year}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Nutri.ink,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$conVoci ${Translations.get(lang, 'su')} $passati ${Translations.get(lang, 'giorni registrati')}',
                  style: TextStyle(fontSize: 12, color: Nutri.mutedSoft),
                ),
              ],
            ),
          ),
          _tondo(Icons.chevron_right, () => _cambiaMese(1)),
        ],
      ),
    );
  }

  Widget _tondo(IconData icona, VoidCallback onTap) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icona, size: 23, color: Nutri.green),
        onPressed: onTap,
      ),
    );
  }

  /// Giorni registrati, striscia più lunga, media giornaliera.
  Widget _statistiche(String lang) {
    final celle = _celleDelMese(_meseMostrato);
    final oggi = _soloData(DateTime.now());
    var registrati = 0;
    double totale = 0;
    var striscia = 0;
    var migliore = 0;
    for (final g in celle) {
      if (g.month != _meseMostrato.month || g.isAfter(oggi)) continue;
      final d = _perGiorno[g];
      if (d != null && d.voci > 0) {
        registrati++;
        totale += d.kcal;
        striscia++;
        if (striscia > migliore) migliore = striscia;
      } else {
        striscia = 0;
      }
    }
    final media = registrati > 0 ? (totale / registrati).round() : 0;

    final voci = <(String, String, Color)>[
      (Translations.get(lang, 'Giorni registrati'), '$registrati', Nutri.green),
      // "7g" si leggeva come grammi, e quella g restava in italiano anche
      // nelle altre lingue (test di release 19/09).
      (
        Translations.get(lang, 'Striscia migliore'),
        '$migliore ${Translations.get(lang, migliore == 1 ? 'day_one' : 'day_many')}',
        Nutri.ink,
      ),
      // Nell'unita' scelta (18/09): prima era il numero delle kcal anche con
      // i kJ, senza sigla.
      (Translations.get(lang, 'Media giornaliera'), media > 0 ? UnitFormat.e(media) : '—', Nutri.ink),
    ];

    return Row(
      children: [
        for (var i = 0; i < voci.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: Nutri.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Nutri.fieldBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voci[i].$2,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: voci[i].$3,
                      letterSpacing: -0.5,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    voci[i].$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Nutri.mutedSoft),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _grigliaMese(String lang) {
    final celle = _celleDelMese(_meseMostrato);
    final oggi = _soloData(DateTime.now());
    const giorniSettimana = [
      'weekday_short_1', 'weekday_short_2', 'weekday_short_3', 'weekday_short_4',
      'weekday_short_5', 'weekday_short_6', 'weekday_short_7',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: Nutri.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Nutri.fieldBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      Translations.get(lang, giorniSettimana[i]),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: i > 4 ? Nutri.hint : Nutri.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: celle.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (_, i) => _cella(celle[i], oggi),
          ),
          Divider(height: 26, thickness: 1, color: Nutri.divider),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _voceLegenda(Translations.get(lang, 'In linea'), _cellaInLinea, const Color(0xFFA5D294)),
              _voceLegenda(Translations.get(lang, 'Sotto obiettivo'), _cellaBassa, const Color(0xFFD3E2CC)),
              _voceLegenda(Translations.get(lang, 'Sopra obiettivo'), _cellaSopra, const Color(0xFFE8C89C)),
              _voceLegenda(Translations.get(lang, 'Nessun pasto'), _cellaVuota, Nutri.hairline),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cella(DateTime giorno, DateTime oggi) {
    if (giorno.month != _meseMostrato.month) {
      return Center(
        child: Text(
          '${giorno.day}',
          style: const TextStyle(fontSize: 14, color: Color(0xFFC7CEC2)),
        ),
      );
    }

    final futuro = giorno.isAfter(oggi);
    final d = _perGiorno[giorno];
    final haVoci = (d?.voci ?? 0) > 0;
    final selezionato = giorno == _selezionato;
    final eOggi = giorno == oggi;

    // Un pallino per pasto registrato, ambra per gli snack: dice quanti pasti
    // ci sono senza dover aprire il giorno.
    final pallini = <Color>[];
    if (d != null) {
      for (final p in _pasti) {
        if ((d.perPasto[p] ?? 0) > 0) {
          pallini.add(p == 'Snack' ? const Color(0xFFE0A81E) : Nutri.green);
        }
      }
    }

    return GestureDetector(
      onTap: () => setState(() => _selezionato = giorno),
      child: Container(
        decoration: BoxDecoration(
          color: _coloreCella(giorno, futuro),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selezionato ? _selezione : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${giorno.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: (selezionato || eOggi) ? FontWeight.bold : FontWeight.w500,
                    color: futuro
                        ? const Color(0xFFB4BCB0)
                        : haVoci
                            ? _selezione
                            : const Color(0xFF9AA398),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final c in pallini.take(4))
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (eOggi)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 12,
                  height: 2,
                  decoration: BoxDecoration(
                    color: _selezione,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _voceLegenda(String label, Color colore, Color bordo) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: colore,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: bordo),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11.5, color: Nutri.muted)),
      ],
    );
  }

  /// Scheda del giorno selezionato: totale, barra, pasti, apertura.
  Widget _schedaGiorno(String lang) {
    final unita = ref.watch(appSettingsProvider).energyUnit;
    final oggi = _soloData(DateTime.now());
    final d = _perGiorno[_selezionato];
    final haVoci = (d?.voci ?? 0) > 0;
    final futuro = _selezionato.isAfter(oggi);
    final obiettivo = _obiettivo;
    final rapporto = haVoci ? d!.kcal / obiettivo : 0.0;
    final coloreBarra = rapporto > 1.12
        ? const Color(0xFFB77A15)
        : rapporto > 0.75
            ? Nutri.green
            : const Color(0xFF4E9A6B);
    final differenza = (d?.kcal ?? 0) - obiettivo;

    final relativo = _selezionato == oggi
        ? Translations.get(lang, 'Oggi')
        : _selezionato == oggi.subtract(const Duration(days: 1))
            ? Translations.get(lang, 'Ieri')
            : futuro
                ? Translations.get(lang, 'Data futura, ancora da registrare')
                : '${d?.voci ?? 0} ${Translations.get(lang, 'voci')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Nutri.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Nutri.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selezionato.day} ${Translations.get(lang, _nomeMese(_selezionato.month))} ${_selezionato.year}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Nutri.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      relativo,
                      style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft),
                    ),
                  ],
                ),
              ),
              if (haVoci)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      UnitFormat.energyValue(d!.kcal, unita),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Nutri.ink,
                        letterSpacing: -0.7,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Translations.get(lang, 'su')} ${UnitFormat.energy(obiettivo, unita)}',
                      style: TextStyle(fontSize: 11.5, color: Nutri.mutedSoft),
                    ),
                  ],
                ),
            ],
          ),
          if (haVoci) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: rapporto.clamp(0.0, 1.0),
                minHeight: 9,
                backgroundColor: Nutri.surfaceSoft,
                valueColor: AlwaysStoppedAnimation(coloreBarra),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              differenza > 0
                  ? '${UnitFormat.energy(differenza, unita)} ${Translations.get(lang, 'sopra il tuo obiettivo')}'
                  : '${UnitFormat.energy(differenza.abs(), unita)} ${Translations.get(lang, 'ancora disponibili')}',
              style: TextStyle(fontSize: 12, color: coloreBarra),
            ),
            const SizedBox(height: 14),
            for (final p in _pasti) _rigaPasto(lang, p, d!),
            const SizedBox(height: 14),
            _pulsanteApri(lang, pieno: false),
          ] else ...[
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.restaurant, size: 28, color: Color(0xFFBAC4B4)),
                  const SizedBox(height: 9),
                  Text(
                    futuro
                        ? Translations.get(lang, 'Ancora niente in programma')
                        : Translations.get(lang, 'Nessun pasto registrato'),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: Nutri.body,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    futuro
                        ? Translations.get(lang, 'Questo giorno non è ancora arrivato, ma puoi già pianificarlo.')
                        : Translations.get(lang, 'Quel giorno non è stato registrato nulla. Puoi aggiungerlo ora.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  _pulsanteApri(lang, pieno: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rigaPasto(String lang, String pasto, _Giorno d) {
    final unita = ref.watch(appSettingsProvider).energyUnit;
    final kcal = d.perPasto[pasto] ?? 0;
    final presente = kcal > 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F4EC))),
      ),
      child: Row(
        children: [
          Icon(
            _iconePasto[pasto],
            size: 19,
            color: presente ? Nutri.green : const Color(0xFFC4CCBF),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              Translations.get(lang, pasto),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: presente ? Nutri.ink : Nutri.hint,
              ),
            ),
          ),
          Text(
            presente ? UnitFormat.energy(kcal, unita) : '—',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: presente ? Nutri.ink : const Color(0xFFC4CCBF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pulsanteApri(String lang, {required bool pieno}) {
    Future<void> apri() async {
      final res = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DailyDetailPage(initialDate: _selezionato)),
      );
      if (res == true && mounted) _loadEntries();
    }

    if (pieno) {
      return GestureDetector(
        onTap: apri,
        child: Container(
          height: 44,
          padding: const EdgeInsets.fromLTRB(14, 0, 17, 0),
          decoration: BoxDecoration(
            color: Nutri.greenFill,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 20, color: Nutri.onGreenFill),
              const SizedBox(width: 7),
              Text(
                Translations.get(lang, 'Registra un pasto'),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Nutri.card,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: apri,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Nutri.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC3D8BA), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              Translations.get(lang, 'Apri questo giorno'),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: Nutri.green,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 19, color: Nutri.green),
          ],
        ),
      ),
    );
  }

  /// Chiave del mese per il dizionario: i nomi erano scritti in italiano
  /// nel codice e restavano tali in inglese, cinese e arabo (test di release
  /// 19/09).
  String _nomeMese(int m) => 'month_full_$m';
}
