// Il tasto "Segnala un errore" nella pagina di un alimento (2026-09-14).
//
// PERCHE' ESISTE: fino al 13/09 il tasto stava solo in fondo alla scheda info,
// che si apre solo per i prodotti OpenFoodFacts con dati extra. Ismail l'ha
// cercato sul telefono e non l'ha trovato: per un alimento del CREA, o per un
// prodotto senza foto, non c'era proprio. Qui si apre la pagina VERA e si
// guarda la barra in alto, anche su un telefono stretto.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutriapp/dictionary/translations.dart';
import 'package:nutriapp/domain/user_provider.dart';
import 'package:nutriapp/models/user_model.dart';
import 'package:nutriapp/screens/manual_entry_page.dart';
import 'package:nutriapp/theme_nutri.dart';
import 'cartella_font.dart';

/// Font veri, come in schermate_layout_test.dart. Senza, il binding dei test
/// disegna ogni lettera come un quadrato largo quanto il corpo del testo: le
/// righe risultano larghe il doppio che sul telefono, e a 360 dp il test
/// "trova" overflow che sullo schermo vero non ci sono.
const _caricaFont = caricaFontDiProva;

class _UtenteFinto extends UserNotifier {
  @override
  UserModel? build() => UserModel(
        id: 1,
        email: 'test@example.com',
        firstName: 'Ismail',
        lastName: 'Barakat',
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
}

/// Un alimento del CREA: niente Nutri-Score, niente foto, niente allergeni —
/// quindi nessuna scheda info, ed era proprio il caso senza tasto.
const _mela = <String, dynamic>{
  'food_name': 'Mela, cruda',
  'calories': 52,
  'carbs': 13.8,
  'proteins': 0.3,
  'fats': 0.2,
  'fonte': 'crea',
};

final _tasto = find.byTooltip(Translations.get('English', 'report_food_action'));

Future<void> _apri(WidgetTester tester, Widget pagina) async {
  // 360 dp: uno dei telefoni piu' stretti in circolazione. Con informazioni,
  // bandierina e matita la barra in alto e' al limite.
  tester.view.physicalSize = const Size(360 * 2, 800 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [userProvider.overrideWith(() => _UtenteFinto())],
      child: MaterialApp(
        theme: temaNutri(Brightness.light),
        debugShowCheckedModeBanner: false,
        home: pagina,
      ),
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'initialize' ? true : null,
    );
  });

  testWidgets('alimento trovato del CREA, senza scheda info: il tasto Segnala c\'e\'', (tester) async {
    await _apri(tester, const ManualEntryPage(prefillData: _mela, isAddingFromLibrary: true));
    expect(_tasto, findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'niente overflow nella barra su 360 dp');
  });

  testWidgets('dati trovati ma da correggere nel form completo: il tasto resta', (tester) async {
    await _apri(tester, const ManualEntryPage(prefillData: _mela));
    expect(_tasto, findsOneWidget);
  });

  testWidgets('inserimento a mano da zero: non c\'e\' niente da segnalare', (tester) async {
    await _apri(tester, const ManualEntryPage());
    expect(_tasto, findsNothing);
  });

  testWidgets('modifica della propria libreria: l\'errore si corregge, non si segnala', (tester) async {
    await _apri(tester, const ManualEntryPage(prefillData: _mela, isEditingMaster: true));
    expect(_tasto, findsNothing);
  });
}
