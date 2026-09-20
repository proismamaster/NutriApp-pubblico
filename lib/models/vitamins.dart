class Vitamins {
  final double a;
  final double b1;
  final double b2;
  final double b3;
  final double b5;
  final double b6;
  final double b7;
  final double b9;
  final double b11;
  final double b12;
  final double c;
  final double d;
  final double e;
  final double k;
  final double biotin;

  ///i valori vengono tutti inizializzati a 0 cosi se utente
  ///non inserisce il valore di un attributo questo di default sara
  ///assegnato a 0. Se durante la creazione dell'oggetto viene assegnato
  ///un valore all'attributo quest'ultimo avra quel valore e non 0.
  const Vitamins({ //lo facciamo come costante essendo immutabile, cosi
  //migliriamo le performnce.
    this.a = 0.0,
    this.b1 = 0.0,
    this.b2 = 0.0,
    this.b3 = 0.0,
    this.b5 = 0.0,
    this.b6 = 0.0,
    this.b7 = 0.0,
    this.b9 = 0.0,
    this.b11 = 0.0,
    this.b12 = 0.0,
    this.c = 0.0,
    this.d = 0.0,
    this.e = 0.0,
    this.k = 0.0,
    this.biotin = 0.0,
});
  /// Converte l'oggetto in una Map<String, dynamic> per la serializzazione JSON.
  /// La chiave è una 'String' (nome del campo nel DB), mentre il valore è 'dynamic'
  /// perché può ospitare tipi diversi (String, double, int) che verranno processati dal server PHP.
  Map<String, dynamic> toJson() => {
    'vit_a': a,
    'vit_b1': b1,
    'vit_b2': b2,
    'vit_b3': b3,
    'vit_b5': b5,
    'vit_b6': b6,
    'vit_b7': b7,
    'vit_b9': b9,
    'vit_b11': b11,
    'vit_b12': b12,
    'vit_c': c,
    'vit_d': d,
    'vit_e': e,
    'vit_k': k,
    'biotin': biotin,
  };

  factory Vitamins.fromJson(Map<String, dynamic> json) {
    double p(String key) => double.tryParse(json[key]?.toString() ?? '0') ?? 0.0;
    return Vitamins(
      a: p('vit_a'),
      b1: p('vit_b1'),
      b2: p('vit_b2'),
      b3: p('vit_b3'),
      b5: p('vit_b5'),
      b6: p('vit_b6'),
      b7: p('vit_b7'),
      b9: p('vit_b9'),
      b11: p('vit_b11'),
      b12: p('vit_b12'),
      c: p('vit_c'),
      d: p('vit_d'),
      e: p('vit_e'),
      k: p('vit_k'),
      biotin: p('biotin'),
    );
  }
}
