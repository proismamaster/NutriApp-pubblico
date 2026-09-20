import 'package:flutter/material.dart';

import 'auth_style.dart';
import 'stato_condivisione.dart';

/// `ParagrafoRicetta`
/// Scheda riassuntiva di una ricetta nell'elenco.
///
/// RIDISEGNATA IL 17/09 ("non mi piace quella disposizione dei pulsanti in
/// colonna", Ismail). Prima: una striscia colorata a sinistra, il testo al
/// centro e quattro pulsanti impilati a destra, che rendevano ogni scheda alta
/// quanto quattro pulsanti anche con un nome di una riga. Ora: foto e testo in
/// alto, i pulsanti in una riga sola in fondo a destra. Il preferito si vede
/// dalla stella piena, non piu' da una striscia.
class ParagrafoRicetta extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? kcalLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final bool isFavorite;
  final VoidCallback? onFavorite;

  /// Foto della ricetta (2026-08-30). Quando c'e' prende il posto dell'icona
  /// generica: e' l'unica cosa che distingue una ricetta dall'altra a colpo
  /// d'occhio in una lista dove erano tutte identiche.
  final String imageUrl;

  /// Condivisione con gli altri utenti (2026-09-12). `null` = la scheda non
  /// parla di condivisione (ricette di altri in "Consigliate").
  final VoidCallback? onShare;

  /// Stato di [onShare]: private | pending | approved | rejected. Decide
  /// icona e colore del pulsante.
  final String sharedStatus;

  /// Riga in piu' sotto al titolo, usata in "Consigliate" per dire di chi e'
  /// la ricetta. Vuota sulle proprie.
  final String? footnote;

  /// Like, solo sulle ricette pubbliche degli altri (15/09). `null` = niente
  /// cuore.
  final VoidCallback? onLike;
  final int likesCount;
  final bool likedByMe;
  final String? likeTooltip;

  const ParagrafoRicetta({
    super.key,
    required this.title,
    required this.subtitle,
    this.kcalLabel,
    this.onEdit,
    this.onDelete,
    this.onTap,
    this.isFavorite = false,
    this.onFavorite,
    this.imageUrl = '',
    this.onShare,
    this.sharedStatus = 'private',
    this.footnote,
    this.onLike,
    this.likesCount = 0,
    this.likedByMe = false,
    this.likeTooltip,
  });

  bool get _haAzioni =>
      onLike != null || onFavorite != null || onShare != null || onEdit != null || onDelete != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foto = nutriImageProvider(imageUrl);
    final segnaposto = Container(
      width: 64,
      height: 64,
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.restaurant_menu, color: scheme.primary, size: 26),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, _haAzioni ? 4 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: foto == null
                          ? segnaposto
                          : Image(
                              image: foto,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              // Un indirizzo rotto non deve lasciare un buco.
                              errorBuilder: (_, _, _) => segnaposto,
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                          ),
                          if (footnote != null && footnote!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              footnote!,
                              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                            ),
                          ],
                          if (kcalLabel != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              kcalLabel!,
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: scheme.onSurface),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (_haAzioni)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onLike != null) ...[
                        IconButton(
                          tooltip: likeTooltip,
                          icon: Icon(
                            likedByMe ? Icons.favorite : Icons.favorite_border,
                            size: 21,
                            color: likedByMe ? scheme.error : scheme.onSurfaceVariant,
                          ),
                          onPressed: onLike,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '$likesCount',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                      if (onFavorite != null)
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 22,
                            color: isFavorite ? Nutri.amber : scheme.onSurfaceVariant,
                          ),
                          onPressed: onFavorite,
                        ),
                      if (onShare != null)
                        Builder(
                          builder: (context) {
                            final segnale = segnaleCondivisione(sharedStatus, scheme);
                            return IconButton(
                              icon: Icon(segnale.icona, size: 21, color: segnale.colore),
                              onPressed: onShare,
                            );
                          },
                        ),
                      if (onEdit != null)
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 21, color: scheme.primary),
                          onPressed: onEdit,
                        ),
                      if (onDelete != null)
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 21, color: scheme.error),
                          onPressed: onDelete,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
