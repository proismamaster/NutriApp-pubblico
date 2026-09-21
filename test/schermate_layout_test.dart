// Due difetti segnalati il 2026-09-12, ognuno con la sua prova.
//
// 1. La Home, su uno schermo corto, finiva schiacciata a sinistra con una
//    fascia vuota a destra (visto sul telefono di un amico di Ismail).
// 2. In "Il mio profilo", scritta un'altezza fuori intervallo e poi corretta,
//    l'errore restava a schermo e il salvataggio restava bloccato.
//
// Entrambi i test fanno girare le SCHERMATE VERE, non una copia della loro
// struttura: e' la lezione dell'08/09 (una prova sui pezzi estratti non
// passava dal `require` e non poteva vedere il difetto).

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutriapp/MainLayout.dart';
import 'package:nutriapp/dictionary/translations.dart';
import 'package:nutriapp/domain/user_provider.dart';
import 'package:nutriapp/models/user_model.dart';
import 'package:nutriapp/screens/profile_page.dart';
import 'package:nutriapp/widgets/segnala_alimento.dart';
import 'package:nutriapp/theme_nutri.dart';
import 'cartella_font.dart';

/// Senza font veri il binding headless disegna ogni glifo come un quadrato,
/// e le altezze del testo (da cui dipende la riduzione della Home) non sono
/// quelle dell'app.
const _caricaFont = caricaFontDiProva;

final _utenteFinto = UserModel(
  id: 1,
  email: 'test@example.com',
  firstName: 'Ismaa',
  lastName: 'Barakata',
  height: 174,
  gender: 'male',
  birthDate: DateTime(2007, 9, 17),
  createdAt: DateTime(2026, 1, 1),
  currentWeight: 50.1,
  targetWeight: 48.0,
  calorieGoal: 960,
  carbGoal: 108,
  proteinGoal: 72,
  fatGoal: 32,
);

class _UtenteFinto extends UserNotifier {
  @override
  UserModel? build() => _utenteFinto;
}

Future<void> _apri(WidgetTester tester, Widget schermata, {required Size schermo}) async {
  tester.view.physicalSize = schermo * 2;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: temaNutri(Brightness.light),
      debugShowCheckedModeBanner: false,
      home: schermata,
    ),
  );
  // Le chiamate di rete (fallite, qui non c'e' rete) non avanzano col tempo
  // finto dei test: serve tempo di orologio vero prima di guardare la pagina.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(_caricaFont);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'initialize' ? true : null,
    );
  });

  // L'area della Home (sotto la barra, sopra la navigazione) e le due misure
  // che contano: la griglia dei pasti per i margini, il riquadro del peso,
  // ultimo della pagina, per il fondo.
  ({Rect area, Rect pasti, Rect peso}) misuraHome(WidgetTester tester) {
    final peso = find.byKey(const Key('home_peso'));
    final area = find.ancestor(of: peso, matching: find.byType(RefreshIndicator)).first;
    return (
      area: tester.getRect(area),
      pasti: tester.getRect(find.byKey(const Key('home_pasti'))),
      peso: tester.getRect(peso),
    );
  }

  testWidgets('Home: su schermo corto resta centrata e larga, senza scorrere', (tester) async {
    // 412x620: piu' corto di quanto serva alla Home, quindi il contenuto
    // viene rimpicciolito — la condizione in cui comparivano la fascia vuota
    // a destra (12/09) e poi le due fasce ai lati (14/09).
    await _apri(
      tester,
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _UtenteFinto())],
        child: const MainLayout(),
      ),
      schermo: const Size(412, 620),
    );

    final m = misuraHome(tester);
    final margineSinistro = m.pasti.left;
    final margineDestro = 412 - m.pasti.right;
    expect(
      (margineSinistro - margineDestro).abs(),
      lessThan(1.0),
      reason: 'margini asimmetrici: sinistro $margineSinistro, destro $margineDestro',
    );
    // Il bordo della Home e' 20: rimpicciolita, il margine puo' solo
    // diminuire. Uno piu' grande e' una fascia vuota ai lati.
    expect(margineSinistro, lessThanOrEqualTo(20.5), reason: 'fascia vuota ai lati: margine $margineSinistro');
    expect(m.peso.bottom, lessThanOrEqualTo(m.area.bottom + 0.5),
        reason: 'il peso esce dallo schermo: per vederlo bisognerebbe scorrere');
  });

  testWidgets('Home: su schermo alto riempie anche in altezza, senza vuoto in fondo', (tester) async {
    // 412x915: un telefono alto, dove prima la Home restava a misura naturale
    // e sotto il peso avanzava una fascia vuota.
    await _apri(
      tester,
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _UtenteFinto())],
        child: const MainLayout(),
      ),
      schermo: const Size(412, 915),
    );

    final m = misuraHome(tester);
    final vuotoInFondo = m.area.bottom - m.peso.bottom;
    // Resta solo il bordo inferiore della Home (10).
    expect(vuotoInFondo, lessThan(12), reason: 'vuoto in fondo alla Home: $vuotoInFondo px');
    expect(vuotoInFondo, greaterThanOrEqualTo(-0.5), reason: 'il peso esce dallo schermo');
    expect(m.pasti.left, closeTo(20, 0.5), reason: 'a misura piena il margine e\' quello vero');
  });

  testWidgets('Profilo: correggere l\'altezza toglie l\'errore e sblocca il salvataggio', (tester) async {
    await _apri(
      tester,
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _UtenteFinto())],
        child: const ProfilePage(),
      ),
      schermo: const Size(412, 900),
    );

    // 'English' e non 'Italiano': con le preferenze vuote l'app parte in
    // inglese (`locale_provider.dart`), quindi e' quello che il test vede.
    const lingua = 'English';
    final errore = find.text(Translations.get(lingua, 'profile_height_error'));
    final controlla = find.text(Translations.get(lingua, 'save_check_fields'));
    final salva = find.text(Translations.get(lingua, 'save_changes'));

    await tester.enterText(find.byKey(const Key('profilo_altezza')), '2');
    await tester.pump();
    expect(errore, findsOneWidget, reason: '2 cm non e\' un\'altezza valida');
    expect(controlla, findsOneWidget);

    await tester.enterText(find.byKey(const Key('profilo_altezza')), '200');
    await tester.pump();
    expect(errore, findsNothing, reason: 'l\'errore deve sparire appena il valore torna valido');
    expect(salva, findsOneWidget, reason: 'e il pulsante deve tornare salvabile');
  });

  testWidgets('Profilo: un peso non numerico viene segnalato invece di essere scartato in silenzio', (tester) async {
    await _apri(
      tester,
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _UtenteFinto())],
        child: const ProfilePage(),
      ),
      schermo: const Size(412, 900),
    );

    const lingua = 'English';
    await tester.enterText(find.byKey(const Key('profilo_peso')), '0');
    await tester.pump();
    expect(find.text(Translations.get(lingua, 'profile_weight_error')), findsOneWidget);
    expect(find.text(Translations.get(lingua, 'save_check_fields')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('profilo_peso')), '54.2');
    await tester.pump();
    expect(find.text(Translations.get(lingua, 'profile_weight_error')), findsNothing);
    expect(find.text(Translations.get(lingua, 'save_changes')), findsOneWidget);
  });

  testWidgets('Segnala alimento: etichetta leggibile sul verde pieno', (tester) async {
    // PERCHE' QUESTO TEST: il pulsante aveva `foregroundColor: onPrimary` e
    // l'etichetta usciva comunque del grigio-verde ereditato dal dialogo,
    // sopra il verde pieno. Misurato, non visto a occhio — e per correggerlo
    // e' servito scrivere il colore anche sul testo. Se qualcuno lo togliesse
    // "perche' e' ridondante", il difetto tornerebbe in silenzio.
    tester.view.physicalSize = const Size(412 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    // ProviderScope FUORI da MaterialApp, come in main.dart: un dialogo vive
    // nell'Overlay della route radice, sopra `home`.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [userProvider.overrideWith(() => _UtenteFinto())],
        child: MaterialApp(
          theme: temaNutri(Brightness.light),
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => mostraSegnalaAlimento(
                    context,
                    product: const {'food_name': 'Croissant', 'barcode': '8001234567890'},
                  ),
                  child: const Text('apri'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('apri'));
    // Dal 15/09 e' un foglio dal basso: bisogna aspettare che sia salito,
    // altrimenti il tocco sotto cade fuori schermo.
    await tester.pumpAndSettle();

    // Serve un tipo di problema scelto, altrimenti il pulsante e' spento e il
    // colore da controllare e' un altro.
    const lingua = 'English';
    await tester.tap(find.text(Translations.get(lingua, 'report_issue_valori')));
    await tester.pump(const Duration(milliseconds: 200));

    final etichetta = tester.renderObject<RenderParagraph>(
      find.text(Translations.get(lingua, 'report_send')),
    );
    final scheme = temaNutri(Brightness.light).colorScheme;
    expect(
      etichetta.text.style?.color,
      scheme.onPrimary,
      reason: 'etichetta senza il colore di contrasto del verde pieno',
    );
  });
}
