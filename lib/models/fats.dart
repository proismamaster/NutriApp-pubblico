class Fats {
  final double saturated;
  final double monounsaturated;
  final double polyunsaturated;
  final double trans;
  final double cholesterol;
  ///i valori vengono tutti inizializzati a 0 cosi se utente
  ///non inserisce il valore di un attributo questo di default sara
  ///assegnato a 0. Se durante la creazione dell'oggetto viene assegnato
  ///un valore all'attributo quest'ultimo avra quel valore e non 0.
  const Fats({ //lo facciamo come costante essendo immutabile, cosi
//migliriamo le performnce.
    this.saturated = 0.0,
    this.monounsaturated = 0.0,
    this.polyunsaturated = 0.0,
    this.trans = 0.0,
    this.cholesterol = 0.0,
  });

  /// Converte l'oggetto in una Map<String, dynamic> per la serializzazione JSON.
  /// La chiave è una 'String' (nome del campo nel DB), mentre il valore è 'dynamic'
  /// perché può ospitare tipi diversi (String, double, int) che verranno processati dal server PHP.
  Map<String, dynamic> toJson() => {
    'saturated_fats': saturated,
    'monounsaturated_fats': monounsaturated,
    'polyunsaturated_fats': polyunsaturated,
    'trans_fats': trans,
    'cholesterol': cholesterol,
  };

  factory Fats.fromJson(Map<String, dynamic> json) {
    double p(String key) => double.tryParse(json[key]?.toString() ?? '0') ?? 0.0;
    return Fats(
      saturated: p('saturated_fats'),
      monounsaturated: p('monounsaturated_fats'),
      polyunsaturated: p('polyunsaturated_fats'),
      trans: p('trans_fats'),
      cholesterol: p('cholesterol'),
    );
  }
}
