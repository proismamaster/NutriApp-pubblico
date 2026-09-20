// I select dell'app sono fogli dal basso (18/09).
//
// PERCHE' ESISTE: Ismail ha mandato lo screenshot della schermata Lingua e
// paese con il menu che copriva il campo e mezza pagina. Qui si controlla che
// le voci si aprano sotto, che la scelta torni indietro, e che il campo che ha
// aperto il foglio resti visibile.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/theme_nutri.dart';
import 'package:nutriapp/widgets/nutri_select.dart';

void main() {
  testWidgets('il foglio si apre, sceglie e non copre il campo', (tester) async {
    tester.view.physicalSize = const Size(412 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    String? scelto;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaNutri(Brightness.light),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: NutriSelect<String>(
                titolo: 'Lingua',
                valore: scelto,
                segnaposto: 'Scegli',
                opzioni: const [
                  NutriOpzione('English', 'English'),
                  NutriOpzione('Italiano', 'Italiano'),
                ],
                onCambiato: (v) => setState(() => scelto = v),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Scegli'), findsOneWidget);
    final campo = tester.getRect(find.byType(NutriSelect<String>));

    await tester.tap(find.text('Scegli'));
    await tester.pumpAndSettle();
    expect(find.text('Lingua'), findsOneWidget, reason: 'il foglio dice cosa si sta scegliendo');
    expect(find.text('Italiano'), findsOneWidget);

    // Il foglio sale dal basso: sta sotto al campo, non sopra.
    final foglio = tester.getRect(find.ancestor(
      of: find.text('Italiano'),
      matching: find.byType(SafeArea),
    ).last);
    expect(foglio.top, greaterThanOrEqualTo(campo.bottom));

    await tester.tap(find.text('Italiano'));
    await tester.pumpAndSettle();
    expect(scelto, 'Italiano');
    expect(find.text('Italiano'), findsOneWidget, reason: 'la scelta resta scritta nel campo');
  });
}
