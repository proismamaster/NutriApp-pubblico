class AvvisoNotifica {
  final DateTime dataOra;
  final String tipo; // "Pasto" o "Acqua"
  final String descrizione;

  const AvvisoNotifica({
    required this.dataOra,
    required this.tipo,
    required this.descrizione,
  });

  String get dataFormattata {
    return "${dataOra.day.toString().padLeft(2, '0')}/${dataOra.month.toString().padLeft(2, '0')}/${dataOra.year}";
  }

  String get oraFormattata {
    final periodo = dataOra.hour >= 12 ? 'PM' : 'AM';
    final ora = dataOra.hour > 12 ? dataOra.hour - 12 : dataOra.hour == 0 ? 12 : dataOra.hour;
    final minuti = dataOra.minute.toString().padLeft(2, '0');
    return "$ora:$minuti $periodo";
  }
}
