// "Proponi i valori corretti": si propone tutto, non solo i numeri (18/09).
//
// PERCHE' ESISTE: Ismail vuole che dalla segnalazione si possa correggere
// qualunque cosa si possa scrivere a mano — nome, marca, categoria, foto e
// tutti i nutrienti — e che l'admin accetti anche solo alcuni campi. Qui si
// controlla la parte dell'app: i campi di testo ci sono e bastano da soli a
// mandare la proposta.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutriapp/dictionary/translations.dart';
import 'package:nutriapp/domain/user_provider.dart';
import 'package:nutriapp/models/user_model.dart';
import 'package:nutriapp/screens/proponi_valori_page.dart';
import 'package:nutriapp/theme_nutri.dart';

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
      );
}

String _t(String chiave) => Translations.get('English', chiave);

Future<void> _apri(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412 * 2, 915 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [userProvider.overrideWith(() => _UtenteFinto())],
      child: MaterialApp(
        theme: temaNutri(Brightness.light),
        home: const ProponiValoriPage(
          product: {'food_name': 'Croissant', 'brand': 'Forno', 'barcode': '123', 'calories': 430},
          problema: 'nome',
        ),
      ),
    ),
  );
  await tester.pump();
}

FilledButton _invio(WidgetTester tester) => tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'initialize' ? true : null,
    );
  });

  testWidgets('la sezione identita\' e\' aperta e il nome basta a proporre', (tester) async {
    await _apri(tester);
    expect(find.text(_t('propose_section_identity').toUpperCase()), findsOneWidget);
    expect(_invio(tester).onPressed, isNull, reason: 'senza niente scritto non si manda');

    final nome = find.ancestor(of: find.text(_t('Nome')), matching: find.byType(Column)).first;
    await tester.ensureVisible(nome);
    await tester.pump();
    await tester.enterText(
      find.descendant(of: nome, matching: find.byType(TextField)).first,
      'Croissant integrale',
    );
    await tester.pump();
    expect(_invio(tester).onPressed, isNotNull, reason: 'un nome proposto basta');
  });

  testWidgets('ci sono anche la foto del prodotto e la qualita\'', (tester) async {
    await _apri(tester);
    // La pagina e' lunga: le sezioni in fondo si costruiscono scorrendo.
    Future<void> fino(String chiave) async {
      await tester.scrollUntilVisible(
        find.text(_t(chiave).toUpperCase()),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
    }

    await fino('propose_section_quality');
    expect(find.text(_t('propose_section_quality').toUpperCase()), findsOneWidget);
    await fino('propose_product_photo');
    expect(find.text(_t('propose_product_photo').toUpperCase()), findsOneWidget);
    // Le prove dell'etichetta restano, separate dalla foto proposta.
    await fino('propose_photos');
    expect(find.text(_t('propose_photos').toUpperCase()), findsOneWidget);
  });
}
