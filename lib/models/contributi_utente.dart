import 'segnalazione_utente.dart';

/// Tutto cio' che l'utente ha mandato alla comunita', come lo restituisce
/// get_my_reports.php dal 15/09: le segnalazioni sui dati, i problemi
/// dell'app, gli alimenti e le ricette proposti. Una chiamata sola per le tre
/// schede di "Le mie segnalazioni".
class ContributiUtente {
  final List<SegnalazioneUtente> segnalazioni;
  final List<ProblemaApp> problemi;
  final List<ContributoPubblico> alimenti;
  final List<ContributoPubblico> ricette;

  const ContributiUtente({
    this.segnalazioni = const [],
    this.problemi = const [],
    this.alimenti = const [],
    this.ricette = const [],
  });

  factory ContributiUtente.fromJson(Map<String, dynamic> json) {
    List<T> lista<T>(String chiave, T Function(Map<String, dynamic>) leggi) =>
        (json[chiave] as List? ?? const [])
            .whereType<Map>()
            .map((m) => leggi(Map<String, dynamic>.from(m)))
            .toList();

    return ContributiUtente(
      segnalazioni: lista('reports', SegnalazioneUtente.fromJson),
      problemi: lista('app_reports', ProblemaApp.fromJson),
      alimenti: lista('foods', ContributoPubblico.fromJson),
      ricette: lista('recipes', ContributoPubblico.fromJson),
    );
  }
}

DateTime? _data(dynamic v) {
  final t = (v ?? '').toString();
  return t.isEmpty ? null : DateTime.tryParse(t);
}

/// Un problema dell'app mandato da "Segnala un problema".
class ProblemaApp {
  final int id;
  final String descrizione;

  /// bug | data | sync | idea | other, oppure vuoto su un server vecchio.
  final String tipo;
  final String schermata;

  /// open | resolved | closed
  final String stato;

  /// La risposta di chi l'ha gestito: per un problema chiuso e' il perche'.
  final String rispostaAdmin;
  final DateTime? creatoIl;
  final DateTime? gestitoIl;

  const ProblemaApp({
    required this.id,
    required this.descrizione,
    this.tipo = '',
    this.schermata = '',
    this.stato = 'open',
    this.rispostaAdmin = '',
    this.creatoIl,
    this.gestitoIl,
  });

  factory ProblemaApp.fromJson(Map<String, dynamic> json) => ProblemaApp(
        id: int.tryParse('${json['id']}') ?? 0,
        descrizione: (json['description'] ?? '').toString(),
        tipo: (json['kind'] ?? '').toString(),
        schermata: (json['screen'] ?? '').toString(),
        // Uno stato sconosciuto si legge come aperto: dire "risolto" una cosa
        // che il server non ha detto risolta sarebbe il modo peggiore di sbagliare.
        stato: const ['open', 'resolved', 'closed'].contains(json['status'])
            ? json['status'] as String
            : 'open',
        rispostaAdmin: (json['admin_note'] ?? '').toString(),
        creatoIl: _data(json['created_at']),
        gestitoIl: _data(json['handled_at']),
      );
}

/// Un alimento o una ricetta proposti al pubblico.
class ContributoPubblico {
  final int id;
  final String nome;

  /// Marca per un alimento; vuoto per una ricetta.
  final String dettaglio;

  /// pending | approved | rejected
  final String stato;
  final DateTime? propostoIl;
  final DateTime? decisoIl;
  final String motivo;

  /// Tolto dalla propria libreria dopo l'approvazione: resta pubblico.
  final bool rimosso;
  final int like;

  const ContributoPubblico({
    required this.id,
    required this.nome,
    this.dettaglio = '',
    this.stato = 'pending',
    this.propostoIl,
    this.decisoIl,
    this.motivo = '',
    this.rimosso = false,
    this.like = 0,
  });

  factory ContributoPubblico.fromJson(Map<String, dynamic> json) => ContributoPubblico(
        id: int.tryParse('${json['id']}') ?? 0,
        nome: (json['name'] ?? '').toString(),
        dettaglio: (json['brand'] ?? '').toString(),
        stato: const ['pending', 'approved', 'rejected'].contains(json['shared_status'])
            ? json['shared_status'] as String
            : 'pending',
        propostoIl: _data(json['shared_at']),
        decisoIl: _data(json['reviewed_at']),
        motivo: (json['review_note'] ?? '').toString(),
        rimosso: json['removed'] == true,
        like: int.tryParse('${json['likes'] ?? 0}') ?? 0,
      );
}
