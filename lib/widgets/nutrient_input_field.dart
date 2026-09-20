import 'package:flutter/material.dart';

/// Widget personalizzato per l'inserimento dei nutrienti
class NutrientInputField extends StatelessWidget {
  final String label;
  final String hint;
  final String suffix;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onManualChanged;
  final String? Function(String?)? validator;
  final bool readOnly;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  /// Pallino colorato davanti al campo (mockup "Goals"/"Manual Entry": ogni
  /// riga macro ha un piccolo indicatore colore-coerente col resto della UI,
  /// es. verde per carboidrati). Null = nessun pallino, comportamento
  /// invariato per tutti gli altri ~50 campi nutrienti dell'app.
  final Color? dotColor;

  /// Testo grigio aggiuntivo mostrato prima dell'unità di misura (mockup
  /// "Goals": lettura live in kcal accanto al campo, es. "216 kcal" prima
  /// della "g"). Null = solo l'unità, come prima.
  final String? trailingHint;

  /// Stile "mockup Goals/Manual Entry": sfondo bianco/superficie con bordo
  /// sottile invece del riempimento grigio pieno usato altrove nell'app
  /// (onboarding/signup, che non fanno parte di questo restyle e restano
  /// invariati). Default `false` = comportamento di sempre.
  final bool outlined;

  const NutrientInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.suffix,
    required this.controller,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.onChanged,
    this.onManualChanged,
    this.validator,
    this.readOnly = false,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.dotColor,
    this.trailingHint,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget? effectivePrefix = prefixIcon ??
        (dotColor == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Align(
                  alignment: Alignment.center,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                ),
              ));
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        obscureText: obscureText,
        onChanged: (value) {
          // Se l'utente digita, segnaliamo che è un cambio manuale
          if (onManualChanged != null) onManualChanged!();
          // Eseguiamo la logica di aggiornamento (es. ricalcolo proporzioni)
          if (onChanged != null) onChanged!(value);
        },
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: trailingHint == null ? suffix : null,
          suffix: trailingHint == null
              ? null
              : Text(
                  '$trailingHint  $suffix',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
          prefixIcon: effectivePrefix,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: outlined ? scheme.surface : scheme.surfaceContainerHighest,
          border: _border(scheme.outlineVariant),
          enabledBorder: _border(scheme.outlineVariant),
          focusedBorder: _border(scheme.primary),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 14.0,
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(outlined ? 14.0 : 12.0),
        borderSide: outlined ? BorderSide(color: color, width: 1.5) : BorderSide.none,
      );
}
