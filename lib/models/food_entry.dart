import 'minerals.dart';
import 'vitamins.dart';
import 'fats.dart';
import 'macronutrients.dart';

/// Il momento da scrivere su una voce nuova del diario (17/09): il giorno che
/// si sta guardando, con l'ora di adesso. Senza giorno, adesso.
DateTime momentoVoce(DateTime? giorno) {
  final adesso = DateTime.now();
  if (giorno == null) return adesso;
  return DateTime(giorno.year, giorno.month, giorno.day, adesso.hour, adesso.minute, adesso.second);
}

class FoodEntry {
  final int? id; //id puo essere null
  final String user_mail;
  final String food_name;
  final String meal_type;
  final DateTime entry_date;
  final double weight_g;
  final Macronutrients macro;
  final Fats fats;
  final Minerals minerals;
  final Vitamins vitamins;
  // Qualita' del prodotto, snapshot al momento del log (vedi
  // migrations/2026-08-23_qualita_giorno.sql) — mai ricalcolati dopo, cosi'
  // la voce riflette cosa l'utente ha davvero mangiato quel giorno anche se
  // il prodotto viene corretto in seguito. null quando il prodotto non ha
  // quel punteggio (es. alimento CREA).
  final String? nutriscoreGrade;
  final int? novaGroup;
  final String? ecoscoreGrade;

  /// Foto di QUESTA voce di diario (21/09, colonna `image_url` aggiunta da
  /// `migrations/2026-09-21_voce_diario_immagine.sql`).
  ///
  /// PERCHE' STA QUI E NON SOLO IN LIBRERIA: prima la foto di un alimento
  /// viveva solo su `na_custom_foods`, quindi cambiarla da una voce del
  /// diario la cambiava anche nella libreria personale — senza che nessuno
  /// avesse chiesto "salva nella libreria" — e modificando una voce gia'
  /// registrata veniva invece scartata in silenzio. Le due foto ora sono
  /// indipendenti: aggiornare la libreria resta una scelta esplicita.
  final String imageUrl;

  ///i valori vengono tutti inizializzati a 0 cosi se utente
  ///non inserisce il valore di un attributo questo di default sara
  ///assegnato a 0. Se durante la creazione dell'oggetto viene assegnato
  ///un valore all'attributo quest'ultimo avra quel valore e non 0.
  const FoodEntry({
    //lo facciamo come costante essendo immutabile, cosi
    //migliriamo le performnce.
    this.id,
    required this.user_mail,
    required this.food_name,
    required this.meal_type,
    required this.entry_date,
    this.weight_g = 0.0,
    this.macro = const Macronutrients(),
    this.fats = const Fats(),
    this.minerals = const Minerals(),
    this.vitamins = const Vitamins(),
    this.nutriscoreGrade,
    this.novaGroup,
    this.ecoscoreGrade,
    this.imageUrl = '',
  });

  /// Converte l'oggetto in una Map<String, dynamic> per la serializzazione JSON.
  /// La chiave è una 'String' (nome del campo nel DB), mentre il valore è 'dynamic'
  /// perché può ospitare tipi diversi (String, double, int) che verranno processati dal server PHP.
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'user_mail': user_mail,
    'food_name': food_name,
    'meal_type': meal_type,
    'weight_g': weight_g,

    /// Formattazione della data nel formato SQL standard (YYYY-MM-DD).
    /// Poiché il database MySQL richiede due cifre per mesi e giorni, usiamo padLeft(2, '0')
    /// per aggiungere lo zero iniziale dove necessario (es. '2' diventa '02').
    'entry_date':
        "${entry_date.year}-${entry_date.month.toString().padLeft(2, '0')}-${entry_date.day.toString().padLeft(2, '0')}",
    ...macro.toJson(), //spread operator per inseire lista
    ...fats.toJson(),
    ...minerals.toJson(),
    ...vitamins.toJson(),
    if (nutriscoreGrade != null) 'nutriscore_grade': nutriscoreGrade,
    if (novaGroup != null) 'nova_group': novaGroup,
    if (ecoscoreGrade != null) 'environmental_score_grade': ecoscoreGrade,
    'image_url': imageUrl,
  };
  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    final String? nutriscore = (json['nutriscore_grade'] ?? '').toString().trim().isEmpty
        ? null : json['nutriscore_grade'].toString().toLowerCase().trim();
    final String? eco = (json['environmental_score_grade'] ?? '').toString().trim().isEmpty
        ? null : json['environmental_score_grade'].toString().toLowerCase().trim();
    final int? nova = int.tryParse(json['nova_group']?.toString() ?? '');
    return FoodEntry(
      id: int.tryParse(json['id']?.toString() ?? ''),
      user_mail: json['user_mail'] ?? '',
      food_name: json['food_name'] ?? '',
      meal_type: json['meal_type'] ?? '',
      entry_date: DateTime.tryParse(json['entry_date'] ?? '') ?? DateTime.now(),
      weight_g: double.tryParse(json['weight_g']?.toString() ?? '0') ?? 0.0,
      macro: Macronutrients.fromJson(json),
      fats: Fats.fromJson(json),
      minerals: Minerals.fromJson(json),
      vitamins: Vitamins.fromJson(json),
      nutriscoreGrade: nutriscore,
      novaGroup: (nova != null && nova > 0) ? nova : null,
      ecoscoreGrade: eco,
      imageUrl: (json['image_url'] ?? '').toString(),
    );
  }
}
