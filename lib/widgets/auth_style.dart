import 'dart:convert';

import 'package:flutter/material.dart';

/// Stile condiviso delle schermate dei mockup Claude Design (Login,
/// Registrazione, New product, Edit recipe).
///
/// PERCHE' NON IL ColorScheme DELL'APP: questi valori arrivano uno a uno dai
/// mockup e non sono derivati da un seed Material. Metterli nel tema
/// significherebbe o falsarli (lasciando che Material li ricalcoli) o
/// riscrivere il tema intero. Qui restano fedeli e in un posto solo, invece di
/// essere ricopiati a mano in ogni schermata — che e' esattamente come i due
/// selettori del pasto erano finiti a divergere fra loro.
class Nutri {
  const Nutri._();

  /// Luminosita' corrente, impostata dal builder di MaterialApp a ogni
  /// ricostruzione (vedi main.dart).
  ///
  /// PERCHE' UNA VARIABILE E NON Theme.of(context): questi colori vengono usati
  /// in 220 punti, moltissimi dentro espressioni `const` (stili di testo,
  /// bordi, decorazioni). Passare dal contesto avrebbe richiesto di togliere
  /// `const` ovunque e di portarsi dietro un parametro in ogni widget privato,
  /// per ottenere lo stesso risultato visivo. Il compromesso e' accettabile
  /// perche' il valore cambia solo quando cambia il tema dell'app, e viene
  /// aggiornato prima che qualunque schermata si disegni.
  ///
  /// Limite dichiarato: non regge due temi diversi contemporaneamente nella
  /// stessa app (es. un'anteprima chiara dentro un'app scura). Oggi non
  /// succede; se un giorno servisse, la strada e' un ThemeExtension letto dal
  /// contesto in ognuno di quei punti.
  static bool _scuro = false;

  static void applicaTema(Brightness b) => _scuro = b == Brightness.dark;
  static bool get scuro => _scuro;

  static Color _c(Color chiaro, Color scuro) => _scuro ? scuro : chiaro;

  /// Sfondo della pagina.
  static Color get bg => _c(const Color(0xFFF4F7EF), const Color(0xFF11150F));

  /// Superficie delle card e dei campi, dove prima c'era Colors.white fisso.
  static Color get card => _c(Colors.white, const Color(0xFF1B211A));

  /// Verde del marchio: in scuro va schiarito, altrimenti sparisce sul fondo.
  static Color get green => _c(const Color(0xFF1B7A33), const Color(0xFF6FBF73));
  static Color get greenDark => _c(const Color(0xFF14522A), const Color(0xFF8FD494));
  static Color get greenHover => _c(const Color(0xFF15612A), const Color(0xFF57A85C));

  /// Verde di RIEMPIMENTO dei pulsanti pieni, con [onGreenFill] sopra.
  ///
  /// PERCHE' SEPARATO DA [green] (2026-09-07): sono due mestieri opposti.
  /// `green` deve risaltare SOPRA il fondo scuro, quindi in scuro e' chiaro
  /// (#6FBF73); ma usato come fondo di un pulsante con la scritta bianca
  /// sopra da' bianco-su-verde-chiaro, che e' esattamente il "pulsanti verdi
  /// sbiaditi" segnalato da Ismail. Il riempimento vuole il contrario: un
  /// verde piu' cupo, su cui il bianco si stacca.
  static Color get greenFill => _c(const Color(0xFF1B7A33), const Color(0xFF2F8A44));
  static Color get onGreenFill => Colors.white;

  /// Fondo tenue verde dello stato "fatto" dei pulsanti.
  static Color get greenSoft => _c(const Color(0xFFEAF4E6), const Color(0xFF1E2A1D));

  /// Testo principale e le sue gradazioni.
  static Color get ink => _c(const Color(0xFF1F2A1C), const Color(0xFFE6EDE3));
  static Color get label => _c(const Color(0xFF3A4437), const Color(0xFFC7D1C3));
  static Color get body => _c(const Color(0xFF5A6157), const Color(0xFFB2BCAE));
  static Color get muted => _c(const Color(0xFF7D857A), const Color(0xFF97A193));
  static Color get mutedSoft => _c(const Color(0xFF8B938A), const Color(0xFF8A947F));
  static Color get hint => _c(const Color(0xFFA9B1A6), const Color(0xFF6E786B));

  /// Bordi e separatori.
  static Color get fieldBorder => _c(const Color(0xFFE7EDDF), const Color(0xFF2C352A));
  static Color get fieldBorderError => _c(const Color(0xFFDFBBB0), const Color(0xFF6E4034));
  static Color get hairline => _c(const Color(0xFFE1E8DA), const Color(0xFF2C352A));
  static Color get socialBorder => _c(const Color(0xFFDDE5D5), const Color(0xFF333D31));
  static Color get divider => _c(const Color(0xFFDDE4D3), const Color(0xFF303A2E));

  /// Riempimenti spenti.
  static Color get disabledBg => _c(const Color(0xFFE4EADC), const Color(0xFF262E24));
  static Color get surfaceSoft => _c(const Color(0xFFEDF1E6), const Color(0xFF20281F));

  /// Fondi tinti degli avvisi e delle note (banner macro fuori soglia, card
  /// dei consigli, riquadro dell'esportazione).
  ///
  /// PERCHE' NELLA PALETTE (2026-09-05): erano tinte chiarissime scritte a mano
  /// dentro i singoli widget — un giallo crema, un pesca — e in modalita' scura
  /// restavano tali: rettangoli quasi bianchi in mezzo a una schermata scura,
  /// con sopra un testo chiaro che spariva. In scuro diventano la stessa tinta
  /// ma cupa, cosi' il riquadro si legge ancora come "attenzione" senza
  /// accecare.
  static Color get warnBg => _c(const Color(0xFFFFF4EC), const Color(0xFF2A2018));
  static Color get warnBorder => _c(const Color(0xFFF3C8A9), const Color(0xFF54402F));
  static Color get noteBg => _c(const Color(0xFFFFFBF1), const Color(0xFF262418));
  static Color get noteBorder => _c(const Color(0xFFF2E5BA), const Color(0xFF4B472F));
  static Color get dangerBg => _c(const Color(0xFFFBEAE6), const Color(0xFF2C1D19));

  /// Ambra dei pasti (icona caffe'/pranzo/cena/spuntino).
  static Color get pasto => _c(const Color(0xFFB77A15), const Color(0xFFD9A441));

  /// Rosso degli errori: schiarito in scuro per restare leggibile.
  static Color get danger => _c(const Color(0xFFB4553C), const Color(0xFFE08469));

  // Stati delle segnalazioni (13/09), dai mockup "Proponi i valori corretti" e
  // "Le mie segnalazioni": ambra = in attesa, rosso = rifiutata. Qui e non
  // scritti nelle due schermate, perche' due pagine con le loro tinte sono il
  // difetto delle due palette che il 07/09 e' costato un giorno. Il rosso NON
  // e' `danger`: quello e' il terracotta delle azioni distruttive, questo e'
  // lo stato di una cosa gia' decisa.
  static Color get amber => _c(const Color(0xFFB26A00), const Color(0xFFE0A24C));
  static Color get amberSoft => _c(const Color(0xFFFDF3E2), const Color(0xFF36291A));
  static Color get red => _c(const Color(0xFFB3261E), const Color(0xFFEE8B80));
  static Color get redSoft => _c(const Color(0xFFFBECEB), const Color(0xFF3A2320));

  /// Colori ufficiali del bollino Nutri-Score. NON cambiano con il tema: sono
  /// un codice colore normato, riconoscibile solo se resta identico.
  static const nutriScore = {
    'a': Color(0xFF038141),
    'b': Color(0xFF7FA92B),
    'c': Color(0xFFD9A400),
    'd': Color(0xFFEE8100),
    'e': Color(0xFFE63E11),
  };

  /// Testo leggibile sopra un colore di punteggio: scuro sulle due tinte
  /// chiare, bianco sulle altre.
  static Color fgOnScore(Color c) =>
      (c == const Color(0xFF7FA92B) || c == const Color(0xFFD9A400))
          ? const Color(0xFF1F2A1C)
          : Colors.white;
}

/// Immagine scelta dall'utente, che puo' essere un indirizzo web OPPURE
/// un'immagine codificata in base64 (foto presa dalla galleria).
///
/// Le due cose convivono nella stessa colonna di proposito: `image_url` di una
/// ricetta o di un alimento puo' arrivare da OpenFoodFacts (indirizzo) o dal
/// telefono dell'utente (base64), e chi la disegna non deve sapere quale delle
/// due sia. Restituisce null quando non c'e' niente da mostrare, cosi' il
/// chiamante puo' ricadere sulla sua icona invece di lasciare un buco.
ImageProvider? nutriImageProvider(String? valore) {
  final v = (valore ?? '').trim();
  if (v.isEmpty) return null;
  if (v.startsWith('http://') || v.startsWith('https://')) {
    return NetworkImage(v);
  }
  // Una data URI ("data:image/jpeg;base64,...") o il solo base64.
  final dati = v.contains(',') ? v.substring(v.indexOf(',') + 1) : v;
  try {
    return MemoryImage(base64Decode(dati));
  } catch (_) {
    // Non e' ne' un indirizzo ne' base64 valido: meglio niente che un errore
    // di decodifica a ogni frame.
    return null;
  }
}

/// Etichetta sopra un campo, come nei mockup: 13px, grassetto, verde scuro.
class NutriFieldLabel extends StatelessWidget {
  const NutriFieldLabel(this.text, {super.key, this.trailing});

  final String text;

  /// Parte non in grassetto accanto all'etichetta, es. "(facoltativo)".
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text.rich(
        TextSpan(
          text: text,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Nutri.label),
          children: [
            if (trailing != null)
              TextSpan(
                text: ' $trailing',
                style: TextStyle(fontWeight: FontWeight.normal, color: Nutri.mutedSoft),
              ),
          ],
        ),
      ),
    );
  }
}

/// Campo di testo dei mockup: riquadro bianco, angoli 14, bordo 1.5 che
/// diventa rosso quando il valore non e' valido.
class NutriField extends StatelessWidget {
  const NutriField({
    super.key,
    required this.controller,
    this.icon,
    this.hint = '',
    this.error = false,
    this.obscure = false,
    this.keyboard,
    this.trailing,
    this.suffixText,
    this.onChanged,
    this.height = 52,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final IconData? icon;
  final String hint;
  final bool error;
  final bool obscure;
  final TextInputType? keyboard;
  final Widget? trailing;
  final String? suffixText;
  final ValueChanged<String>? onChanged;
  final double height;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: Nutri.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error ? Nutri.fieldBorderError : Nutri.fieldBorder,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Nutri.mutedSoft),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboard,
              onChanged: onChanged,
              readOnly: readOnly,
              onTap: onTap,
              style: TextStyle(fontSize: 16, color: Nutri.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: Nutri.hint, fontSize: 16),
              ),
            ),
          ),
          if (suffixText != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                suffixText!,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Nutri.mutedSoft,
                ),
              ),
            ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Riga d'errore sotto un campo: icona rossa + testo, come nei mockup.
class NutriInlineError extends StatelessWidget {
  const NutriInlineError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: Nutri.danger),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 12.5, color: Nutri.danger)),
          ),
        ],
      ),
    );
  }
}

/// Casella di spunta quadrata 22px dei mockup (non la Checkbox di Material,
/// che ha bordi, densita' e area di tocco diverse).
class NutriCheckbox extends StatelessWidget {
  const NutriCheckbox({super.key, required this.value, required this.onChanged, required this.child});

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: value ? Nutri.greenFill : Colors.transparent,
              border: Border.all(
                color: value ? Nutri.greenFill : Nutri.fieldBorder,
                width: 2,
              ),
            ),
            child: value ? Icon(Icons.check, size: 16, color: Nutri.onGreenFill) : null,
          ),
          const SizedBox(width: 11),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Spunta "accetto la privacy", identica in login e registrazione.
///
/// PERCHE' UN WIDGET SOLO: erano due copie con lo stesso aspetto ma
/// comportamenti leggermente diversi, ed e' esattamente il modo in cui i due
/// selettori del pasto erano finiti a divergere. Qui la spunta accende il
/// consenso e la parte in verde apre l'informativa: due azioni distinte nella
/// stessa riga, in un posto solo.
class NutriPrivacyCheck extends StatelessWidget {
  const NutriPrivacyCheck({
    super.key,
    required this.value,
    required this.onChanged,
    required this.testoPrima,
    required this.testoLink,
    required this.onApriInformativa,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// "Accetto la " — la parte che non e' un link.
  final String testoPrima;

  /// "privacy policy" — la parte verde che apre l'informativa.
  final String testoLink;
  final VoidCallback onApriInformativa;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => onChanged(!value),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: value ? Nutri.greenFill : Colors.transparent,
              border: Border.all(
                color: value ? Nutri.greenFill : Nutri.fieldBorder,
                width: 2,
              ),
            ),
            child: value ? Icon(Icons.check, size: 16, color: Nutri.onGreenFill) : null,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: testoPrima,
              style: TextStyle(fontSize: 13.5, color: Nutri.label),
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: onApriInformativa,
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Nutri.green, width: 1.1),
                        ),
                      ),
                      child: Text(
                      testoLink,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Nutri.green,
                      ),
                    ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Pillola selezionabile dei mockup (categorie, allergeni, diete, genere).
class NutriChip extends StatelessWidget {
  const NutriChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 32,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? Nutri.greenFill : Nutri.card,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: selected ? Nutri.greenFill : Nutri.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              Icon(leading, size: 14, color: selected ? Colors.white : Nutri.label),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? Colors.white : Nutri.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsante largo in fondo alle schermate: verde quando l'azione e'
/// disponibile, spento con testo grigio quando manca qualcosa.
class NutriPrimaryButton extends StatelessWidget {
  const NutriPrimaryButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.icon,
    this.iconFirst = false,
    this.height = 54,
    this.doneStyle = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? icon;
  final bool iconFirst;
  final double height;

  /// Stato "fatto" del mockup: fondo verde chiaro e testo verde, non pieno.
  final bool doneStyle;

  @override
  Widget build(BuildContext context) {
    final bg = doneStyle
        ? Nutri.greenSoft
        : enabled
            ? Nutri.greenFill
            : Nutri.disabledBg;
    final fg = doneStyle
        ? Nutri.green
        : enabled
            ? Nutri.onGreenFill
            : Nutri.mutedSoft;
    final testo = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: fg),
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: icon == null
            ? testo
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: iconFirst
                    ? [Icon(icon, size: 21, color: fg), const SizedBox(width: 8), Flexible(child: testo)]
                    : [Flexible(child: testo), const SizedBox(width: 8), Icon(icon, size: 21, color: fg)],
              ),
      ),
    );
  }
}

/// Barra di avanzamento a segmenti con etichetta sotto (mockup Registration).
///
/// A differenza del mockup, che ne disegna sempre due, prende il numero di
/// passi reale: il flusso dell'app ne ha da 3 a 5 a seconda che l'utente
/// scelga il piano personalizzato, e mostrarne due sarebbe una bugia sul
/// tempo che manca.
class NutriStepBar extends StatelessWidget {
  const NutriStepBar({super.key, required this.labels, required this.current});

  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i + 1 < current
                        ? const Color(0xFF7FA92B)
                        : i + 1 == current
                            ? Nutri.green
                            : Nutri.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: i + 1 == current ? FontWeight.bold : FontWeight.w500,
                    color: i + 1 == current
                        ? Nutri.green
                        : i + 1 < current
                            ? Nutri.muted
                            : const Color(0xFFB0B8AC),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Link testuale con la sottolineatura STACCATA dal testo.
///
/// PERCHE' NON `TextDecoration.underline` (2026-09-09): Flutter disegna quella
/// riga appiccicata alla base delle lettere, quindi passa in mezzo alle code
/// di g, y, p — "la sottolineatura risulta sovrapposta al testo", come l'ha
/// vista Ismail su "Register it yourself!" e "Add new recipe". Non esiste un
/// parametro per allontanarla: l'unico modo e' disegnarla noi come bordo
/// inferiore di un contenitore, con qualche pixel di respiro in mezzo.
class NutriLinkTesto extends StatelessWidget {
  const NutriLinkTesto({
    super.key,
    required this.testo,
    this.onTap,
    this.fontSize = 15,
    this.fontWeight = FontWeight.bold,
    this.colore,
  });

  final String testo;
  /// null quando il tocco lo gestisce un InkWell che sta gia' sopra: in quel
  /// caso questo widget non deve intercettare niente, solo disegnare.
  final VoidCallback? onTap;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? colore;

  @override
  Widget build(BuildContext context) {
    final c = colore ?? Nutri.green;
    final riga = Container(
        // 3 px fra la base delle lettere e la riga: bastano perche' le code
        // non la tocchino, senza che smetta di leggersi come un link.
      padding: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c, width: 1.2)),
      ),
      child: Text(
        testo,
        style: TextStyle(color: c, fontSize: fontSize, fontWeight: fontWeight),
      ),
    );
    if (onTap == null) return riga;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: riga,
    );
  }
}
