/// Conversione delle unità di misura al momento di scriverle a schermo.
///
/// PERCHÉ SOLO A SCHERMO (2026-09-05): il mockup "Language & country" chiede
/// di poter vedere i pesi in once e l'energia in kilojoule. Ma i valori
/// restano salvati in grammi e kcal **ovunque** — database, API, calcoli,
/// obiettivi — e la conversione avviene solo nell'ultimo passo, quando il
/// numero diventa testo.
///
/// L'alternativa (convertire alla fonte, salvando once nel database quando
/// l'utente sceglie le once) sembra più semplice ma è il modo classico per
/// ritrovarsi con due unità mescolate nella stessa tabella: basta che
/// l'utente cambi preferenza una volta perché i dati vecchi diventino
/// silenziosamente sbagliati, e nessuna riga dice in che unità è.
class UnitFormat {
  const UnitFormat._();

  /// Preferenze correnti, aggiornate dal builder di MaterialApp a ogni
  /// ricostruzione (vedi main.dart), esattamente come [Nutri.applicaTema].
  ///
  /// PERCHE' UNA VARIABILE E NON ref.watch (2026-09-05): le unita' vanno
  /// scritte in un centinaio di punti sparsi, molti dei quali dentro widget
  /// senza `ref` — anelli, pastiglie, righe di lista. Portare il provider
  /// fin la' avrebbe voluto dire aggiungere un parametro a ogni widget
  /// attraversato, per ottenere lo stesso identico risultato a schermo.
  ///
  /// Limite dichiarato, lo stesso di Nutri: non regge due preferenze diverse
  /// nella stessa app contemporaneamente. Oggi non succede — la preferenza e'
  /// una sola per utente — e viene aggiornata prima che qualunque schermata si
  /// disegni.
  static String _peso = 'metric';
  static String _energia = 'kcal';

  static void applica({required String peso, required String energia}) {
    _peso = peso;
    _energia = energia;
  }

  static String get unitaPeso => _peso;
  static String get unitaEnergia => _energia;

  /// Scorciatoie che usano la preferenza corrente, per i punti in cui non c'e'
  /// modo comodo di passarsela.
  static String e(num kcal) => energy(kcal.toDouble(), _energia);
  static String eValore(num kcal) => energyValue(kcal.toDouble(), _energia);
  static String get eSigla => energySuffix(_energia);

  static String p(num grammi, {int decimaliOnce = 1}) =>
      weight(grammi.toDouble(), _peso, decimaliOnce: decimaliOnce);
  static String pValore(num grammi) => weightValue(grammi.toDouble(), _peso);
  static String get pSigla => weightSuffix(_peso);
  static double aGrammi(double valore) => toGrams(valore, _peso);

  /// Energia e peso come NUMERI nell'unita' scelta (18/09): per i grafici,
  /// dove la scala va fatta sui valori visibili, altrimenti un asse tondo in
  /// kcal diventa un asse di numeri storti in kJ.
  static double eInUnita(num kcal) => _energia == 'kj' ? kcal * _kjPerKcal : kcal.toDouble();
  static double pInUnita(num grammi) => _peso == 'imperial' ? grammi / _grammiPerOncia : grammi.toDouble();

  /// Il peso da leggere, senza sigla: grammi interi, once con un decimale.
  /// Per quando la sigla e' scritta una volta sola accanto a due numeri
  /// ("47/150 g").
  static String pNumero(num grammi) => _peso == 'imperial'
      ? (grammi / _grammiPerOncia).toStringAsFixed(1)
      : grammi.round().toString();

  /// Il peso di un NUTRIENTE (i grammi di grassi saturi, di fibre...), con la
  /// sigla: sotto i 10 g serve un decimale, altrimenti 0,4 g di grassi trans
  /// diventano "0 g"; in once due decimali per lo stesso motivo.
  static String pNutriente(num grammi) {
    if (_peso == 'imperial') return '${(grammi / _grammiPerOncia).toStringAsFixed(2)} oz';
    return grammi < 10 ? '${grammi.toStringAsFixed(1)} g' : '${grammi.round()} g';
  }

  /// Mette la sigla scelta al posto di {u} (energia) e {p} (peso) in un testo
  /// tradotto (18/09): "{u} rimanenti" diventa "kJ rimanenti". Prima quei
  /// testi avevano "kcal" scritto dentro, e con i kJ scelti la Home diceva
  /// "7146 kcal rimanenti" per un numero in kJ.
  static String conUnita(String testo) => testo.replaceAll('{u}', eSigla).replaceAll('{p}', pSigla);

  /// 1 oncia = 28,3495 g (oncia avoirdupois, quella degli alimenti).
  static const double _grammiPerOncia = 28.349523125;

  /// 1 kcal = 4,184 kJ (fattore termochimico, quello usato dalle etichette
  /// nutrizionali europee, che riportano sempre entrambi i valori).
  static const double _kjPerKcal = 4.184;

  /// Peso da grammi all'unità scelta, con la sua sigla.
  ///
  /// [unit] è 'metric' o 'imperial'; qualsiasi altro valore ricade sui
  /// grammi, perché mostrare un numero senza sapere in che unità è sarebbe
  /// peggio che ignorare la preferenza.
  static String weight(double grammi, String unit, {int decimaliOnce = 1}) {
    if (unit != 'imperial') return '${grammi.round()} g';
    final once = grammi / _grammiPerOncia;
    return '${once.toStringAsFixed(decimaliOnce)} oz';
  }

  /// Solo il numero del peso, senza sigla: per quando l'unità è già scritta
  /// altrove (per esempio come suffisso di un campo).
  ///
  /// PERCHÉ DUE DECIMALI E NON UNO (2026-09-05): questo è il valore che
  /// finisce **dentro un campo modificabile**, e da lì torna indietro come
  /// grammi appena si salva. Con un decimale il giro completo perde mezzo
  /// grammo su 250 (8,8 oz riletti fanno 249,5 g): aprire una porzione e
  /// salvarla senza toccarla la cambierebbe da sola. Con due, l'errore scende
  /// a tre centesimi di grammo. Gli zeri finali vengono tolti, così "1.00"
  /// resta "1". Per il testo da leggere e basta c'è [weight], che di decimali
  /// ne mostra uno perché "3.5 oz" si legge meglio di "3.53 oz".
  static String weightValue(double grammi, String unit) {
    if (unit != 'imperial') return grammi.round().toString();
    final once = (grammi / _grammiPerOncia).toStringAsFixed(2);
    return once.contains('.')
        ? once.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : once;
  }

  /// Sigla del peso, da mettere accanto a un campo di input.
  static String weightSuffix(String unit) => unit == 'imperial' ? 'oz' : 'g';

  /// Riporta a grammi ciò che l'utente ha digitato nell'unità scelta.
  ///
  /// Serve ai campi in cui si SCRIVE un peso: quello che entra nel modello
  /// deve tornare in grammi, altrimenti finirebbero once nel database.
  static double toGrams(double valore, String unit) =>
      unit == 'imperial' ? valore * _grammiPerOncia : valore;

  /// Energia da kcal all'unità scelta, con la sua sigla.
  static String energy(double kcal, String unit) {
    if (unit != 'kj') return '${kcal.round()} kcal';
    return '${(kcal * _kjPerKcal).round()} kJ';
  }

  /// Solo il numero dell'energia.
  static String energyValue(double kcal, String unit) =>
      unit == 'kj' ? (kcal * _kjPerKcal).round().toString() : kcal.round().toString();

  /// Sigla dell'energia.
  static String energySuffix(String unit) => unit == 'kj' ? 'kJ' : 'kcal';
}
