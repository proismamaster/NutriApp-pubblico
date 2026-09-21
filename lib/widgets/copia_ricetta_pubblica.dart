import 'package:flutter/material.dart';

import '../dictionary/translations.dart';
import '../models/recipe.dart';
import '../screens/add_recipe.dart';

/// Copia privata di una ricetta pubblica (richiesta di Ismail, 21/09).
///
/// PERCHE' UNA COPIA E NON UNA MODIFICA: una ricetta pubblica la stanno gia'
/// leggendo altri, e chi la cambia sotto i piedi cambierebbe cio' che hanno
/// salvato. Vale sia per quelle degli altri sia per le proprie gia' approvate,
/// che dal 15/09 fanno parte del database e non si riscrivono piu'.
///
/// Prima di oggi la matita su una ricetta approvata apriva solo la
/// spiegazione "questo contenuto e' bloccato": un vicolo cieco. Ora la strada
/// c'e', ma passa da un popup — chi tocca la matita si aspetta di modificare
/// QUELLA ricetta, e senza spiegazione si ritroverebbe due ricette uguali
/// nella lista senza capire da dove sia uscita la seconda.
///
/// Restituisce `true` se la copia e' stata salvata davvero.
Future<bool> copiaRicettaPubblica(
  BuildContext context, {
  required Recipe ricetta,
  required String lang,
}) async {
  final conferma = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(Translations.get(lang, 'recipe_public_copy_title')),
      content: Text(Translations.get(lang, 'recipe_public_copy_body')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(Translations.get(lang, 'Annulla')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(Translations.get(lang, 'recipe_public_copy_confirm')),
        ),
      ],
    ),
  );
  if (conferma != true || !context.mounted) return false;

  // Stessi parametri, stessi ingredienti, stessa foto — senza id: e' l'id che
  // distingue "aggiorna quella" da "creane una nuova" (vedi add_recipe.dart).
  // Anche gli stati ripartono da zero: la copia e' privata e non eredita ne'
  // i like ne' il fatto di essere gia' stata proposta.
  final copia = ricetta.copy()
    ..id = null
    ..sharedStatus = 'private'
    ..isFavorite = false
    ..likesCount = 0
    ..likedByMe = false;

  final salvata = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => CreaRicettaPage(initialRecipe: copia, comeCopia: true),
    ),
  );
  return salvata == true;
}
