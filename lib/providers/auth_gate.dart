import 'package:flutter/material.dart';

import '../widgets/auth_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user_provider.dart';
import '../screens/login.dart';
import '../MainLayout.dart';
import '../screens/complete_profile_social.dart';
import '../widgets/modern_loader.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    // Controlliamo se ci sono credenziali salvate localmente
    await ref.read(userProvider.notifier).checkSavedLogin();
    if (mounted) {
      setState(() {
        _isChecking = false; // Caricamento terminato
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);

    // Mostriamo il loader durante il controllo iniziale
    if (_isChecking) {
      // Fondo dal tema (2026-09-09): era un verde chiarissimo FISSO, quindi
      // ad app scura ogni avvio partiva con un lampo bianco prima che
      // comparisse la prima schermata vera.
      return Scaffold(
        backgroundColor: Nutri.bg,
        body: const ModernLoader(),
      );
    }

    // Reindirizzamento in base allo stato dell'utente
    if (user == null) {
      return const LoginPage();
    } else {
      // Se mancano dati essenziali (es. genere), forziamo il completamento del profilo
      if (user.gender == null || user.gender!.isEmpty) {
        return const CompleteProfileSocialPage();
      }
      
      return const MainLayout();
    }
  }
}
