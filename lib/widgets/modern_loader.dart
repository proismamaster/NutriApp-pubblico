import 'package:flutter/material.dart';

import 'auth_style.dart';

/// Indicatore di caricamento condiviso da tutte le schermate.
///
/// DUE BUG VERI CORRETTI IL 2026-09-05, entrambi visibili nello screenshot
/// della schermata di accesso mandato da Ismail:
///
///  1. Il disco interno era `Colors.white` fisso mentre l'icona prendeva
///     `color`. Passando `color: Colors.white` — cosa che facevano quasi tutte
///     le chiamate, per leggere bene sopra il velo scuro — l'icona diventava
///     bianca su bianco, cioe' invisibile: restava un cerchio vuoto.
///  2. Il messaggio compariva con il testo giallo e sottolineato. Non era una
///     scelta di stile: e' come Flutter disegna un `Text` che non ha nessun
///     `Material` sopra di se', e questo widget veniva quasi sempre messo in
///     uno `Stack` accanto allo `Scaffold`, non dentro. Ora se lo porta
///     dietro da solo, cosi' non dipende piu' da dove viene usato.
class ModernLoader extends StatefulWidget {
  final String? message;

  /// Tinta di icona e testo. Il disco dietro si adatta da solo per restare
  /// leggibile: chiaro sotto un'icona scura, scuro sotto una chiara.
  ///
  /// Se non viene passata si usa il verde del tema, che in modalita' scura e'
  /// chiaro. TERZO BUG (2026-09-07): il valore predefinito era un verde scuro
  /// FISSO (#1E7A4E). Sopra un velo nero, dove i chiamanti passano apposta un
  /// colore chiaro, funzionava; ma nelle schermate che lo usano a tutta pagina
  /// senza velo — Home, calendario, avvio — quel verde finiva su fondo #11150F
  /// e la scritta "Caricamento..." spariva: restava il cerchio che gira senza
  /// nessun testo, ed e' cio' che si vede nello screenshot della Home.
  final Color? color;

  const ModernLoader({super.key, this.message, this.color});

  @override
  State<ModernLoader> createState() => _ModernLoaderState();
}

class _ModernLoaderState extends State<ModernLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tinta = widget.color ?? Nutri.green;
    // Material trasparente: da' al messaggio un contesto di testo valido
    // ovunque questo widget venga usato, anche fuori da uno Scaffold.
    return Material(
      type: MaterialType.transparency,
      child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: _controller,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        tinta.withValues(alpha: 0.1),
                        tinta,
                      ],
                      stops: const [0.7, 1.0],
                    ),
                  ),
                ),
              ),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  // Il disco deve contrastare con l'icona, non essere sempre
                  // bianco: e' cio' che rendeva invisibile l'icona bianca.
                  color: ThemeData.estimateBrightnessForColor(tinta) == Brightness.light
                      ? const Color(0xFF14522A)
                      : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: ScaleTransition(
                    scale: Tween(begin: 0.8, end: 1.2).animate(_animation),
                    child: Icon(Icons.restaurant_rounded, color: tinta, size: 30),
                  ),
                ),
              ),
            ],
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 24),
            Text(
              widget.message!,
              style: TextStyle(
                color: tinta,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ],
          ],
        ),
      ),
    );
  }
}

/// Velo scuro a tutto schermo con sopra il [ModernLoader], per le attese che
/// bloccano la schermata (salvataggio, accesso, registrazione).
///
/// PERCHE' UN WIDGET E NON DIECI COPIE (2026-09-08): erano dieci punti che
/// scrivevano a mano lo stesso `Container(color: nero al 30%)` con dentro un
/// loader, e ognuno sceglieva la tinta per conto suo. Cinque passavano
/// `Nutri.card` pensando "bianco" — vero in chiaro, ma in modalita' scura
/// `Nutri.card` e' quasi nero, quindi la scritta finiva scura su un velo
/// scuro e spariva. E' la segnalazione di Ismail sulla schermata di
/// salvataggio ricetta.
///
/// Il velo e' nero in tutti e due i temi, quindi cio' che ci sta sopra deve
/// essere chiaro in tutti e due: qui la tinta e' fissata e non e' piu' una
/// decisione da prendere ad ogni chiamata.
class VeloDiCaricamento extends StatelessWidget {
  const VeloDiCaricamento({super.key, required this.messaggio});

  final String messaggio;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: ModernLoader(message: messaggio, color: Colors.white),
    );
  }
}
