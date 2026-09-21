import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dictionary/translations.dart';
import '../domain/user_provider.dart';
import '../models/recipe.dart';
import '../providers/locale_provider.dart';
import '../services/api_services.dart';
import 'auth_style.dart';

/// Segnalazione di una ricetta pubblica (richiesta di Ismail, 21/09).
///
/// PERCHE' NON SI RIUSA `segnala_alimento.dart`: quel foglio parla di un
/// prodotto con un barcode e offre la strada "proponi i valori corretti", che
/// qui non esiste — una ricetta e' scritta da una persona e non si corregge
/// per conto suo. Chi ne vuole una versione diversa se ne fa una copia
/// privata (vedi la modifica di una ricetta pubblica in
/// recipe_list_page.dart). Restano identici la forma del foglio e i motivi a
/// lista chiusa, perche' anche queste segnalazioni vanno contate e
/// raggruppate, non lette una per una.
///
/// Chi la manda non cambia niente: la riga nasce `pending` e la vede solo chi
/// rivede. Va detto anche all'utente, altrimenti si aspetta che la ricetta
/// sparisca subito.
Future<void> mostraSegnalaRicetta(
  BuildContext context, {
  required Recipe recipe,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Nutri.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FoglioSegnalaRicetta(recipe: recipe),
  );
}

/// Le sei voci ammesse dal server (`NA_TIPI_SEGNALAZIONE_RICETTA` in
/// community_comune.php), con l'icona. L'elenco valido e' quello del
/// database: qui ci sono solo le etichette da mostrare.
const List<(String, IconData)> _problemi = [
  ('contenuto', Icons.report_gmailerrorred_outlined),
  ('valori', Icons.pie_chart_outline),
  ('copia', Icons.copy_all_outlined),
  ('pericolosa', Icons.health_and_safety_outlined),
  ('spam', Icons.campaign_outlined),
  ('altro', Icons.more_horiz),
];

class _FoglioSegnalaRicetta extends ConsumerStatefulWidget {
  final Recipe recipe;
  const _FoglioSegnalaRicetta({required this.recipe});

  @override
  ConsumerState<_FoglioSegnalaRicetta> createState() => _FoglioSegnalaRicettaState();
}

class _FoglioSegnalaRicettaState extends ConsumerState<_FoglioSegnalaRicetta> {
  String? _problema;
  final _nota = TextEditingController();
  bool _invio = false;

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _invia() async {
    final lang = ref.read(appSettingsProvider).language;
    final email = ref.read(userProvider)?.email ?? '';
    final problema = _problema;
    final id = int.tryParse('${widget.recipe.id}');
    if (problema == null || email.isEmpty || id == null) return;

    setState(() => _invio = true);
    final esito = await ApiServices.saveRecipeReport(
      userEmail: email,
      recipeId: id,
      issue: problema,
      note: _nota.text.trim(),
    );
    if (!mounted) return;
    setState(() => _invio = false);

    final navigator = Navigator.of(context);
    final messaggi = ScaffoldMessenger.of(context);
    final coloreErrore = Theme.of(context).colorScheme.error;
    navigator.pop();

    if (esito['status'] == 'success') {
      // "Gia' aperta" non e' un errore: la segnalazione c'e'. Dirgli "errore"
      // lo farebbe ritentare all'infinito su una cosa gia' fatta.
      final gia = esito['already'] == true;
      messaggi.showSnackBar(
        SnackBar(content: Text(Translations.get(lang, gia ? 'report_already' : 'report_sent'))),
      );
      return;
    }
    // Il messaggio del server, non uno generico: qui i due errori piu'
    // probabili sono "migrazione mancante" e "file non caricato via FTP", e
    // sono l'informazione che serve per sistemarli.
    messaggi.showSnackBar(
      SnackBar(
        backgroundColor: coloreErrore,
        content: Text('${Translations.get(lang, 'report_failed')} ${esito['message'] ?? ''}'.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    final scheme = Theme.of(context).colorScheme;
    final altezzaMassima = MediaQuery.sizeOf(context).height * 0.9;
    final tastiera = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: tastiera),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: altezzaMassima),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Translations.get(lang, 'report_recipe_title'),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Nutri.ink),
                    ),
                    if (widget.recipe.name.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.recipe.name,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.primary),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      Translations.get(lang, 'report_recipe_intro'),
                      style: TextStyle(fontSize: 13, height: 1.45, color: Nutri.body),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      Translations.get(lang, 'report_pick_issue'),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Nutri.label),
                    ),
                    const SizedBox(height: 10),
                    for (final (chiave, icona) in _problemi) _riga(chiave, icona, lang, scheme),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nota,
                      maxLines: 3,
                      minLines: 2,
                      maxLength: 400,
                      decoration: InputDecoration(
                        labelText: Translations.get(lang, 'report_note_hint'),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: Nutri.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Nutri.fieldBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Nutri.fieldBorder),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _barraAzioni(lang, scheme),
          ],
        ),
      ),
    );
  }

  /// Una riga di scelta: sempre la stessa altezza e lo stesso bordo, scelta o
  /// no. Cambia solo il colore, cosi' toccarla non sposta niente — stessa
  /// forma del foglio degli alimenti, rifatta il 15/09.
  Widget _riga(String chiave, IconData icona, String lang, ColorScheme scheme) {
    final scelto = _problema == chiave;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: scelto,
        inMutuallyExclusiveGroup: true,
        button: true,
        child: Material(
          color: scelto ? Nutri.greenSoft : Nutri.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scelto ? scheme.primary : Nutri.hairline, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _invio ? null : () => setState(() => _problema = chiave),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(icona, size: 22, color: scelto ? scheme.primary : Nutri.muted),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Translations.get(lang, 'report_recipe_issue_$chiave'),
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Nutri.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Translations.get(lang, 'report_recipe_issue_${chiave}_desc'),
                            style: TextStyle(fontSize: 12.5, color: Nutri.body),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      scelto ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 22,
                      color: scelto ? scheme.primary : Nutri.hint,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _barraAzioni(String lang, ColorScheme scheme) {
    final attivo = _problema != null && !_invio;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Nutri.bg,
        border: Border(top: BorderSide(color: Nutri.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
                side: BorderSide(color: Nutri.fieldBorder),
              ),
              onPressed: _invio ? null : () => Navigator.pop(context),
              child: Text(
                Translations.get(lang, 'Annulla'),
                style: TextStyle(color: Nutri.label, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              // Colori dichiarati, non ereditati: il tema dell'app non
              // configura `filledButtonTheme`, e il verde di riempimento
              // arrivava con sopra un testo verde scuro — illeggibile.
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                disabledBackgroundColor: scheme.surfaceContainerHighest,
                disabledForegroundColor: scheme.onSurfaceVariant,
              ),
              // Niente da inviare senza aver detto cosa non va: il tipo e' il
              // solo campo obbligatorio, ed e' anche l'unico che rende la
              // segnalazione contabile.
              onPressed: attivo ? _invia : null,
              child: _invio
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onSurfaceVariant),
                    )
                  : Text(
                      Translations.get(lang, 'report_send'),
                      style: TextStyle(
                        color: attivo ? scheme.onPrimary : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
