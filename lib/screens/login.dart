import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutriapp/screens/signup.dart';
import 'complete_profile_social.dart';
import '../MainLayout.dart' show MainLayout;
import '../domain/user_provider.dart';
import '../dictionary/translations.dart';
import '../providers/locale_provider.dart';
import 'markdown_viewer_page.dart';
import '../widgets/modern_loader.dart';
import '../widgets/auth_style.dart';
import '../widgets/nutri_select.dart';
import 'recupero_password_page.dart';


// Schermata di accesso principale.
// Gestisce il login classico, social e il recupero password.
class LoginPage extends ConsumerStatefulWidget {
  final VoidCallback? onLogin;

  const LoginPage({super.key, this.onLogin});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState(); //
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _acceptPrivacy = false;
  bool _isLoggingIn = false;
  /// True dopo un tentativo di accesso col form incompleto: il mockup
  /// mostra il motivo sotto al pulsante solo da quel momento, non prima.
  bool _triedLogin = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitLogin() async {
    // Validazione dei campi
    if (_ready) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      setState(() => _isLoggingIn = true);

      // Chiamata al provider per l'autenticazione
      final result = await ref
          .read(userProvider.notifier)
          .login(email, password);

      // Verifichiamo che il widget sia ancora attivo dopo l'attesa
      if (!mounted) return;
      setState(() => _isLoggingIn = false);

      if (result.error == null) {
        // Tutto ok, entriamo nell'app
        _showMessage(Translations.get(ref.read(appSettingsProvider).language, 'Accesso effettuato con successo!'));
        
        // Vai alla Home e pulisci lo stack delle pagine
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainLayout()),
            (route) => false,
          );
        }
      } else {
        // Gestione errore dal server
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error!), backgroundColor: Colors.red),
        );
      }
    }
  }


  Future<void> _loginWithGoogle() async {
    if (!_acceptPrivacy) {
      _showMessage(Translations.get(ref.read(appSettingsProvider).language, 'Devi accettare la privacy per continuare'));
      return;
    }
    final result = await ref.read(userProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    
    if (result.error == null) {
      if (result.isNew) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const CompleteProfileSocialPage()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
          (route) => false,
        );
      }
    } else if (result.error != 'Accesso annullato') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loginWithApple() async {
    if (!_acceptPrivacy) {
      _showMessage(Translations.get(ref.read(appSettingsProvider).language, 'Devi accettare la privacy per continuare'));
      return;
    }
    final result = await ref.read(userProvider.notifier).signInWithApple();
    if (!mounted) return;
    
    if (result.error == null) {
      if (result.isNew) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const CompleteProfileSocialPage()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!), backgroundColor: Colors.red),
      );
    }
  }

  /// Recupero password (2026-09-14): una schermata a tre passi al posto del
  /// dialogo di prima, che a qualunque errore rispondeva "Email non trovata o
  /// codice errato". Torna con l'email usata, che qui finisce gia' scritta.
  Future<void> _apriRecupero() async {
    final email = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RecuperoPasswordPage(emailIniziale: _emailController.text.trim()),
      ),
    );
    if (!mounted || email == null || email.isEmpty) return;
    setState(() {
      _emailController.text = email;
      _passwordController.clear();
    });
  }

  // ---------------------------------------------------------------------
  // Palette del mockup Claude Design "NutriApp Login" (2026-08-29).
  // Tenuta qui come costanti invece che nel ColorScheme perche' queste
  // schermate di autenticazione vivono fuori dal tema dell'app (nessuna
  // AppBar, sfondo fisso chiaro) e i valori arrivano dal mockup uno a uno.

  /// Le stesse regole del mockup: email formalmente valida, password di
  /// almeno 6 caratteri, privacy accettata. Il pulsante resta spento finche'
  /// non valgono tutte e tre, invece di lasciar premere e poi mostrare un
  /// errore.
  bool get _emailOk => RegExp(r'^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$')
      .hasMatch(_emailController.text.trim());
  bool get _emailInvalid =>
      _emailController.text.trim().length > 3 && !_emailOk;
  bool get _ready =>
      _emailOk && _passwordController.text.length >= 6 && _acceptPrivacy;

  String _missingReason(String lang) {
    if (!_emailOk) return Translations.get(lang, 'Inserisci un indirizzo email valido');
    if (_passwordController.text.length < 6) {
      return Translations.get(lang, 'La password deve contenere almeno 6 caratteri');
    }
    return Translations.get(lang, 'Devi accettare la privacy per continuare');
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          text,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Nutri.label),
        ),
      );

  /// Campo del mockup: riquadro bianco alto 54, angoli 14, bordo 1.5 che
  /// diventa rosso quando il valore non e' valido.
  Widget _field({
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    bool error = false,
    bool obscure = false,
    TextInputType? keyboard,
    Widget? trailing,
  }) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Nutri.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: error ? Nutri.fieldBorderError : Nutri.fieldBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Nutri.mutedSoft),
          const SizedBox(width: 11),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboard,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 16, color: Nutri.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFFA9B1A6), fontSize: 16),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _inlineError(String message) => Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: Nutri.danger),
            const SizedBox(width: 6),
            Expanded(
              child: Text(message, style: TextStyle(fontSize: 12.5, color: Nutri.danger)),
            ),
          ],
        ),
      );

  /// Logo vero dell'app (2026-09-01, richiesta di Ismail).
  ///
  /// Prima era un marchio disegnato a mano che imitava il mockup. Ma il logo
  /// vero esiste gia' — e' l'icona con cui l'app compare nel telefono
  /// (`android/.../launcher_icon.png`, copiata in assets/img/logo.png): usarne
  /// una versione somigliante nella schermata di accesso significava mostrare
  /// due marchi diversi per la stessa app.
  /// Logo alto quanto il blocco titolo + sottotitolo che gli sta accanto
  /// (2026-09-05): a 48 px si perdeva accanto a una scritta da 29 px con la
  /// sua riga sotto, e sembrava un segnaposto invece del marchio.
  Widget _logo() => Image.asset(
        'assets/img/logo.png',
        width: 64,
        height: 64,
        filterQuality: FilterQuality.high,
      );

  Widget _socialButton({required String label, required Widget mark, required VoidCallback onPressed}) {
    return Material(
      color: Nutri.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Nutri.socialBorder, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 22, height: 22, child: Center(child: mark)),
              const SizedBox(width: 11),
              Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Nutri.ink)),
            ],
          ),
        ),
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
          body: SafeArea(
            child: Column(
              children: [
                // Selettore lingua: nel mockup e' una pillola bianca in alto a
                // destra, non piu' un DropdownButton nell'AppBar.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Chiaro/scuro anche qui (2026-09-05): sulla schermata di
                      // accesso il pulsante mancava del tutto, e prima di aver
                      // fatto l'accesso non esiste nessun altro posto da cui
                      // cambiarlo — restava l'unica pagina in cui il tema non
                      // si poteva toccare.
                      GestureDetector(
                        onTap: () => ref
                            .read(appSettingsProvider.notifier)
                            .saveDarkMode(!ref.read(appSettingsProvider).isDarkMode),
                        child: Container(
                          height: 34,
                          width: 34,
                          alignment: Alignment.center,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Nutri.card,
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(color: Nutri.socialBorder),
                          ),
                          child: Icon(
                            ref.watch(appSettingsProvider).isDarkMode
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            size: 17,
                            color: Nutri.green,
                          ),
                        ),
                      ),
                      // Stesso foglio dal basso degli altri select (18/09).
                      GestureDetector(
                        onTap: () async {
                          final scelta = await mostraSceltaNutri<String>(
                            context,
                            titolo: Translations.get(lang, 'Lingua'),
                            selezionato: lang,
                            opzioni: const [
                              NutriOpzione('English', 'English'),
                              NutriOpzione('Italiano', 'Italiano'),
                              NutriOpzione('简体中文', '简体中文'),
                              NutriOpzione('العربية', 'العربية'),
                            ],
                          );
                          if (scelta == null) return;
                          await ref
                              .read(appSettingsProvider.notifier)
                              .saveSettings(scelta, ref.read(appSettingsProvider).country);
                        },
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Nutri.card,
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(color: Nutri.socialBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.language, size: 17, color: Nutri.green),
                              const SizedBox(width: 6),
                              Text(
                                lang,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Nutri.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: ConstrainedBox(
                      // Il mockup spinge "Non hai un account?" in fondo allo
                      // schermo quando c'e' spazio, ma la pagina resta
                      // scrollabile sui telefoni bassi e con la tastiera
                      // aperta: IntrinsicHeight + minHeight fa entrambe le
                      // cose senza overflow.
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height -
                            MediaQuery.of(context).padding.vertical - 100,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 26),
                            Row(
                              children: [
                                _logo(),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'NutriApp',
                                      style: TextStyle(
                                        fontSize: 29,
                                        fontWeight: FontWeight.bold,
                                        color: Nutri.greenDark,
                                        letterSpacing: -1,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      Translations.get(lang, 'login_tagline'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Nutri.muted,
                                        letterSpacing: 1.76,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              Translations.get(lang, 'login_subtitle'),
                              style: const TextStyle(fontSize: 14.5, color: Color(0xFF5A6157), height: 1.5),
                            ),
                            const SizedBox(height: 24),

                            _fieldLabel(Translations.get(lang, 'Email')),
                            _field(
                              icon: Icons.mail_outline,
                              controller: _emailController,
                              hint: 'you@example.com',
                              error: _emailInvalid,
                              keyboard: TextInputType.emailAddress,
                            ),
                            if (_emailInvalid)
                              _inlineError(Translations.get(lang, 'Inserisci un indirizzo email valido')),

                            const SizedBox(height: 16),
                            _fieldLabel(Translations.get(lang, 'Password')),
                            _field(
                              icon: Icons.lock_outline,
                              controller: _passwordController,
                              hint: Translations.get(lang, 'Password'),
                              obscure: _obscurePassword,
                              trailing: GestureDetector(
                                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                child: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  size: 21,
                                  color: Nutri.mutedSoft,
                                ),
                              ),
                            ),

                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: GestureDetector(
                                  onTap: _apriRecupero,
                                  child: Text(
                                    Translations.get(lang, 'Password dimenticata?'),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: Nutri.green,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            NutriPrivacyCheck(
                              value: _acceptPrivacy,
                              onChanged: (v) => setState(() => _acceptPrivacy = v),
                              testoPrima: Translations.get(lang, 'Accetto la '),
                              testoLink: Translations.get(lang, 'privacy policy'),
                              onApriInformativa: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const MarkdownViewerPage(
                                    title: 'Informativa sulla privacy',
                                    assetPathPrefix: 'assets/docs/privacy',
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),
                            GestureDetector(
                              onTap: () {
                                if (_ready) {
                                  _submitLogin();
                                } else {
                                  setState(() => _triedLogin = true);
                                }
                              },
                              child: Container(
                                height: 54,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _ready ? Nutri.greenFill : Nutri.disabledBg,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  Translations.get(lang, 'Accedi'),
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.bold,
                                    color: _ready ? Nutri.onGreenFill : Nutri.mutedSoft,
                                  ),
                                ),
                              ),
                            ),
                            if (!_ready && _triedLogin)
                              Padding(
                                padding: const EdgeInsets.only(top: 9),
                                child: Text(
                                  _missingReason(lang),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12.5, color: Nutri.mutedSoft),
                                ),
                              ),

                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Expanded(child: Divider(color: Nutri.hairline, height: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    Translations.get(lang, 'login_or_continue'),
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF9AA398)),
                                  ),
                                ),
                                Expanded(child: Divider(color: Nutri.hairline, height: 1)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _socialButton(
                              label: Translations.get(lang, 'Continua con Google'),
                              // Marchio Google ufficiale, scaricato dal CDN di Google
                              // (gstatic googleg_48dp) e incluso come asset:
                              // le linee guida del marchio richiedono il file
                              // originale, non una ricostruzione somigliante.
                              mark: Image.asset('assets/img/google_g.png', width: 20, height: 20),
                              onPressed: _loginWithGoogle,
                            ),
                            const SizedBox(height: 10),
                            _socialButton(
                              label: Translations.get(lang, 'Continua con Apple'),
                              // Glifo Apple vero: e' dentro Material Icons, non
                              // serve un asset.
                              // Nero su chiaro, bianco su scuro: sono le uniche
                              // due varianti che le linee guida Apple
                              // ammettono, e a 26 px il glifo pesa quanto la G
                              // di Google a 20 (ha molto piu' spazio vuoto
                              // dentro, a parita' di riquadro sembra meta').
                              mark: Icon(
                                Icons.apple,
                                size: 26,
                                color: Nutri.scuro ? Colors.white : Colors.black,
                              ),
                              onPressed: _loginWithApple,
                            ),

                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    Translations.get(lang, 'login_no_account'),
                                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF5A6157)),
                                  ),
                                  const SizedBox(width: 5),
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const SignUpPage()),
                                    ),
                                    child: Text(
                                      Translations.get(lang, 'login_signup_link'),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Nutri.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isLoggingIn)
          VeloDiCaricamento(messaggio: Translations.get(lang, 'Accesso in corso...')),
      ],
    );
  }
}
