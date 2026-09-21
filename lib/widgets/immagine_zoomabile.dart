import 'package:flutter/material.dart';

/// Visualizzazione ingrandita delle immagini, uguale in tutta NutriApp
/// (richiesta di Ismail, 21/09).
///
/// PERCHE' UN SOLO POSTO: le immagini compaiono in sei punti diversi —
/// elenco ricette, dettaglio ricetta, ricette della comunita', risultati di
/// ricerca, scheda del prodotto, ingredienti — e prima nessuna si poteva
/// aprire. Scriverne una versione per schermata avrebbe dato sei
/// comportamenti che divergono al primo ritocco, come era gia' successo con
/// le due pagine della ricetta (vedi detail_of_ricetta.dart).
///
/// COSA FA: tocco sull'immagine, si apre a tutto schermo; pizzico o doppio
/// tocco per ingrandire, trascinamento per spostarsi quando e' ingrandita,
/// "indietro" o la X per tornare. Niente di piu': e' un visualizzatore, non
/// un editor.

/// Apre [immagine] a tutto schermo, con zoom e spostamento.
///
/// [titolo] compare in alto (il nome della ricetta o del prodotto) e serve a
/// non perdere il filo quando si aprono piu' foto di seguito.
Future<void> apriImmagineIngrandita(
  BuildContext context, {
  required ImageProvider immagine,
  String? titolo,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      // Sfondo trasparente + dissolvenza: l'immagine sembra ingrandirsi da
      // dove stava, invece di arrivare da destra come una schermata nuova.
      opaque: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => _SchermoIntero(immagine: immagine, titolo: titolo),
      transitionsBuilder: (_, animazione, _, figlio) =>
          FadeTransition(opacity: animazione, child: figlio),
    ),
  );
}

/// Rende toccabile [child] per aprire [immagine] ingrandita.
///
/// Quando [immagine] e' `null` (nessuna foto, o indirizzo illeggibile) il
/// figlio resta esattamente com'era: niente tocco a vuoto su un segnaposto.
class ImmagineZoomabile extends StatelessWidget {
  const ImmagineZoomabile({
    super.key,
    required this.child,
    required this.immagine,
    this.titolo,
  });

  final Widget child;
  final ImageProvider? immagine;
  final String? titolo;

  @override
  Widget build(BuildContext context) {
    final foto = immagine;
    if (foto == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => apriImmagineIngrandita(context, immagine: foto, titolo: titolo),
      child: child,
    );
  }
}

/// Riempimento attorno a un'immagine mostrata per intero (`BoxFit.contain`):
/// chiaro col tema chiaro, scuro col tema scuro (richiesta di Ismail, 21/09).
///
/// Serve perche' un'immagine con proporzioni diverse dal riquadro lascia due
/// fasce vuote, e una fascia bianca fissa dentro un'app in tema scuro si vede
/// come un difetto.
Color sfondoImmagine(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return Theme.of(context).brightness == Brightness.dark
      ? scheme.surfaceContainerHighest
      : scheme.surfaceContainerLow;
}

class _SchermoIntero extends StatefulWidget {
  const _SchermoIntero({required this.immagine, this.titolo});

  final ImageProvider immagine;
  final String? titolo;

  @override
  State<_SchermoIntero> createState() => _SchermoInteroState();
}

class _SchermoInteroState extends State<_SchermoIntero>
    with SingleTickerProviderStateMixin {
  final TransformationController _trasformazione = TransformationController();
  late final AnimationController _animazione = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..addListener(() {
      final verso = _verso;
      if (verso != null) _trasformazione.value = verso.value;
    });
  Animation<Matrix4>? _verso;

  static const double _ingrandimento = 2.5;

  @override
  void dispose() {
    _animazione.dispose();
    _trasformazione.dispose();
    super.dispose();
  }

  /// Doppio tocco: ingrandisce sul punto toccato, o torna a schermo intero se
  /// era gia' ingrandita. Senza questo lo zoom si puo' fare solo a due dita,
  /// che su un telefono tenuto con una mano non si fa.
  void _doppioTocco(TapDownDetails dettagli) {
    final giaIngrandita = _trasformazione.value.getMaxScaleOnAxis() > 1.01;
    // La matrice si scrive voce per voce (`setEntry`) invece che con
    // `scale`/`translate`: quei due metodi di vector_math cambiano nome fra
    // una versione e l'altra, e questa e' la stessa scala + spostamento senza
    // dipendere da quale versione ci sia.
    final Matrix4 arrivo = Matrix4.identity();
    if (!giaIngrandita) {
      final p = dettagli.localPosition;
      arrivo
        ..setEntry(0, 0, _ingrandimento)
        ..setEntry(1, 1, _ingrandimento)
        ..setEntry(0, 3, -p.dx * (_ingrandimento - 1))
        ..setEntry(1, 3, -p.dy * (_ingrandimento - 1));
    }
    _verso = Matrix4Tween(begin: _trasformazione.value, end: arrivo).animate(
      CurvedAnimation(parent: _animazione, curve: Curves.easeOut),
    );
    _animazione.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final titolo = (widget.titolo ?? '').trim();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onDoubleTapDown: _doppioTocco,
                // Il doppio tocco ha bisogno di entrambi i gestori: senza
                // `onDoubleTap`, `onDoubleTapDown` non viene mai riconosciuto.
                onDoubleTap: () {},
                child: InteractiveViewer(
                  transformationController: _trasformazione,
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Image(
                      image: widget.immagine,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: Colors.white.withValues(alpha: .7),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              right: 4,
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  if (titolo.isNotEmpty)
                    Expanded(
                      child: Text(
                        titolo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
