import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_services.dart';
import 'package:http/http.dart' as http;

import '../dictionary/translations.dart';
import 'auth_style.dart';

/// Una categoria proposta dal catalogo.
typedef CategoriaProposta = ({String tag, String label, int count, String slug});

/// Selettore di categoria con ricerca, proposte dal catalogo e discesa nelle
/// categorie più specifiche.
///
/// PERCHÉ NON UN ELENCO FISSO (2026-09-05): prima erano sette voci scritte nel
/// codice ("Snack", "Latticini"…). Poche, e soprattutto scollegate dalle
/// categorie vere che il resto dell'app usa per ordinare la ricerca — quelle
/// sono i tag di OpenFoodFacts già presenti in `na_off_products`. Un alimento
/// creato a mano finiva così in un mondo a parte, invisibile a quella logica.
///
/// Se la categoria cercata non esiste, l'utente può registrarla comunque: è
/// esplicitamente ciò che è stato chiesto. Viene salvata così com'è scritta,
/// senza prefisso di lingua, così resta distinguibile da un tag ufficiale.
class CategoryPicker extends StatefulWidget {
  const CategoryPicker({
    super.key,
    required this.lang,
    required this.iniziale,
    required this.onScelta,
  });

  final String lang;
  final String iniziale;
  final ValueChanged<String> onScelta;

  @override
  State<CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<CategoryPicker> {
  static const _url = '${ApiServices.base}search_categories.php';

  final _ctrl = TextEditingController();
  Timer? _debounce;
  bool _caricando = false;
  List<CategoriaProposta> _proposte = [];

  /// Categoria su cui si è "sceso": mostra le più specifiche.
  CategoriaProposta? _dentro;

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.iniziale;
    if (widget.iniziale.trim().isNotEmpty) _cerca(widget.iniziale);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<List<CategoriaProposta>> _chiedi(Map<String, String> query) async {
    final uri = Uri.parse(_url).replace(queryParameters: query);
    final r = await http.get(uri).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return [];
    final j = jsonDecode(r.body);
    if (j['status'] != 'success') return [];
    return [
      for (final c in (j['categories'] as List))
        (
          tag: (c['tag'] ?? '').toString(),
          label: (c['label'] ?? '').toString(),
          count: int.tryParse(c['count'].toString()) ?? 0,
          slug: (c['slug'] ?? '').toString(),
        ),
    ];
  }

  void _cerca(String q) {
    _debounce?.cancel();
    // Stesso ritardo della ricerca alimenti: sotto questa soglia si parte a
    // ogni lettera e la rete fa più lavoro di quanto serva.
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (q.trim().length < 2) {
        setState(() => _proposte = []);
        return;
      }
      setState(() => _caricando = true);
      final r = await _chiedi({'q': q.trim()});
      if (!mounted) return;
      setState(() {
        _proposte = r;
        _caricando = false;
      });
    });
  }

  Future<void> _scendi(CategoriaProposta c) async {
    setState(() {
      _dentro = c;
      _caricando = true;
    });
    final figlie = await _chiedi({'parent': c.slug});
    if (!mounted) return;
    setState(() {
      _proposte = figlie;
      _caricando = false;
    });
  }

  void _risali() {
    setState(() => _dentro = null);
    _cerca(_ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final scritto = _ctrl.text.trim();
    // "Nessuna corrispondenza" non basta: chi ha scritto una categoria che il
    // catalogo non conosce deve poterla usare lo stesso.
    final mostraNuova = _dentro == null &&
        scritto.length >= 2 &&
        !_caricando &&
        !_proposte.any((p) => p.label.toLowerCase() == scritto.toLowerCase());

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
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
          Row(
            children: [
              if (_dentro != null)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.arrow_back, size: 20, color: Nutri.green),
                  onPressed: _risali,
                ),
              if (_dentro != null) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dentro == null
                      ? Translations.get(lang, 'Categoria')
                      : _dentro!.label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Nutri.ink,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _dentro == null
                ? Translations.get(lang, 'Cerca fra le categorie che il catalogo conosce, oppure scrivine una nuova.')
                : Translations.get(lang, 'Categorie più specifiche. Tocca quella giusta, o usa quella sopra.'),
            style: TextStyle(fontSize: 12.5, color: Nutri.muted, height: 1.45),
          ),
          const SizedBox(height: 14),
          if (_dentro == null)
            NutriField(
              controller: _ctrl,
              icon: Icons.search,
              hint: Translations.get(lang, 'Es. riso, biscotti, yogurt'),
              onChanged: (v) {
                setState(() {});
                _cerca(v);
              },
            ),
          const SizedBox(height: 14),
          if (_caricando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (_dentro != null)
                    _riga(
                      etichetta: '${Translations.get(lang, 'Usa')} "${_dentro!.label}"',
                      icona: Icons.check_circle_outline,
                      onTap: () => widget.onScelta(_dentro!.tag),
                    ),
                  for (final c in _proposte)
                    _riga(
                      etichetta: c.label,
                      // Quante schede del catalogo la usano: dice quanto è
                      // comune, quindi quanto è probabile sia quella giusta.
                      sotto: '${c.count} ${Translations.get(lang, 'prodotti')}',
                      icona: Icons.local_offer_outlined,
                      onTap: () => widget.onScelta(c.tag),
                      onScendi: _dentro == null ? () => _scendi(c) : null,
                    ),
                  if (mostraNuova)
                    _riga(
                      etichetta: '${Translations.get(lang, 'Aggiungi')} "$scritto"',
                      sotto: Translations.get(lang, 'Nuova categoria, non ancora nel catalogo'),
                      icona: Icons.add_circle_outline,
                      onTap: () => widget.onScelta(scritto),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _riga({
    required String etichetta,
    required IconData icona,
    required VoidCallback onTap,
    String? sotto,
    VoidCallback? onScendi,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icona, size: 20, color: Nutri.green),
      title: Text(
        etichetta,
        style: TextStyle(fontSize: 15, color: Nutri.ink),
      ),
      subtitle: sotto == null
          ? null
          : Text(sotto, style: TextStyle(fontSize: 12, color: Nutri.mutedSoft)),
      trailing: onScendi == null
          ? null
          : IconButton(
              tooltip: Translations.get(widget.lang, 'Più specifiche'),
              icon: Icon(Icons.chevron_right, color: Nutri.mutedSoft),
              onPressed: onScendi,
            ),
      onTap: onTap,
    );
  }
}
