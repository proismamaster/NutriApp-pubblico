import 'package:flutter/material.dart';
import '../models/nutrient_field_config.dart';
import 'unit_format.dart';

/// Gestisce un set di TextEditingController per i nutrienti.
class NutrientControllerManager {
  final Map<String, TextEditingController> controllers = {};

  void init(List<String> keys) {
    for (final key in keys) {
      controllers[key] = TextEditingController();
    }
  }

  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    controllers.clear();
  }

  /// Chiavi che contengono un'ENERGIA e vanno quindi mostrate nell'unita'
  /// scelta dall'utente (kcal o kJ). Tutte le altre sono grammi o milligrammi
  /// di nutriente, che non cambiano mai unita'.
  static const Set<String> _chiaviEnergia = {'calorie_goal', 'calories'};

  /// Chiavi con un PESO al giorno (gli obiettivi in grammi), mostrate in
  /// grammi o once secondo la preferenza (18/09: prima restavano in grammi
  /// anche con le once scelte). Non ci sono i valori per 100 g
  /// dell'inserimento manuale: quelli si copiano dall'etichetta, che e' in
  /// grammi.
  static const Set<String> _chiaviPeso = {
    'carb_goal', 'protein_goal', 'fat_goal', 'fiber_goal', 'sugar_max', 'saturated_fats_goal',
  };

  /// Da quello che c'e' scritto nel campo all'unita' interna.
  static double _interno(String key, double n) {
    if (_chiaviEnergia.contains(key)) return UnitFormat.unitaEnergia == 'kj' ? n / 4.184 : n;
    if (_chiaviPeso.contains(key)) return UnitFormat.aGrammi(n);
    return n;
  }

  /// Dall'unita' interna a quello che l'utente legge nel campo.
  static String _visibile(String key, double interno, int decimali) {
    if (_chiaviEnergia.contains(key)) return UnitFormat.eValore(interno);
    if (_chiaviPeso.contains(key)) return UnitFormat.pValore(interno);
    return interno.toStringAsFixed(decimali);
  }

  /// Valore di un campo nell'unita' INTERNA dell'app: kcal per l'energia,
  /// grammi o milligrammi per tutto il resto.
  ///
  /// Da usare ovunque si legga un controller a mano invece di passare da
  /// [getValues]: senza, un campo che a schermo dice 8400 kJ verrebbe letto
  /// come 8400 kcal, e i macro calcolati da li' sarebbero quattro volte
  /// troppo grandi.
  double valore(String key) {
    final testo = (controllers[key]?.text ?? '').replaceAll(',', '.').trim();
    return _interno(key, double.tryParse(testo) ?? 0);
  }

  /// Scrive nel campo un valore espresso nell'unita' interna, convertendolo
  /// in cio' che l'utente si aspetta di leggere.
  void scrivi(String key, double valoreInterno, {int decimali = 0}) {
    final c = controllers[key];
    if (c == null) return;
    c.text = _visibile(key, valoreInterno, decimali);
  }

  void setValues(Map<String, dynamic> values) {
    values.forEach((key, value) {
      if (!controllers.containsKey(key)) return;
      if (_chiaviEnergia.contains(key) || _chiaviPeso.contains(key)) {
        // Dal database arrivano SEMPRE kcal e grammi: qui diventano il numero
        // che l'utente si aspetta di leggere nel campo.
        final interno = double.tryParse(value?.toString() ?? '');
        controllers[key]!.text = interno == null ? '' : _visibile(key, interno, 0);
        return;
      }
      controllers[key]!.text = value?.toString() ?? '';
    });
  }

  /// I valori COME VANNO SALVATI: energia sempre riportata a kcal.
  ///
  /// PERCHE' (2026-09-05): se l'utente sceglie i kilojoule, nel campo scrive
  /// 8400 e non 2000. Salvare 8400 nella colonna delle kcal renderebbe
  /// l'obiettivo quattro volte piu' alto, e il giorno che tornasse alle kcal
  /// se lo ritroverebbe cosi'. La conversione qui e' l'unica difesa, perche'
  /// questo e' l'unico punto da cui i campi finiscono nel modello.
  Map<String, double> getValues() {
    final Map<String, double> values = {};
    controllers.forEach((key, controller) {
      final text = controller.text.replaceAll(',', '.').trim();
      final parsed = double.tryParse(text);
      if (parsed == null) return;
      values[key] = _interno(key, parsed);
    });
    return values;
  }

  NutrientFieldConfig getConfig(String key, {
    required String label,
    String suffix = '',
    String hint = '',
    TextInputType keyboardType = const TextInputType.numberWithOptions(decimal: true),
    String? Function(String?)? validator,
    bool readOnly = false,
    Color? dotColor,
    String? trailingHint,
  }) {
    return NutrientFieldConfig(
      label: label,
      controller: controllers[key] ?? TextEditingController(),
      suffix: suffix,
      hint: hint,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      dotColor: dotColor,
      trailingHint: trailingHint,
    );
  }
}
