// Riquadro del pasto quando l'obiettivo manca (18/09).
//
// PERCHE' ESISTE: screenshot di Ismail con "418/0 kcal" e la barra ferma a
// zero. Senza obiettivo qualunque cosa mangiata e' oltre: barra piena e rossa,
// e si scrivono le sole kcal invece di un "/0" che sembra un conto vero.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/theme_nutri.dart';
import 'package:nutriapp/widgets/meal_tile.dart';

Future<void> _apri(WidgetTester tester, {required double mangiate, required double obiettivo}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: temaNutri(Brightness.light),
      home: Scaffold(
        body: SizedBox(
          width: 200,
          child: MealTile(
            label: 'Colazione',
            icon: Icons.coffee,
            eatenKcal: mangiate,
            targetKcal: obiettivo,
            hasEntries: mangiate > 0,
            onTap: () {},
            onAdd: () {},
          ),
        ),
      ),
    ),
  );
}

double _riempimento(WidgetTester tester) =>
    tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value ?? -1;

void main() {
  testWidgets('senza obiettivo: barra piena e niente "/0"', (tester) async {
    await _apri(tester, mangiate: 418, obiettivo: 0);
    expect(find.textContaining('/0'), findsNothing);
    expect(find.textContaining('418'), findsOneWidget);
    expect(_riempimento(tester), 1.0);
  });

  testWidgets('senza obiettivo e senza cibo: barra vuota', (tester) async {
    await _apri(tester, mangiate: 0, obiettivo: 0);
    expect(_riempimento(tester), 0.0);
  });

  testWidgets('con obiettivo: la barra segue le calorie mangiate', (tester) async {
    await _apri(tester, mangiate: 300, obiettivo: 600);
    expect(_riempimento(tester), 0.5);
    expect(find.textContaining('300/600'), findsOneWidget);
  });
}
