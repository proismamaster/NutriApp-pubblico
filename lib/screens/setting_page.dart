import 'package:flutter/material.dart';

import '../widgets/auth_style.dart';

import '../logic/unit_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutriapp/domain/user_provider.dart';
import 'login.dart';
import 'profile_page.dart';
import 'mie_segnalazioni_page.dart';
import 'send_us_problem_page.dart';
import 'setting_notification_page.dart';
import 'country_language_page.dart';
import 'unita_misura_page.dart';
import 'goal_page.dart';
import '../dictionary/translations.dart';
import '../providers/locale_provider.dart';
import 'markdown_viewer_page.dart';
import 'about_us_page.dart';
import 'pdf_viewer_page.dart';
import '../widgets/product_footer.dart';
import '../services/api_services.dart';

// Widget per le impostazioni dell'app
class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key});

  @override
  ConsumerState<SettingPage> createState() => SettingPageState();
}

// Stato della pagina delle impostazioni
class SettingPageState extends ConsumerState<SettingPage> {
  /// Vero mentre la richiesta del consenso e' in volo: l'interruttore si
  /// spegne per non poter partire una seconda richiesta prima che la prima
  /// abbia risposto (sarebbero due giri opposti sugli stessi alimenti).
  bool _salvataggioConsenso = false;

  /// Consenso a proporre i propri alimenti al database pubblico
  /// (2026-09-12, punto 2 della collaborazione).
  ///
  /// Non e' una preferenza locale: sta sul server, perche' decide cosa
  /// finisce in una coda che altri guarderanno. Per questo dopo la risposta si
  /// ricarica l'utente invece di fidarsi di cio' che abbiamo appena mandato:
  /// se il server e' indietro con la migrazione, l'interruttore deve tornare
  /// da solo dov'era, non restare acceso raccontando una cosa falsa.
  Future<void> _cambiaConsensoCondivisione(bool valore) async {
    final lang = ref.read(appSettingsProvider).language;
    final email = ref.read(userProvider)?.email;
    if (email == null || email.isEmpty) return;

    setState(() => _salvataggioConsenso = true);
    final esito = await ApiServices.setSharingPreference(
      userEmail: email,
      share: valore,
    );
    await ref.read(userProvider.notifier).refreshUser();
    if (!mounted) return;
    setState(() => _salvataggioConsenso = false);

    if (esito['status'] != 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('${Translations.get(lang, 'share_failed')} ${esito['message'] ?? ''}'.trim()),
        ),
      );
      return;
    }

    // Quanti alimenti sono stati proposti (o rientrati) e quanti restano
    // pubblici: e' cio' che l'interruttore ha fatto davvero, e l'utente non
    // deve andare a contarli da solo in un'altra schermata.
    final cambiati = esito['foods_changed'] ?? 0;
    final pubblici = esito['foods_public'] ?? 0;
    final righe = <String>[
      Translations.get(lang, valore ? 'share_on_done' : 'share_off_done'),
      '$cambiati ${Translations.get(lang, 'share_foods_changed')}',
      if ((pubblici is int ? pubblici : 0) > 0)
        '$pubblici ${Translations.get(lang, 'share_foods_public')}',
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(righe.join(' · '))),
    );
  }

  // Didascalia reale sotto "Notifiche" (mockup Settings): letta dalle stesse
  // shared_preferences che setting_notification_page.dart scrive. null
  // finche' non e' stata caricata, cosi' semplicemente non compare invece di
  // mostrare un placeholder sbagliato per un istante.
  ///
  /// Si tiene la CHIAVE, non la frase gia' tradotta: tradotta qui, cambiando
  /// lingua restava in italiano finche' non si riapriva la pagina (test di
  /// release 19/09).
  String? _notifCaptionKey;

  @override
  void initState() {
    super.initState();
    _loadNotifCaption();
  }

  Future<void> _loadNotifCaption() async {
    final prefs = await SharedPreferences.getInstance();
    final mealsOn = prefs.getBool('meal_reminder_enabled') ?? true;
    final waterOn = prefs.getBool('water_reminder_enabled') ?? true;
    if (!mounted) return;
    setState(() {
      _notifCaptionKey = !mealsOn && !waterOn
          ? 'notif_off'
          : mealsOn && waterOn
              ? 'Promemoria pasti e acqua attivi'
              : mealsOn
                  ? 'Promemoria pasti'
                  : 'Promemoria acqua';
    });
  }

  void _onItemTap(BuildContext context, String label) {
    switch (label) {
      // Account
      case 'Il mio profilo':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfilePage()),
        );
        break;

      case 'I miei obiettivi':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GoalsPage()),
        );
        break;

      case 'Notifiche':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationsPage()),
        );
        break;

      case 'Lingua e paese':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LinguaPaesePage()),
        );
        break;

      case 'Unità di misura':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UnitaMisuraPage()),
        );
        break;

      // Supporto e Informazioni
      case 'Aiuto':
        final currentLang = ref.read(appSettingsProvider).language;
        String pdfAsset = 'assets/docs/guida_di_utilizzo.pdf'; // Default Italiano

        if (currentLang == 'English') {
          pdfAsset = 'assets/docs/guida_di_utilizzo_ing.pdf';
        } else if (currentLang == '简体中文') {
          pdfAsset = 'assets/docs/guida_di_utilizzo_chi.pdf';
        } else if (currentLang == 'العربية') {
          pdfAsset = 'assets/docs/guida_di_utilizzo_arb.pdf';
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerPage(
              title: Translations.get(currentLang, 'Manuale d\'Uso'),
              assetPath: pdfAsset,
            ),
          ),
        );
        break;

      case 'Informativa sulla privacy':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MarkdownViewerPage(
              title: 'Informativa sulla privacy',
              assetPathPrefix: 'assets/docs/privacy',
            ),
          ),
        );
        break;

      case 'Su di noi':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AboutUsPage()),
        );
        break;

      // Azioni
      case 'Segnala un problema':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SegnalaProblemaPage()),
        );
        break;

      case 'Log out':
        showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              title: Row(
                children: [
                  Icon(Icons.logout, color: Nutri.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      Translations.get(
                        ref.read(appSettingsProvider).language,
                        'Conferma uscita',
                      ),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                Translations.get(
                  ref.read(appSettingsProvider).language,
                  'Sei sicuro di voler uscire e tornare alla schermata di login?',
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                OutlinedButton(
                  onPressed: () {
                    // CORREZIONE: Annulla chiude solo il dialog
                    Navigator.of(dialogContext).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Nutri.green,
                    side: BorderSide(color: Nutri.green),
                    minimumSize: const Size(100, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    Translations.get(
                      ref.read(appSettingsProvider).language,
                      'Annulla',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // CORREZIONE: Esci effettua il logout e poi naviga
                    ref.read(userProvider.notifier).logout();

                    Navigator.of(dialogContext).pop();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Nutri.green,
                    minimumSize: const Size(100, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    Translations.get(
                      ref.read(appSettingsProvider).language,
                      'Esci',
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
        break;

      // ---------------- Voci non ancora implementate ----------------
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pagina "$label" in lavorazione!')),
        );
    }
  }

  /// Interruttore del consenso + la riga che spiega cosa comporta.
  ///
  /// La didascalia cambia con lo stato: "proposti, non pubblicati" quando e'
  /// acceso, perche' e' la cosa che si fraintende piu' facilmente — accendere
  /// non pubblica niente, mette in coda.
  Widget _buildCondivisioneCard(String lang, ColorScheme scheme) {
    final condivide = ref.watch(userProvider)?.shareCustomFoods ?? false;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
        SwitchListTile(
          secondary: Icon(
            condivide ? Icons.groups : Icons.lock_outline,
            color: scheme.primary,
            size: 22,
          ),
          title: Text(
            Translations.get(lang, 'share_foods_title'),
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          subtitle: Text(
            Translations.get(lang, condivide ? 'share_foods_on' : 'share_foods_off'),
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.3),
          ),
          value: condivide,
          activeThumbColor: Colors.white,
          activeTrackColor: scheme.primary,
          onChanged: _salvataggioConsenso ? null : _cambiaConsensoCondivisione,
        ),
        // Qui e non in un'altra sezione (13/09): chi ha mandato una correzione
        // la cerca dove ha acceso la condivisione, ed e' il posto che la
        // conferma dopo l'invio indica per nome.
        Divider(height: 1, color: scheme.outlineVariant),
        ListTile(
          leading: Icon(Icons.flag_outlined, color: scheme.primary, size: 22),
          title: Text(
            Translations.get(lang, 'my_reports_title'),
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: scheme.onSurface),
          ),
          subtitle: Text(
            Translations.get(lang, 'my_reports_caption'),
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          trailing: Icon(Icons.chevron_right, size: 21, color: scheme.outline),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MieSegnalazioniPage()),
          ),
        ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 9),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// Card di righe stile mockup Settings: icona, etichetta + didascalia reale
  /// (non inventata — solo dati gia' disponibili, es. lingua/paese scelti),
  /// divisore fra le righe, chevron di navigazione, rosso per l'azione
  /// distruttiva (logout).
  Widget _buildSectionCard(BuildContext context, List<_SettingItemData> items) {
    final lang = ref.watch(appSettingsProvider).language;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final color = item.isDanger ? scheme.error : scheme.primary;
          return Container(
            decoration: BoxDecoration(
              border: index == 0
                  ? null
                  : Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onItemTap(context, item.label),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(
                    children: [
                      Icon(item.icon, color: color, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Translations.get(lang, item.label),
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w500,
                                color: item.isDanger ? scheme.error : scheme.onSurface,
                              ),
                            ),
                            if (item.caption != null && item.caption!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.caption!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 21, color: scheme.outline),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    final appSettings = ref.watch(appSettingsProvider);
    final isDark = appSettings.isDarkMode;
    final user = ref.watch(userProvider);
    final scheme = Theme.of(context).colorScheme;

    // Didascalie costruite da dati veri gia' disponibili — mai un valore
    // inventato solo per assomigliare al mockup (es. niente "Aggiornato" sulla
    // privacy: non esiste una data di revisione reale da mostrare).
    final fullName = [user?.firstName, user?.lastName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .join(' ');
    final profileCaption = [
      if (fullName.isNotEmpty) fullName,
      if ((user?.height ?? 0) > 0) '${user!.height!.toStringAsFixed(0)} cm',
    ].join(' · ');

    final goalsCaption = user == null
        ? null
        : '${UnitFormat.e(user.calorieGoal)}/${Translations.get(lang, 'giorno')}'
            '${user.targetWeight > 0 ? ' · ${Translations.get(lang, 'obiettivo')} ${user.targetWeight.toStringAsFixed(0)} kg' : ''}';

    final accountItems = <_SettingItemData>[
      _SettingItemData(
        icon: Icons.person_outline,
        label: 'Il mio profilo',
        caption: profileCaption.isEmpty ? null : profileCaption,
      ),
      _SettingItemData(
        icon: Icons.shield_outlined,
        label: 'I miei obiettivi',
        caption: goalsCaption,
      ),
      _SettingItemData(
        icon: Icons.notifications_none,
        label: 'Notifiche',
        caption: _notifCaptionKey == null ? null : Translations.get(lang, _notifCaptionKey!),
      ),
      _SettingItemData(
        icon: Icons.public,
        label: 'Lingua e paese',
        caption: '${appSettings.language} · ${appSettings.country}',
      ),
      // Una voce sua dal 14/09: in fondo a "Lingua e paese" nessuno le cercava.
      _SettingItemData(
        icon: Icons.straighten,
        label: 'Unità di misura',
        caption: '${appSettings.weightUnit == 'imperial' ? 'oz' : 'g'} · '
            '${appSettings.energyUnit == 'kj' ? 'kJ' : 'kcal'}',
      ),
    ];

    final supportItems = <_SettingItemData>[
      const _SettingItemData(icon: Icons.help_outline, label: 'Aiuto'),
      const _SettingItemData(
        icon: Icons.privacy_tip_outlined,
        label: 'Informativa sulla privacy',
      ),
      const _SettingItemData(icon: Icons.info_outline, label: 'Su di noi'),
    ];

    final actionItems = <_SettingItemData>[
      const _SettingItemData(
        icon: Icons.flag_outlined,
        label: 'Segnala un problema',
      ),
      const _SettingItemData(icon: Icons.logout, label: 'Log out', isDanger: true),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          Translations.get(ref.watch(appSettingsProvider).language, 'Settings'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Account ---
              _buildSectionTitle(
                Translations.get(lang, 'Account'),
              ),
              _buildSectionCard(context, accountItems),
              const SizedBox(height: 32),

              // --- Aspetto (sezione dedicata alla dark mode) ---
              _buildSectionTitle(
                Translations.get(lang, 'Aspetto'),
              ),
              SizedBox(
                width: double.infinity,
                child: Material(
                  // Il bordo/sfondo devono vivere sul Material, non su un
                  // Container/DecoratedBox intorno: altrimenti Flutter avvisa
                  // che gli ink splash dello SwitchListTile restano invisibili
                  // (dipinti sul Material piu' vicino, nascosti sotto la
                  // DecoratedBox) — trovato dal test di verifica visiva.
                  color: scheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    secondary: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode_outlined,
                      color: scheme.primary,
                      size: 22,
                    ),
                    title: Text(
                      Translations.get(lang, 'Modalità Scura'),
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      Translations.get(lang, isDark ? 'Attiva' : 'Disattivata'),
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                    value: isDark,
                    activeThumbColor: Colors.white,
                    activeTrackColor: scheme.primary,
                    onChanged: (value) {
                      ref.read(appSettingsProvider.notifier).saveDarkMode(value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // --- Comunita' (2026-09-12) ---
              _buildSectionTitle(Translations.get(lang, 'share_section_title')),
              _buildCondivisioneCard(lang, scheme),
              const SizedBox(height: 32),

              // --- Supporto ---
              _buildSectionTitle(
                Translations.get(lang, 'Support'),
              ),
              _buildSectionCard(context, supportItems),
              const SizedBox(height: 32),

              // --- Azioni ---
              _buildSectionTitle(
                Translations.get(lang, 'Azioni'),
              ),
              _buildSectionCard(context, actionItems),
              const ProductFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingItemData {
  final IconData icon;
  final String label;
  final String? caption;
  final bool isDanger;

  const _SettingItemData({
    required this.icon,
    required this.label,
    this.caption,
    this.isDanger = false,
  });
}
