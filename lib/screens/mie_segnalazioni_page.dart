import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dictionary/translations.dart';
import '../domain/user_provider.dart';
import '../models/contributi_utente.dart';
import '../models/segnalazione_utente.dart';
import '../providers/locale_provider.dart';
import '../services/api_services.dart';
import '../widgets/auth_style.dart';

/// "Le mie segnalazioni" — cosa ho mandato, e com'e' finita (13/09).
///
/// Ricalcata sul mockup 4 di Claude Design: una scheda per segnalazione, la
/// piu' recente in cima, con una pastiglia di stato e sotto il dettaglio che
/// cambia col caso. Quattro casi, tutti diversi e da distinguere a colpo
/// d'occhio: in attesa (ambra), accettata (verde pieno), accettata in parte
/// (verde a filo: non e' un rifiuto), rifiutata (rossa, con la motivazione).
///
/// PERCHE' ESISTE: chi segnala un errore finora non sapeva piu' niente. Senza
/// un ritorno la seconda segnalazione non arriva mai.
///
/// 15/09, richiesta di Ismail: tre schede nella stessa pagina.
///  - Segnalazioni: gli errori sui dati degli alimenti E i problemi dell'app
///    mandati da "Segnala un problema", con la risposta di chi li ha gestiti;
///  - Ricette pubbliche e Alimenti pubblici: cio' che si e' proposto alla
///    comunita', con lo stato e i like.
/// Sopra le schede: ricerca per nome, filtro per stato e ordinamento, che
/// valgono per la scheda aperta. I dati arrivano da una sola chiamata.
///
/// Una differenza voluta dal mockup: la barra in alto usa lo stile di tutte le
/// altre schermate dell'app (titolo verde al centro), non quello del mockup.
class MieSegnalazioniPage extends ConsumerStatefulWidget {
  /// Chi va a prendere i dati. Di default il server; nei test una funzione che
  /// restituisce dati finti. `null` come risultato vuol dire "non ho potuto
  /// chiedere", esattamente come per [ApiServices.fetchMyContributions].
  final Future<ContributiUtente?> Function(String email)? caricatore;

  const MieSegnalazioniPage({super.key, this.caricatore});

  @override
  ConsumerState<MieSegnalazioniPage> createState() => _MieSegnalazioniPageState();
}

/// Una riga di una scheda, gia' pronta per filtro e ordinamento.
class _Voce {
  final String nome;
  final DateTime? data;

  /// attesa | ok | no — la stessa grammatica per segnalazioni, problemi e
  /// contributi, cosi' un filtro solo vale per tutte e tre le schede.
  final String gruppo;
  final Widget scheda;
  const _Voce(this.nome, this.data, this.gruppo, this.scheda);
}

class _MieSegnalazioniPageState extends ConsumerState<MieSegnalazioniPage>
    with SingleTickerProviderStateMixin {
  ContributiUtente? _dati;
  bool _caricamento = true;
  bool _errore = false;
  late final TabController _schede = TabController(length: 4, vsync: this);
  final TextEditingController _cerca = TextEditingController();
  String _filtro = 'tutti';
  String _ordine = 'recenti';

  @override
  void initState() {
    super.initState();
    _cerca.addListener(() => setState(() {}));
    _carica();
  }

  @override
  void dispose() {
    _schede.dispose();
    _cerca.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = false;
    });
    final email = ref.read(userProvider)?.email ?? '';
    final dati = await (widget.caricatore ?? ApiServices.fetchMyContributions)(email);
    if (!mounted) return;
    setState(() {
      _caricamento = false;
      _errore = dati == null;
      _dati = dati;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    final scheme = Theme.of(context).colorScheme;
    final dati = _dati;

    String etichettaScheda(String chiave, int? quanti) {
      final testo = Translations.get(lang, chiave);
      return quanti == null ? testo : '$testo ($quanti)';
    }

    Widget corpo;
    if (_caricamento && dati == null) {
      corpo = const Center(child: CircularProgressIndicator());
    } else if (_errore || dati == null) {
      corpo = _statoVuoto(
        icona: Icons.error_outline,
        titolo: Translations.get(lang, 'my_reports_error_title'),
        testo: Translations.get(lang, 'my_reports_error_body'),
        conRiprova: true,
        lang: lang,
      );
    } else {
      corpo = Column(
        children: [
          _barraFiltri(lang, scheme),
          Expanded(
            child: TabBarView(
              controller: _schede,
              children: [
                _elenco(
                  [for (final s in dati.segnalazioni) _voceSegnalazione(s, lang)],
                  lang,
                  vuotoTitolo: Translations.get(lang, 'my_reports_empty_title'),
                  vuotoTesto: Translations.get(lang, 'my_reports_empty_body'),
                ),
                // Problemi dell'app in una scheda loro (17/09), con la risposta
                // di chi li ha gestiti.
                _elenco(
                  [for (final p in dati.problemi) _voceProblema(p, lang)],
                  lang,
                  vuotoTesto: Translations.get(lang, 'my_reports_app_empty'),
                ),
                _elenco(
                  [for (final c in dati.ricette) _voceContributo(c, lang, ricetta: true)],
                  lang,
                  vuotoTesto: Translations.get(lang, 'my_reports_recipes_empty'),
                ),
                _elenco(
                  [for (final c in dati.alimenti) _voceContributo(c, lang, ricetta: false)],
                  lang,
                  vuotoTesto: Translations.get(lang, 'my_reports_foods_empty'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Nutri.bg,
      appBar: AppBar(
        title: Text(
          Translations.get(lang, 'my_reports_title'),
          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.primary),
          tooltip: Translations.get(lang, 'Indietro'),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _schede,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: etichettaScheda('my_reports_type_food', dati?.segnalazioni.length)),
            Tab(text: etichettaScheda('my_reports_tab_app', dati?.problemi.length)),
            Tab(text: etichettaScheda('my_reports_tab_recipes', dati?.ricette.length)),
            Tab(text: etichettaScheda('my_reports_tab_foods', dati?.alimenti.length)),
          ],
        ),
      ),
      body: corpo,
    );
  }

  // ---------------------------------------------------------------------------
  // Ricerca, filtro, ordinamento
  // ---------------------------------------------------------------------------

  /// Ricerca e ordinamento sulla stessa riga, i filtri per stato sotto a
  /// tutta larghezza (17/09): prima l'ordinamento stava accanto ai filtri e
  /// copriva l'ultimo ("Rifiutati" tagliato a meta').
  Widget _barraFiltri(String lang, ColorScheme scheme) {
    final bordo = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Nutri.fieldBorder),
    );
    final ordini = {
      'recenti': Translations.get(lang, 'my_reports_sort_recent'),
      'nome': Translations.get(lang, 'my_reports_sort_name'),
      'stato': Translations.get(lang, 'my_reports_sort_status'),
    };
    final filtri = {
      'tutti': Translations.get(lang, 'Tutti'),
      'attesa': Translations.get(lang, 'my_reports_filter_pending'),
      'ok': Translations.get(lang, 'my_reports_filter_ok'),
      'no': Translations.get(lang, 'my_reports_filter_no'),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cerca,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: Translations.get(lang, 'my_reports_search'),
                    prefixIcon: Icon(Icons.search, color: scheme.primary),
                    suffixIcon: _cerca.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.cancel, size: 20),
                            color: Nutri.muted,
                            onPressed: _cerca.clear,
                          ),
                    isDense: true,
                    filled: true,
                    fillColor: Nutri.card,
                    border: bordo,
                    enabledBorder: bordo,
                    focusedBorder: bordo.copyWith(borderSide: BorderSide(color: scheme.primary, width: 1.5)),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: ordini[_ordine],
                icon: Icon(Icons.sort, color: scheme.primary),
                onSelected: (v) => setState(() => _ordine = v),
                itemBuilder: (_) => [
                  for (final o in ordini.entries)
                    CheckedPopupMenuItem(value: o.key, checked: o.key == _ordine, child: Text(o.value)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in filtri.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: NutriChip(
                      height: 36,
                      label: f.value,
                      selected: _filtro == f.key,
                      onTap: () => setState(() => _filtro = f.key),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _elenco(List<_Voce> tutte, String lang, {String? vuotoTitolo, required String vuotoTesto}) {
    if (tutte.isEmpty) {
      return _statoVuoto(
        icona: Icons.article_outlined,
        titolo: vuotoTitolo,
        testo: vuotoTesto,
        conRiprova: false,
        lang: lang,
      );
    }

    final testo = _cerca.text.trim().toLowerCase();
    final voci = tutte
        .where((v) => _filtro == 'tutti' || v.gruppo == _filtro)
        .where((v) => testo.isEmpty || v.nome.toLowerCase().contains(testo))
        .toList();

    int perData(_Voce a, _Voce b) => (b.data ?? DateTime(0)).compareTo(a.data ?? DateTime(0));
    const ordineStati = ['attesa', 'ok', 'no'];
    voci.sort(switch (_ordine) {
      'nome' => (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
      'stato' => (a, b) {
          final c = ordineStati.indexOf(a.gruppo).compareTo(ordineStati.indexOf(b.gruppo));
          return c != 0 ? c : perData(a, b);
        },
      _ => perData,
    });

    if (voci.isEmpty) {
      return _statoVuoto(
        icona: Icons.filter_list_off,
        testo: Translations.get(lang, 'my_reports_filter_empty'),
        conRiprova: false,
        lang: lang,
      );
    }

    return RefreshIndicator(
      onRefresh: _carica,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        itemCount: voci.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => voci[i].scheda,
      ),
    );
  }

  _Voce _voceSegnalazione(SegnalazioneUtente s, String lang) => _Voce(
        s.foodName,
        s.createdAt,
        s.status == 'accepted' ? 'ok' : s.status == 'rejected' ? 'no' : 'attesa',
        _scheda(s, lang),
      );

  _Voce _voceProblema(ProblemaApp p, String lang) => _Voce(
        p.descrizione,
        p.creatoIl,
        p.stato == 'resolved' ? 'ok' : p.stato == 'closed' ? 'no' : 'attesa',
        _schedaProblema(p, lang),
      );

  _Voce _voceContributo(ContributoPubblico c, String lang, {required bool ricetta}) => _Voce(
        c.nome,
        c.propostoIl,
        c.stato == 'approved' ? 'ok' : c.stato == 'rejected' ? 'no' : 'attesa',
        _schedaContributo(c, lang, ricetta: ricetta),
      );

  // ---------------------------------------------------------------------------
  // Pezzi comuni
  // ---------------------------------------------------------------------------

  Widget _statoVuoto({
    required IconData icona,
    String? titolo,
    required String testo,
    required bool conRiprova,
    required String lang,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icona, size: 46, color: Nutri.muted),
            const SizedBox(height: 14),
            if (titolo != null) ...[
              Text(
                titolo,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Nutri.ink),
              ),
              const SizedBox(height: 6),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                testo,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.5, color: Nutri.body),
              ),
            ),
            if (conRiprova) ...[
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Nutri.greenFill,
                  foregroundColor: Nutri.onGreenFill,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _carica,
                // Colore scritto anche sul testo: nel dialogo di segnalazione
                // il solo foregroundColor lasciava l'etichetta grigia sul verde
                // (misurato il 12/09).
                child: Text(
                  Translations.get(lang, 'Riprova'),
                  style: TextStyle(color: Nutri.onGreenFill, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Quanto tempo fa, detto come lo direbbe una persona.
  String _quando(DateTime? d, String lang) {
    if (d == null) return '';
    final giorni = DateTime.now().difference(d).inDays;
    if (giorni <= 0) return Translations.get(lang, 'my_reports_today');
    if (giorni == 1) return Translations.get(lang, 'my_reports_day_ago');
    return Translations.get(lang, 'my_reports_days_ago').replaceAll('{n}', '$giorni');
  }

  /// Pastiglia di stato: ambra in attesa, verde accettato (a filo se solo in
  /// parte), rossa rifiutato.
  Widget _pastiglia(String gruppo, String etichetta, {bool parziale = false}) {
    final (colore, fondo, icona) = switch (gruppo) {
      'ok' => (Nutri.green, parziale ? Nutri.card : Nutri.greenSoft, Icons.check),
      'no' => (Nutri.red, Nutri.redSoft, Icons.close),
      _ => (Nutri.amber, Nutri.amberSoft, Icons.circle),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(100),
        border: parziale ? Border.all(color: Nutri.green, width: 1.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icona, size: icona == Icons.circle ? 8 : 11, color: colore),
          const SizedBox(width: 5),
          Text(etichetta, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colore)),
        ],
      ),
    );
  }

  Widget _contenitore(List<Widget> figli) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Nutri.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Nutri.hairline),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: figli),
      );

  Widget _intestazione(String nome, Widget pastiglia) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              nome,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Nutri.ink),
            ),
          ),
          const SizedBox(width: 8),
          pastiglia,
        ],
      );

  Widget _meta(List<String> pezzi) {
    final testo = pezzi.where((t) => t.isNotEmpty).join(', ');
    if (testo.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(testo, style: TextStyle(fontSize: 12.5, color: Nutri.body)),
    );
  }

  Widget _riquadro(String titolo, String testo, {required Color fondo, required Color coloreTitolo}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titolo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: coloreTitolo)),
            const SizedBox(height: 3),
            Text(testo, style: TextStyle(fontSize: 13, height: 1.5, color: Nutri.ink)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Le tre forme di scheda
  // ---------------------------------------------------------------------------

  Widget _scheda(SegnalazioneUtente s, String lang) {
    final problema = Translations.get(lang, 'report_issue_${s.issue.isEmpty ? 'altro' : s.issue}');

    final String gruppo;
    final String etichetta;
    if (s.status == 'rejected') {
      gruppo = 'no';
      etichetta = Translations.get(lang, 'report_status_rejected');
    } else if (s.accettataInParte) {
      gruppo = 'ok';
      etichetta = Translations.get(lang, 'report_status_partial');
    } else if (s.chiusaSenzaModifiche) {
      gruppo = 'ok';
      etichetta = Translations.get(lang, 'report_status_closed');
    } else if (s.status == 'accepted') {
      gruppo = 'ok';
      etichetta = Translations.get(lang, 'report_status_accepted');
    } else {
      gruppo = 'attesa';
      etichetta = Translations.get(lang, 'report_status_pending');
    }

    // Dettaglio sotto il nome: cambia col caso.
    String? dettaglio;
    String? grazie;
    final accettati = Translations.get(lang, 'my_reports_accepted_of')
        .replaceAll('{a}', '${s.acceptedFields.length}')
        .replaceAll('{b}', '${s.proposedFields.length}');
    if (s.status == 'pending') {
      final pezzi = <String>[
        if (s.proposedFields.isNotEmpty)
          '${s.proposedFields.length} ${Translations.get(lang, s.proposedFields.length == 1 ? 'my_reports_field_one' : 'my_reports_field_many')}',
        if (s.photoCount > 0) '${s.photoCount} ${Translations.get(lang, 'my_reports_photos')}',
      ];
      dettaglio = pezzi.isEmpty ? null : pezzi.join(', ');
    } else if (s.accettataInParte) {
      dettaglio = '$accettati. ${Translations.get(lang, 'my_reports_others_unchanged')}';
    } else if (s.chiusaSenzaModifiche) {
      dettaglio = Translations.get(lang, 'my_reports_closed_detail');
      grazie = Translations.get(lang, 'my_reports_thanks_generic');
    } else if (s.status == 'accepted') {
      dettaglio = s.proposedFields.isEmpty ? null : accettati;
      grazie = Translations.get(
        lang,
        s.proposedFields.isEmpty ? 'my_reports_thanks_generic' : 'my_reports_thanks',
      );
    }

    return _contenitore([
      _intestazione(s.foodName, _pastiglia(gruppo, etichetta, parziale: s.accettataInParte)),
      _meta([problema, _quando(s.createdAt, lang)]),
      if (dettaglio != null) ...[
        const SizedBox(height: 8),
        Text(dettaglio, style: TextStyle(fontSize: 12.5, color: Nutri.body)),
      ],
      if (grazie != null) ...[
        const SizedBox(height: 8),
        Text(grazie, style: TextStyle(fontSize: 12.5, color: Nutri.green)),
      ],
      if (s.status == 'rejected' && s.reviewNote.isNotEmpty)
        _riquadro(Translations.get(lang, 'my_reports_reason'), s.reviewNote, fondo: Nutri.redSoft, coloreTitolo: Nutri.red),
    ]);
  }

  Widget _schedaProblema(ProblemaApp p, String lang) {
    final (gruppo, etichetta) = switch (p.stato) {
      'resolved' => ('ok', Translations.get(lang, 'app_status_resolved')),
      'closed' => ('no', Translations.get(lang, 'app_status_closed')),
      _ => ('attesa', Translations.get(lang, 'app_status_open')),
    };
    return _contenitore([
      _intestazione(p.descrizione, _pastiglia(gruppo, etichetta)),
      // Il nome della schermata e' salvato in italiano sul server: qui va
      // tradotto, o in inglese si leggeva "Calendario" (19/09).
      _meta([
        if (p.schermata.isNotEmpty) Translations.get(lang, p.schermata),
        _quando(p.creatoIl, lang),
      ]),
      if (p.rispostaAdmin.isNotEmpty)
        _riquadro(
          Translations.get(lang, 'my_reports_reply'),
          p.rispostaAdmin,
          fondo: gruppo == 'ok' ? Nutri.greenSoft : gruppo == 'no' ? Nutri.redSoft : Nutri.surfaceSoft,
          coloreTitolo: gruppo == 'ok' ? Nutri.green : gruppo == 'no' ? Nutri.red : Nutri.label,
        ),
    ]);
  }

  Widget _schedaContributo(ContributoPubblico c, String lang, {required bool ricetta}) {
    final (gruppo, etichetta) = switch (c.stato) {
      'approved' => ('ok', Translations.get(lang, 'share_state_approved')),
      'rejected' => ('no', Translations.get(lang, 'share_state_rejected')),
      _ => ('attesa', Translations.get(lang, 'share_state_pending')),
    };
    return _contenitore([
      _intestazione(c.nome, _pastiglia(gruppo, etichetta)),
      _meta([c.dettaglio, _quando(c.propostoIl, lang)]),
      if (ricetta && c.stato == 'approved') ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.favorite, size: 14, color: Nutri.red),
            const SizedBox(width: 5),
            Text(
              Translations.get(lang, 'contrib_likes').replaceAll('{n}', '${c.like}'),
              style: TextStyle(fontSize: 12.5, color: Nutri.body),
            ),
          ],
        ),
      ],
      if (c.rimosso) ...[
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 15, color: Nutri.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                Translations.get(lang, 'contrib_removed'),
                style: TextStyle(fontSize: 12.5, color: Nutri.body),
              ),
            ),
          ],
        ),
      ],
      if (c.stato == 'rejected' && c.motivo.isNotEmpty)
        _riquadro(Translations.get(lang, 'my_reports_reason'), c.motivo, fondo: Nutri.redSoft, coloreTitolo: Nutri.red),
    ]);
  }
}
