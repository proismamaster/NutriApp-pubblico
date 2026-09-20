import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dictionary/translations.dart';
import '../logic/unit_format.dart';
import '../providers/locale_provider.dart';
import '../widgets/auth_style.dart';
import '../widgets/modern_loader.dart';

/// Unità di misura, in una schermata sua (2026-09-14).
///
/// PRIMA stavano in fondo a "Lingua e paese": chi cercava come passare dai
/// grammi alle once doveva indovinare che fossero li', sotto il database
/// alimentare. Ismail l'ha trovato poco chiaro, e rinominare la voce in
/// "Lingua, paese e unità" sarebbe stato troppo lungo per la riga delle
/// impostazioni. Ora ha una voce sua, con la scelta attuale scritta sotto.
///
/// In piu' rispetto a prima: un esempio che cambia mentre si sceglie, e la
/// riga che dice cosa NON cambia (peso corporeo e altezza restano in kg e cm),
/// che era proprio la domanda che la sezione vecchia lasciava aperta.
class UnitaMisuraPage extends ConsumerStatefulWidget {
  const UnitaMisuraPage({super.key});

  @override
  ConsumerState<UnitaMisuraPage> createState() => _UnitaMisuraPageState();
}

class _UnitaMisuraPageState extends ConsumerState<UnitaMisuraPage> {
  late String _peso;
  late String _energia;
  bool _modificato = false;
  bool _salvataggio = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(appSettingsProvider);
    _peso = s.weightUnit;
    _energia = s.energyUnit;
  }

  Future<void> _salva() async {
    setState(() => _salvataggio = true);
    await ref.read(appSettingsProvider.notifier).saveUnits(weightUnit: _peso, energyUnit: _energia);
    if (!mounted) return;
    setState(() {
      _salvataggio = false;
      _modificato = false;
    });
    final lang = ref.read(appSettingsProvider).language;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Translations.get(lang, 'settings_saved_msg')),
        backgroundColor: Nutri.greenFill,
      ),
    );
  }

  /// "150 g · 250 kcal" nelle unita' scelte ORA, non in quelle salvate:
  /// l'esempio serve proprio a vedere l'effetto prima di salvare.
  String get _esempio {
    // Numeri scritti come li scrive l'app, con lo stesso separatore
    // decimale: "5,3 oz" era fisso all'italiana anche in inglese e in cinese
    // (test di release 19/09).
    final peso = UnitFormat.weight(150, _peso);
    final energia = UnitFormat.energy(250, _energia);
    return '$peso · $energia';
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Nutri.bg,
          appBar: AppBar(
            backgroundColor: Nutri.bg,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Nutri.green),
              tooltip: Translations.get(lang, 'Indietro'),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              Translations.get(lang, 'Unità di misura'),
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Nutri.green,
                letterSpacing: -0.2,
              ),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    children: [
                      Text(
                        Translations.get(lang, 'Come vengono mostrati pesi ed energia'),
                        style: TextStyle(fontSize: 14, color: Nutri.body, height: 1.45),
                      ),
                      const SizedBox(height: 18),
                      _gruppo(
                        etichetta: Translations.get(lang, 'Peso'),
                        valore: _peso,
                        opzioni: {
                          'metric': Translations.get(lang, 'Grammi (g)'),
                          'imperial': Translations.get(lang, 'Once (oz)'),
                        },
                        onScelta: (v) => setState(() {
                          _peso = v;
                          _modificato = true;
                        }),
                      ),
                      const SizedBox(height: 12),
                      _gruppo(
                        etichetta: Translations.get(lang, 'Energia'),
                        valore: _energia,
                        opzioni: {
                          'kcal': Translations.get(lang, 'Kilocalorie'),
                          'kj': Translations.get(lang, 'Kilojoule'),
                        },
                        onScelta: (v) => setState(() {
                          _energia = v;
                          _modificato = true;
                        }),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                        decoration: BoxDecoration(
                          color: Nutri.surfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Translations.get(lang, 'units_example'),
                              style: TextStyle(fontSize: 12, color: Nutri.mutedSoft),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _esempio,
                              key: const Key('unita_esempio'),
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Nutri.ink),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              Translations.get(lang, 'units_body_note'),
                              style: TextStyle(fontSize: 12.5, color: Nutri.muted, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  decoration: BoxDecoration(
                    color: Nutri.bg,
                    border: Border(top: BorderSide(color: Nutri.disabledBg)),
                  ),
                  child: NutriPrimaryButton(
                    label: _modificato
                        ? Translations.get(lang, 'Salva impostazioni')
                        : Translations.get(lang, 'Tutte le impostazioni sono salvate'),
                    icon: _modificato ? Icons.check : Icons.cloud_done,
                    iconFirst: true,
                    height: 52,
                    enabled: _modificato,
                    onTap: () {
                      if (_modificato) _salva();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_salvataggio) VeloDiCaricamento(messaggio: Translations.get(lang, 'Salvataggio in corso...')),
      ],
    );
  }

  /// Interruttore a due scelte, lo stesso che stava in "Lingua e paese".
  Widget _gruppo({
    required String etichetta,
    required String valore,
    required Map<String, String> opzioni,
    required ValueChanged<String> onScelta,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Nutri.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Nutri.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etichetta,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Nutri.ink),
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Nutri.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                for (final e in opzioni.entries)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onScelta(e.key),
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: valore == e.key ? Nutri.greenFill : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: valore == e.key ? FontWeight.bold : FontWeight.w500,
                            color: valore == e.key ? Colors.white : Nutri.body,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
