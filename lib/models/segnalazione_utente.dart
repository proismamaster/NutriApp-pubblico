/// Una segnalazione mandata dall'utente, con il suo esito — come la restituisce
/// get_my_reports.php (13/09).
///
/// Solo i NOMI dei campi proposti e accettati, non i valori: alla schermata
/// "Le mie segnalazioni" serve dire "1 campo accettato su 3", e i valori li ha
/// gia' chi li ha scritti.
class SegnalazioneUtente {
  final int id;
  final String foodName;
  final String barcode;

  /// valori | nome | categoria | immagine | duplicato | altro
  final String issue;

  /// correzione | nuovo
  final String kind;

  /// pending | accepted | rejected
  final String status;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  /// Motivazione del rifiuto scritta dal revisore. La parte piu' importante di
  /// una segnalazione rifiutata: senza, chi l'ha mandata non sa cosa cambiare.
  final String reviewNote;
  final List<String> proposedFields;
  final List<String> acceptedFields;
  final int photoCount;

  const SegnalazioneUtente({
    required this.id,
    required this.foodName,
    this.barcode = '',
    this.issue = '',
    this.kind = 'correzione',
    required this.status,
    this.createdAt,
    this.reviewedAt,
    this.reviewNote = '',
    this.proposedFields = const [],
    this.acceptedFields = const [],
    this.photoCount = 0,
  });

  /// Accettata ma non per intero: il caso piu' delicato da spiegare in una
  /// riga, perche' non e' un rifiuto e va detto che gli altri valori sono
  /// rimasti come erano.
  bool get accettataInParte =>
      status == 'accepted' &&
      proposedFields.isNotEmpty &&
      acceptedFields.isNotEmpty &&
      acceptedFields.length < proposedFields.length;

  /// Chiusa senza scrivere niente: succede sugli alimenti che il pannello non
  /// puo' modificare (CREA, USDA, librerie personali). "Accettata in parte -
  /// 0 su 3" faceva pensare a un errore (test di release 19/09).
  bool get chiusaSenzaModifiche =>
      status == 'accepted' && proposedFields.isNotEmpty && acceptedFields.isEmpty;

  factory SegnalazioneUtente.fromJson(Map<String, dynamic> json) {
    List<String> nomi(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : const <String>[];
    DateTime? data(dynamic v) {
      final t = (v ?? '').toString();
      return t.isEmpty ? null : DateTime.tryParse(t);
    }

    return SegnalazioneUtente(
      id: int.tryParse('${json['id']}') ?? 0,
      foodName: (json['food_name'] ?? '').toString(),
      barcode: (json['barcode'] ?? '').toString(),
      issue: (json['issue'] ?? '').toString(),
      kind: (json['kind'] ?? 'correzione').toString(),
      // Uno stato sconosciuto si legge come "in attesa": mostrare "accettata"
      // una cosa che il server non ha detto accettata sarebbe il modo peggiore
      // di sbagliare.
      status: const ['pending', 'accepted', 'rejected'].contains(json['status'])
          ? json['status'] as String
          : 'pending',
      createdAt: data(json['created_at']),
      reviewedAt: data(json['reviewed_at']),
      reviewNote: (json['review_note'] ?? '').toString(),
      proposedFields: nomi(json['proposed_fields']),
      acceptedFields: nomi(json['accepted_fields']),
      photoCount: json['photos'] is List ? (json['photos'] as List).length : 0,
    );
  }
}
