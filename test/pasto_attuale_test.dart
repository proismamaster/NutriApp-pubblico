// Il pasto dell'ora per "Per te" (2026-09-15): i bordi delle fasce sono il
// punto dove un errore di un minuto consiglia la cena a colazione.
import 'package:flutter_test/flutter_test.dart';

import 'package:nutriapp/logic/pasto_attuale.dart';

DateTime _alle(int ora, int minuto) => DateTime(2026, 9, 15, ora, minuto);

void main() {
  test('colazione dalle 5:00 alle 10:29', () {
    expect(pastoDellOra(_alle(4, 59)), 'spuntino');
    expect(pastoDellOra(_alle(5, 0)), 'colazione');
    expect(pastoDellOra(_alle(10, 29)), 'colazione');
    expect(pastoDellOra(_alle(10, 30)), 'spuntino');
  });

  test('pranzo dalle 11:00 alle 14:59', () {
    expect(pastoDellOra(_alle(10, 59)), 'spuntino');
    expect(pastoDellOra(_alle(11, 0)), 'pranzo');
    expect(pastoDellOra(_alle(14, 59)), 'pranzo');
    expect(pastoDellOra(_alle(15, 0)), 'spuntino');
  });

  test('cena dalle 18:00 alle 22:59, poi spuntino fino al mattino', () {
    expect(pastoDellOra(_alle(17, 59)), 'spuntino');
    expect(pastoDellOra(_alle(18, 0)), 'cena');
    expect(pastoDellOra(_alle(22, 59)), 'cena');
    expect(pastoDellOra(_alle(23, 0)), 'spuntino');
    expect(pastoDellOra(_alle(2, 0)), 'spuntino');
  });
}
