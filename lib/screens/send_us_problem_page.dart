import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dictionary/translations.dart';
import '../domain/user_provider.dart';
import '../providers/locale_provider.dart';
import '../services/api_services.dart';
import '../widgets/auth_style.dart';
import '../widgets/modern_loader.dart';

/// Segnalazione di un problema, ridisegnata sul mockup "Report Problem"
/// (2026-09-05).
///
/// Prima era una casella di testo libero e basta. Il mockup chiede di sapere
/// CHE TIPO di problema è e su QUALE schermata succede: senza, ogni
/// segnalazione arriva come un paragrafo da leggere e interpretare a mano,
/// impossibile da raggruppare o filtrare. I campi nuovi arrivano con la
/// migrazione `2026-09-05_segnalazioni_e_unita.sql`.
class SegnalaProblemaPage extends ConsumerStatefulWidget {
  const SegnalaProblemaPage({super.key});

  @override
  ConsumerState<SegnalaProblemaPage> createState() => _SegnalaProblemaPageState();
}

/// Un tipo di problema fra quelli proposti.
typedef _Tipo = ({String key, String label, String caption, IconData icon});

class _SegnalaProblemaPageState extends ConsumerState<SegnalaProblemaPage> {
  /// Lunghezza minima della descrizione.
  ///
  /// Non è un capriccio: "non funziona" non è azionabile, e una segnalazione
  /// che non si può usare fa perdere tempo a chi la scrive e a chi la legge.
  static const int _minDescrizione = 20;

  static const List<_Tipo> _tipi = [
    (
      key: 'bug',
      label: 'Qualcosa non funziona',
      caption: 'Un pulsante, una schermata o un calcolo sbagliato',
      icon: Icons.bug_report_outlined,
    ),
    (
      key: 'data',
      label: 'Dati nutrizionali sbagliati',
      caption: 'Un prodotto ha valori errati',
      icon: Icons.fact_check_outlined,
    ),
    (
      key: 'sync',
      label: 'I dati non si aggiornano',
      caption: 'Mancano pasti o obiettivi',
      icon: Icons.sync_problem_outlined,
    ),
    (
      key: 'idea',
      label: 'Suggerimento',
      caption: 'Qualcosa che renderebbe migliore l applicazione',
      icon: Icons.lightbulb_outline,
    ),
    (
      key: 'other',
      label: 'Altro',
      caption: 'Nessuno dei precedenti',
      icon: Icons.help_outline,
    ),
  ];

  static const List<String> _schermate = [
    'Home', 'Calendario', 'Dettaglio pasto', 'Aggiungi alimento',
    'Inserimento manuale', 'Ricette', 'Grafici', 'Impostazioni', 'Profilo',
  ];

  final _descrizioneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String _tipo = '';
  String _schermata = '';
  bool _diagnostica = true;
  bool _tentato = false;
  bool _inviato = false;
  bool _invioInCorso = false;

  @override
  void dispose() {
    _descrizioneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  int get _lunghezza => _descrizioneCtrl.text.trim().length;

  bool get _emailOk {
    final t = _emailCtrl.text.trim();
    if (t.isEmpty) return true; // il contatto è facoltativo
    return RegExp(r'^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$').hasMatch(t);
  }

  bool get _completa => _tipo.isNotEmpty && _lunghezza >= _minDescrizione && _emailOk;

  /// Informazioni tecniche allegate, solo su consenso.
  ///
  /// Ricavate da `dart:io` invece che da un pacchetto dedicato: bastano a
  /// capire su cosa gira il problema e non aggiungono una dipendenza al
  /// progetto per un campo facoltativo. Non contengono niente che identifichi
  /// la persona oltre a ciò che l'account già dice.
  String get _diagnostiche {
    if (!_diagnostica) return '';
    final piattaforma = kIsWeb
        ? 'Web'
        : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    return 'NutriApp 1.0.0 · $piattaforma';
  }

  String _motivo(String lang) {
    if (_tipo.isEmpty) return Translations.get(lang, 'Scegli che tipo di problema è.');
    if (_lunghezza < _minDescrizione) {
      final mancano = _minDescrizione - _lunghezza;
      return '${Translations.get(lang, 'Servono ancora')} $mancano ${Translations.get(lang, 'caratteri nella descrizione.')}';
    }
    return Translations.get(lang, 'Inserisci un indirizzo email valido, oppure lascialo vuoto.');
  }

  Future<void> _invia(String lang) async {
    if (!_completa) {
      setState(() => _tentato = true);
      return;
    }
    setState(() => _invioInCorso = true);
    final esito = await ApiServices.saveReport(
      userEmail: ref.read(userProvider)?.email ?? '',
      problemDescription: _descrizioneCtrl.text.trim(),
      kind: _tipo,
      screen: _schermata,
      contactEmail: _emailCtrl.text.trim(),
      diagnostics: _diagnostiche,
    );
    if (!mounted) return;
    setState(() => _invioInCorso = false);

    if (esito['status'] == 'success') {
      setState(() => _inviato = true);
      return;
    }
    // Il messaggio del server dice cose vere e utili (per esempio "hai già
    // inviato una segnalazione oggi"): mostrarlo com'è vale più di un
    // generico "errore". Quando pero' il server manda anche un codice, vince
    // la traduzione: il messaggio del server e' solo in italiano (21/09).
    final codice = esito['code']?.toString();
    final tradotto = codice == null ? null : Translations.get(lang, codice);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tradotto != codice && tradotto != null
            ? tradotto
            : esito['message']?.toString() ?? Translations.get(lang, 'Errore durante invio')),
        backgroundColor: const Color(0xFFB4553C),
        duration: const Duration(seconds: 5),
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
              Translations.get(lang, 'Segnala un problema'),
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      Text(
                        Translations.get(lang, 'Che tipo di problema è?'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Nutri.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final t in _tipi) _cardTipo(lang, t),

                      const SizedBox(height: 24),
                      Text(
                        Translations.get(lang, 'Su quale schermata?'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Nutri.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Translations.get(lang, 'Facoltativo, ma aiuta a trovarlo prima.'),
                        style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft),
                      ),
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final s in _schermate)
                            NutriChip(
                              label: Translations.get(lang, s),
                              selected: _schermata == s,
                              onTap: () => setState(() {
                                _schermata = _schermata == s ? '' : s;
                                _tentato = false;
                                _inviato = false;
                              }),
                            ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      NutriFieldLabel(Translations.get(lang, 'Cosa è successo')),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Nutri.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: (_lunghezza > 0 && _lunghezza < _minDescrizione)
                                ? Nutri.fieldBorderError
                                : Nutri.fieldBorder,
                            width: 1.5,
                          ),
                        ),
                        child: TextField(
                          controller: _descrizioneCtrl,
                          minLines: 4,
                          maxLines: 8,
                          onChanged: (_) => setState(() {
                            _tentato = false;
                            _inviato = false;
                          }),
                          style: TextStyle(fontSize: 15, height: 1.5, color: Nutri.ink),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: Translations.get(lang, 'Cosa stavi facendo, cosa ti aspettavi e cosa è successo invece.'),
                            hintStyle: TextStyle(color: Nutri.hint, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _lunghezza == 0
                              ? '${Translations.get(lang, 'Almeno')} $_minDescrizione ${Translations.get(lang, 'caratteri')}'
                              : _lunghezza < _minDescrizione
                                  ? '${_minDescrizione - _lunghezza} ${Translations.get(lang, 'in piu')}'
                                  : '$_lunghezza ${Translations.get(lang, 'caratteri')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: (_lunghezza > 0 && _lunghezza < _minDescrizione)
                                ? Nutri.danger
                                : Nutri.mutedSoft,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),
                      NutriFieldLabel(
                        Translations.get(lang, 'Email di contatto'),
                        trailing: Translations.get(lang, '(facoltativo)'),
                      ),
                      NutriField(
                        controller: _emailCtrl,
                        icon: Icons.mail_outline,
                        hint: 'nome@email.it',
                        keyboard: TextInputType.emailAddress,
                        error: !_emailOk,
                        onChanged: (_) => setState(() {
                          _tentato = false;
                          _inviato = false;
                        }),
                      ),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Translations.get(lang, 'Allega informazioni tecniche'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Nutri.ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _diagnostica
                                      ? _diagnostiche
                                      : Translations.get(lang, 'Non verra inviato niente sul tuo dispositivo'),
                                  style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Switch(
                            value: _diagnostica,
                            activeThumbColor: Nutri.green,
                            onChanged: (v) => setState(() => _diagnostica = v),
                          ),
                        ],
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NutriPrimaryButton(
                        label: _inviato
                            ? Translations.get(lang, 'Segnalazione inviata')
                            : _completa
                                ? Translations.get(lang, 'Invia segnalazione')
                                : Translations.get(lang, 'Completa la segnalazione'),
                        icon: _inviato
                            ? Icons.check_circle
                            : _completa
                                ? Icons.send
                                : Icons.info_outline,
                        iconFirst: true,
                        height: 52,
                        enabled: _completa && !_inviato,
                        doneStyle: _inviato,
                        onTap: () {
                          if (!_inviato) _invia(lang);
                        },
                      ),
                      if (!_completa && _tentato)
                        Padding(
                          padding: const EdgeInsets.only(top: 9),
                          child: Text(
                            _motivo(lang),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_invioInCorso)
          VeloDiCaricamento(messaggio: Translations.get(lang, 'Invio in corso...')),
      ],
    );
  }

  Widget _cardTipo(String lang, _Tipo t) {
    final scelto = _tipo == t.key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          _tipo = scelto ? '' : t.key;
          _tentato = false;
          _inviato = false;
        }),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Nutri.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scelto ? Nutri.green : Nutri.fieldBorder,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(t.icon, size: 22, color: scelto ? Nutri.green : Nutri.mutedSoft),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Translations.get(lang, t.label),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: Nutri.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      Translations.get(lang, t.caption),
                      style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft, height: 1.35),
                    ),
                  ],
                ),
              ),
              if (scelto) Icon(Icons.check_circle, size: 20, color: Nutri.green),
            ],
          ),
        ),
      ),
    );
  }
}
