import 'macronutrients.dart';
import 'fats.dart';
import 'minerals.dart';
import 'vitamins.dart';

class DailySummary {
  final int intakeCount;
  final Macronutrients totalMacro;
  final Fats totalFats;
  final Minerals totalMinerals;
  final Vitamins totalVitamins;
  // Qualita' del giorno: media delle voci che hanno il punteggio (le altre
  // sono ignorate, non contate come "il peggiore possibile" — vedi
  // get_daily_summary.php). null se nessuna voce loggata oggi ce l'ha.
  final double? avgNutriscoreNum; // 1..5 (a..e)
  final double? avgNova; // 1..4
  final double? avgEcoscoreNum; // 1..5 (a..e)

  DailySummary({
    required this.intakeCount,
    required this.totalMacro,
    required this.totalFats,
    required this.totalMinerals,
    required this.totalVitamins,
    this.avgNutriscoreNum,
    this.avgNova,
    this.avgEcoscoreNum,
  });

  /// Converte una media numerica 1..5 nella lettera A-E piu' vicina
  /// (arrotondata), per mostrare "Nutri-Score medio del giorno: B" invece
  /// di un numero che l'utente non sa leggere. null se non c'e' media.
  static String? numToGrade(double? n) {
    if (n == null) return null;
    const letters = ['A', 'B', 'C', 'D', 'E'];
    final i = n.round().clamp(1, 5) - 1;
    return letters[i];
  }

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      intakeCount: int.tryParse(json['num_pasti'].toString()) ?? 0,

      //Mappatura Macronutrienti (totali)
      totalMacro: Macronutrients(
        calories: double.tryParse(json['tot_cal'].toString()) ?? 0.0,
        carbs: double.tryParse(json['tot_carbs'].toString()) ?? 0.0,
        proteins: double.tryParse(json['tot_proteins'].toString()) ?? 0.0,
        fats: double.tryParse(json['tot_fats'].toString()) ?? 0.0,
        water: double.tryParse(json['tot_water'].toString()) ?? 0.0,
        fibers: double.tryParse(json['tot_fibers'].toString()) ?? 0.0,
        sugars: double.tryParse(json['tot_sugars'].toString()) ?? 0.0,
      ),

      //Mappatura Grassi (totali)
      totalFats: Fats(
        saturated: double.tryParse(json['tot_saturated'].toString()) ?? 0.0,
        monounsaturated: double.tryParse(json['tot_monounsaturated'].toString()) ?? 0.0,
        polyunsaturated: double.tryParse(json['tot_polyunsaturated'].toString()) ?? 0.0,
        trans: double.tryParse(json['tot_trans'].toString()) ?? 0.0,
        cholesterol: double.tryParse(json['tot_cholesterol'].toString()) ?? 0.0,
      ),

      //Mappatura Minerali (totali)
      totalMinerals: Minerals(
        sodium: double.tryParse(json['tot_sodium'].toString()) ?? 0.0,
        arsenic: double.tryParse(json['tot_arsenic'].toString()) ?? 0.0,
        boron: double.tryParse(json['tot_boron'].toString()) ?? 0.0,
        calcium: double.tryParse(json['tot_calcium'].toString()) ?? 0.0,
        chloride: double.tryParse(json['tot_chloride'].toString()) ?? 0.0,
        choline: double.tryParse(json['tot_choline'].toString()) ?? 0.0,
        chromium: double.tryParse(json['tot_chromium'].toString()) ?? 0.0,
        cobalt: double.tryParse(json['tot_cobalt'].toString()) ?? 0.0,
        copper: double.tryParse(json['tot_copper'].toString()) ?? 0.0,
        fluoride: double.tryParse(json['tot_fluoride'].toString()) ?? 0.0,
        fluorine: double.tryParse(json['tot_fluorine'].toString()) ?? 0.0,
        iodine: double.tryParse(json['tot_iodine'].toString()) ?? 0.0,
        iron: double.tryParse(json['tot_iron'].toString()) ?? 0.0,
        magnesium: double.tryParse(json['tot_magnesium'].toString()) ?? 0.0,
        manganese: double.tryParse(json['tot_manganese'].toString()) ?? 0.0,
        molybdenum: double.tryParse(json['tot_molybdenum'].toString()) ?? 0.0,
        phosphorus: double.tryParse(json['tot_phosphorus'].toString()) ?? 0.0,
        potassium: double.tryParse(json['tot_potassium'].toString()) ?? 0.0,
        selenium: double.tryParse(json['tot_selenium'].toString()) ?? 0.0,
        silicon: double.tryParse(json['tot_silicon'].toString()) ?? 0.0,
        sulfur: double.tryParse(json['tot_sulfur'].toString()) ?? 0.0,
        tin: double.tryParse(json['tot_tin'].toString()) ?? 0.0,
        vanadium: double.tryParse(json['tot_vanadium'].toString()) ?? 0.0,
        zinc: double.tryParse(json['tot_zinc'].toString()) ?? 0.0,
      ),

      //Mappatura Vitamine (totali)
      totalVitamins: Vitamins(
        a: double.tryParse(json['tot_vit_a'].toString()) ?? 0.0,
        b1: double.tryParse(json['tot_vit_b1'].toString()) ?? 0.0,
        b2: double.tryParse(json['tot_vit_b2'].toString()) ?? 0.0,
        b3: double.tryParse(json['tot_vit_b3'].toString()) ?? 0.0,
        b5: double.tryParse(json['tot_vit_b5'].toString()) ?? 0.0,
        b6: double.tryParse(json['tot_vit_b6'].toString()) ?? 0.0,
        b7: double.tryParse(json['tot_vit_b7'].toString()) ?? 0.0,
        b9: double.tryParse(json['tot_vit_b9'].toString()) ?? 0.0,
        b11: double.tryParse(json['tot_vit_b11'].toString()) ?? 0.0,
        b12: double.tryParse(json['tot_vit_b12'].toString()) ?? 0.0,
        c: double.tryParse(json['tot_vit_c'].toString()) ?? 0.0,
        d: double.tryParse(json['tot_vit_d'].toString()) ?? 0.0,
        e: double.tryParse(json['tot_vit_e'].toString()) ?? 0.0,
        k: double.tryParse(json['tot_vit_k'].toString()) ?? 0.0,
        biotin: double.tryParse(json['tot_biotin'].toString()) ?? 0.0,
      ),

      avgNutriscoreNum: double.tryParse(json['avg_nutriscore_num']?.toString() ?? ''),
      avgNova: double.tryParse(json['avg_nova']?.toString() ?? ''),
      avgEcoscoreNum: double.tryParse(json['avg_ecoscore_num']?.toString() ?? ''),
    );
  }
}
