import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../widgets/auth_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/user_provider.dart';
import '../models/food_entry.dart';
import '../models/user_model.dart';
import '../models/macro_analysis.dart';
import '../models/macro_totals.dart';
import '../services/api_services.dart';
import '../models/history_point.dart';
import '../models/metric_type.dart';
import '../models/range_bucket.dart';
import '../models/tab_analysis_data.dart';
import '../widgets/grafico_andamento.dart';
import '../widgets/macro_warning_banner.dart';
import '../widgets/ripartizione_macro.dart';
import '../widgets/state_message.dart';
import '../dictionary/translations.dart';
import '../logic/unit_format.dart';
import '../providers/locale_provider.dart';
import '../widgets/pdf_grafici.dart';
import 'report_pdf_preview_page.dart';


// Schermata principale delle statistiche nutrizionali.
//
// RIDISEGNATA IL 17/09 ("sa di AI slop", Ismail). Tolti: il riquadro verde
// scuro con i numeri in bianco, le schede con icona per ogni cifra, il
// pannello filtri a scomparsa, la barra dei periodi con l'ombra, la ciambella
// ripetuta dalle barre. Ora, dall'alto: periodo, metrica e intervallo in due
// righe fisse; poi la media del periodo come unico numero grande, con
// l'obiettivo e tre cifre di contorno; il grafico a colonne; la ripartizione
// dei macro; l'esportazione in fondo. Superfici e testi dai colori del tema,
// quindi uguale cura in chiaro e in scuro.
class GraphicPage extends ConsumerStatefulWidget {
  const GraphicPage({super.key});

  @override
  ConsumerState<GraphicPage> createState() => _GraphicPageState();
}

class _GraphicPageState extends ConsumerState<GraphicPage> {
  // Non piu' const: Nutri.green e' un getter che cambia col tema.
  Color get _accentColor => Nutri.green;

  // Carichiamo i dati una volta sola e li filtriamo in locale per velocità
  bool _isLoading = true;          // true durante il fetch iniziale o il refresh
  String? _errorMessage;           // messaggio di errore da mostrare all'utente
  List<FoodEntry> _entries = const []; // tutte le voci alimentari caricate
  MetricType _selectedMetric = MetricType.calories; // metrica attiva nei grafici
  DateTimeRange? _customRange;     // intervallo di date selezionato dall'utente
  bool _isExportingPdf = false;    // true mentre il PDF è in fase di generazione

  @override
  void initState() {
    super.initState();
    // Carichiamo lo storico subito dopo l'avvio
    Future<void>.microtask(_loadHistory);
  }

  // Scarica lo storico dei pasti dal server
  ///
  /// Se l'utente non è autenticato mostra un messaggio invece di fare la chiamata.
  /// L'ordinamento cronologico garantisce che riepiloghi e aggregazioni
  /// temporali siano sempre coerenti con l'ordine di inserimento.
  /// Se il widget viene smontato durante il fetch, lo setState viene ignorato.
  Future<void> _loadHistory() async {
    final user = ref.read(userProvider);
    if (user == null) {
      setState(() {
        _entries = const [];
        _isLoading = false;
        final lang = ref.read(appSettingsProvider).language;
        _errorMessage = Translations.get(lang, 'Effettua il login per visualizzare le statistiche.');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // I grafici arrivano al massimo a dodici mesi indietro: chiedere di
      // piu' significa scaricare storico che non verra' disegnato (19/09).
      final entries = await ApiServices.fetchFoodEntries(
        user.email,
        da: DateTime.now().subtract(const Duration(days: 366)),
      );
      // Ordiniamo per data in modo che le aggregazioni per bucket siano corrette
      // e che l'ultima voce corrisponda sempre all'inserimento più recente.
      entries.sort(
        (first, second) => first.entry_date.compareTo(second.entry_date),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _entries = entries;
        // NB: non impostiamo più automaticamente un _customRange qui. Ogni
        // tab calcola la propria finestra di default in _effectiveWindow();
        // _customRange resta null finché l'utente non sceglie esplicitamente
        // un intervallo dal date picker, e a quel punto si applica a tutti i
        // tab (vedi _effectiveWindow).
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        final lang = ref.read(appSettingsProvider).language;
        _errorMessage = Translations.get(lang, 'Impossibile caricare lo storico alimentare.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Nutri.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: _rigaTempo(lang),
              ),
              _rigaMetriche(lang),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final bucket in RangeBucket.values) _buildTabContent(bucket, lang),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Una riga sola per TUTTI i filtri di tempo (richiesta di Ismail, 21/09):
  /// giornaliero, settimanale, mensile, annuale e "Periodo".
  ///
  /// Prima "Periodo" stava in fondo alla riga delle metriche, cioe' in mezzo a
  /// carboidrati, proteine e grassi: un filtro di tempo messo fra i filtri di
  /// nutriente. Chi cercava l'intervallo di date lo trovava dopo aver fatto
  /// scorrere una riga che parla d'altro.
  ///
  /// COME CI STA: i quattro periodi prendono lo spazio che avanza, il
  /// pulsante del periodo personalizzato occupa quel che gli serve fino a un
  /// tetto. Sotto i 360 px resta la sola icona del calendario — a quella
  /// larghezza l'etichetta ruberebbe ai quattro periodi lo spazio per essere
  /// leggibili, e il calendario da solo si capisce.
  Widget _rigaTempo(String lang) {
    return LayoutBuilder(
      builder: (context, vincoli) {
        final stretto = vincoli.maxWidth < 360;
        return Row(
          children: [
            Expanded(child: _selettorePeriodo(lang)),
            const SizedBox(width: 8),
            _bottonePeriodo(lang, soloIcona: stretto),
          ],
        );
      },
    );
  }

  /// Il pulsante "Periodo": apre la scelta dell'intervallo di date, e quando
  /// un intervallo e' scelto lo mostra con la X per toglierlo.
  ///
  /// La X sta DENTRO il pulsante (prima era un tasto separato in fondo a una
  /// riga che scorreva, e per toglierlo bisognava indovinare che ci fosse
  /// altro a destra — test di release 19/09).
  Widget _bottonePeriodo(String lang, {required bool soloIcona}) {
    final intervallo = _customRange;
    final bool attivo = intervallo != null;
    final Color primoPiano = attivo ? Colors.white : Nutri.label;
    final String etichetta =
        attivo ? _windowRangeLabel(intervallo) : Translations.get(lang, 'Periodo');

    return Tooltip(
      message: etichetta,
      child: Material(
        color: attivo ? Nutri.greenFill : Nutri.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickCustomRange(context),
          child: Container(
            height: 48,
            // Stessa altezza del selettore accanto (4 di padding + 40 di
            // linguetta): le due parti della riga devono sembrare una cosa
            // sola, non due controlli appoggiati vicini.
            constraints: const BoxConstraints(maxWidth: 148),
            padding: EdgeInsets.symmetric(horizontal: soloIcona && !attivo ? 12 : 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: attivo ? Nutri.greenFill : Nutri.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.date_range, size: 17, color: primoPiano),
                if (!soloIcona || attivo) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        etichetta,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: attivo ? FontWeight.bold : FontWeight.w500,
                          color: primoPiano,
                        ),
                      ),
                    ),
                  ),
                ],
                if (attivo) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _clearCustomRange,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Semantics(
                        button: true,
                        label: Translations.get(lang, 'public_filters_clear'),
                        child: Icon(Icons.close, size: 16, color: primoPiano),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Giorno, settimana, mese, anno: un selettore segmentato piatto, la voce
  /// scelta in rilievo sul fondo del gruppo.
  Widget _selettorePeriodo(String lang) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Nutri.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Nutri.card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Nutri.hairline),
        ),
        splashBorderRadius: BorderRadius.circular(9),
        labelColor: Nutri.ink,
        unselectedLabelColor: Nutri.muted,
        labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
        // Poco spazio fra i bordi: a 412 px "Giornaliero" e "Settimanale"
        // venivano tagliati a meta' parola (test di release 19/09).
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: [
          for (final chiave in const ['Giornaliero', 'Settimanale', 'Mensile', 'Annuale'])
            Tab(
              height: 40,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(Translations.get(lang, chiave)),
              ),
            ),
        ],
      ),
    );
  }

  /// Le quattro metriche: calorie, carboidrati, proteine, grassi.
  ///
  /// TUTTI DELLA STESSA MISURA (richiesta di Ismail, 21/09): prima erano
  /// pastiglie larghe quanto la parola che contenevano, quindi "Calorie" era
  /// un terzo di "Carboidrati" e cambiando lingua cambiava anche la
  /// disposizione. Ora ogni riquadro e' [_latoMetrica] x [_altezzaMetrica],
  /// con la stessa cornice del riquadro che mostra il valore grande piu'
  /// sotto, e il testo si rimpicciolisce dentro invece di allargare il
  /// riquadro.
  ///
  /// La riga continua a scorrere in orizzontale: a misura fissa i quattro
  /// riquadri stanno su uno schermo normale e scorrono su uno stretto, invece
  /// di stringersi fino a diventare illeggibili.
  Widget _rigaMetriche(String lang) {
    return SizedBox(
      height: _altezzaMetrica + 16,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          for (final metrica in MetricType.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _riquadroMetrica(lang, metrica),
            ),
        ],
      ),
    );
  }

  /// Misura di un riquadro-metrica. Fissa di proposito: e' cio' che li rende
  /// tutti uguali indipendentemente dalla parola e dalla lingua.
  static const double _latoMetrica = 92;
  static const double _altezzaMetrica = 44;

  Widget _riquadroMetrica(String lang, MetricType metrica) {
    final bool scelto = _selectedMetric == metrica;
    return Material(
      color: scelto ? Nutri.greenFill : Nutri.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedMetric = metrica),
        child: Container(
          width: _latoMetrica,
          height: _altezzaMetrica,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            // Stessa cornice del riquadro del valore grande (vedi _riquadro).
            border: Border.all(color: scelto ? Nutri.greenFill : Nutri.hairline),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              Translations.get(lang, metrica.label),
              maxLines: 1,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: scelto ? FontWeight.bold : FontWeight.w500,
                color: scelto ? Colors.white : Nutri.label,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Contenuto di un periodo: caricamento, errore, vuoto o dati.
  Widget _buildTabContent(RangeBucket bucket, String lang) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: _accentColor),
      );
    }

    if (_errorMessage != null) {
      return StateMessage(
        icon: Icons.wifi_off_rounded,
        title: _errorMessage!,
        actionLabel: Translations.get(lang, 'Riprova'),
        onPressed: _loadHistory,
      );
    }

    final analysis = _buildTabAnalysis(bucket, lang);
    if (analysis == null) {
      return StateMessage(
        icon: Icons.insights_outlined,
        title: Translations.get(lang, 'Nessun dato disponibile nel periodo selezionato.'),
        subtitle: Translations.get(lang, 'Prova ad ampliare l’intervallo di date per vedere più dati.'),
        actionLabel: Translations.get(lang, 'Aggiorna'),
        onPressed: _loadHistory,
      );
    }

    final metrica = _selectedMetric;
    final obiettivo = _scaledGoalFor(bucket);
    final confronto = _goalComparisonLabel(analysis, bucket, lang);

    return RefreshIndicator(
      color: _accentColor,
      onRefresh: _loadHistory,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _riquadro(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Translations.get(lang, 'Media')}, ${Translations.get(lang, metrica.label).toLowerCase()}',
                  style: TextStyle(fontSize: 13, color: Nutri.muted),
                ),
                const SizedBox(height: 2),
                _numeroGrande(metrica.format(analysis.averageValue)),
                if (obiettivo != null && obiettivo > 0) ...[
                  const SizedBox(height: 12),
                  _misuratore(analysis.averageValue / obiettivo, metrica.color),
                  if (confronto != null) ...[
                    const SizedBox(height: 8),
                    Text(confronto, style: TextStyle(fontSize: 12.5, color: Nutri.body)),
                  ],
                ],
                const SizedBox(height: 16),
                Divider(height: 1, color: Nutri.hairline),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _cifra(Translations.get(lang, 'Totale'), metrica.format(analysis.totalValue)),
                    _cifra(
                      Translations.get(lang, 'Picco'),
                      metrica.format(metrica.readFromPoint(analysis.peakPoint)),
                      sotto: analysis.peakPoint.label,
                    ),
                    _cifra(
                      '${_bucketPluralNoun(bucket, lang)} ${Translations.get(lang, 'con dati')}',
                      '${analysis.trackedPeriods}/${analysis.totalPeriods}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _riquadro(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _titoloSezione(
                  '${Translations.get(lang, metrica.label)} ${Translations.get(lang, 'nel tempo')}',
                  _windowRangeLabel(analysis.window),
                ),
                const SizedBox(height: 16),
                GraficoAndamento(
                  punti: analysis.points,
                  metrica: metrica,
                  obiettivo: obiettivo,
                  etichettaObiettivo: Translations.get(lang, 'obiettivo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _riquadro(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _titoloSezione(
                  Translations.get(lang, 'Distribuzione macronutrienti'),
                  Translations.get(lang, 'Grammi totali e quota energetica del periodo selezionato'),
                ),
                const SizedBox(height: 16),
                if (analysis.macroAnalysis.showDominanceWarning ||
                    analysis.macroAnalysis.showCalorieMismatchWarning) ...[
                  MacroWarningBanner(analysis: analysis.macroAnalysis, lang: lang),
                  const SizedBox(height: 14),
                ],
                RipartizioneMacro(
                  analisi: analysis.macroAnalysis,
                  totali: analysis.macroTotals,
                  lang: lang,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _pulsanteEsporta(
                  icona: Icons.print_outlined,
                  etichetta: _isExportingPdf
                      ? Translations.get(lang, 'Preparazione...')
                      : Translations.get(lang, 'Stampa PDF'),
                  onPressed: () => _exportPdf(bucket: bucket, analysis: analysis, share: false, lang: lang),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _pulsanteEsporta(
                  icona: Icons.ios_share,
                  etichetta: Translations.get(lang, 'Condividi PDF'),
                  onPressed: () => _exportPdf(bucket: bucket, analysis: analysis, share: true, lang: lang),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _riquadro(Widget figlio) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Nutri.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Nutri.hairline),
        ),
        child: figlio,
      );

  Widget _titoloSezione(String titolo, String sotto) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titolo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Nutri.ink)),
          const SizedBox(height: 2),
          Text(sotto, style: TextStyle(fontSize: 12.5, color: Nutri.muted)),
        ],
      );

  /// Il numero del periodo, grande, con l'unita' piu' piccola accanto.
  Widget _numeroGrande(String valore) {
    final spazio = valore.lastIndexOf(' ');
    final numero = spazio < 0 ? valore : valore.substring(0, spazio);
    final unita = spazio < 0 ? '' : valore.substring(spazio);
    return Text.rich(
      TextSpan(
        text: numero,
        style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, height: 1.1, color: Nutri.ink),
        children: [
          TextSpan(
            text: unita,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Nutri.muted),
          ),
        ],
      ),
    );
  }

  /// Quanto della media copre l'obiettivo: il vuoto e' il fondo tenue, il
  /// pieno il colore della metrica.
  Widget _misuratore(double quota, Color colore) => LinearProgressIndicator(
        value: quota.clamp(0.0, 1.0),
        minHeight: 8,
        borderRadius: BorderRadius.circular(4),
        backgroundColor: Nutri.surfaceSoft,
        color: colore,
      );

  Widget _cifra(String etichetta, String valore, {String? sotto}) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etichetta, maxLines: 2, style: TextStyle(fontSize: 12, color: Nutri.muted)),
              const SizedBox(height: 3),
              Text(
                valore,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Nutri.ink),
              ),
              if (sotto != null)
                Text(
                  sotto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: Nutri.muted),
                ),
            ],
          ),
        ),
      );

  Widget _pulsanteEsporta({
    required IconData icona,
    required String etichetta,
    required VoidCallback onPressed,
  }) =>
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          foregroundColor: Nutri.green,
          side: BorderSide(color: Nutri.fieldBorder),
        ),
        onPressed: _isExportingPdf ? null : onPressed,
        icon: Icon(icona, size: 19),
        label: Text(etichetta, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  /// Apre il selettore di date nativo e aggiorna [_customRange].
  ///
  /// Il picker è limitato all'intervallo effettivo delle voci presenti;
  /// se l'utente annulla, il range corrente rimane invariato.
  Future<void> _pickCustomRange(BuildContext context) async {
    final firstAvailableDate = _entries.isEmpty
        ? DateTime(2020)
        : _normalizeDate(_entries.first.entry_date);
    final lastAvailableDate = _entries.isEmpty
        ? DateTime.now()
        : _normalizeDate(_entries.last.entry_date);
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: firstAvailableDate,
      lastDate: DateTime.now(),
      initialDateRange:
          _customRange ??
          DateTimeRange(start: firstAvailableDate, end: lastAvailableDate),
      helpText: Translations.get(ref.read(appSettingsProvider).language, 'Seleziona intervallo'),
      cancelText: Translations.get(ref.read(appSettingsProvider).language, 'Annulla'),
      confirmText: Translations.get(ref.read(appSettingsProvider).language, 'Conferma'),
      saveText: Translations.get(ref.read(appSettingsProvider).language, 'Salva'),
    );

    if (pickedRange == null || !mounted) {
      return;
    }

    setState(() {
      _customRange = DateTimeRange(
        start: _normalizeDate(pickedRange.start),
        end: _normalizeDate(pickedRange.end),
      );
    });
  }

  /// Genera e mostra/condivide il PDF del report nutrizionale.
  ///
  /// Stampa: apre l'anteprima nell'app, dove il PDF si costruisce per il
  /// formato della stampante. Condividi: costruisce il PDF in A4 e lo passa
  /// alla condivisione di sistema.
  /// Usa [_isExportingPdf] per prevenire esportazioni doppie.
  Future<void> _exportPdf({
    required RangeBucket bucket,
    required TabAnalysisData analysis,
    required bool share,
    required String lang,
  }) async {
    if (_isExportingPdf) {
      return;
    }

    final fileName = _buildPdfFileName(bucket, lang);

    // Stampa (14/09): anteprima nell'app invece di quella di sistema con un
    // A4 gia' fatto, che arrivava col formato sbagliato — vedi
    // ReportPdfPreviewPage.
    if (!share) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportPdfPreviewPage(
            titolo: Translations.get(lang, 'Report nutrizionale'),
            nomeFile: fileName,
            messaggioErrore: Translations.get(lang, 'Impossibile generare il PDF delle statistiche.'),
            costruisci: (formato) => _buildPdfBytes(
              bucket: bucket,
              analysis: analysis,
              lang: lang,
              format: formato,
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isExportingPdf = true);

    try {
      final pdfBytes = await _buildPdfBytes(
        bucket: bucket,
        analysis: analysis,
        lang: lang,
      );
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Translations.get(lang, 'Impossibile generare il PDF delle statistiche.')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  Future<Uint8List> _buildPdfBytes({
    required RangeBucket bucket,
    required TabAnalysisData analysis,
    required String lang,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final generatedAt = DateTime.now();
    
    // Caricamento Font per supporto Multilingue (Cinese, Arabo, ecc)
    final mainFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    
    pw.Font? fallbackFont;
    if (lang == '简体中文') {
      fallbackFont = await PdfGoogleFonts.notoSansSCRegular();
    } else if (lang == 'العربية') {
      fallbackFont = await PdfGoogleFonts.notoSansArabicRegular();
    }

    final theme = pw.ThemeData.withFont(
      base: mainFont,
      bold: boldFont,
      fontFallback: fallbackFont != null ? [fallbackFont] : null,
    );

    final document = pw.Document(
      title: Translations.get(lang, 'Report nutrizionale NutriApp'),
      theme: theme,
    );

    final metricColor = PdfColor.fromInt(_selectedMetric.color.toARGB32() & 0x00FFFFFF);
    final accentPdfColor = PdfColor.fromInt(_accentColor.toARGB32() & 0x00FFFFFF);
    final goalTarget = _scaledGoalFor(bucket);
    // Solo i periodi con dati veri: i buchi riempirebbero grafico e tabella di
    // zeri che non sono "zero mangiato" ma "niente registrato".
    final periodiConDati = analysis.points.where((point) => point.hasData).toList();
    final isRtl = lang == 'العربية';
    final generatedLabel =
        '${_formatDate(generatedAt)} ${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}';

    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(28),
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: accentPdfColor,
              borderRadius: pw.BorderRadius.circular(18),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  Translations.get(lang, 'Report nutrizionale'),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  Translations.get(lang, 'Documento pronto per la stampa generato da NutriApp'),
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          _buildPdfSectionTitle(
            Translations.get(lang, 'Informazioni report'),
            Translations.get(lang, 'Contesto della statistica esportata'),
          ),
          pw.SizedBox(height: 10),
          _buildPdfInfoCard(
            rows: [
              (Translations.get(lang, 'Metrica'), Translations.get(lang, _selectedMetric.label)),
              (Translations.get(lang, 'Vista'), _bucketTitle(bucket, lang)),
              (
                Translations.get(lang, 'Periodo'),
                '${_windowRangeLabel(analysis.window)} · ${_coverageLabel(analysis, bucket, lang)}',
              ),
              (Translations.get(lang, 'Generato il'), generatedLabel),
            ],
          ),
          pw.SizedBox(height: 20),
          _buildPdfSectionTitle(
            Translations.get(lang, 'Riepilogo numerico'),
            Translations.get(lang, 'Valori principali della vista selezionata'),
          ),
          pw.SizedBox(height: 10),
          _buildPdfInfoCard(
            rows: [
              (Translations.get(lang, 'Totale'), _selectedMetric.format(analysis.totalValue)),
              (Translations.get(lang, 'Media'), _selectedMetric.format(analysis.averageValue)),
              (
                Translations.get(lang, 'Picco'),
                '${_selectedMetric.format(_selectedMetric.readFromPoint(analysis.peakPoint))} (${analysis.peakPoint.label})',
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          // Titolo e grafico restano insieme e non si spezzano (18/09): il
          // riquadro e' una Column, che il PDF divide fra due pagine. Quando il
          // grafico non ci stava, a fine pagina restava lo sfondo vuoto e il
          // grafico ripartiva nella pagina dopo (screenshot di Ismail).
          pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
          _buildPdfSectionTitle(
            '${Translations.get(lang, _selectedMetric.label)} ${Translations.get(lang, 'nel tempo')}',
            '${_windowRangeLabel(analysis.window)} · ${_coverageLabel(analysis, bucket, lang)}',
          ),
          pw.SizedBox(height: 10),
          // Grafico vero, disegnato nel PDF (14/09): prima qui c'erano righe di
          // testo con una barretta ciascuna. Vedi PdfGrafici.
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(10, 14, 14, 10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF7FAF6),
              borderRadius: pw.BorderRadius.circular(16),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE6EEE4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                PdfGrafici.andamento(
                  etichette: [for (final p in periodiConDati) p.label],
                  // Nell'unita' scelta, come il grafico dell'app: l'asse del PDF diceva
                  // numeri in kcal sotto un titolo in kJ.
                  valori: [for (final p in periodiConDati) _selectedMetric.visibile(_selectedMetric.readFromPoint(p))],
                  colore: metricColor,
                  obiettivo: goalTarget == null ? null : _selectedMetric.visibile(goalTarget),
                ),
                if (goalTarget != null) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    '${Translations.get(lang, 'Obiettivo di riferimento')}: ${_selectedMetric.format(goalTarget)}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ],
            ),
          ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          PdfGrafici.tabellaValori(
            righe: [
              for (final p in periodiConDati)
                (p.label, _selectedMetric.format(_selectedMetric.readFromPoint(p))),
            ],
          ),
          pw.SizedBox(height: 20),
          // Stesso motivo del grafico sopra: titolo e ciambella non si dividono.
          pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
            _buildPdfSectionTitle(
              Translations.get(lang, 'Distribuzione macronutrienti'),
              Translations.get(lang, 'Grammi totali e quota energetica del periodo selezionato'),
            ),
            pw.SizedBox(height: 10),
            // La ciambella dei macro disegnata nel PDF (14/09): prima era una
            // foto della schermata, presa solo se il grafico era gia'
            // disegnato — di solito no, e il PDF usciva senza.
            PdfGrafici.ripartizioneMacro(
              fette: [
                (
                  etichetta: Translations.get(lang, 'Carboidrati'),
                  quota: analysis.macroAnalysis.carbsEnergyShare,
                  colore: PdfColor.fromInt(0xFFF0B429),
                ),
                (
                  etichetta: Translations.get(lang, 'Proteine'),
                  quota: analysis.macroAnalysis.proteinsEnergyShare,
                  colore: PdfColor.fromInt(0xFF2D7FF9),
                ),
                (
                  etichetta: Translations.get(lang, 'Grassi'),
                  quota: analysis.macroAnalysis.fatsEnergyShare,
                  colore: PdfColor.fromInt(0xFF8A5CF6),
                ),
              ],
            ),
              ],
            ),
          ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(16),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE2ECE0)),
              ),
              child: pw.Column(
                children: [
                  _buildPdfMacroRow(
                    label: Translations.get(lang, 'Carboidrati'),
                    grams: analysis.macroTotals.carbs,
                    share: analysis.macroAnalysis.carbsEnergyShare,
                    color: PdfColor.fromInt(0xFFF0B429),
                    lang: lang,
                  ),
                  pw.SizedBox(height: 12),
                  _buildPdfMacroRow(
                    label: Translations.get(lang, 'Proteine'),
                    grams: analysis.macroTotals.proteins,
                    share: analysis.macroAnalysis.proteinsEnergyShare,
                    color: PdfColor.fromInt(0xFF2D7FF9),
                    lang: lang,
                  ),
                  pw.SizedBox(height: 12),
                  _buildPdfMacroRow(
                    label: Translations.get(lang, 'Grassi'),
                    grams: analysis.macroTotals.fats,
                    share: analysis.macroAnalysis.fatsEnergyShare,
                    color: PdfColor.fromInt(0xFF8A5CF6),
                    lang: lang,
                  ),
                  if (analysis.macroAnalysis.showDominanceWarning ||
                      analysis.macroAnalysis.showCalorieMismatchWarning) ...[
                    pw.SizedBox(height: 14),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFFFF4EC),
                        borderRadius: pw.BorderRadius.circular(12),
                        border: pw.Border.all(
                          color: PdfColor.fromInt(0xFFF3C8A9),
                        ),
                      ),
                      child: pw.Text(
                        _buildPdfMacroWarningText(analysis.macroAnalysis, lang),
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          color: PdfColor.fromInt(0xFF7B3E11),
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );

    return document.save();
  }

  String _buildPdfFileName(RangeBucket bucket, String lang) {
    final stamp = DateTime.now();
    final date =
        '${stamp.year}${stamp.month.toString().padLeft(2, '0')}${stamp.day.toString().padLeft(2, '0')}';
    return 'nutriapp_${bucket.name}_${_selectedMetric.name}_$date.pdf';
  }

  String _bucketTitle(RangeBucket bucket, String lang) {
    switch (bucket) {
      case RangeBucket.day:
        return Translations.get(lang, 'Giornaliero');
      case RangeBucket.week:
        return Translations.get(lang, 'Settimanale');
      case RangeBucket.month:
        return Translations.get(lang, 'Mensile');
      case RangeBucket.year:
        return Translations.get(lang, 'Annuale');
    }
  }

  pw.Widget _buildPdfInfoCard({required List<(String, String)> rows}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE2ECE0)),
      ),
      child: pw.Column(
        children: rows.indexed.map((entry) {
          final index = entry.$1;
          final row = entry.$2;

          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            decoration: pw.BoxDecoration(
              border: index == rows.length - 1
                  ? null
                  : const pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300),
                    ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        row.$1,
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        row.$2,
                        style: const pw.TextStyle(
                          fontSize: 11.5,
                          lineSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  pw.Widget _buildPdfSectionTitle(String title, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey700),
        ),
      ],
    );
  }

  pw.Widget _buildPdfMacroRow({
    required String label,
    required double grams,
    required double share,
    required PdfColor color,
    required String lang,
  }) {
    final percentage = (share.clamp(0.0, 1.0) * 100).round();
    return PdfGrafici.barraMacro(
      etichetta: label,
      dettaglio: '${UnitFormat.pNutriente(grams)} · $percentage% ${Translations.get(lang, 'della quota energetica')}',
      quota: share,
      colore: color,
    );
  }

  String _buildPdfMacroWarningText(MacroAnalysis analysis, String lang) {
    final messages = <String>[];
    if (analysis.showDominanceWarning) {
      messages.add(
        '${analysis.dominantLabel} ${Translations.get(lang, 'sopra l’80% della quota energetica: possibile squilibrio o dato anomalo.')}',
      );
    }
    if (analysis.showCalorieMismatchWarning) {
      messages.add(
        Translations.get(lang, 'I kcal derivati dai macro non sono coerenti con le calorie registrate: controlla unita` o mapping dei dati.'),
      );
    }

    return messages.join(' ');
  }

  /// Calcola tutte le metriche necessarie per la tab [bucket] attiva.
  ///
  /// Aggrega le entry filtrate in punti temporali, calcola totale, media,
  /// picco, distribuzione dei macro e gli insight automatici.
  /// Restituisce `null` se non ci sono punti nel periodo selezionato.
  // Raccoglie tutti i valori pronti per la tab attiva in un unico oggetto.
  TabAnalysisData? _buildTabAnalysis(RangeBucket bucket, String lang) {
    final window = _effectiveWindow(bucket);
    final points = _buildHistoryPointsFromEntries(
      bucket,
      sourceEntries: _entries,
      lang: lang,
      window: window,
    );
    // Solo i periodi con almeno una entry reale contribuiscono a
    // totale/media/picco/insight/macro: i periodi riempiti per completare la
    // serie continua (hasData=false) non vanno confusi con "zero registrato",
    // altrimenti la media si abbasserebbe artificialmente per i giorni in cui
    // l'utente ha semplicemente dimenticato di segnare qualcosa.
    final dataPoints = points.where((point) => point.hasData).toList();
    if (dataPoints.isEmpty) {
      return null;
    }

    final selectedValues = dataPoints.map(_selectedMetric.readFromPoint).toList();
    final totalValue = selectedValues.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final averageValue = totalValue / dataPoints.length;
    final peakPoint = dataPoints.reduce(
      (current, next) =>
          _selectedMetric.readFromPoint(next) >
              _selectedMetric.readFromPoint(current)
          ? next
          : current,
    );
    final analysisPoints =
        dataPoints.map((point) => point.toAnalysisPoint()).toList();
    final macroTotals = MacroTotals.fromPoints(analysisPoints);
    final macroAnalysis = MacroAnalysis.fromPoints(analysisPoints);

    return TabAnalysisData(
      points: points,
      totalValue: totalValue,
      averageValue: averageValue,
      peakPoint: peakPoint,
      macroTotals: macroTotals,
      macroAnalysis: macroAnalysis,
      trackedPeriods: dataPoints.length,
      totalPeriods: points.length,
      window: window,
      insights: _buildInsights(
        points: dataPoints,
        macroAnalysis: macroAnalysis,
        bucket: bucket,
        lang: lang,
      ),
    );
  }

  /// Restituisce la finestra temporale effettiva da mostrare per [bucket].
  ///
  /// Se l'utente ha scelto esplicitamente un intervallo dal date picker
  /// ([_customRange] non nullo), quello si applica a TUTTI i tab — è l'unica
  /// fonte di verità sia per la UI sia per il PDF, così la card "Totale" e i
  /// sottotitoli raccontano sempre la stessa storia invece di ignorare
  /// silenziosamente il filtro come accadeva prima. Altrimenti si usa una
  /// finestra di default sensata per il bucket, ancorata a oggi (non
  /// all'ultima entry: un buco recente nel diario deve restare visibile
  /// come tale, non sparire dalla vista).
  DateTimeRange _effectiveWindow(RangeBucket bucket) {
    final explicitRange = _customRange;
    if (explicitRange != null) {
      return DateTimeRange(
        start: _normalizeDate(explicitRange.start),
        end: _normalizeDate(explicitRange.end),
      );
    }

    final today = _normalizeDate(DateTime.now());
    switch (bucket) {
      case RangeBucket.day:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
        );
      case RangeBucket.week:
        final currentWeekStart = _resolvePeriodStart(today, RangeBucket.week);
        return DateTimeRange(
          start: currentWeekStart.subtract(const Duration(days: 7 * 11)),
          end: today,
        );
      case RangeBucket.month:
        final currentMonthStart = DateTime(today.year, today.month);
        return DateTimeRange(
          start: DateTime(currentMonthStart.year, currentMonthStart.month - 11),
          end: today,
        );
      case RangeBucket.year:
        if (_entries.isEmpty) {
          return DateTimeRange(start: today, end: today);
        }
        final firstEntry = _normalizeDate(_entries.first.entry_date);
        return DateTimeRange(start: DateTime(firstEntry.year), end: today);
    }
  }

  /// Prossimo inizio-periodo dopo [periodStart], per il [bucket] dato.
  DateTime _nextPeriodStart(DateTime periodStart, RangeBucket bucket) {
    switch (bucket) {
      case RangeBucket.day:
        return periodStart.add(const Duration(days: 1));
      case RangeBucket.week:
        return periodStart.add(const Duration(days: 7));
      case RangeBucket.month:
        return DateTime(periodStart.year, periodStart.month + 1);
      case RangeBucket.year:
        return DateTime(periodStart.year + 1);
    }
  }

  /// Elenca tutti gli inizio-periodo civili compresi in [window] (estremi
  /// inclusi). Usata per costruire una serie continua senza buchi
  /// invisibili, indipendentemente dal fatto che un periodo abbia dati.
  List<DateTime> _periodStartsInWindow(RangeBucket bucket, DateTimeRange window) {
    final starts = <DateTime>[];
    final lastStart = _resolvePeriodStart(window.end, bucket);
    var cursor = _resolvePeriodStart(window.start, bucket);
    while (!cursor.isAfter(lastStart)) {
      starts.add(cursor);
      cursor = _nextPeriodStart(cursor, bucket);
    }
    return starts;
  }

  /// Costruisce la serie continua di [HistoryPoint] per [bucket] entro
  /// [window]: un punto per OGNI periodo civile della finestra, non solo per
  /// quelli con almeno una entry. I periodi senza dati sono marcati
  /// [HistoryPoint.hasData] false invece di essere saltati, così il grafico
  /// mostra onestamente i buchi nel diario invece di accostare periodi
  /// distanti nel tempo come se fossero consecutivi.
  List<HistoryPoint> _buildHistoryPointsFromEntries(
    RangeBucket bucket, {
    required List<FoodEntry> sourceEntries,
    required String lang,
    required DateTimeRange window,
  }) {
    final windowStart = _resolvePeriodStart(window.start, bucket);
    final windowEnd = _resolvePeriodStart(window.end, bucket);

    // Raggruppiamo ogni entry nel suo bucket temporale e ne sommiamo i macro,
    // scartando ciò che cade fuori dalla finestra effettiva.
    final grouped = <DateTime, _HistoryAccumulator>{};
    for (final entry in sourceEntries) {
      final periodStart = _resolvePeriodStart(entry.entry_date, bucket);
      if (periodStart.isBefore(windowStart) || periodStart.isAfter(windowEnd)) {
        continue;
      }
      final accumulator = grouped.putIfAbsent(
        periodStart,
        _HistoryAccumulator.new,
      );
      accumulator.add(entry);
    }

    return _periodStartsInWindow(bucket, window).map((periodStart) {
      final accumulator = grouped[periodStart];
      return HistoryPoint(
        periodStart: periodStart,
        label: _buildLabel(periodStart, bucket, lang),
        calories: accumulator?.calories ?? 0.0,
        carbs: accumulator?.carbs ?? 0.0,
        proteins: accumulator?.proteins ?? 0.0,
        fats: accumulator?.fats ?? 0.0,
        hasData: accumulator != null,
        giorniConDati: accumulator?.giorni.length ?? 0,
      );
    }).toList();
  }

  /// Azzera la parte oraria di una data, mantenendo solo anno/mese/giorno.
  ///
  /// Serve per confrontare date senza che le ore influenzino il risultato.
  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  /// Calcola la data di inizio del periodo a cui appartiene [date] per il [bucket].
  ///
  /// Esempi:
  /// - bucket `day` → la data stessa
  /// - bucket `week` → il lunedì della settimana
  /// - bucket `month` → il primo del mese
  /// - bucket `year` → il primo gennaio dell'anno
  DateTime _resolvePeriodStart(DateTime date, RangeBucket bucket) {
    // Normalizziamo prima di tutto per non portarci dietro le ore della data originale.
    final normalized = DateTime(date.year, date.month, date.day);

    switch (bucket) {
      case RangeBucket.day:
        return normalized;
      case RangeBucket.week:
        final difference = normalized.weekday - DateTime.monday;
        return normalized.subtract(Duration(days: difference));
      case RangeBucket.month:
        return DateTime(normalized.year, normalized.month);
      case RangeBucket.year:
        return DateTime(normalized.year);
    }
  }

  /// Azzera il range personalizzato scelto dall'utente, tornando alle
  /// finestre di default per bucket (vedi [_effectiveWindow]).
  void _clearCustomRange() {
    setState(() => _customRange = null);
  }

  /// Etichetta "dd/mm/yyyy - dd/mm/yyyy" della finestra temporale effettiva.
  String _windowRangeLabel(DateTimeRange window) {
    return '${_formatDate(window.start)} - ${_formatDate(window.end)}';
  }

  /// Nome plurale del bucket nella lingua corrente (giorni/settimane/mesi/anni).
  String _bucketPluralNoun(RangeBucket bucket, String lang) {
    switch (bucket) {
      case RangeBucket.day:
        return Translations.get(lang, 'giorni');
      case RangeBucket.week:
        return Translations.get(lang, 'settimane');
      case RangeBucket.month:
        return Translations.get(lang, 'mesi');
      case RangeBucket.year:
        return Translations.get(lang, 'anni');
    }
  }

  /// Etichetta di copertura, es. "18/30 giorni con dati".
  ///
  /// Rende esplicito che Totale/Media riflettono solo i periodi realmente
  /// loggati, non l'intera finestra mostrata nel grafico — questa è
  /// l'informazione che prima mancava del tutto (nessuna indicazione di
  /// quanto sia affidabile/completa la media mostrata).
  String _coverageLabel(TabAnalysisData analysis, RangeBucket bucket, String lang) {
    final noun = _bucketPluralNoun(bucket, lang);
    return '${analysis.trackedPeriods}/${analysis.totalPeriods} $noun ${Translations.get(lang, 'con dati')}';
  }

  /// Numero medio di giorni civili coperti da un singolo punto del bucket.
  ///
  /// Usato per scalare un obiettivo giornaliero (calorieGoal ecc.) al livello
  /// di aggregazione corrente: 1 per il bucket giorno, 7 per settimana, media
  /// dei giorni/mese e giorni/anno per gli altri due. È un'approssimazione
  /// voluta: l'obiettivo mostrato è un singolo riferimento su tutto il
  /// grafico e non può variare barra per barra (i mesi hanno lunghezze
  /// diverse), ma resta coerente perché è la STESSA approssimazione usata
  /// sia nella StatTile "Media" sia nella linea di riferimento del grafico.
  double _averageDaysPerPeriod(RangeBucket bucket) {
    switch (bucket) {
      case RangeBucket.day:
        return 1;
      case RangeBucket.week:
        return 7;
      case RangeBucket.month:
        return 30.44;
      case RangeBucket.year:
        return 365.25;
    }
  }

  /// Obiettivo giornaliero impostato dall'utente per [metric], o null se non
  /// c'è un utente loggato o il campo non è stato impostato (convenzione già
  /// in uso altrove nell'app: goal <= 0 = non impostato, vedi
  /// widgets/nutrient_progress_bar.dart).
  double? _dailyGoalFor(MetricType metric) {
    final UserModel? user = ref.read(userProvider);
    if (user == null) {
      return null;
    }
    final goal = switch (metric) {
      MetricType.calories => user.calorieGoal,
      MetricType.carbs => user.carbGoal,
      MetricType.proteins => user.proteinGoal,
      MetricType.fats => user.fatGoal,
    };
    return goal > 0 ? goal : null;
  }

  /// Obiettivo scalato al livello di aggregazione di [bucket], confrontabile
  /// direttamente con [TabAnalysisData.averageValue]. Null se l'utente non ha
  /// impostato un obiettivo per la metrica selezionata.
  double? _scaledGoalFor(RangeBucket bucket) {
    final dailyGoal = _dailyGoalFor(_selectedMetric);
    if (dailyGoal == null) {
      return null;
    }
    return dailyGoal * _averageDaysPerPeriod(bucket);
  }

  /// Obiettivo da confrontare con la MEDIA del periodo, calcolato sui giorni
  /// davvero registrati e non sulla durata civile del periodo. Un anno con
  /// due mesi di diario veniva dichiarato "411991 kcal sotto obiettivo"
  /// anche con la media giornaliera sopra l'obiettivo (test di release 19/09).
  double? _obiettivoSuiGiorniRegistrati(TabAnalysisData analysis, RangeBucket bucket) {
    final dailyGoal = _dailyGoalFor(_selectedMetric);
    if (dailyGoal == null) return null;
    final conDati = analysis.points.where((p) => p.hasData).toList();
    if (conDati.isEmpty) return null;
    final giorni = conDati.fold<int>(0, (a, p) => a + p.giorniConDati);
    if (giorni <= 0) return dailyGoal * _averageDaysPerPeriod(bucket);
    return dailyGoal * giorni / conDati.length;
  }

  /// Testo di confronto tra la media del periodo e l'obiettivo personale,
  /// mostrato come sottotitolo della StatTile "Media". Null se l'utente non
  /// ha impostato un obiettivo per la metrica corrente (in quel caso la
  /// StatTile non mostra nessun sottotitolo, invece di un confronto inventato).
  String? _goalComparisonLabel(TabAnalysisData analysis, RangeBucket bucket, String lang) {
    final goal = _obiettivoSuiGiorniRegistrati(analysis, bucket);
    if (goal == null || goal <= 0) {
      return null;
    }

    final delta = analysis.averageValue - goal;
    final goalLabel = _selectedMetric.format(goal);
    if (delta.abs() <= goal * 0.05) {
      return '${Translations.get(lang, 'In linea con l’obiettivo')} ($goalLabel)';
    }

    final deltaLabel = _selectedMetric.format(delta.abs());
    final direction = delta > 0
        ? Translations.get(lang, 'sopra obiettivo')
        : Translations.get(lang, 'sotto obiettivo');
    return '$deltaLabel $direction · ${Translations.get(lang, 'obiettivo')} $goalLabel';
  }

  /// Genera l'etichetta testuale dell'asse X per un punto del grafico.
  ///
  /// Formato per bucket:
  /// - `day` → "3 Apr"
  /// - `week` → "3-9 Apr"
  /// - `month` → "Apr"
  /// - `year` → "2024"
  String _buildLabel(DateTime periodStart, RangeBucket bucket, String lang) {
    switch (bucket) {
      case RangeBucket.day:
        return '${periodStart.day} ${_monthShort(periodStart.month, lang)}';
      case RangeBucket.week:
        final weekEnd = periodStart.add(const Duration(days: 6));
        return '${periodStart.day}-${weekEnd.day} ${_monthShort(weekEnd.month, lang)}';
      case RangeBucket.month:
        return _monthShort(periodStart.month, lang);
      case RangeBucket.year:
        return periodStart.year.toString();
    }
  }

  String _monthShort(int month, String lang) {
    final months = <String>[
      Translations.get(lang, 'Gen'),
      Translations.get(lang, 'Feb'),
      Translations.get(lang, 'Mar'),
      Translations.get(lang, 'Apr'),
      Translations.get(lang, 'Mag'),
      Translations.get(lang, 'Giu'),
      Translations.get(lang, 'Lug'),
      Translations.get(lang, 'Ago'),
      Translations.get(lang, 'Set'),
      Translations.get(lang, 'Ott'),
      Translations.get(lang, 'Nov'),
      Translations.get(lang, 'Dic'),
    ];
    return months[month - 1];
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  /// Genera automaticamente le osservazioni testuali mostrate nella card insight.
  ///
  /// Include:
  /// - variazione percentuale rispetto al periodo precedente
  /// - avviso se un macro supera l'80% della quota energetica
  /// - avviso se le calorie dai macro non coincidono con quelle registrate
  List<String> _buildInsights({
    required List<HistoryPoint> points,
    required MacroAnalysis macroAnalysis,
    required RangeBucket bucket,
    required String lang,
  }) {
    final insights = <String>[];

    if (points.length >= 2) {
      final current = _selectedMetric.readFromPoint(points.last);
      final previous = _selectedMetric.readFromPoint(points[points.length - 2]);
      if (previous > 0) {
        final delta = ((current - previous) / previous) * 100;
        final direction = delta >= 0 ? '+' : '';
        insights.add(
          '$direction${delta.toStringAsFixed(0)}% ${Translations.get(lang, _selectedMetric.label.toLowerCase())} ${Translations.get(lang, 'rispetto al')} ${_previousBucketLabel(bucket, lang)} ${Translations.get(lang, 'precedente.')}'.trim(),
        );
      }
    }

    if (macroAnalysis.showDominanceWarning) {
      insights.add(
        '${Translations.get(lang, macroAnalysis.dominantLabel)} ${Translations.get(lang, 'sopra l’80% della quota energetica: possibile squilibrio o dato anomalo.')}',
      );
    } else if (macroAnalysis.hasMacroData) {
      // Niente "macro predominante" quando non ci sono dati: senza questo
      // controllo si otteneva un fuorviante "Grassi predominante con 0%"
      // ogni volta che il periodo non aveva macronutrienti registrati.
      insights.add(
        '${Translations.get(lang, macroAnalysis.dominantLabel)} ${Translations.get(lang, 'e` il macro predominante con')} ${macroAnalysis.dominantEnergyShareLabel} ${Translations.get(lang, 'della quota energetica')}.',
      );
    }

    if (macroAnalysis.showCalorieMismatchWarning) {
      insights.add(
        Translations.get(lang, 'I kcal derivati dai macro non sono coerenti con le calorie registrate: controlla unita` o mapping dei dati.'),
      );
    }

    return insights;
  }

  String _previousBucketLabel(RangeBucket bucket, String lang) {
    switch (bucket) {
      case RangeBucket.day:
        return Translations.get(lang, 'giorno');
      case RangeBucket.week:
        return Translations.get(lang, 'settimana');
      case RangeBucket.month:
        return Translations.get(lang, 'mese');
      case RangeBucket.year:
        return Translations.get(lang, 'anno');
    }
  }
}

/// Accumulatore mutabile usato durante l'aggregazione delle entry per bucket.
///
/// Per ogni bucket temporale viene creata un'istanza di questa classe;
/// il metodo [add] somma progressivamente i macro di ogni voce alimentare.
class _HistoryAccumulator {
  double calories = 0.0;
  double carbs = 0.0;
  double proteins = 0.0;
  double fats = 0.0;

  /// I giorni davvero registrati dentro il periodo: un mese in corso ne ha
  /// meno di trenta, e l'obiettivo va confrontato su quelli (19/09).
  final Set<DateTime> giorni = {};

  // Aggiunge i macronutrienti di una singola voce al totale del bucket.
  void add(FoodEntry entry) {
    calories += entry.macro.calories;
    carbs += entry.macro.carbs;
    proteins += entry.macro.proteins;
    fats += entry.macro.fats;
    giorni.add(DateTime(entry.entry_date.year, entry.entry_date.month, entry.entry_date.day));
  }
}
