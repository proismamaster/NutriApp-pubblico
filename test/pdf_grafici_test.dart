// Grafici del report PDF (2026-09-14).
//
// PERCHE' ESISTE: il report stampabile usciva senza grafici. Qui si costruisce
// un documento VERO con i grafici nuovi, per ogni numero di periodi che l'app
// puo' chiedere: un giorno, una settimana, un anno, un mese, e un intervallo
// scelto a mano molto lungo. Un grafico che non sta nella pagina, o una tabella
// troppo lunga, fanno fallire `save()`: e' esattamente l'errore che l'utente
// vedrebbe come "Impossibile generare il PDF". I file restano in
// build/prove_pdf per guardarli.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:nutriapp/widgets/pdf_grafici.dart';

Future<List<int>> _documento(int periodi) {
  final etichette = [for (var i = 0; i < periodi; i++) 'G${i + 1}'];
  final valori = [for (var i = 0; i < periodi; i++) 1500.0 + (i * 137) % 900];
  final documento = pw.Document();
  documento.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => [
        PdfGrafici.andamento(
          etichette: etichette,
          valori: valori,
          colore: PdfColors.green,
          obiettivo: 2000,
        ),
        pw.SizedBox(height: 10),
        PdfGrafici.tabellaValori(
          righe: [for (var i = 0; i < periodi; i++) (etichette[i], '${valori[i].round()} kcal')],
        ),
        pw.SizedBox(height: 20),
        PdfGrafici.ripartizioneMacro(
          fette: [
            (etichetta: 'Carboidrati', quota: .5, colore: PdfColors.amber),
            (etichetta: 'Proteine', quota: .2, colore: PdfColors.blue),
            (etichetta: 'Grassi', quota: .3, colore: PdfColors.purple),
          ],
        ),
      ],
    ),
  );
  return documento.save();
}

void main() {
  test('l\'asse finisce su un numero tondo, divisibile in quattro', () {
    expect(PdfGrafici.tettoTondo(2371), 4000);
    expect(PdfGrafici.tettoTondo(1100), 2000);
    expect(PdfGrafici.tettoTondo(80), 80);
    expect(PdfGrafici.tettoTondo(0), 1);
  });

  for (final periodi in [1, 7, 12, 31, 400]) {
    test('report con $periodi periodi: si impagina e si salva', () async {
      final byte = await _documento(periodi);
      expect(String.fromCharCodes(byte.take(5)), '%PDF-');
      final cartella = Directory('build/prove_pdf')..createSync(recursive: true);
      File('${cartella.path}/report_$periodi.pdf').writeAsBytesSync(byte);
    });
  }

  test('senza dati i grafici non disegnano niente, e non si rompono', () async {
    final documento = pw.Document()
      ..addPage(
        pw.Page(
          build: (_) => pw.Column(
            children: [
              PdfGrafici.andamento(etichette: const [], valori: const [], colore: PdfColors.green),
              PdfGrafici.ripartizioneMacro(fette: const []),
              PdfGrafici.tabellaValori(righe: const []),
            ],
          ),
        ),
      );
    final byte = await documento.save();
    expect(byte, isNotEmpty);
  });

  // 18/09. PERCHE': nell'anteprima del telefono la pagina dei macro era
  // coperta da archi enormi gialli, blu e viola. Non era la ciambella (rifatta
  // il 15/09 senza effetto): le barre dei macro avevano
  // `BorderRadius.circular(999)`, e il pacchetto pdf — a differenza di
  // Flutter — non riduce il raggio a meta' dell'altezza. Su una barra alta 10
  // disegnava curve di 999 punti. Qui si leggono i disegni della pagina e
  // nessuna coordinata deve uscire dal foglio.
  test('nessun disegno esce dalla pagina (barre dei macro comprese)', () async {
    final documento = pw.Document()
      ..addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (_) => [
            PdfGrafici.andamento(
              etichette: const ['28 Ago', '10 Set', '13 Set'],
              valori: const [1567, 1431, 271],
              colore: PdfColors.green,
              obiettivo: 7146,
            ),
            PdfGrafici.ripartizioneMacro(
              fette: [
                (etichetta: 'Carboidrati', quota: .65, colore: PdfColors.amber),
                (etichetta: 'Proteine', quota: .15, colore: PdfColors.blue),
                (etichetta: 'Grassi', quota: .20, colore: PdfColors.purple),
              ],
            ),
            for (final (nome, quota) in [('Carboidrati', .65), ('Proteine', .15), ('Grassi', .20), ('Vuoto', 0.0)])
              PdfGrafici.barraMacro(etichetta: nome, dettaglio: '12 g', quota: quota, colore: PdfColors.blue),
          ],
        ),
      );
    final byte = await documento.save();
    File('${(Directory('build/prove_pdf')..createSync(recursive: true)).path}/report_macro.pdf')
        .writeAsBytesSync(byte);

    final numeri = _numeriDeiDisegni(byte);
    expect(numeri, isNotEmpty, reason: 'la pagina deve contenere dei disegni');
    final massimo = numeri.map((n) => n.abs()).reduce((a, b) => a > b ? a : b);
    expect(massimo, lessThan(PdfPageFormat.a4.height + 1), reason: 'coordinata fuori dal foglio: $massimo');
  });
}

/// Tutti i numeri dei flussi di disegno del PDF, decompressi. Grezzo ma
/// sufficiente: i disegni sono fatti di numeri seguiti da un operatore.
List<double> _numeriDeiDisegni(List<int> pdf) {
  final testo = latin1.decode(pdf);
  final numeri = <double>[];
  final flussi = RegExp(r'stream\r?\n').allMatches(testo);
  for (final m in flussi) {
    final fine = testo.indexOf('endstream', m.end);
    if (fine < 0) continue;
    List<int> dati = pdf.sublist(m.end, fine);
    try {
      dati = zlib.decode(dati);
    } catch (_) {
      continue; // un flusso non compresso o un font: non sono disegni
    }
    final contenuto = latin1.decode(dati, allowInvalid: true);
    // Solo i flussi di pagina: contengono operatori di tracciato.
    if (!RegExp(r'\s(re|m|l|c)\s').hasMatch(contenuto)) continue;
    for (final n in RegExp(r'-?\d+\.?\d*').allMatches(contenuto)) {
      numeri.add(double.parse(n.group(0)!));
    }
  }
  return numeri;
}
