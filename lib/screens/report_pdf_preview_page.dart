import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Anteprima del report PDF dentro l'app, con stampa e condivisione (14/09).
///
/// PRIMA "Stampa" apriva direttamente l'anteprima di sistema con un PDF gia'
/// costruito in A4, qualunque formato chiedesse la stampante: il documento
/// arrivava con il formato sbagliato e l'anteprima lo mostrava tagliato o
/// ridimensionato male — "la preview della stampa risulta buggata", la
/// segnalazione di Ismail. Qui il documento si costruisce PER il formato
/// richiesto ([costruisci] riceve il formato), e si vede nell'app prima di
/// mandarlo alla stampante.
class ReportPdfPreviewPage extends StatelessWidget {
  const ReportPdfPreviewPage({
    super.key,
    required this.titolo,
    required this.nomeFile,
    required this.messaggioErrore,
    required this.costruisci,
  });

  final String titolo;
  final String nomeFile;
  final String messaggioErrore;
  final Future<Uint8List> Function(PdfPageFormat formato) costruisci;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titolo,
          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PdfPreview(
        build: costruisci,
        pdfFileName: nomeFile,
        initialPageFormat: PdfPageFormat.a4,
        allowPrinting: true,
        allowSharing: true,
        // Il report e' impaginato per il verticale: cambiare orientamento o
        // formato dal menu produrrebbe pagine vuote a meta'.
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        maxPageWidth: 700,
        onError: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(messaggioErrore, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
