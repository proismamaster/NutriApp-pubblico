import 'package:flutter/material.dart';

import '../dictionary/translations.dart';
import '../logic/unit_format.dart';
import '../models/food_entry.dart';
import '../screens/manual_entry_page.dart';
import 'auth_style.dart';

/// Una voce del diario, identica nel dettaglio del giorno e in quello del
/// pasto (17/09, richiesta di Ismail: "devono essere coerenti").
///
///  - tocco sulla riga: la scheda del prodotto in sola lettura;
///  - matita: la STESSA scheda che si apre dalla ricerca, con pasto e peso gia'
///    scelti, segnala e modifica nella barra. Prima apriva l'inserimento
///    manuale, cioe' un modulo vuoto di sessanta campi per cambiare un peso;
///  - cestino: elimina.
class RigaAlimentoDiario extends StatelessWidget {
  final FoodEntry voce;
  final String lang;

  /// Da chiamare quando la voce e' stata modificata, per ricaricare.
  final VoidCallback onCambiata;
  final VoidCallback onElimina;

  const RigaAlimentoDiario({
    super.key,
    required this.voce,
    required this.lang,
    required this.onCambiata,
    required this.onElimina,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grado = (voce.nutriscoreGrade ?? '').toLowerCase();
    final coloreGrado = Nutri.nutriScore[grado];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => apriVoceDiario(context, voce, modifica: false),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voce.food_name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${UnitFormat.e(voce.macro.calories)}, ${UnitFormat.p(voce.weight_g)}',
                              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                            ),
                          ),
                          if (coloreGrado != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: coloreGrado, borderRadius: BorderRadius.circular(5)),
                              child: Text(
                                grado.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeData.estimateBrightnessForColor(coloreGrado) == Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF1F2A1C),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: Translations.get(lang, 'Modifica'),
                  icon: Icon(Icons.edit_outlined, color: scheme.primary),
                  onPressed: () async {
                    final cambiata = await apriVoceDiario(context, voce, modifica: true);
                    if (cambiata == true) onCambiata();
                  },
                ),
                IconButton(
                  tooltip: Translations.get(lang, 'Elimina'),
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  onPressed: onElimina,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Apre la scheda del prodotto di una voce del diario. I valori della voce
/// sono gia' per il suo peso, quindi quel peso fa da base del riproporzionamento.
Future<bool?> apriVoceDiario(BuildContext context, FoodEntry voce, {required bool modifica}) {
  return Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => ManualEntryPage(
        prefillData: {...voce.toJson(), 'base_weight_g': voce.weight_g},
        foodEntry: voce,
        isAddingFromLibrary: true,
        soloLettura: !modifica,
      ),
    ),
  );
}
