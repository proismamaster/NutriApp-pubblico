<?php
/**
 * index.php — cruscotto: quante cose aspettano, e da quanto.
 *
 * Ricalcato sulla schermata 3A dei mockup: tre riquadri con un numero grande,
 * sotto la tabella delle attese piu' vecchie con i giorni colorati (ambra da 7,
 * rosso da 14), e una variante "tutto fatto" quando le code sono vuote — che
 * deve sembrare una buona notizia, non un errore.
 *
 * Una differenza voluta dal mockup: nel riquadro il numero NON e' ripetuto
 * nell'etichetta ("7" sopra, "segnalazioni aperte" sotto, non "7 segnalazioni
 * aperte"). Due volte lo stesso numero a pochi pixel non aggiunge niente.
 */

declare(strict_types=1);
require __DIR__ . '/_comune.php';
richiediAccesso();

/** Conteggio secco, con 0 se la tabella non c'e' ancora (migrazione a meta'). */
function conta(mysqli $conn, string $sql): int
{
    $res = @$conn->query($sql);
    if (!$res) {
        return 0;
    }
    return (int) ($res->fetch_row()[0] ?? 0);
}

$segnalazioni = conta($conn, "SELECT COUNT(*) FROM na_food_reports WHERE status = 'pending'");
// Segnalazioni sulle ricette pubbliche (21/09): `conta` risponde 0 se la
// tabella non c'e' ancora, quindi il cruscotto regge un server a meta'
// migrazione senza mostrare un errore.
$segnRicette = conta($conn, "SELECT COUNT(*) FROM na_recipe_reports WHERE status = 'pending'");
$alimenti = conta($conn, "SELECT COUNT(*) FROM na_custom_foods WHERE shared_status = 'pending'");
$ricette = conta($conn, "SELECT COUNT(*) FROM na_recipes WHERE shared_status = 'pending'");

$riquadro = static function (string $file, int $n, string $etichetta): string {
    return '<a class="contatore' . ($n === 0 ? ' zero' : '') . '" href="' . e($file) . '">'
        . '<div class="n">' . $n . '</div>'
        . '<div class="etichetta">' . e($etichetta) . '</div></a>';
};

$html = '<div class="contatori">'
    . $riquadro('segnalazioni.php', $segnalazioni, $segnalazioni === 1 ? 'segnalazione aperta' : 'segnalazioni aperte')
    . $riquadro('segnalazioni_ricette.php', $segnRicette, $segnRicette === 1 ? 'ricetta segnalata' : 'ricette segnalate')
    . $riquadro('alimenti.php', $alimenti, $alimenti === 1 ? 'alimento in attesa' : 'alimenti in attesa')
    . $riquadro('ricette.php', $ricette, $ricette === 1 ? 'ricetta in attesa' : 'ricette in attesa')
    . '</div>';

// Le piu' vecchie delle tre code insieme: chi rivede ha un solo tempo a
// disposizione, e deve vedere in un colpo cosa e' rimasto indietro.
$piuVecchie = [];
$sql = "SELECT 'Segnalazioni' AS coda, id, CONCAT(food_name, ' · ', issue) AS nome, created_at AS quando, 's' AS tipo
          FROM na_food_reports WHERE status = 'pending'
        UNION ALL
        SELECT 'Alimenti proposti', id, food_name, shared_at, 'a'
          FROM na_custom_foods WHERE shared_status = 'pending'
        UNION ALL
        SELECT 'Ricette proposte', id, recipe_name, shared_at, 'r'
          FROM na_recipes WHERE shared_status = 'pending'
        ORDER BY quando ASC LIMIT 8";
$res = @$conn->query($sql);
while ($res && ($r = $res->fetch_assoc())) {
    $piuVecchie[] = $r;
}

if ($piuVecchie === []) {
    $html .= '<div class="tutto-fatto"><div class="cerchio">'
        . '<svg width="22" height="22" viewBox="0 0 24 24" fill="none"><path d="M5 13l5 5L19 7" stroke="#1B7A33" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>'
        . '</div><div>Nessuna coda aperta: non c\'è niente da rivedere</div></div>';
} else {
    $righe = '';
    foreach ($piuVecchie as $r) {
        $dove = match ($r['tipo']) {
            's' => 'segnalazione.php?id=' . (int) $r['id'],
            'a' => 'alimenti.php#a' . (int) $r['id'],
            default => 'ricette.php#r' . (int) $r['id'],
        };
        $righe .= '<div class="riga">'
            . '<span class="secondario">' . e($r['coda']) . '</span>'
            . '<a class="taglia" href="' . e($dove) . '">' . e($r['nome'] ?: '(senza nome)') . '</a>'
            . '<strong class="destra ' . classeAttesa($r['quando']) . '">' . e(attesa($r['quando'])) . '</strong>'
            . '</div>';
    }
    $html .= '<h2>Le più vecchie in attesa</h2><div class="riquadro attese">'
        . '<div class="riga testa">'
        . '<span>Coda</span><span>Cosa</span><span class="destra">In attesa da</span></div>'
        . $righe . '</div>';
}

pagina('Cruscotto', $html, 'index.php');
