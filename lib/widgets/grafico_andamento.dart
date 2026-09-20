import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/history_point.dart';
import '../models/metric_type.dart';
import 'auth_style.dart';
import 'pdf_grafici.dart';

/// Andamento nel tempo della metrica scelta, a colonne (17/09).
///
/// PRIMA era una linea con un punto per periodo, larga 46 px a periodo e da
/// scorrere: con 30 giorni e pochi giorni registrati restavano punti isolati e
/// una stanghetta, il fumetto del valore sempre aperto e tagliato in alto, e
/// un'etichetta di data ogni tanto ("non si vede bene il giorno", Ismail).
/// Ora ogni periodo e' una colonna nella larghezza disponibile, niente
/// scorrimento, il valore si legge toccando la colonna, e le date sono sempre
/// la prima, l'ultima e alcune in mezzo a distanza fissa.
///
/// Regole di disegno (skill dataviz): colonne al massimo 24 px con l'estremo
/// arrotondato di 4 px, griglia a filo sottile e continua, testo mai nel
/// colore della serie, un'unica serie quindi nessuna legenda.
class GraficoAndamento extends StatelessWidget {
  const GraficoAndamento({
    super.key,
    required this.punti,
    required this.metrica,
    this.obiettivo,
    this.etichettaObiettivo = '',
  });

  final List<HistoryPoint> punti;
  final MetricType metrica;

  /// Obiettivo gia' scalato al periodo (giorno, settimana...). Null o <= 0:
  /// nessuna linea.
  final double? obiettivo;
  final String etichettaObiettivo;

  static const double _altezza = 220;
  static const double _asse = 40;

  /// Spazio orizzontale che serve a un'etichetta di data per non toccare la vicina.
  static const double _spazioEtichetta = 56;

  @override
  Widget build(BuildContext context) {
    if (punti.isEmpty) return const SizedBox(height: _altezza);
    final scheme = Theme.of(context).colorScheme;

    // Tutto nell'unita' scelta (kJ, once) PRIMA di fare la scala, cosi' l'asse
    // finisce su numeri tondi in quell'unita' (18/09).
    final valori = [for (final p in punti) p.hasData ? metrica.visibile(metrica.readFromPoint(p)) : 0.0];
    final massimo = valori.fold<double>(0, math.max);
    final meta = (obiettivo ?? 0) > 0 ? metrica.visibile(obiettivo!) : 0.0;
    // Un obiettivo molto sopra i dati (una settimana con due giorni
    // registrati) schiaccerebbe tutte le colonne sul fondo: resta fuori scala.
    final metaInScala = meta > 0 && (massimo == 0 || meta <= massimo * 2.5);
    final tetto = PdfGrafici.tettoTondo(math.max(massimo, metaInScala ? meta : 0) * 1.05);
    final passo = tetto / 4;
    final ultimo = punti.length - 1;

    return LayoutBuilder(
      builder: (context, vincoli) {
        final utile = math.max(1.0, vincoli.maxWidth - _asse);
        final slot = utile / punti.length;
        final spessore = (slot * 0.6).clamp(2.0, 24.0);
        final ogni = math.max(1, (_spazioEtichetta / slot).ceil());

        return SizedBox(
          height: _altezza,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: tetto,
              alignment: BarChartAlignment.spaceAround,
              barGroups: [
                for (var i = 0; i < punti.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: valori[i],
                        width: spessore,
                        color: punti[i].hasData ? metrica.color : Colors.transparent,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(math.min(4, spessore / 2))),
                      ),
                    ],
                  ),
              ],
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: passo,
                getDrawingHorizontalLine: (_) => FlLine(color: Nutri.hairline, strokeWidth: 1),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(bottom: BorderSide(color: Nutri.divider)),
              ),
              extraLinesData: metaInScala
                  ? ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: meta,
                          color: Nutri.muted,
                          strokeWidth: 1,
                          dashArray: const [4, 4],
                          label: HorizontalLineLabel(
                            show: etichettaObiettivo.isNotEmpty,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(bottom: 2),
                            style: TextStyle(fontSize: 10.5, color: Nutri.muted),
                            labelResolver: (_) => etichettaObiettivo,
                          ),
                        ),
                      ],
                    )
                  : const ExtraLinesData(),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: _asse,
                    interval: passo,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      meta: meta,
                      space: 6,
                      // Solo il numero: l'unita' la dice il titolo della sezione.
                      child: Text(
                        metrica.scriviBreve(v).split(' ').first,
                        style: TextStyle(fontSize: 10.5, color: Nutri.muted),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      final mostra = i == ultimo || (i % ogni == 0 && ultimo - i >= ogni);
                      if (i < 0 || i > ultimo || !mostra) return const SizedBox.shrink();
                      return SideTitleWidget(
                        meta: meta,
                        space: 6,
                        child: Text(punti[i].label, style: TextStyle(fontSize: 10.5, color: Nutri.muted)),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => scheme.inverseSurface,
                  getTooltipItem: (gruppo, _, asta, _) {
                    final p = punti[gruppo.x];
                    if (!p.hasData) return null;
                    return BarTooltipItem(
                      '${p.label}\n',
                      TextStyle(fontSize: 11.5, color: scheme.onInverseSurface),
                      children: [
                        TextSpan(
                          text: metrica.scrivi(asta.toY),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: scheme.onInverseSurface),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
