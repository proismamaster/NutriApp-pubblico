import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dictionary/translations.dart';
import 'auth_style.dart';
import 'immagine_zoomabile.dart';
import 'segnala_alimento.dart';
import 'translated_text.dart';

/// Pannello con i metadati extra di un prodotto OpenFoodFacts (Nutri-Score,
/// NOVA, additivi, allergeni, etichette, olio di palma, foto, porzione,
/// categoria, luogo di produzione, ingredienti, alcol, caffeina).
///
/// Aggiunto 2026-07-24 insieme all'estensione di na_off_products con questi
/// campi (vedi vault: PROBLEMS.md / import_off_italy.py). Riusato da
/// ManualEntryPage, quindi disponibile sia per il diario alimentare sia per
/// gli ingredienti delle ricette (entrambi i flussi passano da lì).
///
/// I dati arrivano SOLO dalla fonte 'off_local_it' (na_off_products): per
/// alimenti CREA/USDA/personali questi campi sono vuoti/0 e ogni sezione si
/// nasconde da sola, niente sezioni vuote o placeholder confusi.
void showProductInfoSheet(
  BuildContext context, {
  required Map<String, dynamic> product,
  required String lang,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) =>
        ProductInfoSheetContent(product: product, lang: lang),
  );
}

/// True se il prodotto ha almeno un campo extra da mostrare: usato per
/// decidere se mostrare o no il pulsante "Info prodotto" nelle schermate
/// che possono ricevere dati da fonti diverse (OFF locale vs CREA/USDA/
/// personali, che non hanno questi metadati).
bool productHasExtraInfo(Map<String, dynamic>? product) {
  if (product == null) return false;
  const keys = [
    'nutriscore_grade', 'nova_group', 'additives_n', 'allergens', 'labels',
    'palm_oil_n', 'palm_oil_maybe_n', 'image_url', 'serving_size',
    'categories', 'predicted_category', 'manufacturing_places', 'ingredients',
    'alcohol_percent', 'caffeine',
  ];
  for (final k in keys) {
    final v = product[k];
    if (v == null) continue;
    // Stessa trappola di hasQuality: OFF usa 'unknown'/'not-applicable' come
    // segnaposto invece del vuoto. Sono "nessun dato", non un dato.
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s.isNotEmpty && s != 'unknown' && s != 'not-applicable') return true;
    }
    if (v is num && v > 0) return true;
  }
  return false;
}

/// Ripulisce i tag OFF grezzi tipo "en:gluten,en:milk" in una lista di
/// singoli tag leggibili ["Gluten", "Milk"] (toglie il prefisso lingua,
/// sostituisce trattini/underscore con spazi, capitalizza). Funzione
/// condivisa: usata sia dal pannello info sia dalla schermata "Prodotto
/// trovato" (dove servono i tag singoli per costruire i chip rimovibili).
List<String> splitOffTags(String raw) {
  return raw
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .map((t) {
        final withoutPrefix = t.contains(':') ? t.split(':').last : t;
        final spaced = withoutPrefix.replaceAll('-', ' ').replaceAll('_', ' ');
        if (spaced.isEmpty) return spaced;
        return spaced[0].toUpperCase() + spaced.substring(1);
      })
      .toList();
}

/// Ripulisce i tag OFF grezzi tipo "en:gluten,en:milk" in un testo
/// leggibile "Gluten, Milk". Funzione condivisa: usata sia dal pannello
/// info sia dalla schermata "Prodotto trovato".
String cleanOffTags(String raw) => splitOffTags(raw).join(', ');

/// Un livello del "semaforo" nutrienti di OpenFoodFacts: quale nutriente e
/// se e' in quantita' bassa / moderata / alta.
typedef LivelloNutriente = ({String nutriente, String livello});

/// Interpreta `nutrient_levels_tags` di OFF, che arriva come
/// "en:fat-in-high-quantity,en:sugars-in-low-quantity,...".
///
/// PERCHE' UN PARSER E NON UNA STRINGA MOSTRATA COSI' COM'E': il tag grezzo
/// e' illeggibile per un utente, ma l'informazione dentro (questo prodotto ha
/// TANTI grassi) e' la piu' immediata di tutta la scheda per chi non sa
/// interpretare i numeri. Copertura misurata sul dump del 22/08: 41,6% dei
/// prodotti, contro il 35,1% del Nutri-Score.
///
/// Ordine di uscita FISSO (grassi, saturi, zuccheri, sale) e non quello del
/// tag: OFF non garantisce un ordine, e una lista che cambia posizione da un
/// prodotto all'altro si legge peggio.
List<LivelloNutriente> parseNutrientLevels(String raw) {
  const ordine = ['fat', 'saturated-fat', 'sugars', 'salt'];
  final trovati = <String, String>{};
  for (final tag in raw.split(',')) {
    final t = tag.trim().toLowerCase().replaceFirst(RegExp(r'^[a-z]{2}:'), '');
    final m = RegExp(r'^(.+)-in-(low|moderate|high)-quantity$').firstMatch(t);
    if (m != null) trovati[m.group(1)!] = m.group(2)!;
  }
  return [
    for (final n in ordine)
      if (trovati.containsKey(n)) (nutriente: n, livello: trovati[n]!),
  ];
}

/// Verde/giallo/rosso del semaforo. Volutamente gli stessi colori del
/// Nutri-Score (A verde, C giallo, E rosso) invece di una scala nuova: sono
/// due indicatori diversi ma dello stesso tipo, e usare due palette diverse
/// nella stessa scheda confonderebbe e basta.
Color? livelloColore(String livello) {
  switch (livello) {
    case 'low':
      return const Color(0xFF038141);
    case 'moderate':
      return const Color(0xFFFECB02);
    case 'high':
      return const Color(0xFFE63E11);
  }
  return null;
}

/// Colore ufficiale del bollino Nutri-Score (A-E). Funzione condivisa: usata
/// sia dal pannello info sia dalla schermata "Prodotto trovato".
Color? nutriscoreColor(String grade) {
  const colors = {
    'a': Color(0xFF038141),
    'b': Color(0xFF85BB2F),
    'c': Color(0xFFFECB02),
    'd': Color(0xFFEE8100),
    'e': Color(0xFFE63E11),
  };
  return colors[grade.toLowerCase().trim()];
}

class ProductInfoSheetContent extends StatelessWidget {
  final Map<String, dynamic> product;
  final String lang;

  const ProductInfoSheetContent({
    super.key,
    required this.product,
    required this.lang,
  });

  String _str(String key) => (product[key] ?? '').toString().trim();

  int _int(String key) {
    final v = product[key];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  double _double(String key) {
    final v = product[key];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  String _novaLabel(int group) {
    switch (group) {
      case 1:
        return Translations.get(lang, 'nova_group_1');
      case 2:
        return Translations.get(lang, 'nova_group_2');
      case 3:
        return Translations.get(lang, 'nova_group_3');
      case 4:
        return Translations.get(lang, 'nova_group_4');
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String imageUrl = _str('image_url');
    final String foodName = (product['food_name'] ?? '').toString();
    final String nutriscore = _str('nutriscore_grade');
    final int nova = _int('nova_group');
    final int additives = _int('additives_n');
    final String allergens = _str('allergens');
    final String labels = _str('labels');
    final int palmOil = _int('palm_oil_n');
    final int palmOilMaybe = _int('palm_oil_maybe_n');
    final String servingSize = _str('serving_size');
    final String categories = _str('categories');
    // Proposta di categoria, non un fatto: si guarda SOLO quando il dato reale
    // manca, non la si mostra mai accanto/al posto di una categoria vera.
    final String predictedCategory = _str('predicted_category');
    final String manufacturingPlaces = _str('manufacturing_places');
    final String ingredients = _str('ingredients');
    final double alcohol = _double('alcohol_percent');
    final double caffeine = _double('caffeine');

    // `nutriscore.isNotEmpty` non basta: OpenFoodFacts scrive 'unknown' o
    // 'not-applicable' (acqua, alcolici) invece di lasciare vuoto, e
    // _NutriScoreRow quei valori non li disegna — quindi la sezione si
    // apriva col titolo e NIENTE dentro. Misurato sul dump del 22/08:
    // succedeva sul 62,4% dei prodotti (160.211 su 256.921).
    final livelli = parseNutrientLevels(_str('nutrient_levels_tags'));
    final bool hasQuality = nutriscoreColor(nutriscore) != null ||
        nova > 0 ||
        additives > 0 ||
        livelli.isNotEmpty;
    final bool hasSafety =
        allergens.isNotEmpty || labels.isNotEmpty || palmOil > 0 || palmOilMaybe > 0;
    final bool hasComposition =
        ingredients.isNotEmpty || alcohol > 0 || caffeine > 0;
    final bool hasProductInfo = servingSize.isNotEmpty ||
        categories.isNotEmpty ||
        (categories.isEmpty && predictedCategory.isNotEmpty) ||
        manufacturingPlaces.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty) ...[
                  // Apribile con un tocco come le altre foto dell'app (21/09).
                  ImmagineZoomabile(
                    immagine: nutriImageProvider(imageUrl),
                    titolo: foodName,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 56),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    foodName.isEmpty ? '' : foodName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (hasQuality)
              _InfoSection(
                title: Translations.get(lang, 'info_quality_title'),
                icon: Icons.verified_outlined,
                initiallyExpanded: true,
                children: [
                  // Stesso criterio di `hasQuality` qui sopra (riga ~211): con
                  // `isNotEmpty` un grade 'unknown'/'not-applicable' passava il
                  // controllo e _NutriScoreRow disegnava una riga senza
                  // bollino. Corretto il 2026-08-29.
                  if (nutriscoreColor(nutriscore) != null)
                    _NutriScoreRow(grade: nutriscore, color: nutriscoreColor(nutriscore)),
                  if (nova > 0)
                    _KeyValueRow(
                      label: Translations.get(lang, 'info_nova'),
                      value: '$nova · ${_novaLabel(nova)}',
                    ),
                  if (additives > 0)
                    _KeyValueRow(
                      label: Translations.get(lang, 'info_additives'),
                      value: '$additives',
                    ),
                  if (livelli.isNotEmpty) _SemaforoNutrienti(livelli: livelli, lang: lang),
                ],
              ),
            if (hasSafety)
              _InfoSection(
                title: Translations.get(lang, 'info_safety_title'),
                icon: Icons.shield_outlined,
                initiallyExpanded: true,
                children: [
                  if (allergens.isNotEmpty)
                    _KeyValueRow(
                      label: Translations.get(lang, 'info_allergens'),
                      value: cleanOffTags(allergens),
                    ),
                  if (labels.isNotEmpty)
                    _KeyValueRow(
                      label: Translations.get(lang, 'info_labels'),
                      value: cleanOffTags(labels),
                    ),
                  if (palmOil > 0)
                    _KeyValueRow(
                      label: Translations.get(lang, 'info_palm_oil'),
                      value: Translations.get(lang, 'info_palm_oil_yes'),
                    ),
                  if (palmOil == 0 && palmOilMaybe > 0)
                    _KeyValueRow(
                      label: Translations.get(lang, 'info_palm_oil'),
                      value: Translations.get(lang, 'info_palm_oil_maybe'),
                    ),
                ],
              ),
            if (hasComposition)
              _InfoSection(
                title: Translations.get(lang, 'info_composition_title'),
                icon: Icons.science_outlined,
                children: [
                  if (caffeine > 0)
                    _KeyValueRow(
                      label: Translations.get(lang, 'info_caffeine'),
                      value: '${caffeine.toStringAsFixed(0)} mg /100g',
                    ),
                  if (alcohol > 0)
                    _KeyValueRow(
                      label: Translations.get(lang, 'info_alcohol'),
                      value: '${alcohol.toStringAsFixed(1)} % vol',
                    ),
                  if (ingredients.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Translations.get(lang, 'info_ingredients'),
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          TranslatedText(
                            text: ingredients,
                            displayLanguage: lang,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            if (hasProductInfo)
              _InfoSection(
                title: Translations.get(lang, 'info_product_title'),
                icon: Icons.inventory_2_outlined,
                children: [
                  if (servingSize.isNotEmpty)
                    _KeyValueRow(
                      label: Translations.get(lang, 'info_serving_size'),
                      value: servingSize,
                    ),
                  if (categories.isNotEmpty)
                    _KeyValueRow(
                      label: Translations.get(lang, 'info_categories'),
                      value: cleanOffTags(categories),
                    )
                  else if (predictedCategory.isNotEmpty)
                    _KeyValueRow(
                      label: Translations.get(lang, 'info_categories_estimated'),
                      value: cleanOffTags(predictedCategory),
                      estimated: true,
                      hint: Translations.get(lang, 'info_categories_estimated_hint'),
                    ),
                  if (manufacturingPlaces.isNotEmpty)
                    _KeyValueRow(
                      label: Translations.get(lang, 'info_manufacturing_places'),
                      value: manufacturingPlaces,
                    ),
                ],
              ),
            // Segnalare un errore nei dati (2026-09-12). Sta qui in fondo, e
            // non nella riga di ricerca, perche' questo e' il punto in cui
            // l'utente sta GUARDANDO i valori: e' li' che si accorge che uno
            // non torna, ed e' li' che deve poterlo dire senza perdere il
            // filo di cio' che stava facendo.
            //
            // Un Consumer e non un ConsumerWidget: questo pannello e' aperto
            // da due schermate diverse come widget senza stato, e cambiarne
            // la natura per un pulsante avrebbe toccato anche loro.
            const SizedBox(height: 18),
            Consumer(
              builder: (context, ref, _) => Center(
                child: TextButton.icon(
                  onPressed: () => mostraSegnalaAlimento(context, product: product),
                  icon: Icon(Icons.flag_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  label: Text(
                    Translations.get(lang, 'report_food_action'),
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Sezione chiudibile (ExpansionTile) di una categoria di metadati. Ogni
/// sezione viene creata solo se ha almeno un contenuto (controllato dal
/// chiamante), quindi non serve gestire qui il caso "vuota".
class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _InfoSection({
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: children,
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  /// Riga di un dato PROPOSTO da un modello, non di un fatto letto
  /// dall'etichetta/da OFF — cambia stile (corsivo, icona info) e non deve
  /// mai avere lo stesso aspetto di un dato certo. Vedi
  /// DATA-QUALITY-PLAN.md §5-bis regola 6.
  final bool estimated;
  final String? hint;

  const _KeyValueRow({
    required this.label,
    required this.value,
    this.estimated = false,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              if (estimated && hint != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: hint!,
                  triggerMode: TooltipTriggerMode.tap,
                  child: const Icon(Icons.info_outline, size: 13, color: Colors.grey),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontStyle: estimated ? FontStyle.italic : FontStyle.normal,
              // Dal tema e non `Colors.grey[700]`: in scuro era grigio scuro su
              // fondo scuro (15/09).
              color: estimated ? Theme.of(context).colorScheme.onSurfaceVariant : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Il "semaforo" nutrienti: una riga per nutriente con un pallino colorato.
/// Non mostra numeri di proposito — i valori esatti sono gia' nella tabella
/// nutrizionale della schermata prodotto, qui serve il colpo d'occhio.
class _SemaforoNutrienti extends StatelessWidget {
  final List<LivelloNutriente> livelli;
  final String lang;

  const _SemaforoNutrienti({required this.livelli, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Translations.get(lang, 'info_nutrient_levels'),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 6),
          for (final l in livelli)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: livelloColore(l.livello) ?? Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${Translations.get(lang, 'nutrient_${l.nutriente}')}: '
                      '${Translations.get(lang, 'level_${l.livello}')}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NutriScoreRow extends StatelessWidget {
  final String grade;
  final Color? color;

  const _NutriScoreRow({required this.grade, required this.color});

  @override
  Widget build(BuildContext context) {
    if (color == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              grade.toUpperCase().trim(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('Nutri-Score', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
