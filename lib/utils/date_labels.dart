import '../dictionary/translations.dart';

/// Etichette relative per una data ("Oggi"/"Ieri"/nome del giorno/data
/// completa), condivise fra DaySelector (home) e MealDetailPage — stessa
/// logica in entrambi i posti invece di due convenzioni diverse (i due
/// mockup indipendenti — Home Final e Meal Detail v2 — ne proponevano una
/// ciascuno, tenuta una sola per coerenza nell'app).
String relativeDayLabel(String lang, DateTime date, DateTime today) {
  final diff = DateTime(date.year, date.month, date.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  if (diff == 0) return Translations.get(lang, 'day_today');
  if (diff == -1) return Translations.get(lang, 'day_yesterday');
  if (diff == 1) return Translations.get(lang, 'day_tomorrow');
  if (diff.abs() < 7) return Translations.get(lang, 'weekday_${date.weekday}');
  return fullDateLabel(lang, date);
}

String fullDateLabel(String lang, DateTime date) {
  final weekday = Translations.get(lang, 'weekday_${date.weekday}');
  final month = Translations.get(lang, 'month_${date.month}');
  // Il cinese scrive anno, mese e giorno in quest'ordine: "星期六, 19 9月
  // 2026" era la forma italiana con le parole cinesi dentro (test di
  // release 19/09).
  if (lang == '简体中文') return '${date.year}年${date.month}月${date.day}日 $weekday';
  return '$weekday, ${date.day} $month ${date.year}';
}

/// Solo "23 ago 2026", senza il nome del giorno — usata dove il layout
/// mostra gia' l'etichetta relativa a fianco (es. MealDetailPage).
String shortDateLabel(String lang, DateTime date) {
  final month = Translations.get(lang, 'month_${date.month}');
  if (lang == '简体中文') return '${date.year}年${date.month}月${date.day}日';
  return '${date.day} $month ${date.year}';
}
