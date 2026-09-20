// Banco di prova per i giri end-to-end (19/09, test di release).
//
// L'app VERA (MyApp, con AuthGate, tema, lingue, unita') gira dentro
// flutter_test ma parla con un server PHP locale via rete vera: gli scenari
// fanno cio' che farebbe una persona (tocchi, testo, cambi di pagina) e il
// database locale registra cio' che succede. A ogni passo si raccolgono gli
// errori di layout e si puo' salvare uno scatto e il testo visibile.
//
// Si lancia con:
//   flutter test test_e2e/<scenario>_test.dart --dart-define=NUTRI_API=http://127.0.0.1:8790/
// Senza NUTRI_API gli scenari si saltano: non devono mai toccare il server vero.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:barcode_scan2/gen/protos/protos.pb.dart' as proto;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutriapp/dictionary/translations.dart';
import 'package:nutriapp/main.dart';

const serverLocale = String.fromEnvironment('NUTRI_API');
bool get senzaServer => !serverLocale.startsWith('http://127.0.0.1');

/// Dove finiscono scatti e diari di ogni scenario. Si cambia con E2E_SCATTI.
final String cartellaScatti =
    Platform.environment['E2E_SCATTI'] ?? '${Directory.systemTemp.path}/nutriapp_e2e/scatti';

/// I font veri di Flutter: senza, ogni testo esce come una fila di rettangoli
/// e gli scatti non servono a niente. Si cambia con E2E_FONTS.
final String cartellaFont = Platform.environment['E2E_FONTS'] ??
    r'C:\Users\ismai\flutter\bin\cache\artifacts\material_fonts';

/// Il client mysql con cui si preparano e si controllano i dati.
final String mysql = Platform.environment['E2E_MYSQL'] ?? r'C:\xampp\mysql\bin\mysql.exe';

/// Il database di prova: mai quello vero, mai quello dell'hosting.
final String databaseProva = Platform.environment['E2E_DB'] ?? 'nutriapp_e2e';

/// Rete vera solo verso il server locale: USDA, Google Translate e
/// OpenFoodFacts restano fuori (le prove non devono uscire su internet), come
/// se fossero irraggiungibili.
class _SoloLocale extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (uri, proxyHost, proxyPort) {
      if (uri.host == '127.0.0.1') return Socket.startConnect(uri.host, uri.port);
      return Future.error(SocketException('bloccato nel banco di prova: ${uri.host}'));
    };
    return client;
  }
}

Future<void> preparaBanco() async {
  // flutter_test risponde 400 a ogni richiesta: qui serve la rete vera, verso
  // il solo server locale (NUTRI_API).
  HttpOverrides.global = _SoloLocale();
  final roboto = FontLoader('Roboto');
  for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']) {
    roboto.addFont(File('$cartellaFont/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')
        ..addFont(File('$cartellaFont/materialicons-regular.otf').readAsBytes().then((b) => ByteData.view(b.buffer))))
      .load();
  Directory(cartellaScatti).createSync(recursive: true);
}

/// Una query sul database di prova, per preparare o controllare i dati.
Future<String> sql(String query) async {
  final r = await Process.run(mysql, ['-u', 'root', '-N', '-B', '--default-character-set=utf8mb4', databaseProva, '-e', query]);
  if (r.exitCode != 0) throw StateError('sql fallita: ${r.stderr}');
  return (r.stdout as String).trim();
}

class Banco {
  Banco(this.t, this.scenario);

  final WidgetTester t;
  final String scenario;
  final GlobalKey _radice = GlobalKey();
  final List<String> problemi = [];
  final StringBuffer diario = StringBuffer();
  void Function(FlutterErrorDetails)? _gestorePrima;
  String _passo = 'avvio';

  /// Lingua dell'app in questo momento: la imposta avvia() e va aggiornata
  /// dallo scenario quando la cambia. Serve al controllo delle traduzioni.
  String lingua = 'English';
  final Set<String> _traduzioniSegnalate = {};
  int _scatti = 0;
  int pdfCondivisi = 0;

  /// Percorso che il selettore di immagini finto restituisce (null = annullato).
  String? fotoFinta;

  /// Codice che lo scanner finto legge; null = annullato, 'NEGATO' = niente fotocamera.
  String? codiceFinto;

  static const _canali = [
    'dexterous.com/flutter/local_notifications',
    'flutter_timezone',
    'de.mintware.barcode_scan',
    'de.mintware.barcode_scan/events',
    'net.nfet.printing',
    'plugins.flutter.io/image_picker',
  ];

  Future<void> avvia({Map<String, Object> preferenze = const {}, Size schermo = const Size(412, 915)}) async {
    // Sessione gia' aperta: chi parte da "utente dentro" ha bisogno del
    // gettone, altrimenti ogni richiesta torna 401 (autenticazione del 20/09).
    final pref = Map<String, Object>.from(preferenze);
    if (pref.containsKey('user_email') && !pref.containsKey('auth_token')) {
      final token = List.generate(64, (i) => '0123456789abcdef'[Random().nextInt(16)]).join();
      await t.runAsync(() => sql(
          "INSERT INTO na_sessions (token, user_mail) VALUES ('$token','${pref['user_email']}')"));
      pref['auth_token'] = token;
    }
    SharedPreferences.setMockInitialValues(pref);
    lingua = (pref['app_language'] as String?) ?? 'English';
    final messaggero = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final c in _canali) {
      messaggero.setMockMethodCallHandler(MethodChannel(c), (call) async {
        switch (call.method) {
          case 'initialize':
          case 'requestNotificationsPermission':
          case 'requestPermissions':
            return true;
          case 'printingInfo':
            // Il plugin di stampa in flutter_test non risponde: senza questa
            // mappa PdfPreview lancia un Null check e nasconde i problemi veri.
            return <String, dynamic>{
              'directPrint': false,
              'dynamicLayout': false,
              'canPrint': false,
              'canConvertHtml': false,
              'canShare': true,
              'canRaster': false,
              'canListPrinters': false,
            };
          case 'getLocalTimezone':
            return 'Europe/Rome';
          case 'requestCameraPermission':
            return false;
          case 'scan':
            // Lo scanner finto: un codice, "annullato" (null) o permesso negato.
            if (codiceFinto == 'NEGATO') throw PlatformException(code: BarcodeScanner.cameraAccessDenied);
            return (proto.ScanResult()
                  ..type = codiceFinto == null ? ResultType.Cancelled : ResultType.Barcode
                  ..format = BarcodeFormat.ean13
                  ..rawContent = codiceFinto ?? '')
                .writeToBuffer();
          case 'pickImage':
            return fotoFinta;
          case 'pickMultiImage':
          case 'pickMultiImageWithOptions':
            return fotoFinta == null ? null : [fotoFinta];
          case 'sharePdf':
            // Il PDF "condiviso" finisce accanto agli scatti, per guardarlo.
            final doc = (call.arguments as Map)['doc'] as Uint8List;
            File('$cartellaScatti/${scenario}_${++pdfCondivisi}.pdf').writeAsBytesSync(doc);
            return true;
          default:
            return null;
        }
      });
    }
    t.view.physicalSize = Size(schermo.width * 2, schermo.height * 2);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);

    _gestorePrima = FlutterError.onError;
    FlutterError.onError = (dettagli) {
      final riga = dettagli.exceptionAsString().split('\n').first;
      // Le prime righe dello stack che stanno nel codice dell'app: dicono dove.
      final dove = (dettagli.stack?.toString() ?? '')
          .split('\n')
          .where((r) => r.contains('package:nutriapp/'))
          .take(3)
          .map((r) => r.replaceAll(RegExp(r'^#\d+\s+'), '').trim())
          .join(' <- ');
      problemi.add('[$_passo] $riga${dove.isEmpty ? '' : '  @ $dove'}');
    };
    await t.pumpWidget(RepaintBoundary(key: _radice, child: const ProviderScope(child: MyApp())));
    await attendi(1500);
  }

  /// Lascia correre la rete vera e ridisegna.
  ///
  /// Tanti giri corti e non pochi lunghi: una catena di richieste (salva, poi
  /// ricarica riepilogo, poi voci) avanza di un anello per ogni giro fra rete
  /// vera e ridisegno. Con tre giri la schermata restava "un passo indietro".
  Future<void> attendi([int ms = 900]) async {
    final giri = (ms / 120).ceil().clamp(4, 60);
    for (var i = 0; i < giri; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await t.pump(const Duration(milliseconds: 40));
    }
    await t.pump(const Duration(milliseconds: 400));
  }

  void passo(String nome) {
    _passo = nome;
    diario.writeln('--- $nome');
  }

  Future<void> tocca(Finder f, {int attesa = 900, bool primo = true}) async {
    final bersaglio = primo ? f.first : f;
    expect(bersaglio, findsOneWidget, reason: 'passo "$_passo": manca $f');
    // Scorre solo se serve: ensureVisible porta sempre il bersaglio in cima
    // e sposterebbe elenchi gia' visibili (sembrerebbe un difetto dell'app).
    final r = t.getRect(bersaglio);
    final alto = t.view.physicalSize.height / t.view.devicePixelRatio;
    // Margini: barra in alto e barra di navigazione in basso coprono l'elenco.
    if (r.top < 0 || r.bottom > alto - 100) {
      await t.ensureVisible(bersaglio);
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.tap(bersaglio, warnIfMissed: false);
    await attendi(attesa);
  }

  Future<void> scrivi(Finder campo, String testo) async {
    final bersaglio = campo.first;
    await t.ensureVisible(bersaglio);
    await t.pump();
    await t.enterText(bersaglio, testo);
    await t.pump(const Duration(milliseconds: 200));
  }

  /// Il campo di testo che sta nella stessa colonna di un'etichetta visibile.
  Finder campoDi(String etichetta) => find.descendant(
        of: find.ancestor(of: find.text(etichetta).first, matching: find.byType(Column)).first,
        matching: find.byType(TextField),
      );

  Future<void> indietro() async {
    final back = find.byTooltip('Back');
    if (back.evaluate().isNotEmpty) {
      await tocca(back);
      return;
    }
    await t.binding.handlePopRoute();
    await attendi();
  }

  /// Aspetta che un testo compaia (rete lenta, animazioni): false se non
  /// compare entro [secondi].
  Future<bool> aspettaTesto(String testo, {int secondi = 10, bool parziale = false}) async {
    for (var i = 0; i < secondi * 2; i++) {
      if (parziale ? vedeParte(testo) : vede(testo)) return true;
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await t.pump(const Duration(milliseconds: 100));
    }
    problemi.add('[$_passo] "$testo" non comparso entro $secondi s');
    return false;
  }

  /// Toglie la snackbar aperta, come farebbe un dito che la scorre via.
  Future<void> viaSnackbar() async {
    for (final e in find.byType(ScaffoldMessenger).evaluate()) {
      (e as StatefulElement).state is ScaffoldMessengerState
          ? (e.state as ScaffoldMessengerState).removeCurrentSnackBar()
          : null;
    }
    await t.pump(const Duration(milliseconds: 300));
  }

  bool vede(String testo) => find.text(testo).evaluate().isNotEmpty;
  bool vedeParte(String testo) => find.textContaining(testo).evaluate().isNotEmpty;

  /// I testi visibili sullo schermo, uno per riga: per leggere la pagina come
  /// farebbe una persona.
  List<String> testi() {
    final fuori = <String>[];
    for (final e in find.byType(RichText).evaluate()) {
      final w = e.widget as RichText;
      final s = w.text.toPlainText().trim();
      if (s.isNotEmpty && !fuori.contains(s)) fuori.add(s);
    }
    for (final e in find.byType(EditableText).evaluate()) {
      final s = (e.widget as EditableText).controller.text.trim();
      if (s.isNotEmpty) fuori.add('[campo] $s');
    }
    return fuori;
  }

  static final _parolaItaliana = RegExp(
      r"(^|\s)(il|lo|la|gli|le|di|del|della|dei|delle|con|una|uno|sono|questo|questa|alimento|pasto|giorno|salva|elimina|annulla|completa|completo|porzione|nessun|nessuna|ancora|oggi|ieri)(\s|$|[.,:!?])",
      caseSensitive: false);
  static final _chiaveGrezza = RegExp(r'^[a-z]+(_[a-z0-9]+)+$');

  /// Testi visibili che non sono nella lingua dell'app: chiavi grezze, voci
  /// del dizionario rimaste nella lingua di partenza, parole italiane in una
  /// schermata straniera.
  List<String> controllaTraduzioni() {
    final fuori = <String>[];
    final mappa = Translations.strings[lingua] ?? const {};
    for (final testo in testi()) {
      if (testo.startsWith('[campo]')) continue;
      final riga = testo.replaceAll(RegExp(r'\s+'), ' ');
      String? motivo;
      if (_chiaveGrezza.hasMatch(riga)) {
        motivo = 'chiave grezza';
      } else if (lingua != 'Italiano') {
        final tradotta = mappa[riga];
        final eChiave = Translations.strings.values.any((m) => m.containsKey(riga));
        if (eChiave && tradotta == null) {
          motivo = 'manca in $lingua';
        } else if (eChiave && tradotta != null && tradotta != riga) {
          motivo = 'mostrata la chiave invece di "$tradotta"';
        } else if (_parolaItaliana.hasMatch(riga)) {
          motivo = 'sembra italiano';
        }
      }
      if (motivo != null && _traduzioniSegnalate.add('$lingua|$riga')) {
        fuori.add('"$riga" ($motivo)');
      }
    }
    return fuori;
  }

  Future<void> scatta(String nome) async {
    for (final f in controllaTraduzioni()) {
      problemi.add('[$_passo] TRADUZIONE $f');
    }
    _scatti++;
    final file = '${scenario}_${_scatti.toString().padLeft(2, '0')}_$nome';
    diario.writeln('scatto $file');
    diario.writeln(testi().map((s) => '  | ${s.replaceAll('\n', ' ')}').join('\n'));
    await t.runAsync(() async {
      final b = _radice.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1.0);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$cartellaScatti/$file.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  /// Esegue lo scenario e chiude sempre: se un passo fallisce, l'errore va
  /// nel log (con lo scatto dello schermo in quel momento) invece di perdersi
  /// dietro all'assert di flutter_test su FlutterError.onError.
  Future<void> giro(Future<void> Function() corpo) async {
    Object? errore;
    try {
      await corpo();
    } catch (e, st) {
      errore = e;
      problemi.add('[$_passo] FALLITO: ${e.toString().split('\n').take(3).join(' ')}');
      diario.writeln('STACK: ${st.toString().split('\n').take(8).join('\n')}');
      try {
        await scatta('ERRORE');
      } catch (_) {}
    }
    await chiudi();
    if (errore != null) fail('scenario $scenario fermo al passo "$_passo": $errore');
  }

  Future<void> chiudi() async {
    FlutterError.onError = _gestorePrima;
    final rapporto = StringBuffer()
      ..writeln('SCENARIO $scenario')
      ..writeln('PROBLEMI (${problemi.length}):')
      ..writeAll(problemi.map((p) => '  $p\n'))
      ..writeln()
      ..write(diario);
    File('$cartellaScatti/$scenario.log').writeAsStringSync(rapporto.toString());
    // Chiude l'app dentro il test, cosi' timer e animazioni non restano appesi.
    await t.pumpWidget(const SizedBox());
    // Timer lasciati dall'app (snackbar, ritardi): si fanno scadere.
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(seconds: 5));
    }
  }
}
