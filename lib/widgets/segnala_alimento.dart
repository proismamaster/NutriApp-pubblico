import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dictionary/translations.dart';
import '../domain/user_provider.dart';
import '../providers/locale_provider.dart';
import '../services/api_services.dart';
import '../screens/proponi_valori_page.dart';
import 'auth_style.dart';

/// Segnalazione di un errore nei dati di un alimento (punto 1 della
/// collaborazione, ROADMAP 2026-09-12).
///
/// PERCHE' UNA LISTA CHIUSA DI PROBLEMI E NON SOLO UN TESTO LIBERO
/// `na_reports`, che raccoglie i problemi dell'app, per mesi ha avuto solo un
/// paragrafo scritto a mano: ogni segnalazione andava letta e interpretata, e
/// non c'era modo di contarle o raggrupparle. Qui il tipo di problema si
/// sceglie con un tocco, e il testo libero resta facoltativo — serve a
/// spiegare, non a classificare.
///
/// Chi la manda non cambia niente nel database: la riga nasce `pending` e la
/// vede solo chi rivede. Va detto anche all'utente, altrimenti si aspetta di
/// vedere il dato corretto subito dopo.
///
/// RIDISEGNATO IL 15/09 ("il design e' un disastro", screenshot di Ismail):
///  - un foglio dal basso invece di un dialogo stretto, con Annulla e Invia
///    sempre in fondo;
///  - i tipi di problema sono righe intere con icona e una riga di spiegazione,
///    a scelta singola. Le pastiglie di prima cambiavano larghezza quando le
///    toccavi (compariva la spunta) e l'impaginazione saltava;
///  - tolti "Quale campo" e "Valore corretto": due caselle di testo libero che
///    nessuno poteva applicare, doppione peggiore di "Proponi i valori
///    corretti", che ha i campi veri e le foto. Per i valori quella e' la
///    strada, e il foglio la mette in evidenza.
Future<void> mostraSegnalaAlimento(
  BuildContext context, {
  required Map<String, dynamic> product,
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
    builder: (_) => _FoglioSegnalazione(product: product),
  );
}

/// Le sei voci ammesse dal server (`NA_TIPI_SEGNALAZIONE` in
/// community_comune.php), con l'icona. L'elenco valido e' quello del
/// database: qui ci sono solo le etichette da mostrare.
const List<(String, IconData)> _problemi = [
  ('valori', Icons.pie_chart_outline),
  ('nome', Icons.label_outline),
  ('categoria', Icons.category_outlined),
  ('immagine', Icons.image_outlined),
  ('duplicato', Icons.copy_all_outlined),
  ('altro', Icons.more_horiz),
];

class _FoglioSegnalazione extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;
  const _FoglioSegnalazione({required this.product});

  @override
  ConsumerState<_FoglioSegnalazione> createState() => _FoglioSegnalazioneState();
}

class _FoglioSegnalazioneState extends ConsumerState<_FoglioSegnalazione> {
  String? _problema;
  final _nota = TextEditingController();
  bool _invio = false;

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  String get _nomeAlimento => (widget.product['food_name'] ?? '').toString();

  /// Da dove viene l'alimento, per chi poi dovra' correggerlo: un valore
  /// sbagliato di OpenFoodFacts si corregge in un posto, uno del CREA in un
  /// altro, uno personale non si corregge affatto.
  String get _fonte {
    final f = (widget.product['fonte'] ?? widget.product['source'] ?? '').toString();
    if (f.isNotEmpty) return f;
    if ((widget.product['barcode'] ?? '').toString().isNotEmpty) return 'off';
    return '';
  }

  Future<void> _invia() async {
    final lang = ref.read(appSettingsProvider).language;
    final email = ref.read(userProvider)?.email ?? '';
    final problema = _problema;
    if (problema == null || email.isEmpty) return;

    setState(() => _invio = true);
    final esito = await ApiServices.saveFoodReport(
      userEmail: email,
      foodName: _nomeAlimento,
      issue: problema,
      barcode: (widget.product['barcode'] ?? '').toString(),
      source: _fonte,
      fieldName: '',
      suggestedValue: '',
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

  void _apriProposta() {
    // Il navigator si prende PRIMA di chiudere il foglio: dopo il pop il suo
    // context non e' piu' valido.
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      // Il motivo gia' scelto viaggia con la proposta (18/09): chi rivede
      // legge "foto" o "nome", non sempre "valori".
      MaterialPageRoute(
        builder: (_) => ProponiValoriPage(product: widget.product, problema: _problema ?? 'valori'),
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
                      Translations.get(lang, 'report_food_title'),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Nutri.ink),
                    ),
                    if (_nomeAlimento.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _nomeAlimento,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.primary),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      Translations.get(lang, 'report_food_intro'),
                      style: TextStyle(fontSize: 13, height: 1.45, color: Nutri.body),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      Translations.get(lang, 'report_pick_issue'),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Nutri.label),
                    ),
                    const SizedBox(height: 10),
                    for (final (chiave, icona) in _problemi) _riga(chiave, icona, lang, scheme),
                    // 18/09: la proposta sta in fondo a QUALUNQUE motivo, non
                    // piu' solo ai valori. Da li' si correggono anche nome,
                    // marca, categoria e foto, cioe' tutti i motivi elencati
                    // sopra: chi sceglie "Nome o marca" aveva solo la nota.
                    const SizedBox(height: 4),
                    _stradaProposta(lang, scheme),
                    const SizedBox(height: 8),
                    Text(
                      Translations.get(lang, 'report_values_or_note'),
                      style: TextStyle(fontSize: 12.5, color: Nutri.muted),
                    ),
                    const SizedBox(height: 14),
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
  /// no. Cambia solo il colore, cosi' toccarla non sposta niente.
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
                            Translations.get(lang, 'report_issue_$chiave'),
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Nutri.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Translations.get(lang, 'report_issue_${chiave}_desc'),
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

  Widget _stradaProposta(String lang, ColorScheme scheme) {
    return Material(
      color: Nutri.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.primary, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _invio ? null : _apriProposta,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Icon(Icons.edit_note, size: 26, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Translations.get(lang, 'propose_title'),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: scheme.primary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      Translations.get(lang, 'report_values_path_body'),
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: Nutri.body),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.primary),
            ],
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
              // Colori dichiarati, non ereditati: il tema dell'app non configura
              // `filledButtonTheme`, e il verde di riempimento arrivava con sopra
              // un testo verde scuro — illeggibile.
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                disabledBackgroundColor: scheme.surfaceContainerHighest,
                disabledForegroundColor: scheme.onSurfaceVariant,
              ),
              // Niente da inviare senza aver detto cosa non torna: il tipo e' il
              // solo campo obbligatorio, ed e' anche l'unico che rende la
              // segnalazione contabile.
              onPressed: attivo ? _invia : null,
              // Colore scritto anche sul testo, non solo nello stile del pulsante:
              // misurato in un test, con il solo `foregroundColor` l'etichetta
              // restava del grigio-verde ereditato (#424940) sopra il verde pieno.
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
