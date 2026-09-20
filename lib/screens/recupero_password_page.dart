import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dictionary/translations.dart';
import '../providers/locale_provider.dart';
import '../services/api_services.dart';
import '../widgets/auth_style.dart';
import '../widgets/modern_loader.dart';

/// Risposta del server: sempre `status`, e un `code` fisso da tradurre.
typedef EsitoServer = Map<String, dynamic>;

/// Recupero della password in tre passi: email, codice, password nuova (14/09).
///
/// PRIMA era un dialogo con due caselle che a qualunque errore rispondeva
/// "Email non trovata o codice errato" — anche quando il problema era che
/// `reset_password.php` sul server non esisteva. Qui ogni risposta ha il suo
/// messaggio: codice sbagliato (con i tentativi rimasti), scaduto, troppi
/// tentativi, nessun account, mail non partita.
///
/// Il codice si controlla al passo 2 SENZA consumarlo (`check_only`) e si
/// ricontrolla al passo 3 insieme alla password: l'errore sul codice arriva
/// subito, e il server non si fida di un "ho gia' verificato" detto dall'app.
///
/// Nessun mockup di Claude Design copre questa schermata (il mockup Login ha
/// solo il link "Forgot password?"): usa i pezzi delle schermate di accesso e
/// registrazione — barra dei passi, campi, pulsante in fondo — cosi' sembra
/// parte dello stesso giro e non una pagina a se'.
class RecuperoPasswordPage extends ConsumerStatefulWidget {
  const RecuperoPasswordPage({
    super.key,
    this.emailIniziale = '',
    this.inviaCodice,
    this.controllaCodice,
    this.cambiaPassword,
  });

  /// L'email gia' scritta nella schermata di accesso, se c'era.
  final String emailIniziale;

  /// Le tre chiamate al server. Di default quelle vere; nei test funzioni
  /// finte, cosi' ogni risposta si prova senza rete e senza mandare mail.
  final Future<EsitoServer> Function(String email)? inviaCodice;
  final Future<EsitoServer> Function(String email, String codice)? controllaCodice;
  final Future<EsitoServer> Function(String email, String codice, String password)? cambiaPassword;

  @override
  ConsumerState<RecuperoPasswordPage> createState() => _RecuperoPasswordPageState();
}

class _RecuperoPasswordPageState extends ConsumerState<RecuperoPasswordPage> {
  /// Stessa soglia della registrazione, e di reset_password.php.
  static const int _minPassword = 8;

  /// Attesa prima di poter chiedere un altro codice: evita tre mail uguali
  /// per tre tocchi impazienti.
  static const int _secondiReinvio = 60;

  late final TextEditingController _email = TextEditingController(text: widget.emailIniziale);
  final _codice = TextEditingController();
  final _password = TextEditingController();
  final _conferma = TextEditingController();

  /// 1 email, 2 codice, 3 password nuova, 4 fatto.
  int _passo = 1;
  bool _invio = false;
  bool _tentato = false;
  bool _nascosta = true;
  String? _errore;
  String? _dettaglio;
  String? _avviso;
  int _attesa = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _codice.dispose();
    _password.dispose();
    _conferma.dispose();
    super.dispose();
  }

  bool get _emailOk => RegExp(r'^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$').hasMatch(_email.text.trim());

  /// Solo le cifre: chi incolla "123 456" dalla mail non deve vedersi
  /// rifiutare il codice per uno spazio.
  String get _cifre => _codice.text.replaceAll(RegExp(r'\D'), '');
  bool get _codiceOk => _cifre.length == 6;
  bool get _passwordOk => _password.text.length >= _minPassword && _password.text == _conferma.text;

  void _vaiA(int passo) => setState(() {
        _passo = passo;
        _errore = null;
        _dettaglio = null;
        _avviso = null;
        _tentato = false;
      });

  void _pulisci(String _) => setState(() {
        _tentato = false;
        _errore = null;
        _dettaglio = null;
        _avviso = null;
      });

  void _partiAttesa() {
    _timer?.cancel();
    setState(() => _attesa = _secondiReinvio);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _attesa--);
      if (_attesa <= 0) t.cancel();
    });
  }

  /// Il messaggio per ogni risposta negativa del server.
  String _messaggio(String lang, EsitoServer esito) {
    switch (esito['code']) {
      case 'wrong_code':
        return Translations.get(lang, 'recovery_wrong_code').replaceAll('{n}', '${esito['remaining'] ?? '?'}');
      case 'too_many':
        return Translations.get(lang, 'recovery_too_many');
      case 'expired':
        return Translations.get(lang, 'recovery_expired');
      case 'no_account':
        return Translations.get(lang, 'recovery_no_account');
      case 'network':
        return Translations.get(lang, 'recovery_network_error');
      default:
        return Translations.get(lang, 'recovery_generic_error');
    }
  }

  Future<EsitoServer> _chiama(Future<EsitoServer> Function() chiamata) async {
    setState(() {
      _invio = true;
      _errore = null;
      _dettaglio = null;
      _avviso = null;
    });
    final esito = await chiamata();
    if (mounted) setState(() => _invio = false);
    return esito;
  }

  Future<void> _mandaCodice(String lang, {bool reinvio = false}) async {
    final email = _email.text.trim();
    final esito = await _chiama(() => (widget.inviaCodice ?? ApiServices.sendOTPEsito)(email));
    if (!mounted) return;
    if (esito['status'] == 'success') {
      _partiAttesa();
      if (reinvio) {
        setState(() => _avviso = Translations.get(lang, 'recovery_code_resent'));
      } else {
        _codice.clear();
        _vaiA(2);
      }
      return;
    }
    setState(() {
      _errore = esito['code'] == 'network'
          ? Translations.get(lang, 'recovery_network_error')
          : Translations.get(lang, 'recovery_send_failed');
      // Il motivo del server resta visibile in piccolo: "chiave Brevo non
      // configurata" e' esattamente l'informazione che serve per sistemarlo.
      final motivo = esito['message']?.toString() ?? '';
      _dettaglio = motivo.isEmpty ? null : motivo;
    });
  }

  Future<void> _verificaCodice(String lang) async {
    final controlla = widget.controllaCodice ??
        ((String email, String codice) => ApiServices.resetPassword(email: email, otp: codice));
    final esito = await _chiama(() => controlla(_email.text.trim(), _cifre));
    if (!mounted) return;
    if (esito['status'] == 'success') {
      _vaiA(3);
      return;
    }
    setState(() => _errore = _messaggio(lang, esito));
  }

  Future<void> _salva(String lang) async {
    final cambia = widget.cambiaPassword ??
        ((String email, String codice, String password) =>
            ApiServices.resetPassword(email: email, otp: codice, newPassword: password));
    final esito = await _chiama(() => cambia(_email.text.trim(), _cifre, _password.text));
    if (!mounted) return;
    if (esito['status'] == 'success') {
      _timer?.cancel();
      _vaiA(4);
      return;
    }
    final messaggio = _messaggio(lang, esito);
    // Un codice scaduto nel frattempo, o bruciato dai tentativi, si risolve al
    // passo del codice: restare qui lascerebbe premere "Salva" all'infinito.
    if (const ['wrong_code', 'too_many', 'expired'].contains(esito['code'])) {
      _vaiA(2);
    }
    setState(() => _errore = messaggio);
  }

  /// Freccia e tasto indietro del telefono: un passo alla volta, non fuori
  /// dal recupero perdendo il codice appena arrivato.
  void _indietro() {
    if (_invio) return;
    if (_passo == 2 || _passo == 3) {
      _vaiA(_passo - 1);
      return;
    }
    Navigator.pop(context, _passo == 4 ? _email.text.trim() : null);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;

    return PopScope(
      canPop: _passo == 1 && !_invio,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _indietro();
      },
      child: Stack(
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
                onPressed: _indietro,
              ),
              title: Text(
                Translations.get(lang, 'Recupero Password'),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Nutri.green,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            body: SafeArea(
              child: _passo == 4
                  ? _fatto(lang)
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                            children: [
                              NutriStepBar(
                                labels: [
                                  Translations.get(lang, 'recovery_step_email'),
                                  Translations.get(lang, 'recovery_step_code'),
                                  Translations.get(lang, 'recovery_step_password'),
                                ],
                                current: _passo,
                              ),
                              const SizedBox(height: 24),
                              ..._contenuto(lang),
                            ],
                          ),
                        ),
                        _barraPulsante(lang),
                      ],
                    ),
            ),
          ),
          if (_invio) VeloDiCaricamento(messaggio: Translations.get(lang, 'Invio in corso...')),
        ],
      ),
    );
  }

  Widget _titolo(String testo) => Text(
        testo,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Nutri.ink, letterSpacing: -0.4),
      );

  Widget _spiegazione(String testo) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 22),
        child: Text(testo, style: TextStyle(fontSize: 14.5, height: 1.5, color: Nutri.body)),
      );

  /// Errore, motivo del server e conferme: sotto al campo a cui si riferiscono.
  List<Widget> _esiti() => [
        if (_errore != null) NutriInlineError(_errore!),
        if (_dettaglio != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4, start: 22),
            child: Text(_dettaglio!, style: TextStyle(fontSize: 11.5, height: 1.35, color: Nutri.mutedSoft)),
          ),
        if (_avviso != null)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: Nutri.green),
                const SizedBox(width: 6),
                Expanded(child: Text(_avviso!, style: TextStyle(fontSize: 12.5, color: Nutri.green))),
              ],
            ),
          ),
      ];

  List<Widget> _contenuto(String lang) {
    switch (_passo) {
      case 1:
        final invalida = _email.text.trim().length > 3 && !_emailOk;
        return [
          _titolo(Translations.get(lang, 'recovery_email_title')),
          _spiegazione(Translations.get(lang, 'recovery_email_body')),
          NutriFieldLabel(Translations.get(lang, 'Email')),
          NutriField(
            key: const Key('recupero_email'),
            controller: _email,
            icon: Icons.mail_outline,
            hint: 'you@example.com',
            keyboard: TextInputType.emailAddress,
            error: invalida,
            onChanged: _pulisci,
          ),
          if (invalida || (_tentato && !_emailOk))
            NutriInlineError(Translations.get(lang, 'Inserisci un indirizzo email valido')),
          ..._esiti(),
        ];

      case 2:
        return [
          _titolo(Translations.get(lang, 'recovery_code_title')),
          _spiegazione(Translations.get(lang, 'recovery_code_body').replaceAll('{email}', _email.text.trim())),
          NutriFieldLabel(Translations.get(lang, 'Codice di recupero')),
          NutriField(
            key: const Key('recupero_codice'),
            controller: _codice,
            icon: Icons.pin_outlined,
            hint: '123456',
            keyboard: TextInputType.number,
            error: _errore != null || (_tentato && !_codiceOk),
            onChanged: _pulisci,
          ),
          if (_tentato && !_codiceOk && _errore == null)
            NutriInlineError(Translations.get(lang, 'recovery_code_format')),
          ..._esiti(),
          const SizedBox(height: 18),
          Text(
            Translations.get(lang, 'recovery_code_spam'),
            style: TextStyle(fontSize: 13, height: 1.4, color: Nutri.mutedSoft),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_attesa > 0)
                Text(
                  Translations.get(lang, 'recovery_resend_wait').replaceAll('{s}', '$_attesa'),
                  style: TextStyle(fontSize: 14, color: Nutri.mutedSoft),
                )
              else
                NutriLinkTesto(
                  testo: Translations.get(lang, 'recovery_resend'),
                  fontSize: 14,
                  onTap: () => _mandaCodice(lang, reinvio: true),
                ),
              NutriLinkTesto(
                testo: Translations.get(lang, 'recovery_change_email'),
                fontSize: 14,
                onTap: () => _vaiA(1),
              ),
            ],
          ),
        ];

      default:
        final corta = _password.text.isNotEmpty && _password.text.length < _minPassword;
        final diversa = _conferma.text.isNotEmpty && _conferma.text != _password.text;
        final occhio = GestureDetector(
          onTap: () => setState(() => _nascosta = !_nascosta),
          child: Icon(
            _nascosta ? Icons.visibility : Icons.visibility_off,
            size: 21,
            color: Nutri.mutedSoft,
          ),
        );
        return [
          _titolo(Translations.get(lang, 'recovery_password_title')),
          _spiegazione(Translations.get(lang, 'recovery_password_body')),
          NutriFieldLabel(Translations.get(lang, 'Nuova Password')),
          NutriField(
            key: const Key('recupero_password'),
            controller: _password,
            icon: Icons.lock_outline,
            obscure: _nascosta,
            error: corta,
            trailing: occhio,
            onChanged: _pulisci,
          ),
          if (corta) NutriInlineError(Translations.get(lang, 'recovery_password_short')),
          const SizedBox(height: 16),
          NutriFieldLabel(Translations.get(lang, 'recovery_confirm_label')),
          NutriField(
            key: const Key('recupero_conferma'),
            controller: _conferma,
            icon: Icons.lock_outline,
            obscure: _nascosta,
            error: diversa,
            onChanged: _pulisci,
          ),
          if (diversa) NutriInlineError(Translations.get(lang, 'recovery_password_mismatch')),
          // Premuto con i campi vuoti: il motivo, altrimenti il pulsante
          // spento non spiegherebbe niente.
          if (_tentato && !_passwordOk && !corta && !diversa)
            NutriInlineError(
              _password.text.length < _minPassword
                  ? Translations.get(lang, 'recovery_password_short')
                  : Translations.get(lang, 'recovery_password_mismatch'),
            ),
          ..._esiti(),
        ];
    }
  }

  Widget _barraPulsante(String lang) {
    final (etichetta, pronto, azione) = switch (_passo) {
      1 => (Translations.get(lang, 'recovery_send_code'), _emailOk, () => _mandaCodice(lang)),
      2 => (Translations.get(lang, 'recovery_verify'), _codiceOk, () => _verificaCodice(lang)),
      _ => (Translations.get(lang, 'recovery_save'), _passwordOk, () => _salva(lang)),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        color: Nutri.bg,
        border: Border(top: BorderSide(color: Nutri.disabledBg)),
      ),
      child: NutriPrimaryButton(
        label: etichetta,
        enabled: pronto && !_invio,
        onTap: () {
          if (_invio) return;
          if (pronto) {
            azione();
          } else {
            setState(() => _tentato = true);
          }
        },
      ),
    );
  }

  Widget _fatto(String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: Nutri.greenSoft, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: 42, color: Nutri.green),
          ),
          const SizedBox(height: 18),
          Text(
            Translations.get(lang, 'recovery_done_title'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Nutri.ink),
          ),
          const SizedBox(height: 8),
          Text(
            Translations.get(lang, 'recovery_done_body'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, height: 1.5, color: Nutri.body),
          ),
          const Spacer(),
          NutriPrimaryButton(
            label: Translations.get(lang, 'recovery_back_to_login'),
            enabled: true,
            onTap: _indietro,
          ),
        ],
      ),
    );
  }
}
