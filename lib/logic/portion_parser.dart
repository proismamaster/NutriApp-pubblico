/// Interpretazione delle porzioni dichiarate dai prodotti.
///
/// Logica pura (nessuna dipendenza da Flutter) estratta da
/// `manual_entry_page.dart` il 2026-07-24 per due motivi: era finita dentro
/// lo State di un widget pur non avendo nulla di grafico, e soprattutto così
/// diventa testabile — è il punto in cui si è già annidato due volte lo
/// stesso bug (ogni prodotto proponeva sempre e solo 100 g).
library;

/// Estrae un peso in grammi da una stringa libera come quelle del campo
/// `serving_size` di OpenFoodFacts: "30 g", "40g", "30 gr", "125 grammi",
/// "1 barretta (35 g)", "250 ml". Ritorna `null` se non trova nulla di
/// sensato.
///
/// I millilitri vengono trattati come grammi: è un'approssimazione (vale per
/// acqua e bevande, meno per oli o sciroppi), ma resta molto più vicina al
/// vero che ignorare la porzione e ricadere sui 100 g di default.
double? parseServingGrams(String servingSize) {
  if (servingSize.trim().isEmpty) return null;
  // L'ordine delle alternative conta: 'grammi' e 'gr' vanno provate prima di
  // 'g', altrimenti 'g' matcherebbe per primo lasciando fuori il resto.
  final match = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(?:grammi|gr|g|ml)\b',
    caseSensitive: false,
  ).firstMatch(servingSize);
  if (match == null) return null;
  final raw = match.group(1)?.replaceAll(',', '.');
  final value = double.tryParse(raw ?? '');
  // Scarta valori assurdi (0 o porzioni da chili): quasi sempre sono
  // stringhe malformate nel dato OpenFoodFacts, meglio ricadere sul default.
  if (value == null || value <= 0 || value > 2000) return null;
  return value;
}

/// Porzione reale del prodotto in grammi, 0 se il dato non la fornisce.
///
/// ATTENZIONE (bug ricorrente, corretto due volte): NON usare qui
/// `base_weight_g`. Quello è il peso di riferimento su cui sono espressi i
/// nutrienti — per i prodotti OpenFoodFacts vale **sempre 100**, perché i
/// valori OFF sono per 100 g — e non ha niente a che vedere con la porzione
/// della confezione. Usarlo faceva sì che ogni prodotto proponesse 100 g e
/// che `serving_size` non venisse mai nemmeno letto.
double productPortionGrams(Map<String, dynamic> data) {
  final servingQty = _asDouble(data['serving_quantity']);
  if (servingQty > 0) return servingQty;
  final parsed = parseServingGrams((data['serving_size'] ?? '').toString());
  if (parsed != null && parsed > 0) return parsed;
  return 0;
}

/// Porzioni selezionabili dall'utente: sempre 100 g (la base dei valori
/// nutrizionali) più, quando disponibile, la porzione reale della confezione.
/// Se il prodotto non ne dichiara una resta solo 100 g, e il peso si scrive
/// comunque a mano nel campo dedicato.
List<double> availablePortions(Map<String, dynamic> data) {
  final portions = <double>{100.0};
  final portion = productPortionGrams(data);
  if (portion > 0) portions.add(portion);
  return portions.toList()..sort();
}

/// "40" invece di "40.0", ma "12.5" resta "12.5".
String formatGrams(double g) =>
    g % 1 == 0 ? g.toStringAsFixed(0) : g.toString();

double _asDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
}
