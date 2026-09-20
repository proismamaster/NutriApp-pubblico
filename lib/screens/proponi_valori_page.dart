import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../dictionary/translations.dart';
import '../domain/user_provider.dart';
import '../providers/locale_provider.dart';
import '../logic/unit_format.dart';
import '../services/api_services.dart';
import '../widgets/auth_style.dart';
import '../widgets/category_picker.dart';
import '../widgets/nutri_select.dart';

/// "Proponi i valori corretti" — l'utente corregge i valori di un prodotto e
/// allega le foto dell'etichetta come prova (13/09).
///
/// Ricalcata sul mockup 1 di Claude Design. La proposta NON cambia il database:
/// finisce in una segnalazione `pending` che un revisore guarda nel pannello e
/// accetta campo per campo.
///
/// TRE SCELTE CHE DIVERGONO DAL MOCKUP, TUTTE PER I DATI VERI
///  - Niente "Energia (kJ)": in `na_off_products` non c'e' una colonna kJ, i
///    kJ si ricavano dalle kcal. Due caselle per lo stesso dato vorrebbero dire
///    due proposte che possono contraddirsi.
///  - Niente "Sale (g)" accanto a "Sodio": stesso motivo, il sale e' il sodio
///    per 2,5. Resta il Sodio, che e' la colonna che esiste.
///  - Il nome del campo sta su una riga sola, con i puntini se non ci sta:
///    nello scatto di verifica del mockup le etichette andavano a capo e
///    l'unita' finiva tagliata sotto la casella ("Energia (k.l)").
///
/// Le chiavi della proposta sono i nomi delle colonne. Il pannello le
/// confronta comunque con le colonne vere prima di scrivere: questa lista
/// decide solo cosa si puo' proporre, non cosa si puo' scrivere.
class ProponiValoriPage extends ConsumerStatefulWidget {
  /// La riga del prodotto come arriva dalla ricerca: nome, marca, barcode,
  /// foto e i valori attuali con i nomi delle colonne.
  final Map<String, dynamic> product;

  /// Il motivo scelto nel foglio di segnalazione, se si arriva da li'
  /// (valori · nome · categoria · immagine · duplicato · altro). Serve a chi
  /// rivede: dice da dove nasce la proposta.
  final String problema;

  const ProponiValoriPage({super.key, required this.product, this.problema = 'valori'});

  @override
  ConsumerState<ProponiValoriPage> createState() => _ProponiValoriPageState();
}

/// Come si scrive un campo: un numero, testo libero, una lista chiusa, o la
/// categoria (che ha il suo cercatore, lo stesso dell'inserimento manuale).
enum _Tipo { numero, testo, scelta, categoria }

/// Un campo proponibile: colonna, chiave di traduzione, unita' di misura.
/// Le unita' sono quelle delle pagine gia' esistenti (obiettivi e inserimento
/// manuale), non scelte qui: µg e mg scambiati sono gia' un bug aperto nei dati.
class _Campo {
  final String colonna;
  final String etichetta;
  final String unita;
  final _Tipo tipo;

  /// Le voci ammesse quando [tipo] e' `scelta`.
  final List<String> scelte;

  const _Campo(
    this.colonna,
    this.etichetta,
    this.unita, {
    this.tipo = _Tipo.numero,
    this.scelte = const [],
  });
}

class _Sezione {
  final String chiave;
  final String titolo;
  final List<_Campo> campi;
  const _Sezione(this.chiave, this.titolo, this.campi);
}

/// 18/09: si propone tutto quello che si puo' scrivere nell'inserimento
/// manuale — identita', qualita', tutti i nutrienti e la foto — perche' prima
/// un nome sbagliato o una foto di un altro prodotto si potevano solo
/// raccontare nella nota, e chi rivede non aveva niente da accettare.
const List<_Sezione> _sezioni = [
  _Sezione('identita', 'propose_section_identity', [
    _Campo('food_name', 'Nome', '', tipo: _Tipo.testo),
    _Campo('brand', 'Marca', '', tipo: _Tipo.testo),
    _Campo('categories', 'Categoria', '', tipo: _Tipo.categoria),
    _Campo('quantity', 'Quantità', '', tipo: _Tipo.testo),
    _Campo('serving_size', 'Porzione', '', tipo: _Tipo.testo),
  ]),
  _Sezione('energia', 'propose_section_energy', [
    _Campo('calories', 'Calorie', 'kcal'),
    _Campo('carbs', 'Carboidrati', 'g'),
    _Campo('sugars', 'Zuccheri', 'g'),
    _Campo('added_sugars', 'Zuccheri aggiunti', 'g'),
    _Campo('starch', 'Amido', 'g'),
    _Campo('polyols', 'Polioli', 'g'),
    _Campo('lactose', 'Lattosio', 'g'),
    _Campo('fibers', 'Fibre', 'g'),
    _Campo('proteins', 'Proteine', 'g'),
    _Campo('water', 'Acqua', 'g'),
    _Campo('alcohol_percent', 'Alcol', '%'),
    _Campo('caffeine', 'Caffeina', 'mg'),
  ]),
  _Sezione('grassi', 'propose_section_fats', [
    _Campo('fats', 'Grassi', 'g'),
    _Campo('saturated_fats', 'Grassi saturi', 'g'),
    _Campo('monounsaturated_fats', 'Grassi monoinsaturi', 'g'),
    _Campo('polyunsaturated_fats', 'Grassi polinsaturi', 'g'),
    _Campo('trans_fats', 'Grassi trans', 'g'),
    _Campo('cholesterol', 'Colesterolo', 'mg'),
  ]),
  _Sezione('vitamine', 'propose_section_vitamins', [
    _Campo('vit_a', 'Vitamina A', 'µg'),
    _Campo('vit_b1', 'Vitamina B1', 'mg'),
    _Campo('vit_b2', 'Vitamina B2', 'mg'),
    _Campo('vit_b3', 'Vitamina B3', 'mg'),
    _Campo('vit_b5', 'Vitamina B5', 'mg'),
    _Campo('vit_b6', 'Vitamina B6', 'mg'),
    _Campo('vit_b7', 'Vitamina B7', 'µg'),
    _Campo('vit_b9', 'Vitamina B9', 'µg'),
    _Campo('vit_b12', 'Vitamina B12', 'µg'),
    _Campo('vit_c', 'Vitamina C', 'mg'),
    _Campo('vit_d', 'Vitamina D', 'µg'),
    _Campo('vit_e', 'Vitamina E', 'mg'),
    _Campo('vit_k', 'Vitamina K', 'µg'),
    _Campo('biotin', 'Biotina', 'µg'),
  ]),
  _Sezione('minerali', 'propose_section_minerals', [
    _Campo('sodium', 'Sodio', 'mg'),
    _Campo('salt', 'Sale', 'g'),
    _Campo('calcium', 'Calcio', 'mg'),
    _Campo('iron', 'Ferro', 'mg'),
    _Campo('potassium', 'Potassio', 'mg'),
    _Campo('magnesium', 'Magnesio', 'mg'),
    _Campo('phosphorus', 'Fosforo', 'mg'),
    _Campo('zinc', 'Zinco', 'mg'),
    _Campo('copper', 'Rame', 'mg'),
    _Campo('manganese', 'Manganese', 'mg'),
    _Campo('selenium', 'Selenio', 'µg'),
    _Campo('iodine', 'Iodio', 'µg'),
    _Campo('chloride', 'Cloruro', 'mg'),
    _Campo('fluoride', 'Fluoruro', 'mg'),
    _Campo('chromium', 'Cromo', 'µg'),
    _Campo('molybdenum', 'Molibdeno', 'µg'),
  ]),
  _Sezione('qualita', 'propose_section_quality', [
    _Campo('nutriscore_grade', 'Nutri-Score', '', tipo: _Tipo.scelta, scelte: ['a', 'b', 'c', 'd', 'e']),
    _Campo('nova_group', 'NOVA', '', tipo: _Tipo.scelta, scelte: ['1', '2', '3', '4']),
    _Campo('additives_n', 'Additivi', ''),
    _Campo('ingredients', 'Ingredienti', '', tipo: _Tipo.testo),
  ]),
];

/// I quattro ruoli delle foto, nello stesso ordine del pannello.
const List<String> _ruoli = ['fronte', 'tabella', 'ingredienti', 'altro'];

enum _StatoFoto { vuota, caricamento, piena, errore }

class _Foto {
  _StatoFoto stato = _StatoFoto.vuota;
  File? file;
  String? url;
  String? errore;
}

class _ProponiValoriPageState extends ConsumerState<ProponiValoriPage> {
  final Map<String, TextEditingController> _valori = {
    for (final s in _sezioni)
      for (final c in s.campi) c.colonna: TextEditingController(),
  };
  final Map<String, bool> _aperte = {'identita': true, 'energia': true};
  final Map<String, _Foto> _foto = {for (final r in _ruoli) r: _Foto()};

  /// Foto proposta come nuova immagine del prodotto: non e' una prova, e'
  /// il valore proposto per la colonna `image_url` (18/09).
  _Foto _fotoProdotto = _Foto();
  final _nota = TextEditingController();
  bool _invio = false;

  @override
  void dispose() {
    for (final c in _valori.values) {
      c.dispose();
    }
    _nota.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Stato derivato
  // -------------------------------------------------------------------------

  /// Il numero scritto, o null se la casella e' vuota o non e' un numero.
  /// La virgola vale come il punto: e' quella che scrive chi legge un'etichetta
  /// italiana.
  double? _numero(String testo) {
    final t = testo.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  /// I campi numerici, per colonna: gli altri si scrivono come testo e non
  /// hanno niente da controllare.
  static final Map<String, _Campo> _perColonna = {
    for (final s in _sezioni)
      for (final c in s.campi) c.colonna: c,
  };

  bool _nonValido(String colonna) {
    if (_perColonna[colonna]?.tipo != _Tipo.numero) return false;
    final t = _valori[colonna]!.text.trim();
    return t.isNotEmpty && _numero(t) == null;
  }

  /// Solo i campi toccati e validi: una casella vuota vuol dire "non tocco
  /// questo", mai "azzera". I numeri partono come numeri, il resto come testo
  /// (il pannello li scrive con il tipo della colonna).
  Map<String, dynamic> get _proposta {
    final fuori = <String, dynamic>{};
    for (final e in _valori.entries) {
      final testo = e.value.text.trim();
      if (testo.isEmpty) continue;
      if (_perColonna[e.key]?.tipo == _Tipo.numero) {
        final n = _numero(testo);
        // Le calorie si scrivono nell'unita' scelta (kJ compresi) e partono
        // sempre in kcal, la colonna del database (18/09).
        if (n != null) fuori[e.key] = e.key == 'calories' && UnitFormat.unitaEnergia == 'kj' ? n / 4.184 : n;
      } else {
        fuori[e.key] = testo;
      }
    }
    if (_fotoProdotto.stato == _StatoFoto.piena && _fotoProdotto.url != null) {
      fuori['image_url'] = _fotoProdotto.url!;
    }
    return fuori;
  }

  bool get _qualcheNonValido => _valori.keys.any(_nonValido);
  bool get _fotoInCaricamento =>
      _foto.values.any((f) => f.stato == _StatoFoto.caricamento) ||
      _fotoProdotto.stato == _StatoFoto.caricamento;
  bool get _haFoto => _foto.values.any((f) => f.stato == _StatoFoto.piena);

  bool get _puoInviare =>
      !_invio && !_fotoInCaricamento && !_qualcheNonValido && (_proposta.isNotEmpty || _haFoto);

  String _valoreAttuale(String colonna) {
    final v = widget.product[colonna];
    if (v == null || v.toString().trim().isEmpty) return '—';
    final letto = double.tryParse(v.toString());
    if (letto == null) return v.toString();
    final n = colonna == 'calories' ? UnitFormat.eInUnita(letto) : letto;
    final testo = n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return testo.replaceAll('.', ',');
  }

  // -------------------------------------------------------------------------
  // Foto
  // -------------------------------------------------------------------------

  Future<void> _scegliFoto(_Foto f) async {
    final lang = ref.read(appSettingsProvider).language;
    // Via il fuoco dal campo numerico: chiudendo il foglio la pagina ci
    // tornava sopra e saltava in cima da sola (test di release 19/09).
    FocusScope.of(context).unfocus();
    final sorgente = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Nutri.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: Nutri.green),
              title: Text(Translations.get(lang, 'propose_photo_camera')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: Nutri.green),
              title: Text(Translations.get(lang, 'propose_photo_gallery')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (sorgente == null || !mounted) return;

    // Stesse dimensioni della foto ricetta: una tabella nutrizionale resta
    // leggibile a 1600 px, e la foto grezza di un telefono supererebbe gli
    // 8 MB che upload_image.php accetta.
    final scelta = await ImagePicker().pickImage(
      source: sorgente,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (scelta == null || !mounted) return;
    setState(() => f.file = File(scelta.path));
    await _carica(f);
  }

  Future<void> _carica(_Foto f) async {
    if (f.file == null) return;
    setState(() {
      f.stato = _StatoFoto.caricamento;
      f.errore = null;
    });
    final esito = await ApiServices.uploadImage(
      userMail: ref.read(userProvider)?.email ?? '',
      file: f.file!,
    );
    if (!mounted) return;
    setState(() {
      if (esito.url != null) {
        f.url = esito.url;
        f.stato = _StatoFoto.piena;
      } else {
        // Una foto andata male non tocca le altre: resta al suo posto con
        // "Riprova", e le altre restano come sono.
        f.errore = esito.errore;
        f.stato = _StatoFoto.errore;
      }
    });
  }

  /// Le categorie vere le conosce il catalogo: si cercano con lo stesso
  /// foglio dell'inserimento manuale invece di scriverle a mano.
  Future<void> _apriCategorie(String lang, TextEditingController dove) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Nutri.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => CategoryPicker(
        lang: lang,
        iniziale: dove.text,
        onScelta: (tag) {
          Navigator.pop(ctx);
          setState(() => dove.text = tag);
        },
      ),
    );
  }

  void _togli(String ruolo) => setState(() {
        if (ruolo == 'prodotto') {
          _fotoProdotto = _Foto();
        } else {
          _foto[ruolo] = _Foto();
        }
      });

  // -------------------------------------------------------------------------
  // Invio
  // -------------------------------------------------------------------------

  Future<void> _invia() async {
    if (!_puoInviare) return;
    final lang = ref.read(appSettingsProvider).language;
    final barcode = (widget.product['barcode'] ?? '').toString();
    final fonte = (widget.product['fonte'] ?? widget.product['source'] ?? (barcode.isNotEmpty ? 'off' : '')).toString();

    setState(() => _invio = true);
    final esito = await ApiServices.saveFoodReport(
      userEmail: ref.read(userProvider)?.email ?? '',
      foodName: (widget.product['food_name'] ?? '').toString(),
      issue: widget.problema.isEmpty ? 'valori' : widget.problema,
      barcode: barcode,
      source: fonte,
      note: _nota.text.trim(),
      proposed: _proposta,
      photos: [
        for (final r in _ruoli)
          if (_foto[r]!.stato == _StatoFoto.piena && _foto[r]!.url != null)
            {'url': _foto[r]!.url!, 'role': r},
      ],
    );
    if (!mounted) return;
    setState(() => _invio = false);

    if (esito['status'] != 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Nutri.red,
          content: Text('${Translations.get(lang, 'propose_failed')} ${esito['message'] ?? ''}'.trim()),
        ),
      );
      return;
    }
    await _conferma(lang);
    if (mounted) Navigator.pop(context, true);
  }

  /// Foglio di conferma che sale dal basso. Nessuna promessa sui tempi: la
  /// revisione la fanno persone, e un "entro 24 ore" non mantenuto e' peggio
  /// di nessuna data.
  Future<void> _conferma(String lang) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Nutri.card,
      isDismissible: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(color: Nutri.hairline, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Nutri.greenSoft, shape: BoxShape.circle),
                child: Icon(Icons.check, color: Nutri.green, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                Translations.get(lang, 'propose_done_title'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Nutri.ink),
              ),
              const SizedBox(height: 6),
              Text(
                Translations.get(lang, 'propose_done_where'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5, color: Nutri.body),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    side: BorderSide(color: Nutri.green, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    Translations.get(lang, 'propose_done_ok'),
                    style: TextStyle(color: Nutri.green, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Disegno
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Nutri.bg,
      appBar: AppBar(
        title: Text(
          Translations.get(lang, 'propose_title'),
          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.primary),
          tooltip: Translations.get(lang, 'Indietro'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _intestazione(lang),
                for (final s in _sezioni) _sezione(s, lang),
                // La foto del prodotto e' un valore proposto, non una prova:
                // sta da sola, sopra alle foto dell'etichetta (18/09).
                _titoloSezione(Translations.get(lang, 'propose_product_photo')),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: SizedBox(height: 150, child: _tessera('prodotto', lang)),
                ),
                _titoloSezione(Translations.get(lang, 'propose_photos')),
                _griglia(lang),
                _suggerimentoTabella(lang),
                _titoloSezione(Translations.get(lang, 'propose_note')),
                _campoNota(lang),
              ],
            ),
          ),
          _barraInvio(lang),
        ],
      ),
    );
  }

  Widget _intestazione(String lang) {
    final nome = (widget.product['food_name'] ?? '').toString();
    final marca = (widget.product['brand'] ?? '').toString();
    final barcode = (widget.product['barcode'] ?? '').toString();
    final foto = (widget.product['image_url'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: foto.startsWith('http')
                      ? Image.network(foto, fit: BoxFit.cover, errorBuilder: (_, _, _) => _miniaturaVuota())
                      : _miniaturaVuota(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Nutri.ink)),
                    if (marca.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(marca, style: TextStyle(fontSize: 13, color: Nutri.body)),
                    ],
                    if (barcode.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.qr_code_2, size: 13, color: Nutri.muted),
                          const SizedBox(width: 5),
                          Text(
                            barcode,
                            style: TextStyle(
                              fontSize: 11,
                              color: Nutri.muted,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            Translations.get(lang, 'propose_intro'),
            style: TextStyle(fontSize: 13, height: 1.5, color: Nutri.body),
          ),
        ],
      ),
    );
  }

  Widget _miniaturaVuota() => Container(
        color: Nutri.greenSoft,
        child: Icon(Icons.fastfood_outlined, size: 22, color: Nutri.muted),
      );

  Widget _titoloSezione(String testo) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          testo.toUpperCase(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .5, color: Nutri.body),
        ),
      );

  Widget _sezione(_Sezione s, String lang) {
    final aperta = _aperte[s.chiave] ?? false;
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Nutri.hairline))),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _aperte[s.chiave] = !aperta),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      Translations.get(lang, s.titolo).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .5, color: Nutri.body),
                    ),
                  ),
                  AnimatedRotation(
                    turns: aperta ? .5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(Icons.keyboard_arrow_down, size: 20, color: Nutri.muted),
                  ),
                ],
              ),
            ),
          ),
          if (aperta)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                children: [
                  for (final c in s.campi) ...[
                    _riga(c, lang),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _riga(_Campo c, String lang) {
    final controller = _valori[c.colonna]!;
    final modificato = controller.text.trim().isNotEmpty;
    final nonValido = _nonValido(c.colonna);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: modificato && !nonValido ? Nutri.greenSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
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
                  c.unita.isEmpty
                      ? Translations.get(lang, c.etichetta)
                      : '${Translations.get(lang, c.etichetta)} (${c.colonna == 'calories' ? UnitFormat.eSigla : c.unita})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, color: Nutri.ink),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _valoreAttuale(c.colonna),
                style: TextStyle(
                  fontSize: 12.5,
                  color: Nutri.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (c.tipo == _Tipo.scelta)
            NutriSelect<String>(
              titolo: Translations.get(lang, c.etichetta),
              valore: controller.text.trim().isEmpty ? null : controller.text.trim(),
              segnaposto: Translations.get(lang, 'propose_leave_empty'),
              opzioni: [for (final s in c.scelte) NutriOpzione(s, s.toUpperCase())],
              onCambiato: (v) => setState(() => controller.text = v),
            )
          else if (c.tipo == _Tipo.categoria)
            // Stesso cercatore dell'inserimento manuale: le categorie vere le
            // conosce il catalogo, non una lista scritta qui.
            NutriCampoScelta(
              testo: controller.text.trim().isEmpty
                  ? Translations.get(lang, 'propose_leave_empty')
                  : controller.text.trim(),
              vuoto: controller.text.trim().isEmpty,
              onTap: () => _apriCategorie(lang, controller),
            )
          else
            TextField(
            controller: controller,
            keyboardType: c.tipo == _Tipo.testo
                ? TextInputType.text
                : const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: c.tipo == _Tipo.testo
                ? null
                : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            onChanged: (_) => setState(() {}),
            style: TextStyle(fontSize: 13.5, color: Nutri.ink),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Nutri.card,
              hintText: Translations.get(lang, 'propose_leave_empty'),
              hintStyle: TextStyle(fontSize: 13.5, color: Nutri.hint),
              errorText: nonValido ? Translations.get(lang, 'propose_invalid_number') : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(color: modificato ? Nutri.green : Nutri.hairline, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(color: Nutri.green, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(color: Nutri.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(color: Nutri.red, width: 1.5),
              ),
            ),
          ),
          if (modificato && !nonValido) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Nutri.card,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Nutri.green),
                  ),
                  child: Text(
                    Translations.get(lang, 'propose_modified'),
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Nutri.green),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(controller.clear),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(color: Nutri.hairline, shape: BoxShape.circle),
                    child: Icon(Icons.close, size: 12, color: Nutri.body),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _griglia(String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 4 / 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [for (final r in _ruoli) _tessera(r, lang)],
      ),
    );
  }

  Widget _tessera(String ruolo, String lang) {
    // 'prodotto' non e' una prova ma la foto proposta per l'alimento (18/09).
    final f = ruolo == 'prodotto' ? _fotoProdotto : _foto[ruolo]!;
    final nomeRuolo = Translations.get(lang, 'photo_role_$ruolo');

    Widget contenuto;
    switch (f.stato) {
      case _StatoFoto.vuota:
        contenuto = InkWell(
          onTap: () => _scegliFoto(f),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_camera_outlined, size: 22, color: Nutri.muted),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    nomeRuolo,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: Nutri.body),
                  ),
                ),
              ],
            ),
          ),
        );
      case _StatoFoto.caricamento:
        contenuto = Container(
          color: Nutri.greenSoft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(Translations.get(lang, 'propose_photo_uploading'), style: TextStyle(fontSize: 11, color: Nutri.body)),
              const SizedBox(height: 8),
              FractionallySizedBox(
                widthFactor: .7,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    color: Nutri.green,
                    backgroundColor: Nutri.hairline,
                  ),
                ),
              ),
            ],
          ),
        );
      case _StatoFoto.piena:
        contenuto = Stack(
          fit: StackFit.expand,
          children: [
            if (f.file != null) Image.file(f.file!, fit: BoxFit.cover),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Nutri.card, borderRadius: BorderRadius.circular(6)),
                child: Text(nomeRuolo, style: TextStyle(fontSize: 10, color: Nutri.body)),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _togli(ruolo),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(color: Color(0x8C000000), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      case _StatoFoto.errore:
        contenuto = Container(
          color: Nutri.redSoft,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                Translations.get(lang, 'propose_photo_failed'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Nutri.red),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _carica(f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Nutri.red, borderRadius: BorderRadius.circular(100)),
                  child: Text(
                    Translations.get(lang, 'Riprova'),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(
        foregroundPainter: _BordoTessera(
          colore: f.stato == _StatoFoto.errore ? Nutri.red : Nutri.hairline,
          tratteggiato: f.stato == _StatoFoto.vuota,
        ),
        child: Material(color: Colors.transparent, child: contenuto),
      ),
    );
  }

  Widget _suggerimentoTabella(String lang) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Nutri.amberSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(width: 8, height: 8, decoration: BoxDecoration(color: Nutri.amber, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              Translations.get(lang, 'propose_table_hint'),
              style: TextStyle(fontSize: 12.5, height: 1.5, color: Nutri.amber),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoNota(String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: _nota,
            maxLines: 3,
            maxLength: 400,
            onChanged: (_) => setState(() {}),
            style: TextStyle(fontSize: 13.5, color: Nutri.ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: Nutri.card,
              counterText: '',
              hintText: Translations.get(lang, 'propose_note_hint'),
              hintStyle: TextStyle(fontSize: 13.5, color: Nutri.hint),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(color: Nutri.hairline, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(color: Nutri.green, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text('${_nota.text.length}/400', style: TextStyle(fontSize: 11, color: Nutri.muted)),
        ],
      ),
    );
  }

  Widget _barraInvio(String lang) {
    final attivo = _puoInviare;
    String? spiegazione;
    if (_fotoInCaricamento) {
      spiegazione = Translations.get(lang, 'propose_wait_photos');
    } else if (!attivo && !_invio) {
      spiegazione = Translations.get(lang, 'propose_send_disabled');
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Nutri.card,
        border: Border(top: BorderSide(color: Nutri.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Nutri.greenFill,
                  disabledBackgroundColor: Nutri.hairline,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: attivo ? _invia : null,
                // Colore anche sul testo, non solo sullo stile: misurato il
                // 12/09, col solo foregroundColor l'etichetta usciva grigia
                // sopra il verde.
                child: _invio
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Nutri.onGreenFill),
                      )
                    : Text(
                        Translations.get(lang, 'propose_send'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: attivo ? Nutri.onGreenFill : Nutri.muted,
                        ),
                      ),
              ),
            ),
            if (spiegazione != null) ...[
              const SizedBox(height: 8),
              Text(
                spiegazione,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.5, color: Nutri.body),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bordo delle tessere foto: tratteggiato quando la tessera e' vuota (e'
/// un invito), pieno quando c'e' qualcosa dentro. Flutter non ha un bordo
/// tratteggiato di serie.
class _BordoTessera extends CustomPainter {
  final Color colore;
  final bool tratteggiato;

  const _BordoTessera({required this.colore, required this.tratteggiato});

  @override
  void paint(Canvas canvas, Size size) {
    final pennello = Paint()
      ..color = colore
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final forma = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    ).deflate(.75);
    final percorso = Path()..addRRect(forma);

    if (!tratteggiato) {
      canvas.drawPath(percorso, pennello);
      return;
    }
    for (final metrica in percorso.computeMetrics()) {
      var distanza = 0.0;
      while (distanza < metrica.length) {
        canvas.drawPath(metrica.extractPath(distanza, distanza + 6), pennello);
        distanza += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_BordoTessera old) => old.colore != colore || old.tratteggiato != tratteggiato;
}
