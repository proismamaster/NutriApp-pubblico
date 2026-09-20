import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Grafici vettoriali del report PDF (2026-09-14).
///
/// PERCHE' ESISTE: "il report pdf stampabile non fa vedere i grafici"
/// (Ismail). Ed era vero in due modi diversi:
///  - l'andamento nel tempo non era un grafico: una riga di testo con una
///    barretta per ogni periodo, trenta righe per un mese;
///  - la ripartizione dei macro era una FOTO della schermata, scattata solo se
///    in quel momento il grafico era disegnato. Sta in fondo a una lista che
///    si costruisce mentre si scorre, quindi di solito non lo era e il PDF
///    ripiegava sul testo senza dirlo.
/// Qui i grafici si disegnano direttamente nel PDF: non dipendono da cosa c'e'
/// sullo schermo, restano nitidi in stampa e hanno tutti i periodi.
///
/// Senza stato e senza Flutter, cosi' si provano costruendo un documento vero
/// (test/pdf_grafici_test.dart).
class PdfGrafici {
  PdfGrafici._();

  /// Oltre questo numero di periodi le etichette sotto le barre si
  /// accavallerebbero: se ne scrive una ogni tanto, le barre restano tutte.
  static const int _etichetteMassime = 8;

  static const pw.TextStyle _asse = pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700);

  /// Il primo numero "tondo" non inferiore a [valore], scelto fra quelli che
  /// divisi in quattro danno ancora numeri tondi (1, 2, 4, 6, 8 per una
  /// potenza di dieci): l'asse dice 0-4000 a passi di 1000, non 0-2371.
  static double tettoTondo(double valore) {
    if (valore <= 0) return 1;
    final potenza = math.pow(10, (math.log(valore) / math.ln10).floor()).toDouble();
    for (final passo in const [1.0, 2.0, 4.0, 6.0, 8.0, 10.0]) {
      if (passo * potenza >= valore - 1e-9) return passo * potenza;
    }
    return 10 * potenza;
  }

  static String _numeroAsse(num v) {
    if (v >= 1000) {
      final migliaia = v / 1000;
      return '${migliaia == migliaia.roundToDouble() ? migliaia.toStringAsFixed(0) : migliaia.toStringAsFixed(1)}k';
    }
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  /// Barre dell'andamento, una per periodo, con la linea dell'obiettivo se
  /// c'e'. [etichette] e [valori] vanno di pari passo.
  static pw.Widget andamento({
    required List<String> etichette,
    required List<double> valori,
    required PdfColor colore,
    double? obiettivo,
    double altezza = 190,
  }) {
    assert(etichette.length == valori.length);
    if (valori.isEmpty) return pw.SizedBox();

    final massimo = [...valori, ?obiettivo].fold<double>(0, math.max);
    final tetto = tettoTondo(massimo);
    const divisioni = 4;
    final gradini = [for (var i = 0; i <= divisioni; i++) tetto * i / divisioni];
    final ogni = (etichette.length / _etichetteMassime).ceil();
    final sotto = [
      for (var i = 0; i < etichette.length; i++) i % ogni == 0 ? etichette[i] : '',
      // Con un periodo solo (la vista "giorno") l'asse andrebbe da 0 a 0, e la
      // libreria divide per quella larghezza nulla: il PDF falliva con NaN.
      // Una seconda posizione vuota da' all'asse una larghezza.
      if (etichette.length == 1) '',
    ];
    // Barre larghe poco piu' della meta' dello spazio di ciascun periodo:
    // abbastanza da leggersi, abbastanza separate da contarle.
    final larghezzaBarra = (380 / valori.length * 0.55).clamp(2.0, 22.0);

    return pw.SizedBox(
      height: altezza,
      child: pw.Chart(
        grid: pw.CartesianGrid(
          xAxis: pw.FixedAxis.fromStrings(
            sotto,
            marginStart: larghezzaBarra,
            marginEnd: larghezzaBarra,
            ticks: true,
            textStyle: _asse,
          ),
          yAxis: pw.FixedAxis<double>(
            gradini,
            format: _numeroAsse,
            divisions: true,
            divisionsColor: PdfColors.grey300,
            divisionsDashed: true,
            textStyle: _asse,
          ),
        ),
        datasets: [
          pw.BarDataSet(
            color: colore,
            width: larghezzaBarra,
            drawBorder: false,
            data: [
              for (var i = 0; i < valori.length; i++) pw.PointChartValue(i.toDouble(), valori[i]),
            ],
          ),
          if (obiettivo != null && obiettivo > 0 && valori.length > 1)
            pw.LineDataSet(
              color: PdfColors.grey600,
              lineWidth: 1,
              drawPoints: false,
              data: [
                pw.PointChartValue(0, obiettivo),
                pw.PointChartValue((valori.length - 1).toDouble(), obiettivo),
              ],
            ),
        ],
      ),
    );
  }

  /// Ciambella della quota di energia dei macro, con la legenda a fianco.
  /// [quota] e' una frazione (0-1); le fette a zero non si disegnano.
  static pw.Widget ripartizioneMacro({
    required List<({String etichetta, double quota, PdfColor colore})> fette,
    double diametro = 140,
  }) {
    final valide = fette.where((f) => f.quota > 0).toList();
    if (valide.isEmpty) return pw.SizedBox();
    final totale = valide.fold<double>(0, (somma, f) => somma + f.quota);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // A SEGMENTI DRITTI, non `pw.Chart` + `PieDataSet` (15/09). Quella
        // ciambella e' fatta di curve di Bezier ripassate con un bordo bianco:
        // stampata usciva giusta, ma l'anteprima dell'app sul telefono la
        // disegnava enorme e fuori posto, sopra mezza pagina (screenshot di
        // Ismail). Un poligono di soli `lineTo` e un riempimento, senza bordo,
        // e' la forma che ogni lettore PDF disegna uguale.
        pw.CustomPaint(
          size: PdfPoint(diametro, diametro),
          painter: (canvas, size) => _ciambella(canvas, size, valide, totale),
        ),
        pw.SizedBox(width: 18),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              for (final f in valide)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 7),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 10,
                        height: 10,
                        decoration: pw.BoxDecoration(
                          color: f.colore,
                          borderRadius: pw.BorderRadius.circular(2),
                        ),
                      ),
                      pw.SizedBox(width: 7),
                      pw.Expanded(child: pw.Text(f.etichetta, style: const pw.TextStyle(fontSize: 10.5))),
                      pw.Text(
                        '${(f.quota / totale * 100).round()}%',
                        style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Le fette della ciambella come poligoni: un punto ogni 2 gradi sull'arco
  /// esterno, poi indietro su quello interno. Si parte in alto e si gira in
  /// senso orario (nel PDF l'asse y va verso l'alto). Fra una fetta e l'altra
  /// resta uno spiraglio di mezzo grado al posto del bordo bianco.
  static void _ciambella(
    PdfGraphics canvas,
    PdfPoint size,
    List<({String etichetta, double quota, PdfColor colore})> fette,
    double totale,
  ) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final esterno = size.x / 2;
    final interno = esterno * 0.4;
    const passoMassimo = math.pi / 90;
    const spiraglio = math.pi / 360;
    // `+ 0.0` toglie lo zero negativo: "-0" e' un numero PDF valido, ma non
    // serve rischiarlo.
    PdfPoint punto(double raggio, double angolo) =>
        PdfPoint(cx + raggio * math.cos(angolo) + 0.0, cy + raggio * math.sin(angolo) + 0.0);

    var inizio = math.pi / 2;
    for (final f in fette) {
      final ampiezza = f.quota / totale * 2 * math.pi;
      final gap = fette.length > 1 && ampiezza > spiraglio * 4 ? spiraglio : 0.0;
      final da = inizio - gap;
      final a = inizio - ampiezza + gap;
      final passi = math.max(1, ((da - a) / passoMassimo).ceil());

      final primo = punto(esterno, da);
      canvas.moveTo(primo.x, primo.y);
      for (var i = 1; i <= passi; i++) {
        final p = punto(esterno, da - (da - a) * i / passi);
        canvas.lineTo(p.x, p.y);
      }
      for (var i = passi; i >= 0; i--) {
        final p = punto(interno, da - (da - a) * i / passi);
        canvas.lineTo(p.x, p.y);
      }
      canvas
        ..closePath()
        ..setFillColor(f.colore)
        ..fillPath();
      inizio -= ampiezza;
    }
  }

  /// Una riga della ripartizione dei macro: nome, grammi e quota, e sotto una
  /// barra con la quota piena. Spostata qui da graphic_page.dart (18/09) per
  /// poterla provare in un documento vero.
  static pw.Widget barraMacro({
    required String etichetta,
    required String dettaglio,
    required double quota,
    required PdfColor colore,
    double larghezza = 320,
  }) {
    const altezza = 10.0;
    final pieno = larghezza * quota.clamp(0.0, 1.0);
    // Il raggio NON puo' superare meta' del lato piu' corto. Flutter lo riduce
    // da solo, il pacchetto pdf no: il `circular(999)` che c'era qui disegnava
    // curve di 999 punti, gli archi enormi che coprivano la pagina
    // nell'anteprima del telefono (screenshot del 15/09 e del 18/09).
    pw.BorderRadius raggio(double lato) => pw.BorderRadius.circular(math.min(altezza, lato) / 2);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(etichetta, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11.5)),
        pw.SizedBox(height: 2),
        pw.Text(dettaglio, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 6),
        pw.Container(
          width: larghezza,
          height: altezza,
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFE8EEE7),
            borderRadius: raggio(larghezza),
          ),
          child: pieno <= 0
              ? null
              : pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Container(
                    width: pieno,
                    decoration: pw.BoxDecoration(color: colore, borderRadius: raggio(pieno)),
                  ),
                ),
        ),
      ],
    );
  }

  /// I valori del grafico in una tabella, per chi stampa e vuole il numero
  /// esatto. Con piu' di dieci periodi va su due colonne affiancate; e' una
  /// `Table` e non una colonna di righe perche' una tabella puo' continuare
  /// sulla pagina dopo (un intervallo scelto a mano puo' avere mesi di giorni).
  static pw.Widget tabellaValori({required List<(String, String)> righe}) {
    if (righe.isEmpty) return pw.SizedBox();
    const normale = pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800);
    final grassetto = pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold);
    final perRiga = righe.length > 10 ? 2 : 1;

    pw.Widget cella(String testo, pw.TextStyle stile, {bool destra = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: pw.Text(testo, style: stile, textAlign: destra ? pw.TextAlign.right : pw.TextAlign.left),
        );

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: .5),
      ),
      columnWidths: {
        for (var i = 0; i < perRiga * 2; i++)
          i: i.isEven ? const pw.FlexColumnWidth(2) : const pw.FlexColumnWidth(1.3),
      },
      children: [
        for (var i = 0; i < righe.length; i += perRiga)
          pw.TableRow(
            children: [
              for (var j = 0; j < perRiga; j++) ...[
                cella(i + j < righe.length ? righe[i + j].$1 : '', normale),
                cella(i + j < righe.length ? righe[i + j].$2 : '', grassetto, destra: true),
              ],
            ],
          ),
      ],
    );
  }
}
