import 'package:flutter/material.dart';

import 'auth_style.dart';

/// Una voce del foglio di scelta.
class NutriOpzione<T> {
  final T valore;
  final String etichetta;

  /// Riga piccola sotto l'etichetta, quando l'opzione ha bisogno di una
  /// spiegazione (per esempio "ogni 2 ore" sotto "2h").
  final String? sotto;
  final IconData? icona;

  const NutriOpzione(this.valore, this.etichetta, {this.sotto, this.icona});
}

/// Foglio dal basso con le opzioni, una per riga. Torna la scelta, o `null`
/// se l'utente chiude senza scegliere.
///
/// PERCHE' ESISTE (18/09, richiesta di Ismail): i menu di `DropdownMenu` e
/// `DropdownButton` si aprono come uno strato sopra la pagina e coprono il
/// campo e quello che c'e' sotto — nello screenshot della schermata Lingua e
/// paese il menu nascondeva meta' della pagina. Un foglio dal basso occupa
/// tutta la larghezza, non copre mai il campo che lo ha aperto e regge le
/// liste lunghe, in italiano come in arabo.
Future<T?> mostraSceltaNutri<T>(
  BuildContext context, {
  required String titolo,
  required List<NutriOpzione<T>> opzioni,
  T? selezionato,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Nutri.card,
    // Con molte voci il foglio si alza fino a tre quarti dello schermo e poi
    // scorre, invece di spingere le ultime fuori.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  decoration: BoxDecoration(
                    color: Nutri.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  titolo,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Nutri.ink),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    for (final o in opzioni)
                      InkWell(
                        onTap: () => Navigator.pop(context, o.valore),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            children: [
                              if (o.icona != null) ...[
                                Icon(o.icona, size: 20, color: Nutri.green),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      o.etichetta,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: o.valore == selezionato ? FontWeight.w700 : FontWeight.w500,
                                        color: Nutri.ink,
                                      ),
                                    ),
                                    if (o.sotto != null)
                                      Text(
                                        o.sotto!,
                                        style: TextStyle(fontSize: 12.5, color: Nutri.muted),
                                      ),
                                  ],
                                ),
                              ),
                              if (o.valore == selezionato)
                                Icon(Icons.check, size: 20, color: scheme.primary),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Lo stesso campo, ma con un'azione propria al posto del foglio: serve dove
/// la scelta ha gia' il suo cercatore (le categorie degli alimenti).
class NutriCampoScelta extends StatelessWidget {
  final String testo;
  final bool vuoto;
  final VoidCallback onTap;

  const NutriCampoScelta({
    super.key,
    required this.testo,
    required this.onTap,
    this.vuoto = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Nutri.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Nutri.fieldBorder, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  testo,
                  style: TextStyle(fontSize: 14, color: vuoto ? Nutri.hint : Nutri.ink),
                ),
              ),
              Icon(Icons.expand_more, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo di scelta: si vede come un campo di testo, si tocca e apre
/// [mostraSceltaNutri]. Sostituisce ovunque `DropdownMenu`/`DropdownButton`.
class NutriSelect<T> extends StatelessWidget {
  final T? valore;
  final List<NutriOpzione<T>> opzioni;
  final ValueChanged<T> onCambiato;

  /// Titolo del foglio: dice cosa si sta scegliendo ("Pasto", "Lingua").
  final String titolo;

  /// Testo quando non c'e' ancora niente di scelto.
  final String? segnaposto;

  /// Messaggio rosso sotto il campo (il pasto obbligatorio lo usa).
  final String? errore;
  final IconData? icona;

  const NutriSelect({
    super.key,
    required this.valore,
    required this.opzioni,
    required this.onCambiato,
    required this.titolo,
    this.segnaposto,
    this.errore,
    this.icona,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scelta = opzioni.where((o) => o.valore == valore).firstOrNull;
    final bordo = errore != null ? Nutri.fieldBorderError : Nutri.fieldBorder;

    return Column(
      // Alto quanto il campo (piu' l'eventuale errore): dentro una Column di
      // un form non deve prendersi tutto lo spazio che avanza.
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Nutri.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final scelto = await mostraSceltaNutri<T>(
                context,
                titolo: titolo,
                opzioni: opzioni,
                selezionato: valore,
              );
              if (scelto != null) onCambiato(scelto);
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: bordo, width: 1.5),
              ),
              child: Row(
                children: [
                  if (icona != null) ...[
                    Icon(icona, size: 20, color: Nutri.green),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      scelta?.etichetta ?? segnaposto ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        color: scelta == null ? Nutri.hint : Nutri.ink,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more, color: scheme.primary),
                ],
              ),
            ),
          ),
        ),
        if (errore != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Text(
              errore!,
              style: TextStyle(fontSize: 12, color: scheme.error),
            ),
          ),
      ],
    );
  }
}
