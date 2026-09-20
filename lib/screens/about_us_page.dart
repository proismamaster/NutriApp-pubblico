import 'package:flutter/material.dart';

import '../widgets/auth_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dictionary/translations.dart';
import '../providers/locale_provider.dart';
import '../widgets/product_footer.dart';


class AboutUsPage extends ConsumerWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).language;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          Translations.get(lang, 'Su di noi'),
          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intestazione
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green.shade200, width: 2),
                    ),
                    // Logo vero dell'app (2026-09-05): qui c'era un'icona
                    // generica a forma di foglia, che non e' il marchio di
                    // NutriApp — l'app ne mostrava uno diverso da quello con
                    // cui compare nel telefono.
                    // Riempie tutto il cerchio invece di galleggiarci dentro
                    // a 44 px: il logo ha gia' il suo margine disegnato.
                    child: ClipOval(
                      child: Image.asset(
                        'assets/img/logo.png',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'NutriApp',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ITIS Galileo Galilei · Crema · 2025/2026',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Descrizione del progetto
            _buildSection(
              context: context,
              title: Translations.get(lang, 'about_title'),
              icon: Icons.info_outline_rounded,
              child: Text(
                Translations.get(lang, 'about_desc'),
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Il nostro team
            _buildSection(
              context: context,
              title: Translations.get(lang, 'about_team_title'),
              icon: Icons.groups_rounded,
              child: Column(
                children: [
                  Text(
                    Translations.get(lang, 'about_team_desc'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMemberCard(
                    context: context,
                    name: 'Ismail Barakat',
                    role: Translations.get(lang, 'about_ismail_role'),
                    desc: Translations.get(lang, 'about_ismail_desc'),
                    email: 'info@nutriapp.com',
                    color: const Color(0xFF2E7D32),
                    initials: 'IB',
                  ),
                  const SizedBox(height: 12),
                  _buildMemberCard(
                    context: context,
                    name: 'Serena Yu',
                    role: Translations.get(lang, 'about_serena_role'),
                    desc: Translations.get(lang, 'about_serena_desc'),
                    email: 'info@nutriapp.com',
                    color: const Color(0xFF1565C0),
                    initials: 'SY',
                  ),
                  const SizedBox(height: 12),
                  _buildMemberCard(
                    context: context,
                    name: 'Emanuel Maltese',
                    role: Translations.get(lang, 'about_emanuel_role'),
                    desc: Translations.get(lang, 'about_emanuel_desc'),
                    email: 'info@nutriapp.com',
                    color: const Color(0xFF6A1B9A),
                    initials: 'EM',
                  ),
                  const SizedBox(height: 12),
                  _buildMemberCard(
                    context: context,
                    name: 'Christian Donzelli',
                    role: Translations.get(lang, 'about_christian_role'),
                    desc: Translations.get(lang, 'about_christian_desc'),
                    email: 'info@nutriapp.com',
                    color: const Color(0xFFE65100),
                    initials: 'CD',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Sezione contatti
            _buildSection(
              context: context,
              title: Translations.get(lang, 'about_contact_title'),
              icon: Icons.mail_outline_rounded,
              child: Text(
                Translations.get(lang, 'about_contact_desc'),
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),

            const SizedBox(height: 32),

            const ProductFooter(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required BuildContext context, required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.green, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMemberCard({
    required BuildContext context,
    required String name,
    required String role,
    required String desc,
    required String email,
    required Color color,
    required String initials,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withAlpha(220),
            radius: 22,
            child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(role, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.mail_outline, size: 13, color: Nutri.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
