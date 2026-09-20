// Inserimento manuale da zero: additivi e peso della porzione (2026-09-15).
//
// PERCHE' ESISTE: due screenshot di Ismail sulla stessa schermata. Scegliendo
// le famiglie di additivi il numero nella scheda qualita' restava "—"; e con
// "Per porzione" non c'era modo di dire quanto pesa la porzione dell'etichetta,
// quindi i valori venivano salvati come se la porzione fosse il peso mangiato.
// Si apre la pagina VERA, con i font veri (vedi segnala_visibile_test.dart).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutriapp/dictionary/translations.dart';
import 'package:nutriapp/domain/user_provider.dart';
import 'package:nutriapp/models/user_model.dart';
import 'package:nutriapp/screens/manual_entry_page.dart';
import 'package:nutriapp/theme_nutri.dart';

const _fontCache = r'C:\Users\ismai\flutter\bin\cache\artifacts\material_fonts';

Future<void> _caricaFont() async {
  final roboto = FontLoader('Roboto');
  for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']) {
    roboto.addFont(File('$_fontCache/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(File('$_fontCache/materialicons-regular.otf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  await icons.load();
}

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
      );
}

Future<void> _apri(WidgetTester tester, {Widget pagina = const ManualEntryPage()}) async {
  tester.view.physicalSize = const Size(412 * 2, 915 * 2);
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
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
  await tester.pump(const Duration(milliseconds: 200));
}

String _t(String chiave) => Translations.get('English', chiave);

Finder _campo(String etichetta) =>
    find.ancestor(of: find.text(etichetta), matching: find.byType(TextField)).first;

Future<void> _scrivi(WidgetTester tester, Finder campo, String testo) async {
  await tester.ensureVisible(campo);
  await tester.pump();
  await tester.enterText(campo, testo);
  await tester.pump();
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

  testWidgets('le famiglie di additivi scelte si contano nella scheda qualita\'', (tester) async {
    await _apri(tester);
    final conteggio = find.byKey(const Key('conteggio_additivi'));
    expect(tester.widget<Text>(conteggio).data, '—');

    for (final (famiglia, atteso) in [('Coloranti', '1'), ('Conservanti', '2')]) {
      final pastiglia = find.text(_t(famiglia));
      await tester.ensureVisible(pastiglia);
      await tester.pump();
      await tester.tap(pastiglia);
      await tester.pump();
      expect(tester.widget<Text>(conteggio).data, atteso, reason: 'dopo $famiglia');
    }
  });

  testWidgets('riaprendo un alimento della libreria le famiglie di additivi ci sono ancora', (tester) async {
    await _apri(
      tester,
      pagina: const ManualEntryPage(
        isEditingMaster: true,
        prefillData: {'food_name': 'Croissant', 'calories': 430, 'additives_tags': 'Coloranti, Aromi'},
      ),
    );
    expect(tester.widget<Text>(find.byKey(const Key('conteggio_additivi'))).data, '2');
  });

  testWidgets('per porzione: il peso della porzione scala i valori sul peso mangiato', (tester) async {
    await _apri(tester);
    final porzione = find.byKey(const Key('peso_porzione'));
    expect(porzione, findsOneWidget, reason: 'con "Per porzione" si deve poter scrivere il peso della porzione');

    await _scrivi(tester, _campo(_t('Calorie')), '100');
    await _scrivi(tester, porzione, '30');
    await _scrivi(tester, _campo(_t('Peso')), '60');

    // 100 kcal per una porzione da 30 g, mangiati 60 g: 200 kcal.
    expect(find.textContaining('${_t('AGGIUNGI')} 200'), findsOneWidget);
  });
}
