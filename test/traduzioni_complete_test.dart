// Ogni stringa che il codice chiede a Translations.get deve esistere in TUTTE
// le lingue, non solo in italiano.
//
// PERCHE' ESISTE (2026-09-09): `Translations.get` ricade sull'italiano quando
// una chiave manca nella lingua scelta, e poi sulla chiave stessa. Quindi una
// traduzione mancante non produce nessun errore, nessun avviso e nessun crash:
// si vede solo aprendo l'app in inglese e trovandoci una parola italiana in
// mezzo. E' il difetto che Ismail ha segnalato piu' volte, e quando l'ho
// misurato mancavano 55 chiavi in inglese, 64 in cinese e 60 in arabo.
//
// Questo test le conta al posto suo.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chiavi definite, lingua per lingua, lette dal sorgente del dizionario.
Map<String, Set<String>> _chiaviPerLingua(String sorgente) {
  final intestazione = RegExp(r"^    '([^']+)': \{$", multiLine: true);
  final chiave = RegExp(r"^      '((?:[^'\\]|\\.)+)':", multiLine: true);

  final aperture = intestazione.allMatches(sorgente).toList();
  final risultato = <String, Set<String>>{};
  for (var i = 0; i < aperture.length; i++) {
    final lingua = aperture[i].group(1)!;
    final da = aperture[i].end;
    final a = i + 1 < aperture.length ? aperture[i + 1].start : sorgente.length;
    risultato[lingua] = chiave
        .allMatches(sorgente.substring(da, a))
        .map((m) => m.group(1)!)
        .toSet();
  }
  return risultato;
}

/// Chiavi LETTERALI chieste dal codice.
///
/// Quelle costruite con l'interpolazione (`'month_${date.month}'`) sono
/// escluse: il loro valore vero si conosce solo mentre l'app gira, e le
/// famiglie corrispondenti (month_1..12, weekday_1..7, nova_group_1..4,
/// nutrient_*, level_*) sono comunque tutte presenti.
Set<String> _chiaviUsate(Directory lib) {
  final uso = RegExp(r"""Translations\.get\(\s*[A-Za-z_.()\[\] ]+,\s*'((?:[^'\\]|\\.)+)'\s*\)""");
  final trovate = <String>{};
  for (final f in lib.listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    if (f.path.endsWith('translations.dart')) continue;
    for (final m in uso.allMatches(f.readAsStringSync())) {
      final k = m.group(1)!;
      if (k.contains(r'$')) continue;
      trovate.add(k);
    }
  }
  return trovate;
}

void main() {
  final radice = Directory.current;
  final dizionario =
      File('${radice.path}/lib/dictionary/translations.dart').readAsStringSync();
  final perLingua = _chiaviPerLingua(dizionario);
  final usate = _chiaviUsate(Directory('${radice.path}/lib'));

  test('il dizionario ha tutte e quattro le lingue', () {
    expect(perLingua.keys, containsAll(['Italiano', 'English']));
    expect(perLingua.length, greaterThanOrEqualTo(4));
  });

  test('il codice chiede davvero delle traduzioni (la lettura funziona)', () {
    // Se la regex smettesse di combaciare, tutti i test sotto passerebbero
    // per il motivo sbagliato: nessuna chiave da controllare.
    expect(usate.length, greaterThan(300),
        reason: 'lette solo ${usate.length} chiavi: la lettura del sorgente '
            'non funziona piu, non e che il codice ne usi poche');
  });

  for (final lingua in ['English', '简体中文', 'العربية']) {
    test('nessuna stringa italiana trapela in $lingua', () {
      final definite = perLingua[lingua]!;
      final mancanti = usate.where((k) => !definite.contains(k)).toList()
        ..sort();
      expect(
        mancanti,
        isEmpty,
        reason: 'Queste chiavi non esistono in $lingua, quindi l\'utente le '
            'vede in italiano:\n  ${mancanti.join('\n  ')}',
      );
    });
  }
}
