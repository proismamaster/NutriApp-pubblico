import 'package:flutter/material.dart';

import 'auth_style.dart';
import '../services/api_services.dart';
import '../dictionary/translations.dart';

/// Mostra un testo (tipicamente gli ingredienti di un prodotto
/// OpenFoodFacts) tradotto automaticamente nella lingua dell'app se scritto
/// in una lingua diversa — richiesta 2026-07-24.
///
/// Design non bloccante: mostra subito il testo originale (niente spinner
/// che blocca la UI), e lo sostituisce con la traduzione appena pronta, con
/// un'etichetta "Tradotto automaticamente" che l'utente può toccare per
/// tornare a vedere l'originale. Se il testo è già nella lingua dell'app
/// (o la traduzione fallisce), non cambia nulla: nessuna etichetta mostrata.
///
/// Riusato sia da `product_info_sheet.dart` (sezione Composizione) sia da
/// `manual_entry_page.dart` (sezione Ingredienti della vista "Prodotto
/// Trovato"), per non duplicare la logica di chiamata/cache/fallback.
class TranslatedText extends StatefulWidget {
  final String text;
  final String displayLanguage;
  final TextStyle? style;

  const TranslatedText({
    super.key,
    required this.text,
    required this.displayLanguage,
    this.style,
  });

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  String? _translated;
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    _translate();
  }

  @override
  void didUpdateWidget(covariant TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.displayLanguage != widget.displayLanguage) {
      _translated = null;
      _showOriginal = false;
      _translate();
    }
  }

  Future<void> _translate() async {
    if (widget.text.trim().isEmpty) return;
    final result = await ApiServices.translateIngredients(
      widget.text,
      widget.displayLanguage,
    );
    if (!mounted) return;
    setState(() {
      _translated = result.wasTranslated ? result.text : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasTranslation = _translated != null;
    final String shown = (hasTranslation && !_showOriginal)
        ? _translated!
        : widget.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(shown, style: widget.style),
        if (hasTranslation) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () => setState(() => _showOriginal = !_showOriginal),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.translate, size: 12, color: Nutri.muted),
                const SizedBox(width: 4),
                Text(
                  _showOriginal
                      ? Translations.get(widget.displayLanguage, 'show_translation_label')
                      : Translations.get(widget.displayLanguage, 'auto_translated_label'),
                  style: TextStyle(
                    fontSize: 11,
                    color: Nutri.muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
