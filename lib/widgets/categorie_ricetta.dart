import 'package:flutter/material.dart';

import '../dictionary/translations.dart';
import 'auth_style.dart';

/// Categorie delle ricette a lista chiusa (2026-09-15).
///
/// Gli stessi valori di `na_recipes.meal_types`, `course` e `diet_tags`: un
/// valore diverso il server lo scarta. Liste chiuse e non tag liberi, perche'
/// una categoria serve a filtrare e a consigliare, e "Primo", "primo piatto" e
/// "primi" sarebbero tre filtri per la stessa cosa.
const List<String> pastiRicetta = ['colazione', 'pranzo', 'cena', 'spuntino'];
const List<String> portateRicetta = [
  'primo', 'secondo', 'piatto_unico', 'contorno', 'dolce', 'bevanda', 'altro',
];
const List<String> dieteRicetta = ['vegetariana', 'vegana', 'senza_glutine'];

typedef CategorieRicetta = ({List<String> pasti, String? portata, List<String> diete});
typedef FiltriRicette = ({String? pasto, String? portata, String? dieta});

/// Chiede le categorie prima di proporre una ricetta. `null` se l'utente
/// chiude il foglio senza proporre.
Future<CategorieRicetta?> chiediCategorieRicetta(
  BuildContext context, {
  required String lang,
  CategorieRicetta? iniziali,
}) {
  return showModalBottomSheet<CategorieRicetta>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Nutri.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _FoglioCategorie(lang: lang, iniziali: iniziali),
  );
}

/// I filtri di Consigliate: una scelta per gruppo, tutte facoltative. `null`
/// se il foglio si chiude senza toccare niente.
Future<FiltriRicette?> scegliFiltriRicette(
  BuildContext context, {
  required String lang,
  String? pasto,
  String? portata,
  String? dieta,
}) {
  return showModalBottomSheet<FiltriRicette>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Nutri.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _FoglioFiltri(lang: lang, pasto: pasto, portata: portata, dieta: dieta),
  );
}

/// Un gruppo di scelte: titolo e pastiglie alte 44, a 8 di distanza.
Widget _gruppo({
  required String titolo,
  required List<String> valori,
  required String prefisso,
  required bool Function(String) scelto,
  required void Function(String) tocca,
  required String lang,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(titolo, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Nutri.label)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in valori)
            NutriChip(
              height: 44,
              label: Translations.get(lang, '$prefisso$v'),
              selected: scelto(v),
              onTap: () => tocca(v),
            ),
        ],
      ),
    ],
  );
}

ButtonStyle _stilePrincipale() => FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      shape: const StadiumBorder(),
      backgroundColor: Nutri.greenFill,
      foregroundColor: Nutri.onGreenFill,
      disabledBackgroundColor: Nutri.disabledBg,
      disabledForegroundColor: Nutri.muted,
    );

class _FoglioCategorie extends StatefulWidget {
  final String lang;
  final CategorieRicetta? iniziali;
  const _FoglioCategorie({required this.lang, this.iniziali});

  @override
  State<_FoglioCategorie> createState() => _FoglioCategorieState();
}

class _FoglioCategorieState extends State<_FoglioCategorie> {
  late final Set<String> _pasti = {...?widget.iniziali?.pasti}..retainAll(pastiRicetta);
  late String? _portata = portateRicetta.contains(widget.iniziali?.portata) ? widget.iniziali?.portata : null;
  late final Set<String> _diete = {...?widget.iniziali?.diete}..retainAll(dieteRicetta);

  bool get _completo => _pasti.isNotEmpty && _portata != null;

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Translations.get(lang, 'share_categories_title'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Nutri.ink),
          ),
          const SizedBox(height: 6),
          Text(
            Translations.get(lang, 'share_categories_intro'),
            style: TextStyle(fontSize: 13, height: 1.45, color: Nutri.body),
          ),
          const SizedBox(height: 20),
          _gruppo(
            titolo: Translations.get(lang, 'share_categories_meals'),
            valori: pastiRicetta,
            prefisso: 'meal_',
            scelto: _pasti.contains,
            tocca: (v) => setState(() => _pasti.contains(v) ? _pasti.remove(v) : _pasti.add(v)),
            lang: lang,
          ),
          const SizedBox(height: 20),
          _gruppo(
            titolo: Translations.get(lang, 'share_categories_course'),
            valori: portateRicetta,
            prefisso: 'course_',
            scelto: (v) => _portata == v,
            tocca: (v) => setState(() => _portata = v),
            lang: lang,
          ),
          const SizedBox(height: 20),
          _gruppo(
            titolo: Translations.get(lang, 'share_categories_diet'),
            valori: dieteRicetta,
            prefisso: 'diet_',
            scelto: _diete.contains,
            tocca: (v) => setState(() => _diete.contains(v) ? _diete.remove(v) : _diete.add(v)),
            lang: lang,
          ),
          const SizedBox(height: 24),
          if (!_completo) ...[
            Text(
              Translations.get(lang, 'share_categories_missing'),
              style: TextStyle(fontSize: 12.5, color: Nutri.muted),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton(
            style: _stilePrincipale(),
            onPressed: _completo
                ? () => Navigator.pop<CategorieRicetta>(context, (
                      pasti: [for (final p in pastiRicetta) if (_pasti.contains(p)) p],
                      portata: _portata,
                      diete: [for (final d in dieteRicetta) if (_diete.contains(d)) d],
                    ))
                : null,
            child: Text(
              Translations.get(lang, 'share_categories_send'),
              style: TextStyle(
                color: _completo ? Nutri.onGreenFill : Nutri.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoglioFiltri extends StatefulWidget {
  final String lang;
  final String? pasto;
  final String? portata;
  final String? dieta;
  const _FoglioFiltri({required this.lang, this.pasto, this.portata, this.dieta});

  @override
  State<_FoglioFiltri> createState() => _FoglioFiltriState();
}

class _FoglioFiltriState extends State<_FoglioFiltri> {
  late String? _pasto = widget.pasto;
  late String? _portata = widget.portata;
  late String? _dieta = widget.dieta;

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Translations.get(lang, 'public_filters'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Nutri.ink),
          ),
          const SizedBox(height: 20),
          // Un secondo tocco sulla scelta attiva la toglie.
          _gruppo(
            titolo: Translations.get(lang, 'share_categories_meals'),
            valori: pastiRicetta,
            prefisso: 'meal_',
            scelto: (v) => _pasto == v,
            tocca: (v) => setState(() => _pasto = _pasto == v ? null : v),
            lang: lang,
          ),
          const SizedBox(height: 20),
          _gruppo(
            titolo: Translations.get(lang, 'share_categories_course'),
            valori: portateRicetta,
            prefisso: 'course_',
            scelto: (v) => _portata == v,
            tocca: (v) => setState(() => _portata = _portata == v ? null : v),
            lang: lang,
          ),
          const SizedBox(height: 20),
          _gruppo(
            titolo: Translations.get(lang, 'share_categories_diet'),
            valori: dieteRicetta,
            prefisso: 'diet_',
            scelto: (v) => _dieta == v,
            tocca: (v) => setState(() => _dieta = _dieta == v ? null : v),
            lang: lang,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                    side: BorderSide(color: Nutri.fieldBorder),
                  ),
                  onPressed: () => Navigator.pop<FiltriRicette>(context, (pasto: null, portata: null, dieta: null)),
                  child: Text(
                    Translations.get(lang, 'public_filters_clear'),
                    style: TextStyle(color: Nutri.label, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: _stilePrincipale(),
                  onPressed: () => Navigator.pop<FiltriRicette>(context, (pasto: _pasto, portata: _portata, dieta: _dieta)),
                  child: Text(
                    Translations.get(lang, 'public_filters_apply'),
                    style: TextStyle(color: Nutri.onGreenFill, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
