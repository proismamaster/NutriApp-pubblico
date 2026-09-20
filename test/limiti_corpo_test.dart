// Limiti dei dati del corpo (2026-09-14).
//
// PERCHE' ESISTE: fino al 13/09 si poteva creare un account di 3 anni e 2 kg.
// Questi test fissano gli estremi — il valore limite ammesso e quello subito
// fuori — perche' e' li' che un `<` scritto al posto di un `<=` sbaglia.
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriapp/logic/limiti_corpo.dart';

void main() {
  final oggi = DateTime(2026, 9, 14);

  group('eta', () {
    test('14 anni compiuti oggi si, un giorno prima no', () {
      expect(LimitiCorpo.erroreNascita(DateTime(2012, 9, 14), oggi), isNull);
      expect(LimitiCorpo.erroreNascita(DateTime(2012, 9, 15), oggi), 'limit_age_young');
    });

    test('100 anni si, 101 no', () {
      expect(LimitiCorpo.erroreNascita(DateTime(1926, 9, 14), oggi), isNull);
      expect(LimitiCorpo.erroreNascita(DateTime(1925, 9, 14), oggi), 'limit_age_old');
    });

    test('senza data: manca', () {
      expect(LimitiCorpo.erroreNascita(null, oggi), 'limit_birth_missing');
    });

    test('gli estremi del calendario sono date ammesse, un giorno oltre no', () {
      expect(LimitiCorpo.erroreNascita(LimitiCorpo.nascitaPiuRecente(oggi), oggi), isNull);
      expect(LimitiCorpo.erroreNascita(LimitiCorpo.nascitaPiuLontana(oggi), oggi), isNull);
      expect(
        LimitiCorpo.erroreNascita(
          LimitiCorpo.nascitaPiuLontana(oggi).subtract(const Duration(days: 1)),
          oggi,
        ),
        'limit_age_old',
      );
    });

    test('il calendario parte sempre da una data ammessa', () {
      expect(LimitiCorpo.dataInizialeCalendario(null, oggi), DateTime(2000));
      expect(LimitiCorpo.dataInizialeCalendario(DateTime(2020, 1, 1), oggi), LimitiCorpo.nascitaPiuRecente(oggi));
      expect(LimitiCorpo.dataInizialeCalendario(DateTime(1900, 1, 1), oggi), LimitiCorpo.nascitaPiuLontana(oggi));
      expect(LimitiCorpo.dataInizialeCalendario(DateTime(1990, 5, 3), oggi), DateTime(1990, 5, 3));
    });
  });

  test('altezza 100-230 cm', () {
    expect(LimitiCorpo.erroreAltezza(99.9), 'limit_height');
    expect(LimitiCorpo.erroreAltezza(100), isNull);
    expect(LimitiCorpo.erroreAltezza(230), isNull);
    expect(LimitiCorpo.erroreAltezza(230.1), 'limit_height');
    expect(LimitiCorpo.erroreAltezza(null), 'limit_height');
  });

  test('peso 30-300 kg', () {
    expect(LimitiCorpo.errorePeso(29.9), 'limit_weight');
    expect(LimitiCorpo.errorePeso(30), isNull);
    expect(LimitiCorpo.errorePeso(300), isNull);
    expect(LimitiCorpo.errorePeso(300.5), 'limit_weight');
    expect(LimitiCorpo.errorePeso(0), 'limit_weight');
  });

  group('peso obiettivo', () {
    test('stesso intervallo del peso', () {
      expect(LimitiCorpo.erroreObiettivo(20), 'limit_target');
      expect(LimitiCorpo.erroreObiettivo(45), isNull, reason: 'senza altezza vale solo l\'intervallo');
    });

    test('non sotto un BMI di 16, se l\'altezza e\' nota', () {
      // 175 cm: BMI 16 = 49 kg.
      expect(LimitiCorpo.erroreObiettivo(49, altezzaCm: 175), isNull);
      expect(LimitiCorpo.erroreObiettivo(48.9, altezzaCm: 175), 'limit_target_bmi');
    });

    test('un\'altezza fuori limite non fa scattare il controllo del BMI', () {
      expect(LimitiCorpo.erroreObiettivo(35, altezzaCm: 50), isNull);
    });
  });

  test('calorie 800-6000', () {
    expect(LimitiCorpo.erroreCalorie(799), 'limit_calories');
    expect(LimitiCorpo.erroreCalorie(800), isNull);
    expect(LimitiCorpo.erroreCalorie(6000), isNull);
    expect(LimitiCorpo.erroreCalorie(6001), 'limit_calories');
  });

  test('numeri scritti da una persona', () {
    expect(LimitiCorpo.numero('70,5'), 70.5);
    expect(LimitiCorpo.numero(' 72.0 '), 72.0);
    expect(LimitiCorpo.numero(''), isNull);
    expect(LimitiCorpo.numero('abc'), isNull);
  });
}
