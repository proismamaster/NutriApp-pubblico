/// Limiti dei dati del corpo, gli stessi ovunque si scrivono (2026-09-14).
///
/// PERCHE' UN FILE SOLO: fino al 13/09 l'unico limite vero era l'altezza
/// (100-230 cm), e scritto due volte. Il peso doveva solo essere "maggiore di
/// zero", l'eta' pure: si poteva creare un account di 3 anni e 2 kg, e da quei
/// numeri partono il calcolo delle calorie e le quote dei pasti. Registrazione,
/// completamento del profilo social, profilo e obiettivi leggono tutti da qui,
/// cosi' un limite non puo' essere diverso a seconda della schermata. Gli
/// stessi numeri sono ripetuti negli endpoint PHP (signup, update_profile,
/// update_goals), contro un'app vecchia o una richiesta scritta a mano.
///
/// PERCHE' QUESTI NUMERI
///  - Eta' 14-100: 14 anni e' l'eta' dal consenso digitale in Italia (art.
///    2-quinquies del Codice privacy), e un'app che conta calorie non va
///    proposta a bambini. Oltre i 100 e' quasi sempre un anno sbagliato.
///  - Altezza 100-230 cm: invariata, era gia' il limite di profilo e
///    registrazione.
///  - Peso 30-300 kg: fuori da questo intervallo il numero e' un errore di
///    battitura (grammi al posto di kg, una cifra in piu') molto piu' spesso
///    che un dato vero, e le formule degli obiettivi non valgono comunque.
///  - Obiettivo sopra BMI 16: sotto quella soglia si parla di magrezza grave.
///    Un'app non deve aiutare a darsi un traguardo pericoloso.
///  - Calorie 800-6000: sotto le 800 al giorno e' una dieta da seguire solo con
///    un medico; sopra le 6000 e' quasi sempre uno zero in piu'.
///
/// Le funzioni `errore...` restituiscono la CHIAVE di traduzione del
/// messaggio, oppure `null` se il valore va bene: chi le usa decide dove
/// mostrarlo.
class LimitiCorpo {
  LimitiCorpo._();

  static const int etaMin = 14;
  static const int etaMax = 100;
  static const double altezzaMin = 100;
  static const double altezzaMax = 230;
  static const double pesoMin = 30;
  static const double pesoMax = 300;
  static const double bmiObiettivoMin = 16;
  static const double calorieMin = 800;
  static const double calorieMax = 6000;

  /// Un numero scritto da una persona: accetta la virgola ("70,5"), e un
  /// campo vuoto o illeggibile vale `null`, non zero.
  static double? numero(String testo) {
    final pulito = testo.trim().replaceAll(',', '.');
    if (pulito.isEmpty) return null;
    return double.tryParse(pulito);
  }

  /// Anni compiuti alla data [oggi].
  static int eta(DateTime nascita, [DateTime? oggi]) {
    final o = oggi ?? DateTime.now();
    var anni = o.year - nascita.year;
    if (o.month < nascita.month || (o.month == nascita.month && o.day < nascita.day)) {
      anni -= 1;
    }
    return anni;
  }

  /// La data di nascita piu' recente ammessa: chi e' nato dopo non ha ancora
  /// [etaMin] anni. E' il `lastDate` dei calendari.
  static DateTime nascitaPiuRecente([DateTime? oggi]) {
    final o = oggi ?? DateTime.now();
    return DateTime(o.year - etaMin, o.month, o.day);
  }

  /// La data di nascita piu' lontana ammessa ([etaMax] anni compiuti, non
  /// ancora [etaMax] + 1). E' il `firstDate` dei calendari.
  static DateTime nascitaPiuLontana([DateTime? oggi]) {
    final o = oggi ?? DateTime.now();
    return DateTime(o.year - etaMax - 1, o.month, o.day).add(const Duration(days: 1));
  }

  /// Da dove parte il calendario. Una data gia' salvata fuori dai limiti (un
  /// account vecchio) farebbe fallire l'apertura del calendario, che pretende
  /// una data iniziale compresa fra la prima e l'ultima: si riporta dentro.
  static DateTime dataInizialeCalendario(DateTime? attuale, [DateTime? oggi]) {
    final primo = nascitaPiuLontana(oggi);
    final ultimo = nascitaPiuRecente(oggi);
    final d = attuale ?? DateTime(2000);
    if (d.isBefore(primo)) return primo;
    if (d.isAfter(ultimo)) return ultimo;
    return d;
  }

  static String? erroreNascita(DateTime? nascita, [DateTime? oggi]) {
    if (nascita == null) return 'limit_birth_missing';
    final anni = eta(nascita, oggi);
    if (anni < etaMin) return 'limit_age_young';
    if (anni > etaMax) return 'limit_age_old';
    return null;
  }

  static String? erroreAltezza(double? cm) =>
      cm == null || cm < altezzaMin || cm > altezzaMax ? 'limit_height' : null;

  static String? errorePeso(double? kg) =>
      kg == null || kg < pesoMin || kg > pesoMax ? 'limit_weight' : null;

  /// Il peso obiettivo: stesso intervallo del peso e, se l'altezza e' nota e
  /// valida, non sotto un BMI di [bmiObiettivoMin].
  static String? erroreObiettivo(double? kg, {double? altezzaCm}) {
    if (kg == null || kg < pesoMin || kg > pesoMax) return 'limit_target';
    if (altezzaCm != null && erroreAltezza(altezzaCm) == null) {
      final metri = altezzaCm / 100;
      if (kg / (metri * metri) < bmiObiettivoMin) return 'limit_target_bmi';
    }
    return null;
  }

  static String? erroreCalorie(double? kcal) =>
      kcal == null || kcal < calorieMin || kcal > calorieMax ? 'limit_calories' : null;
}
