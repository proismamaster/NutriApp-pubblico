import 'dart:io';

import 'package:flutter/services.dart';

/// I font veri di Flutter (Roboto e MaterialIcons) per le prove che misurano
/// l'impaginazione.
///
/// PERCHE' SERVONO: senza, il binding dei test disegna ogni lettera come un
/// quadrato largo quanto il corpo del testo. Le righe risultano larghe il
/// doppio che sul telefono, e a 360 dp la prova "trova" sforamenti che sullo
/// schermo vero non ci sono.
///
/// PERCHE' ESISTE QUESTO FILE (21/09): quattro prove avevano scritto dentro
/// il percorso del computer di Ismail
/// (`C:\Users\ismai\flutter\bin\cache\artifacts\material_fonts`) e i nomi dei
/// file tutti in minuscolo. Su Windows funziona — il filesystem non distingue
/// maiuscole e minuscole — ma su qualunque altra macchina (un'altra persona
/// del gruppo, la macchina di GitHub Actions, una sessione AI) quelle quattro
/// prove fallivano tutte in `setUpAll` con "Cannot open file": cioe' proprio
/// le prove sull'impaginazione, le uniche che si accorgono se una schermata
/// sfora. Una prova che gira su un computer solo, quel giorno, non protegge
/// niente.
///
/// Ora la cartella si cerca, e i nomi dei file si confrontano senza guardare
/// maiuscole e minuscole.

/// Dove stanno i font.
///
/// `Platform.resolvedExecutable` durante `flutter test` e'
/// `<flutter>/bin/cache/dart-sdk/bin/dart`, quindi due cartelle piu' su c'e'
/// `<flutter>/bin/cache`. Il percorso scritto a mano resta la prima scelta,
/// cosi' sulla macchina di Ismail non cambia niente.
String cartellaFont() {
  const scrittoAMano = r'C:\Users\ismai\flutter\bin\cache\artifacts\material_fonts';
  if (Directory(scrittoAMano).existsSync()) return scrittoAMano;

  final sep = Platform.pathSeparator;
  final dartBin = File(Platform.resolvedExecutable).parent; // .../dart-sdk/bin
  final candidati = <String>[
    '${dartBin.parent.parent.path}${sep}artifacts${sep}material_fonts',
    // FLUTTER_ROOT c'e' quando le prove partono dallo strumento `flutter`.
    if ((Platform.environment['FLUTTER_ROOT'] ?? '').isNotEmpty)
      '${Platform.environment['FLUTTER_ROOT']}${sep}bin${sep}cache${sep}artifacts'
          '${sep}material_fonts',
  ];
  for (final c in candidati) {
    if (Directory(c).existsSync()) return c;
  }
  // Niente trovato: si restituisce comunque un percorso di questa macchina,
  // cosi' l'errore che arriva nomina una cartella vera invece di quella di un
  // altro computer.
  return candidati.first;
}

/// Il file [nome] dentro [cartellaFont], cercato senza distinguere maiuscole
/// e minuscole: nella cache di Flutter si chiama `Roboto-Regular.ttf`, ma le
/// prove lo chiedevano come `roboto-regular.ttf` e su Windows passava.
File fileFont(String nome) {
  final cartella = Directory(cartellaFont());
  if (cartella.existsSync()) {
    final cercato = nome.toLowerCase();
    for (final f in cartella.listSync().whereType<File>()) {
      if (f.uri.pathSegments.last.toLowerCase() == cercato) return f;
    }
  }
  // Nessuna corrispondenza: si restituisce il percorso atteso, cosi'
  // l'eccezione dice quale file manca.
  return File('${cartella.path}${Platform.pathSeparator}$nome');
}

/// Carica Roboto e MaterialIcons nel binding delle prove.
Future<void> caricaFontDiProva() async {
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(
      fileFont(f).readAsBytes().then((b) => ByteData.view(b.buffer)),
    );
  }
  await roboto.load();
  final icone = FontLoader('MaterialIcons')
    ..addFont(
      fileFont('MaterialIcons-Regular.otf')
          .readAsBytes()
          .then((b) => ByteData.view(b.buffer)),
    );
  await icone.load();
}
