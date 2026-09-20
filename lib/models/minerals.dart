class Minerals {
  final double sodium;
  final double arsenic;
  final double boron;
  final double calcium;
  final double chloride;
  final double choline;
  final double chromium;
  final double cobalt;
  final double copper;
  final double fluoride;
  final double fluorine;
  final double iodine;
  final double iron;
  final double magnesium;
  final double manganese;
  final double molybdenum;
  final double phosphorus;
  final double potassium;
  final double selenium;
  final double silicon;
  final double sulfur;
  final double tin;
  final double vanadium;
  final double zinc;
  ///i valori vengono tutti inizializzati a 0 cosi se utente
  ///non inserisce il valore di un attributo questo di default sara
  ///assegnato a 0. Se durante la creazione dell'oggetto viene assegnato
  ///un valore all'attributo quest'ultimo avra quel valore e non 0.
  const Minerals({ //lo facciamo come costante essendo immutabile, cosi
    //migliriamo le performnce.
    this.sodium = 0.0,
    this.arsenic = 0.0,
    this.boron = 0.0,
    this.calcium = 0.0,
    this.chloride = 0.0,
    this.choline = 0.0,
    this.chromium = 0.0,
    this.cobalt = 0.0,
    this.copper = 0.0,
    this.fluoride = 0.0,
    this.fluorine = 0.0,
    this.iodine = 0.0,
    this.iron = 0.0,
    this.magnesium = 0.0,
    this.manganese = 0.0,
    this.molybdenum = 0.0,
    this.phosphorus = 0.0,
    this.potassium = 0.0,
    this.selenium = 0.0,
    this.silicon = 0.0,
    this.sulfur = 0.0,
    this.tin = 0.0,
    this.vanadium = 0.0,
    this.zinc = 0.0,
  });

  /// Converte l'oggetto in una Map<String, dynamic> per la serializzazione JSON.
  /// La chiave è una 'String' (nome del campo nel DB), mentre il valore è 'dynamic'
  /// perché può ospitare tipi diversi (String, double, int) che verranno processati dal server PHP.
  Map<String, dynamic> toJson() => {
    'sodium': sodium,
    'arsenic': arsenic,
    'boron': boron,
    'calcium': calcium,
    'chloride': chloride,
    'choline': choline,
    'chromium': chromium,
    'cobalt': cobalt,
    'copper': copper,
    'fluoride': fluoride,
    'fluorine': fluorine,
    'iodine': iodine,
    'iron': iron,
    'magnesium': magnesium,
    'manganese': manganese,
    'molybdenum': molybdenum,
    'phosphorus': phosphorus,
    'potassium': potassium,
    'selenium': selenium,
    'silicon': silicon,
    'sulfur': sulfur,
    'tin': tin,
    'vanadium': vanadium,
    'zinc': zinc,
  };

  factory Minerals.fromJson(Map<String, dynamic> json) {
    double p(String key) => double.tryParse(json[key]?.toString() ?? '0') ?? 0.0;
    return Minerals(
      sodium: p('sodium'),
      arsenic: p('arsenic'),
      boron: p('boron'),
      calcium: p('calcium'),
      chloride: p('chloride'),
      choline: p('choline'),
      chromium: p('chromium'),
      cobalt: p('cobalt'),
      copper: p('copper'),
      fluoride: p('fluoride'),
      fluorine: p('fluorine'),
      iodine: p('iodine'),
      iron: p('iron'),
      magnesium: p('magnesium'),
      manganese: p('manganese'),
      molybdenum: p('molybdenum'),
      phosphorus: p('phosphorus'),
      potassium: p('potassium'),
      selenium: p('selenium'),
      silicon: p('silicon'),
      sulfur: p('sulfur'),
      tin: p('tin'),
      vanadium: p('vanadium'),
      zinc: p('zinc'),
    );
  }
}
