/// Il pasto dell'ora, per "Per te" in Consigliate (2026-09-15).
///
/// L'ora la sa il telefono, non il server: get_public_recipes.php riceve il
/// pasto gia' deciso qui (`now_meal`), cosi' un server in un altro fuso non
/// consiglia la cena a colazione.
///
/// Fasce: colazione 5:00-10:29, pranzo 11:00-14:59, cena 18:00-22:59; tutto il
/// resto e' spuntino (10:30-10:59, 15:00-17:59, notte). Restituisce i valori di
/// `na_recipes.meal_types`: colazione · pranzo · cena · spuntino.
String pastoDellOra(DateTime ora) {
  final minuti = ora.hour * 60 + ora.minute;
  if (minuti >= 5 * 60 && minuti < 10 * 60 + 30) return 'colazione';
  if (minuti >= 11 * 60 && minuti < 15 * 60) return 'pranzo';
  if (minuti >= 18 * 60 && minuti < 23 * 60) return 'cena';
  return 'spuntino';
}
