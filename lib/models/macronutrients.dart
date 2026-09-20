class Macronutrients {
  final double calories;
  final double carbs;
  final double proteins;
  final double fats;
  final double water;
  final double fibers;
  final double sugars;
  ///i valori vengono tutti inizializzati a 0 cosi se utente
  ///non inserisce il valore di un attributo questo di default sara
  ///assegnato a 0. Se durante la creazione dell'oggetto viene assegnato
  ///un valore all'attributo quest'ultimo avra quel valore e non 0.
  const Macronutrients({ //lo facciamo come costante essendo immutabile, cosi
  //migliriamo le performnce.
    this.calories = 0.0,
    this.carbs = 0.0,
    this.proteins = 0.0,
    this.fats = 0.0,
    this.water = 0.0,
    this.fibers = 0.0,
    this.sugars = 0.0,
  });

  /// Converte l'oggetto in una Map<String, dynamic> per la serializzazione JSON.
  /// La chiave è una 'String' (nome del campo nel DB), mentre il valore è 'dynamic'
  /// perché può ospitare tipi diversi (String, double, int) che verranno processati dal server PHP.
  Map<String, dynamic> toJson() => {
    'calories': calories,
    'carbs': carbs,
    'proteins': proteins,
    'fats': fats,
    'water': water,
    'fibers': fibers,
    'sugars': sugars,
  };

  factory Macronutrients.fromJson(Map<String, dynamic> json) {
    double p(String key) => double.tryParse(json[key]?.toString() ?? '0') ?? 0.0;
    return Macronutrients(
      calories: p('calories'),
      carbs: p('carbs'),
      proteins: p('proteins'),
      fats: p('fats'),
      water: p('water'),
      fibers: p('fibers'),
      sugars: p('sugars'),
    );
  }
}
