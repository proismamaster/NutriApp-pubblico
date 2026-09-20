<?php
/**
 * search_off_products.php — Ricerca full-text sulla tabella na_off_products
 * (prodotti OpenFoodFacts importati in locale, non ricerca live su OFF).
 *
 * CONTESTO (vedi vault: 03 Projects/NutriApp/PROBLEMS.md -> "Ricerca testuale
 * alimenti inaffidabile", punti 9 e P3): na_off_products esiste gia' nel DB con
 * PRIMARY KEY(barcode) e FULLTEXT KEY(food_name, brand) gia' configurati
 * (vedi fileDatabase/na_off_products.sql), ma finora nessuno script PHP la
 * interrogava. Questo file colma quel buco. Per popolarla oltre al pilota di
 * 30 righe esistente, vedi fileDatabase/tools/import_off_italy.py.
 *
 * Non sostituisce search_crea_foods.php (lascio quel file intoccato: in
 * modifica in parallelo in un'altra sessione sullo stesso progetto) — e' una
 * fonte aggiuntiva pensata per essere chiamata in parallelo alle altre, sullo
 * stesso modello di _searchCreaItalianDb/_searchUsdaAmericanDb in
 * lib/services/api_services.dart.
 *
 * INTEGRAZIONE LATO DART (non ancora fatta in questa sessione per non toccare
 * api_services.dart mentre e' in modifica altrove — istruzioni per quando si potra'):
 *   1. Aggiungere una costante `_urlServerSearchOffProducts` puntata a questo file,
 *      sullo stesso modello di `_urlServerSearchCrea`.
 *   2. Aggiungere `_searchOffProductsLocalDb(String q)` sul modello di
 *      `_searchCreaItalianDb`, con `'source': 'off_local_it'` nel mapping.
 *   3. Aggiungerla alla `Future.wait([...])` in `searchProducts()`.
 *   4. In `_calculateHybridScore`, dare priorita' tra crea_it e openfoodfacts_it
 *      (es. stesso punteggio di 'openfoodfacts_it', visto che i dati vengono
 *      dalla stessa fonte, solo importata invece che live).
 *
 * Risposta JSON nello stesso formato di search_crea_foods.php: {status, message, foods}.
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

require_once 'db_config.php';

$response = array("status" => "error", "message" => "Errore sconosciuto", "foods" => array());

$query = isset($_GET['query']) ? trim($_GET['query']) : '';
// Filtro opzionale per insegna (2026-08-22, multi-selezione dal 2026-08-23):
// "insegna" = che questa catena e' stata VISTA vendere il prodotto durante
// la raccolta, non disponibilita' in tempo reale (vedi commento in
// migrations/2026-08-22_ricerca_per_insegna.sql). Piu' insegne separate da
// virgola ("coop,lidl,esselunga"): OR fra loro, un prodotto visto in una
// qualunque delle catene selezionate.
$insegne = isset($_GET['insegna'])
    ? array_values(array_filter(array_map('trim', explode(',', $_GET['insegna'])), fn($s) => $s !== ''))
    : [];

// Query vuota ammessa SOLO se c'e' almeno un'insegna: "sfoglia questo
// supermercato" senza aver scritto niente e' un caso d'uso legittimo (tap sul
// filtro senza prima digitare), non un errore. Senza insegna una query vuota
// resta un errore: senza FULLTEXT ne' filtro non c'e' niente su cui rispondere.
if ($query === '' && empty($insegne)) {
    $response["message"] = "Query mancante";
    echo json_encode($response);
    exit;
}

// Tetto di sicurezza alto invece di un numero basso arbitrario (richiesta
// 2026-07-24: "niente limite ma tutto ordinato"). na_off_products ha 214k+
// righe: un LIMIT davvero assente rischierebbe query lente su hosting
// condiviso, quindi teniamo un tetto largo che in pratica l'utente non
// raggiunge mai in una ricerca reale.
$limit = 300;

if (!isset($conn) || $conn->connect_error) {
    $response["message"] = "Errore di connessione al database MySQLi";
    echo json_encode($response);
    exit;
}

/**
 * Ordinamento dei risultati FULLTEXT: rilevanza pesata sulla popolarita'.
 *
 * PERCHE' NON BASTA `relevance DESC`
 * La rilevanza di MySQL premia la RIPETIZIONE del termine nel nome. Misurato su
 * tutti i 256.921 prodotti: cercando "pasta" il primo risultato era
 * "Cellentani - Pasta Reale - Pasta Reale - Pasta Reale" con 3 scansioni, primo
 * solo perche' contiene "pasta" quattro volte. Cercando "cola" uscivano
 * prodotti con 1-3 scansioni mentre la Coca-Cola da 763 non compariva.
 *
 * PERCHE' NON BASTA NEANCHE `relevance DESC, unique_scans_n DESC`
 * Provato: non cambia quasi nulla. La rilevanza e' un float e i pareggi esatti
 * sono rari, quindi il secondo criterio non entra quasi mai in gioco. Serve
 * combinarli in un punteggio solo.
 *
 * LA FORMA SCELTA
 * Logaritmo e non lineare: fra 0 e 50 scansioni la differenza conta molto, fra
 * 700 e 750 non deve contare quasi niente, altrimenti i pochi prodotti
 * famosissimi soffocano tutto il resto. Peso 2x scelto confrontando 1x e 2x su
 * ricerche reali: 2x fa emergere De Cecco e Rummo su "gnocchi" e Barilla su
 * "pasta", e lascia invariate le ricerche gia' precise come "nutella".
 *
 * `unique_scans_n` e' il numero di persone che hanno scansionato quel prodotto
 * su OpenFoodFacts: e' popolarita' misurata, non un peso inventato da noi.
 */
const RILEVANZA_POPOLARITA = 'relevance * (1 + 2 * LOG10(1 + unique_scans_n))';

/**
 * Esegue una query preparata e restituisce le righe come array associativo.
 */
function runQuery(mysqli $conn, string $sql, string $types, array $params): array {
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return [];
    }
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $result = $stmt->get_result();
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = $row;
    }
    $stmt->close();
    return $rows;
}

/**
 * Fallback finale: stesso approccio AND/OR di search_crea_foods.php, parola
 * per parola su food_name E brand, invece di LIKE sull'intera query come
 * blocco unico. LIKE non ha un limite minimo di lunghezza parola (a
 * differenza di FULLTEXT sopra), quindi funziona anche con "zuc", refusi a
 * meta' parola, o ordine delle parole diverso da come compare nel nome.
 */
function runLikeSearch(mysqli $conn, array $words, string $fullQuery, string $mode, int $limit,
                        array $insegne = []): array {
    if (empty($words)) {
        $words = [$fullQuery];
    }

    $conditions = [];
    $types = "";
    $params = [];
    foreach ($words as $w) {
        $conditions[] = "(food_name LIKE ? OR brand LIKE ?)";
        $types .= "ss";
        $params[] = "%" . $w . "%";
        $params[] = "%" . $w . "%";
    }
    $glue = ($mode === 'OR') ? ' OR ' : ' AND ';
    $whereClause = implode($glue, $conditions);
    if (!empty($insegne)) {
        $ph = implode(',', array_fill(0, count($insegne), '?'));
        $whereClause .= ") AND barcode IN (SELECT barcode FROM na_product_retailer WHERE insegna IN ($ph)";
        $types .= str_repeat('s', count($insegne));
        array_push($params, ...$insegne);
        // la parentesi di apertura resta quella di sotto: si chiude qui
        // sopra e se ne apre una nuova, cosi' l'AND resta fuori dal blocco
        // OR/AND delle parole invece di entrarci per errore di precedenza.
    }

    // La popolarita' viene PRIMA della lunghezza del nome. Misurato su tutti i
    // 256.921 prodotti: cercando "zuc" (troppo corta per FULLTEXT, quindi si
    // finisce qui) l'ordinamento per solo nome piu' corto restituiva cinque
    // "Zucca" identiche con 0 scansioni; con la popolarita' restituisce lo
    // zucchero, che e' quello che la gente scansiona davvero.
    // Match esatto e prefisso restano sopra: chi digita il nome intero vuole
    // quel prodotto, non il piu' famoso che gli somiglia.
    $sql = "SELECT * FROM na_off_products
            WHERE ($whereClause)
            ORDER BY
                (food_name = ?) DESC,
                (food_name LIKE ?) DESC,
                unique_scans_n DESC,
                LENGTH(food_name) ASC
            LIMIT $limit";
    $types .= "ss";
    $params[] = $fullQuery;
    $params[] = $fullQuery . "%";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return [];
    }
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = $row;
    }
    $stmt->close();
    return $rows;
}

/**
 * Aggiunge ai risultati la categoria PROPOSTA, quando almeno due metodi
 * indipendenti sono d'accordo.
 *
 * COSA NON FA
 * Non tocca il campo `categories`, che resta il dato di fonte. La proposta
 * viaggia in campi separati (`predicted_category`, `predicted_category_sources`,
 * `predicted_category_agreement`) proprio perche' il client debba decidere
 * esplicitamente di usarla: e' ammessa per **ordinare e raggruppare** i
 * risultati (dove un errore costa una posizione in lista), mai per essere
 * mostrata come dato certo. Vedi DATA-QUALITY-PLAN.md §5-bis, regola 4.
 *
 * PERCHE' "ALMENO DUE METODI D'ACCORDO" E NON "LA CONFIDENZA PIU' ALTA"
 * Le confidenze dei tre metodi non sono confrontabili fra loro: sono scale
 * diverse (Robotoff mette il 41% delle sue proposte sopra 0,9, l'LLM il 4%).
 * E non sappiamo quale metodo sia piu' accurato, perche' quella misura — la
 * revisione umana su campione stratificato — non e' stata ancora fatta.
 * L'accordo fra approcci indipendenti (rete neurale su immagini, confronto
 * sulla tassonomia, LLM sul nome) e' l'unica evidenza utilizzabile senza
 * quella misura: se due strade diverse arrivano allo stesso tag, l'errore
 * dovrebbe essere scorrelato.
 * Misurato sul campione da 2.000 prodotti: 201 con tre metodi concordi, 496
 * con due, 600 dove nessuno concorda (e quelli restano senza proposta).
 *
 * Una query sola sui barcode gia' trovati, non una JOIN dentro la ricerca:
 * l'ordinamento resta quello che e', e la ricerca non rallenta.
 */
function attachPredictedCategories(mysqli $conn, array $rows): array {
    if (empty($rows)) {
        return $rows;
    }
    $barcodes = [];
    foreach ($rows as $r) {
        if (!empty($r['barcode'])) {
            $barcodes[] = $r['barcode'];
        }
    }
    if (empty($barcodes)) {
        return $rows;
    }

    $ph  = implode(',', array_fill(0, count($barcodes), '?'));
    $sql = "SELECT barcode, predicted_value,
                   COUNT(DISTINCT source) AS fonti,
                   GROUP_CONCAT(DISTINCT source ORDER BY source SEPARATOR ',') AS elenco
            FROM na_product_predictions
            WHERE field_name = 'categories'
              AND status IN ('pending','accepted')
              AND barcode IN ($ph)
            GROUP BY barcode, predicted_value
            HAVING fonti >= 2
            ORDER BY barcode, fonti DESC";

    $proposte = [];
    try {
        // `try` e non `if (!$stmt)`: da PHP 8.1 mysqli segnala gli errori
        // lanciando un'eccezione, quindi prepare() non restituisce mai false e
        // il controllo sul valore di ritorno non intercetta niente. Verificato:
        // senza questo blocco, su un DB dove `na_product_predictions` non
        // esiste ancora (cioe' l'hosting finche' la migrazione non e' stata
        // eseguita) l'eccezione risaliva al try esterno e **l'intera ricerca
        // rispondeva "error"**, invece di limitarsi a non avere le proposte.
        $stmt = $conn->prepare($sql);
        $stmt->bind_param(str_repeat('s', count($barcodes)), ...$barcodes);
        $stmt->execute();
        $res = $stmt->get_result();
        while ($p = $res->fetch_assoc()) {
            // ORDER BY fonti DESC: la prima riga per barcode e' quella su cui
            // concordano piu' metodi. Se due tag diversi hanno lo stesso
            // numero di fonti concordi non c'e' modo di scegliere e si tiene
            // il primo: sono casi rari e servono comunque solo a raggruppare.
            if (!isset($proposte[$p['barcode']])) {
                $proposte[$p['barcode']] = $p;
            }
        }
        $stmt->close();
    } catch (Throwable $e) {
        // Le proposte sono un di piu', non un requisito: se la quarantena non
        // c'e' o e' inaccessibile, la ricerca deve funzionare come prima.
        $proposte = [];
    }

    foreach ($rows as &$r) {
        $p = $proposte[$r['barcode']] ?? null;
        $r['predicted_category']           = $p ? $p['predicted_value'] : null;
        $r['predicted_category_sources']   = $p ? $p['elenco'] : null;
        $r['predicted_category_agreement'] = $p ? (int) $p['fonti'] : 0;
    }
    unset($r);

    return $rows;
}

try {
    $foods = [];

    // Sfoglia un'insegna senza query di testo: nessun FULLTEXT in gioco,
    // ordina per popolarita' e basta. Ramo separato invece di infilarci
    // dentro le 3 strategie sotto (pensate per il testo, non per il caso
    // "nessuna parola da cercare").
    if ($query === '' && !empty($insegne)) {
        $ph = implode(',', array_fill(0, count($insegne), '?'));
        $sql = "SELECT * FROM na_off_products
                WHERE barcode IN (SELECT barcode FROM na_product_retailer WHERE insegna IN ($ph))
                ORDER BY unique_scans_n DESC
                LIMIT $limit";
        $foods = runQuery($conn, $sql, str_repeat('s', count($insegne)), $insegne);
        $foods = attachPredictedCategories($conn, $foods);
        $response["status"] = "success";
        $response["message"] = count($foods) . " risultati trovati";
        $response["foods"] = $foods;
        echo json_encode($response);
        exit;
    }

    // Filtro insegna: sottoquery invece di JOIN, cosi' le 3 strategie di
    // ricerca sotto restano invariate nella forma, si aggiunge solo una
    // condizione e (quando serve) i parametri in coda. IN invece di = per
    // permettere piu' insegne selezionate insieme (OR fra loro).
    $filtroInsegnaSql = !empty($insegne)
        ? ' AND barcode IN (SELECT barcode FROM na_product_retailer WHERE insegna IN ('
            . implode(',', array_fill(0, count($insegne), '?')) . '))'
        : '';
    $filtroInsegnaParam = $insegne;
    $filtroInsegnaTypes = str_repeat('s', count($insegne));

    // 1. FULLTEXT natural language: veloce e rilevante, ma MySQL/MariaDB la
    //    ignora se la query e' troppo corta o fatta solo di "stopword" comuni
    //    (limite di default ft_min_word_len=4 lato server) — da qui i fallback sotto.
    $sql = "SELECT *, MATCH(food_name, brand) AGAINST (? IN NATURAL LANGUAGE MODE) AS relevance
            FROM na_off_products
            WHERE MATCH(food_name, brand) AGAINST (? IN NATURAL LANGUAGE MODE)$filtroInsegnaSql
            ORDER BY " . RILEVANZA_POPOLARITA . " DESC
            LIMIT $limit";
    $foods = runQuery($conn, $sql, "ss" . $filtroInsegnaTypes,
                       array_merge([$query, $query], $filtroInsegnaParam));

    // 2. Fallback: FULLTEXT in modalita' BOOLEAN con wildcard di prefisso su ogni
    //    parola (utile per query brevi o parole singole che il modo NATURAL scarta).
    if (empty($foods)) {
        $words = preg_split('/\s+/', trim($query));
        $boolQuery = '';
        foreach ($words as $w) {
            $w = trim($w);
            if ($w === '') continue;
            // Escape dei caratteri speciali della modalita' BOOLEAN (+ - * " ( ) < > ~)
            $w = preg_replace('/[+\-*"()<>~]/', '', $w);
            if ($w === '') continue;
            $boolQuery .= '+' . $w . '* ';
        }
        if ($boolQuery !== '') {
            $sql = "SELECT *, MATCH(food_name, brand) AGAINST (? IN BOOLEAN MODE) AS relevance
                    FROM na_off_products
                    WHERE MATCH(food_name, brand) AGAINST (? IN BOOLEAN MODE)$filtroInsegnaSql
                    ORDER BY " . RILEVANZA_POPOLARITA . " DESC
                    LIMIT $limit";
            $foods = runQuery($conn, $sql, "ss" . $filtroInsegnaTypes,
                               array_merge([$boolQuery, $boolQuery], $filtroInsegnaParam));
        }
    }

    // 3. Ultima spiaggia: fallback parola-per-parola (AND, poi OR), non piu'
    //    l'intera query come blocco unico. Il blocco unico falliva su query
    //    multi-parola non nell'ordine esatto del nome prodotto, ed e' proprio
    //    il caso in cui FULLTEXT sopra si arrende piu' spesso (parole corte o
    //    ancora incomplete mentre l'utente digita nella ricerca live, es.
    //    "zuc" mentre scrive "zucchine": FULLTEXT/BOOLEAN scartano i termini
    //    sotto il limite minimo di lunghezza anche col wildcard *, LIKE no).
    if (empty($foods)) {
        $words = array_values(array_filter(
            array_map('trim', preg_split('/\s+/', $query)),
            fn($w) => strlen($w) > 2
        ));
        $foods = runLikeSearch($conn, $words, $query, 'AND', $limit, $insegne);
        if (empty($foods)) {
            $foods = runLikeSearch($conn, $words, $query, 'OR', $limit, $insegne);
        }
    }

    $foods = attachPredictedCategories($conn, $foods);

    $response["status"] = "success";
    $response["message"] = count($foods) . " risultati trovati";
    $response["foods"] = $foods;
} catch (Exception $e) {
    $response["message"] = "Errore: " . $e->getMessage();
}

echo json_encode($response);
