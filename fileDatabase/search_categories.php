<?php
/**
 * search_categories.php — propone le categorie che il catalogo conosce gia'.
 *
 * PERCHE' ESISTE (2026-09-05)
 * L'inserimento manuale offriva sette categorie fisse scritte nel codice
 * ("Snack", "Latticini", ...). Sono poche e, soprattutto, non c'entrano niente
 * con le categorie vere che il resto dell'app usa per ordinare la ricerca:
 * quelle sono i tag della tassonomia OpenFoodFacts gia' presenti in
 * na_off_products. Un alimento creato a mano finiva quindi in un mondo a
 * parte. Qui le categorie vengono dal catalogo vero.
 *
 * ORDINAMENTO PER DIFFUSIONE, non alfabetico: cercando "pas" ci sono decine di
 * tag che contengono quel pezzo di parola; quello utile e' quasi sempre il
 * piu' usato, non il primo in ordine alfabetico.
 *
 * SOTTOCATEGORIE — LIMITE DICHIARATO: OpenFoodFacts non memorizza la gerarchia
 * dentro na_off_products, memorizza solo l'elenco dei tag. Qui la parentela e'
 * DEDOTTA dalla forma del nome (`arborio-rices` sta sotto `rices`), che e' la
 * convenzione con cui quei tag sono scritti. Funziona nella grande maggioranza
 * dei casi ma non e' la gerarchia ufficiale: per questo l'app le presenta come
 * "categorie piu' specifiche" e non come una tassonomia certificata.
 */

require 'db_config.php';

header('Content-Type: application/json');

$q = trim($_GET['q'] ?? '');
$parent = trim($_GET['parent'] ?? '');
$limit = min(30, max(1, (int)($_GET['limit'] ?? 20)));

/** Da `en:breakfast-cereals` a "Breakfast cereals". */
function na_etichetta(string $tag): string {
    $senza = strpos($tag, ':') !== false ? substr($tag, strpos($tag, ':') + 1) : $tag;
    $senza = str_replace(['-', '_'], ' ', $senza);
    return $senza === '' ? '' : mb_strtoupper(mb_substr($senza, 0, 1)) . mb_substr($senza, 1);
}

/**
 * `categories` contiene piu' tag separati da virgola: per contarli uno per uno
 * servirebbe una tabella di appoggio. Con i numeri in gioco conviene invece
 * leggere le righe che contengono il termine e scomporle qui, limitando quante
 * se ne guardano.
 */
$risultati = [];

if ($parent !== '') {
    // Sottocategorie: tag che finiscono con "-<parent>", la convenzione OFF.
    $like = '%' . $conn->real_escape_string($parent) . '%';
    $sql = "SELECT categories FROM na_off_products
            WHERE categories LIKE ? AND categories <> ''
            LIMIT 4000";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('s', $like);
} else {
    if ($q === '') {
        echo json_encode(['status' => 'success', 'categories' => []]);
        exit;
    }
    $like = '%' . $conn->real_escape_string($q) . '%';
    $sql = "SELECT categories FROM na_off_products
            WHERE categories LIKE ? AND categories <> ''
            LIMIT 4000";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('s', $like);
}

if (!$stmt || !$stmt->execute()) {
    echo json_encode(['status' => 'error', 'message' => 'Errore SQL: ' . $conn->error]);
    exit;
}

$res = $stmt->get_result();
$conteggi = [];
$termine = mb_strtolower($q);
while ($riga = $res->fetch_assoc()) {
    foreach (explode(',', $riga['categories']) as $tag) {
        $tag = trim($tag);
        if ($tag === '') continue;
        $basso = mb_strtolower($tag);

        if ($parent !== '') {
            // figlio = finisce con "-<parent>" e non e' il parent stesso
            $suffisso = '-' . mb_strtolower($parent);
            $nudo = strpos($basso, ':') !== false ? substr($basso, strpos($basso, ':') + 1) : $basso;
            if ($nudo === mb_strtolower($parent)) continue;
            if (substr($nudo, -strlen($suffisso)) !== $suffisso) continue;
        } elseif (mb_strpos($basso, $termine) === false) {
            continue;
        }

        $conteggi[$tag] = ($conteggi[$tag] ?? 0) + 1;
    }
}
$stmt->close();

arsort($conteggi);
foreach (array_slice($conteggi, 0, $limit, true) as $tag => $n) {
    $nudo = strpos($tag, ':') !== false ? substr($tag, strpos($tag, ':') + 1) : $tag;
    $risultati[] = [
        'tag' => $tag,
        'label' => na_etichetta($tag),
        'count' => $n,
        // Indica se vale la pena proporre un secondo livello: lo verifica
        // l'app con una seconda chiamata, qui basta il nome nudo.
        'slug' => $nudo,
    ];
}

echo json_encode(['status' => 'success', 'categories' => $risultati]);
$conn->close();
