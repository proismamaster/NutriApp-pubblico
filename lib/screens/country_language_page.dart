import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dictionary/translations.dart';
import '../providers/locale_provider.dart';
import '../widgets/auth_style.dart';
import '../widgets/modern_loader.dart';
import '../widgets/nutri_select.dart';

/// Lingua e paese — ridisegnata sul mockup "NutriApp Language & country"
/// (2026-09-05).
///
/// Le unità di misura, che il mockup metteva qui in fondo, dal 14/09 hanno una
/// schermata loro (`unita_misura_page.dart`): sotto "Lingua e paese" nessuno
/// le andava a cercare.
class LinguaPaesePage extends ConsumerStatefulWidget {
  const LinguaPaesePage({super.key});

  @override
  ConsumerState<LinguaPaesePage> createState() => _LinguaPaesePageState();
}

class _LinguaPaesePageState extends ConsumerState<LinguaPaesePage> {
  final List<String> _listaLingue = ['English', 'Italiano', '简体中文', 'العربية'];
  final List<String> _listaPaesi = ['Italia'];

  late String _linguaSelezionata;
  late String _paeseSelezionato;

  bool _isSaving = false;

  /// True quando c'è qualcosa da salvare: il mockup spegne il pulsante finché
  /// non si tocca niente, invece di lasciarlo sempre acceso e non far capire
  /// se il salvataggio sia già avvenuto.
  bool _modificato = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(appSettingsProvider);
    // Normalizzazione una volta sola: se il valore salvato non è fra quelli
    // selezionabili, si riporta al default QUI, così ciò che si vede e ciò che
    // si salva coincidono (correzione del 29/08, vedi PROBLEMS).
    _linguaSelezionata = _listaLingue.contains(s.language) ? s.language : 'Italiano';
    _paeseSelezionato = _listaPaesi.contains(s.country) ? s.country : 'Italia';
  }

  Future<void> _salva() async {
    setState(() => _isSaving = true);
    final notifier = ref.read(appSettingsProvider.notifier);
    await notifier.saveSettings(_linguaSelezionata, _paeseSelezionato);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _modificato = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Translations.get(_linguaSelezionata, 'settings_saved_msg')),
        backgroundColor: Nutri.greenFill,
      ),
    );
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
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              Translations.get(lang, 'Lingua e paese'),
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
                      _titoloSezione(
                        Icons.language,
                        Translations.get(lang, 'Lingua'),
                        Translations.get(lang, 'Lingua dell interfaccia'),
                      ),
                      _tendina(
                        titolo: Translations.get(lang, 'Lingua'),
                        valore: _linguaSelezionata,
                        voci: _listaLingue,
                        onScelta: (v) => setState(() {
                          _linguaSelezionata = v;
                          _modificato = true;
                        }),
                      ),

                      const SizedBox(height: 26),
                      _titoloSezione(
                        Icons.public,
                        Translations.get(lang, 'Paese'),
                        Translations.get(lang, 'Decide quale database alimentare viene usato'),
                      ),
                      _tendina(
                        titolo: Translations.get(lang, 'Paese'),
                        valore: _paeseSelezionato,
                        voci: _listaPaesi,
                        onScelta: (v) => setState(() {
                          _paeseSelezionato = v;
                          _modificato = true;
                        }),
                      ),

                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                        decoration: BoxDecoration(
                          color: Nutri.surfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(Icons.storage, size: 19, color: Nutri.body),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Translations.get(lang, 'Database alimentare italiano'),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Nutri.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${Translations.get(lang, 'Prodotti, porzioni e valori di riferimento seguono le etichette italiane ed europee. Interfaccia in')} $_linguaSelezionata.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Nutri.muted,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        Translations.get(lang, 'Altri paesi in una versione futura.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft),
                      ),

                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.only(top: 14),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Nutri.disabledBg)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '© 2025/2026 I.I.S. Galileo Galilei',
                              style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'NutriApp v1.0.0',
                              style: TextStyle(fontSize: 12, color: Nutri.hint),
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
        if (_isSaving)
          VeloDiCaricamento(messaggio: Translations.get(lang, 'Salvataggio in corso...')),
      ],
    );
  }

  Widget _titoloSezione(IconData icona, String titolo, String sotto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icona, size: 21, color: Nutri.green),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  titolo,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Nutri.ink,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(sotto, style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft)),
        ],
      ),
    );
  }

  /// Dal 18/09 e' un foglio dal basso e non piu' un menu sovrapposto: il menu
  /// copriva il campo e mezza pagina (screenshot di Ismail).
  Widget _tendina({
    required String titolo,
    required String valore,
    required List<String> voci,
    required ValueChanged<String> onScelta,
  }) {
    return NutriSelect<String>(
      titolo: titolo,
      valore: valore,
      opzioni: [for (final v in voci) NutriOpzione(v, v)],
      onCambiato: onScelta,
    );
  }
}
