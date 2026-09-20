import 'recipe_ingredient.dart'; // Importiamo il nuovo file!

/// Modello della Ricetta Completa
class Recipe {
  String? id;
  String name;
  String portion;
  String notes;
  List<RecipeIngredient> ingredients;
  bool isFavorite;

  /// Foto della ricetta (2026-08-30). Indirizzo web finche' non esiste un
  /// endpoint di upload sul server. Stesso nome e stesso tipo che hanno gia'
  /// prodotti e ingredienti, cosi' il codice che sa disegnare un'immagine
  /// funziona qui senza casi speciali.
  String imageUrl;

  /// Visibilita' della ricetta agli altri utenti (2026-09-12):
  /// `private` (solo tua) · `pending` (proposta, in attesa di revisione) ·
  /// `approved` (pubblicata in "Consigliate") · `rejected` (non accettata).
  ///
  /// La decide il server: l'app la manda solo tramite share_recipe.php, mai
  /// dentro il salvataggio di una ricetta — cosi' un normale salvataggio non
  /// puo' pubblicare niente per sbaglio.
  String sharedStatus;

  /// Nome di chi ha scritto la ricetta, presente solo sulle ricette pubbliche
  /// arrivate da get_public_recipes.php. Vuoto sulle proprie. Il server manda
  /// il nome proprio e nient'altro: nessuna email, nessun cognome.
  final String authorName;

  /// Categorie a lista chiusa (15/09): i pasti per cui la ricetta ha senso
  /// (colazione · pranzo · cena · spuntino), la portata e le etichette di
  /// dieta. Le sceglie l'autore quando la propone.
  List<String> mealTypes;
  String course;
  List<String> dietTags;

  /// Like, solo sulle ricette pubbliche (15/09).
  int likesCount;
  bool likedByMe;

  /// In Consigliate: la ricetta e' dell'utente che guarda (17/09). Si vede
  /// anche la propria, ma senza cuore.
  bool isMine;

  Recipe({
    this.id,
    required this.name,
    required this.portion,
    required this.notes,
    required this.ingredients,
    this.isFavorite = false,
    this.imageUrl = '',
    this.sharedStatus = 'private',
    this.authorName = '',
    this.mealTypes = const [],
    this.course = '',
    this.dietTags = const [],
    this.likesCount = 0,
    this.likedByMe = false,
    this.isMine = false,
  });

  // Clona la ricetta
  Recipe copy() => Recipe(
    id: id,
    name: name,
    portion: portion,
    notes: notes,
    ingredients: ingredients.map((i) => i.copy()).toList(),
    isFavorite: isFavorite,
    imageUrl: imageUrl,
    sharedStatus: sharedStatus,
    authorName: authorName,
    mealTypes: List.of(mealTypes),
    course: course,
    dietTags: List.of(dietTags),
    likesCount: likesCount,
    likedByMe: likedByMe,
    isMine: isMine,
  );

  // Da Dart a JSON (Per salvare nel DB)
  Map<String, dynamic> toJson(String userMail) {
    return {
      if (id != null) 'id': id,
      'user_mail': userMail,
      'recipe_name': name,
      'portion': portion,
      'notes': notes,
      'is_favorite': isFavorite ? 1 : 0,
      'image_url': imageUrl,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
    };
  }

  // Da JSON a Dart (Per leggere dal DB)
  factory Recipe.fromJson(Map<String, dynamic> json) {
    var list = json['ingredients'] as List? ?? [];
    List<RecipeIngredient> ingredientsList = list
        .map((i) => RecipeIngredient.fromJson(i))
        .toList();

    return Recipe(
      id: json['id'].toString(),
      name: json['recipe_name'] ?? '',
      portion: json['portion'] ?? '1',
      notes: json['notes'] ?? '',
      isFavorite: (json['is_favorite'] == 1 || json['is_favorite'] == true),
      imageUrl: (json['image_url'] ?? '').toString(),
      // 'private' quando la chiave manca: e' cosi' che risponde un server
      // ancora senza la migrazione della condivisione, e "privata" e' la
      // verita' in quel caso, non un valore di riempimento.
      sharedStatus: (json['shared_status'] ?? 'private').toString(),
      authorName: (json['author_name'] ?? '').toString(),
      mealTypes: _elenco(json['meal_types']),
      course: (json['course'] ?? '').toString(),
      dietTags: _elenco(json['diet_tags']),
      likesCount: int.tryParse('${json['likes_count'] ?? 0}') ?? 0,
      likedByMe: json['liked_by_me'] == true || json['liked_by_me'] == 1,
      isMine: json['is_mine'] == true || json['is_mine'] == 1,
      ingredients: ingredientsList,
    );
  }

  /// Un SET di MySQL arriva come "pranzo,cena"; vuoto o assente = nessuno.
  static List<String> _elenco(dynamic valore) {
    return (valore ?? '')
        .toString()
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
  }

  // Getters for nutritional values
  double get carbs => ingredients.fold(0.0, (sum, ing) => sum + ing.macro.carbs);
  double get sugars => ingredients.fold(0.0, (sum, ing) => sum + ing.macro.sugars);
  double get fiber => ingredients.fold(0.0, (sum, ing) => sum + ing.macro.fibers);
  double get fats => ingredients.fold(0.0, (sum, ing) => sum + ing.macro.fats);
  double get saturatedFats => ingredients.fold(0.0, (sum, ing) => sum + ing.fats.saturated);
  double get unsaturatedFats => ingredients.fold(0.0, (sum, ing) => sum + ing.fats.monounsaturated + ing.fats.polyunsaturated);
  double get proteins => ingredients.fold(0.0, (sum, ing) => sum + ing.macro.proteins);
  double get calories => ingredients.fold(0.0, (sum, ing) => sum + ing.macro.calories);

  List<Map<String, String>> get vitamins => [
    {'name': 'Vitamina A', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.vitamins.a).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Vitamina B1', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.vitamins.b1).toStringAsFixed(1), 'unit': 'mg'},
    {'name': 'Vitamina B2', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.vitamins.b2).toStringAsFixed(1), 'unit': 'mg'},
    {'name': 'Vitamina B3', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.vitamins.b3).toStringAsFixed(1), 'unit': 'mg'},
    {'name': 'Vitamina B5', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.vitamins.b5).toStringAsFixed(1), 'unit': 'mg'},
    {'name': 'Vitamina B6', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.vitamins.b6).toStringAsFixed(1), 'unit': 'mg'},
    {'name': 'Vitamina B7', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.vitamins.b7).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Vitamina B9', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.vitamins.b9).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Vitamina B11', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.vitamins.b11).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Vitamina B12', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.vitamins.b12).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Vitamina C', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.vitamins.c).toStringAsFixed(1), 'unit': 'mg'},
    {'name': 'Vitamina D', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.vitamins.d).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Vitamina E', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.vitamins.e).toStringAsFixed(1), 'unit': 'mg'},
    {'name': 'Vitamina K', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.vitamins.k).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Biotina', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.vitamins.biotin).toStringAsFixed(1), 'unit': 'µg'},
  ];

  List<Map<String, String>> get minerals => [
    {'name': 'Sodio', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.sodium).toStringAsFixed(1), 'unit': 'mg'},
    {'name': 'Arsenico', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.arsenic).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Boro', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.boron).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Calcio', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.calcium).toStringAsFixed(1), 'unit': 'mg'},
    {'name': 'Cloruro', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.chloride).toStringAsFixed(1), 'unit': 'mg'},
    {'name': 'Colina', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.choline).toStringAsFixed(1), 'unit': 'mg'},
    {'name': 'Cromo', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.chromium).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Cobalto', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.cobalt).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Rame', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.copper).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Fluoro', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.fluoride).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Fluoro', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.fluorine).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Iodio', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.iodine).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Ferro', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.iron).toStringAsFixed(1), 'unit': 'mg'},
    {'name': 'Magnesio', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.magnesium).toStringAsFixed(1), 'unit': 'mg'},
    {'name': 'Manganese', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.manganese).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Molibdeno', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.molybdenum).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Fosforo', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.phosphorus).toStringAsFixed(1), 'unit': 'mg'},
    {'name': 'Potassio', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.potassium).toStringAsFixed(1), 'unit': 'mg'},
    {'name': 'Selenio', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.selenium).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Silicio', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.silicon).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Zolfo', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.sulfur).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Stagno', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.tin).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Vanadio', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.vanadium).toStringAsFixed(1), 'unit': 'µg'},
    {'name': 'Zinco', 'value': ingredients.fold(0.0, (sum, ing) => sum + ing.minerals.zinc).toStringAsFixed(1), 'unit': 'mg'},
  ];
}
