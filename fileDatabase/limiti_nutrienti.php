<?php
/**
 * limiti_nutrienti.php — cosa puo' esistere davvero in 100 g di cibo.
 *
 * PERCHE' (decisione del 20/09, dopo il test di release)
 * In `na_off_products` ci sono valori arrivati da OpenFoodFacts che nessun
 * alimento puo' avere: il prodotto `0810128370448` dichiara 40000 kcal per
 * 100 g. Non e' un errore dell'app: e' un dato sbagliato alla fonte, entrato
 * senza che nessuno lo guardasse. Da qui in poi non entra piu': quello che
 * sfora i limiti fisici viene scartato in import e rifiutato agli endpoint.
 *
 * I LIMITI, E DA DOVE VENGONO
 *  - 100 g di prodotto non possono contenere piu' di 100 g di qualcosa;
 *  - il grasso puro da' 9 kcal/g, quindi oltre 900 kcal per 100 g non si va
 *    (l'olio, il massimo che esista, sta a 884);
 *  - l'energia dichiarata deve somigliare a quella dei macro (4/4/9): oltre il
 *    doppio o sotto la meta' vuol dire che qualcuno ha sbagliato unita' o
 *    virgola. La tolleranza e' larga apposta, perche' fibre, polioli e alcol
 *    spostano il conto e non vogliamo buttare via dati buoni.
 *
 * Chi lo usa: save_custom_food.php (quello che scrivono gli utenti), il
 * pannello di revisione quando accetta una correzione, e gli import di massa
 * (vedi import_plausibilita.sql, che applica le stesse soglie in SQL).
 */

declare(strict_types=1);

/** Oltre 900 kcal per 100 g non esiste alimento: il grasso puro ne fa 900. */
const NUTRI_MAX_KCAL = 900.0;

/** Campi espressi in grammi su 100 g di prodotto. */
const NUTRI_CAMPI_IN_GRAMMI = [
    'carbs', 'proteins', 'fats', 'fibers', 'sugars', 'water', 'saturated_fats',
    'monounsaturated_fats', 'polyunsaturated_fats', 'trans_fats', 'added_sugars',
    'starch', 'polyols', 'lactose', 'salt',
];

/**
 * Il motivo per cui questi valori non possono essere veri, o null se reggono.
 *
 * [$riga] sono i valori per 100 g con i nomi delle colonne. I campi assenti
 * non si controllano: un prodotto senza fibre dichiarate non e' un errore.
 */
function erroreNutrienti(array $riga): ?string
{
    $numero = static function ($v): ?float {
        if ($v === null || $v === '') {
            return null;
        }
        return is_numeric($v) ? (float) $v : null;
    };

    foreach ($riga as $campo => $valore) {
        $n = $numero($valore);
        if ($n === null) {
            continue;
        }
        if ($n < 0 && in_array($campo, array_merge(NUTRI_CAMPI_IN_GRAMMI, ['calories']), true)) {
            return "valore negativo in $campo";
        }
        if (in_array($campo, NUTRI_CAMPI_IN_GRAMMI, true) && $n > 100) {
            return "$campo oltre 100 g su 100 g di prodotto";
        }
    }

    $kcal = $numero($riga['calories'] ?? null);
    if ($kcal !== null && $kcal > NUTRI_MAX_KCAL) {
        return 'oltre ' . (int) NUTRI_MAX_KCAL . ' kcal per 100 g: nemmeno l\'olio ci arriva';
    }

    // Somma dei tre macro: oltre 100 g su 100 g non ci stanno.
    $carb = $numero($riga['carbs'] ?? null) ?? 0;
    $prot = $numero($riga['proteins'] ?? null) ?? 0;
    $gras = $numero($riga['fats'] ?? null) ?? 0;
    if ($carb + $prot + $gras > 100.5) {
        return 'la somma dei macro supera i 100 g';
    }

    // Energia dichiarata contro energia dei macro, con tolleranza larga.
    $daMacro = $carb * 4 + $prot * 4 + $gras * 9;
    if ($kcal !== null && $kcal > 0 && $daMacro > 50) {
        if ($kcal > $daMacro * 2.2) {
            return 'energia dichiarata piu' . "'" . ' che doppia rispetto ai macro';
        }
        if ($kcal < $daMacro / 2.2) {
            return 'energia dichiarata meno della meta' . "'" . ' di quella dei macro';
        }
    }

    return null;
}
