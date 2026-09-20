import 'package:flutter/material.dart';

import '../dictionary/translations.dart';

/// Come si mostra lo stato di condivisione di un contenuto dell'utente
/// (alimento personale o ricetta), 2026-09-12.
///
/// PERCHE' UN FILE SOLO: questo stato compare in tre posti — la card di una
/// ricetta, la riga di un alimento in "I miei alimenti", la scheda di una
/// ricetta. Tre copie della stessa mappatura icona/colore/etichetta erano
/// destinate a divergere: e' il difetto che in questo progetto e' tornato
/// piu' volte (due palette, due pagine ricetta, due elenchi di colonne).
/// Qui c'e' una definizione e tre usi.
///
/// Gli stati sono quelli del database (`na_custom_foods.shared_status`,
/// `na_recipes.shared_status`): private · pending · approved · rejected.
({IconData icona, Color colore, String chiave}) segnaleCondivisione(
  String stato,
  ColorScheme scheme,
) {
  switch (stato) {
    case 'pending':
      // Ambra e clessidra: "in attesa" non e' ne' un successo ne' un errore,
      // ed e' lo stato in cui un contenuto passa piu' tempo.
      return (
        icona: Icons.hourglass_top,
        colore: Colors.amber.shade700,
        chiave: 'share_state_pending',
      );
    case 'approved':
      return (icona: Icons.public, colore: scheme.primary, chiave: 'share_state_approved');
    case 'rejected':
      return (icona: Icons.block, colore: scheme.error, chiave: 'share_state_rejected');
    default:
      // Privato e' il default anche per uno stato sconosciuto: se il server
      // un giorno mandasse un valore nuovo, mostrarlo come pubblico sarebbe
      // il modo peggiore di sbagliare.
      return (
        icona: Icons.public_off,
        colore: scheme.outline,
        chiave: 'share_state_private',
      );
  }
}

/// Un contenuto approvato e' del database (2026-09-15, decisione di Ismail):
/// l'autore non lo ritira e non lo modifica piu'. Chi tocca condividi o
/// modifica su un contenuto cosi' legge il perche', invece di un pulsante che
/// non fa niente o di un errore del server.
Future<void> mostraContenutoBloccato(BuildContext context, String lang) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.public, color: Theme.of(ctx).colorScheme.primary),
      title: Text(Translations.get(lang, 'share_locked_title')),
      content: Text(Translations.get(lang, 'share_locked_body')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
        ),
      ],
    ),
  );
}

/// Pastiglia con icona ed etichetta dello stato — si mostra solo quando c'e'
/// qualcosa da dire, cioe' mai per i contenuti privati: la stragrande
/// maggioranza lo e', e una pastiglia "privato" su ogni riga sarebbe rumore.
class PastigliaCondivisione extends StatelessWidget {
  final String stato;
  final String lang;

  const PastigliaCondivisione({super.key, required this.stato, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (stato == 'private' || stato.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final segnale = segnaleCondivisione(stato, scheme);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: segnale.colore.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(segnale.icona, size: 12, color: segnale.colore),
          const SizedBox(width: 4),
          Text(
            Translations.get(lang, segnale.chiave),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: segnale.colore,
            ),
          ),
        ],
      ),
    );
  }
}
