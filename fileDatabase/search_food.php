<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$query    = $_GET['query']   ?? '';
$barcode  = $_GET['barcode'] ?? '';
// SICUREZZA 2026-07-23: rimossa una seconda API key USDA hardcoded trovata qui
// (diversa da quella in lib/services/api_services.dart, entrambe segnalate in
// 03 Projects/NutriApp/PROBLEMS.md del vault — repo pubblico fino al 2026-07-22,
// da considerare compromessa). Questo file non e' comunque chiamato da nessun
// punto del codice Dart (vedi PROBLEMS.md, punto 5/10): finche' resta cosi',
// va solo evitato di rimetterla in chiaro se in futuro si decide di ricollegarlo.
// Passare la chiave reale via variabile d'ambiente (getenv('USDA_API_KEY')) e
// configurarla lato hosting, mai committarla di nuovo nel sorgente.
$USDA_KEY = getenv('USDA_API_KEY') ?: '';

if (empty($query) && empty($barcode)) {
    echo json_encode(["status" => "error", "message" => "Parametri mancanti"]);
    exit;
}

// Helper per gestire i dati di OpenFoodFacts
function parseOFF($p) {
    $n = $p['nutriments'] ?? [];

    // helper inline
    $g  = fn($k) => (float)($n[$k] ?? 0);          
    $mg = fn($k) => (float)($n[$k] ?? 0) * 1000;    // g → mg
    $ug = fn($k) => (float)($n[$k] ?? 0) * 1000000; // g → µg

    return [
        'source'               => 'off',
        'name'                 => $p['product_name'] ?? '',
        'brand'                => $p['brands']       ?? '',
        'barcode'              => $p['code']          ?? '',
        'image'                => $p['image_front_url'] ?? '',
        // Macro (g)
        'calories'             => $g('energy-kcal_100g'),
        'proteins'             => $g('proteins_100g'),
        'carbs'                => $g('carbohydrates_100g'),
        'fats'                 => $g('fat_100g'),
        'fibers'               => $g('fiber_100g'),
        'sugars'               => $g('sugars_100g'),
        'saturated_fats'       => $g('saturated-fat_100g'),
        'monounsaturated_fats' => $g('monounsaturated-fat_100g'),
        'polyunsaturated_fats' => $g('polyunsaturated-fat_100g'),
        'trans_fats'           => $g('trans-fat_100g'),
        'water'                => $g('water_100g'),
        // Macro in mg
        'cholesterol'          => $mg('cholesterol_100g'),  // g → mg
        // Minerali principali (g → mg)
        'sodium'               => $mg('sodium_100g'),
        'calcium'              => $mg('calcium_100g'),
        'iron'                 => $mg('iron_100g'),
        'magnesium'            => $mg('magnesium_100g'),
        'phosphorus'           => $mg('phosphorus_100g'),
        'potassium'            => $mg('potassium_100g'),
        'zinc'                 => $mg('zinc_100g'),
        'copper'               => $mg('copper_100g'),
        'manganese'            => $mg('manganese_100g'),
        'chloride'             => $mg('chloride_100g'),
        // Minerali traccia (g → µg)
        'selenium'             => $ug('selenium_100g'),
        'iodine'               => $ug('iodine_100g'),
        'fluoride'             => $ug('fluoride_100g'),
        'chromium'             => $ug('chromium_100g'),
        'molybdenum'           => $ug('molybdenum_100g'),
        // Vitamine idrosolubili (g → mg)
        'vit_b1'               => $mg('vitamin-b1_100g'),
        'vit_b2'               => $mg('vitamin-b2_100g'),
        'vit_b3'               => $mg('vitamin-b3_100g'),
        'vit_b5'               => $mg('pantothenic-acid_100g'),
        'vit_b6'               => $mg('vitamin-b6_100g'),
        'vit_c'                => $mg('vitamin-c_100g'),
        'vit_e'                => $mg('vitamin-e_100g'),
        // Vitamine liposolubili / traccia (g → µg)
        'vit_a'                => $ug('vitamin-a_100g'),
        'vit_b7'               => $ug('biotin_100g'),
        'vit_b9'               => $ug('folates_100g'),
        'vit_b11'              => $ug('folates_100g'), 
        'vit_b12'              => $ug('vitamin-b12_100g'),
        'vit_d'                => $ug('vitamin-d_100g'),
        'vit_k'                => $ug('vitamin-k_100g'),
    ];
}

// Helper per gestire i dati USDA
function parseUSDA($food) {
    $raw = [];
    foreach ($food['foodNutrients'] ?? [] as $n) {
        $raw[$n['nutrientName']] = (float)($n['value'] ?? 0);
    }
    $g = fn($k) => $raw[$k] ?? 0; // valore già nell'unità giusta

    return [
        'source'               => 'usda',
        'name'                 => $food['description'] ?? '',
        'brand'                => $food['brandOwner']  ?? '',
        'barcode'              => $food['gtinUpc']     ?? '',
        'image'                => '',
        // Macro (g)
        'calories'             => $g('Energy') ?: $g('Energy (Atwater General Factors)'),
        'proteins'             => $g('Protein'),
        'carbs'                => $g('Carbohydrate, by difference'),
        'fats'                 => $g('Total lipid (fat)'),
        'fibers'               => $g('Fiber, total dietary'),
        'sugars'               => $g('Sugars, total including NLEA') ?: $g('Sugars, Total'),
        'saturated_fats'       => $g('Fatty acids, total saturated'),
        'monounsaturated_fats' => $g('Fatty acids, total monounsaturated'),
        'polyunsaturated_fats' => $g('Fatty acids, total polyunsaturated'),
        'trans_fats'           => $g('Fatty acids, total trans'),
        'water'                => $g('Water'),
        // mg
        'cholesterol'          => $g('Cholesterol'),           // mg
        'sodium'               => $g('Sodium, Na'),            // mg
        'calcium'              => $g('Calcium, Ca'),           // mg
        'iron'                 => $g('Iron, Fe'),              // mg
        'magnesium'            => $g('Magnesium, Mg'),         // mg
        'phosphorus'           => $g('Phosphorus, P'),         // mg
        'potassium'            => $g('Potassium, K'),          // mg
        'zinc'                 => $g('Zinc, Zn'),              // mg
        'copper'               => $g('Copper, Cu'),            // mg
        'manganese'            => $g('Manganese, Mn'),         // mg
        'chloride'             => $g('Chlorine, Cl'),          // mg
        // µg
        'selenium'             => $g('Selenium, Se'),          // µg
        'iodine'               => $g('Iodine, I'),             // µg
        'fluoride'             => $g('Fluoride, F'),           // µg
        'chromium'             => $g('Chromium, Cr'),          // µg
        'molybdenum'           => $g('Molybdenum, Mo'),        // µg
        // Vitamine idrosolubili (mg)
        'vit_b1'               => $g('Thiamin'),               // mg
        'vit_b2'               => $g('Riboflavin'),            // mg
        'vit_b3'               => $g('Niacin'),                // mg
        'vit_b5'               => $g('Pantothenic acid'),      // mg
        'vit_b6'               => $g('Vitamin B-6'),           // mg
        'vit_c'                => $g('Vitamin C, total ascorbic acid'), // mg
        'vit_e'                => $g('Vitamin E (alpha-tocopherol)'),   // mg
        // Vitamine liposolubili / traccia (µg)
        'vit_a'                => $g('Vitamin A, RAE'),        // µg
        'vit_b7'               => $g('Biotin'),                // µg
        'vit_b9'               => $g('Folate, total'),         // µg
        'vit_b11'              => $g('Folate, total'),         // µg (alias)
        'vit_b12'              => $g('Vitamin B-12'),          // µg
        'vit_d'                => $g('Vitamin D (D2 + D3)'),  // µg
        'vit_k'                => $g('Vitamin K (phylloquinone)'), // µg
    ];
}

// Funzione per effettuare le chiamate API
function fetchUrl($url) {
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 10,
        CURLOPT_USERAGENT      => 'NutriApp/1.0 (school project; ismail.barakat@galileo.galileicrema.it)',
        CURLOPT_HTTPHEADER     => ['Accept: application/json'],
    ]);
    $result   = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return [$result, $httpCode];
}

// Traduzione della query (Italiano -> Inglese)
function translateITtoEN($text) {
    $url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=it&tl=en&dt=t&q=" . urlencode($text);
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_TIMEOUT, 3);
    $result = curl_exec($ch);
    curl_close($ch);
    if ($result) {
        $json = json_decode($result, true);
        if (isset($json[0][0][0])) {
            return $json[0][0][0];
        }
    }
    return $text;
}

// Traduzione in blocco (Inglese -> Italiano)
function translateArrayENtoIT($texts) {
    if(empty($texts)) return [];
    
    $mh = curl_multi_init();
    $handles = [];
    
    foreach ($texts as $i => $text) {
        $url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=it&dt=t&q=" . urlencode($text);
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_TIMEOUT, 4);
        $handles[$i] = $ch;
        curl_multi_add_handle($mh, $ch);
    }
    
    $running = null;
    do {
        curl_multi_exec($mh, $running);
        if (curl_multi_select($mh) == -1) {
            usleep(100);
        }
    } while ($running > 0);
    
    $results = [];
    foreach ($handles as $i => $ch) {
        $result = curl_multi_getcontent($ch);
        $translated = $texts[$i]; // fallback
        if ($result) {
            $json = json_decode($result, true);
            if (isset($json[0]) && is_array($json[0])) {
                $full_translation = "";
                foreach ($json[0] as $segment) {
                    if (isset($segment[0])) $full_translation .= $segment[0];
                }
                if (!empty(trim($full_translation))) {
                    $translated = trim($full_translation);
                }
            }
        }
        $results[$i] = $translated;
        curl_multi_remove_handle($mh, $ch);
    }
    curl_multi_close($mh);
    
    return $results;
}

// Ricerca tramite codice a barre
if (!empty($barcode)) {
    [$result, $code] = fetchUrl(
        "https://world.openfoodfacts.org/api/v2/product/" . urlencode($barcode)
    );
    if ($code === 200) {
        $data = json_decode($result, true);
        if (($data['status'] ?? 0) === 1 && !empty($data['product']['product_name'])) {
            echo json_encode(["status" => "success", "products" => [parseOFF($data['product'])]]);
            exit;
        }
    }

    // Fallback USDA
    [$result, $code] = fetchUrl(
        "https://api.nal.usda.gov/fdc/v1/foods/search?query=" . urlencode($barcode)
        . "&api_key=$USDA_KEY&pageSize=5&dataType=Branded"
    );
    if ($code === 200) {
        $data  = json_decode($result, true);
        $foods = $data['foods'] ?? [];
        if (!empty($foods)) {
            // Traduzione batch dei nomi
            $namesToTranslate = array_map(fn($f) => $f['description'] ?? '', $foods);
            $translatedNames = translateArrayENtoIT($namesToTranslate);
            
            foreach ($foods as $i => &$food) {
                if (!empty($translatedNames[$i])) {
                    $food['description'] = $translatedNames[$i];
                }
            }
            unset($food);

            echo json_encode(["status" => "success", "products" => array_map('parseUSDA', $foods)]);
            exit;
        }
    }

    echo json_encode(["status" => "error", "message" => "Prodotto non trovato"]);
    exit;
}

// Controllo pertinenza tra nome prodotto e ricerca
function isRelevant(string $productName, string $query): bool {
    $name  = mb_strtolower(trim($productName));
    $query = mb_strtolower(trim($query));

    // Parole della query con almeno 3 caratteri (esclude articoli/preposizioni)
    $words = array_filter(
        preg_split('/\s+/', $query),
        fn($w) => mb_strlen($w) >= 3
    );

    // Se la query è troppo corta usala intera
    if (empty($words)) {
        return str_contains($name, $query);
    }

    // Basta che il nome contenga ALMENO UNA parola della query
    foreach ($words as $word) {
        if (str_contains($name, $word)) return true;
    }
    return false;
}

// Ricerca tramite nome
if (!empty($query)) {
    $offUrl = "https://world.openfoodfacts.org/api/v2/search"
            . "?search_terms=" . urlencode($query)
            . "&fields=product_name,brands,code,nutriments,image_front_url"
            . "&lc=it&cc=it&page_size=25";

    [$result, $code] = fetchUrl($offUrl);
    if ($code === 200) {
        $data = json_decode($result, true);

        // 1. Filtra prodotti senza nome
        $products = array_filter(
            $data['products'] ?? [],
            fn($p) => !empty($p['product_name'])
        );

        // Filtra per pertinenza: tieni solo prodotti il cui nome
        // contiene almeno una parola significativa della query.
        $relevant = array_filter(
            $products,
            fn($p) => isRelevant($p['product_name'], $query)
        );

        if (!empty($relevant)) {
            echo json_encode([
                "status"   => "success",
                "products" => array_values(array_map('parseOFF', $relevant)),
            ]);
            exit;
        }
        // Se non ci sono risultati pertinenti, proviamo con il database americano (USDA)
    }

    // Fallback USDA
    $queryEN = translateITtoEN($query);
    $usdaUrl = "https://api.nal.usda.gov/fdc/v1/foods/search"
             . "?query=" . urlencode($queryEN)
             . "&api_key=$USDA_KEY&pageSize=25&dataType=Branded,Foundation,SR%20Legacy";

    [$result, $code] = fetchUrl($usdaUrl);
    if ($code === 200) {
        $data  = json_decode($result, true);
        $foods = $data['foods'] ?? [];
        if (!empty($foods)) {
            // Traduzione batch dei nomi
            $namesToTranslate = array_map(fn($f) => $f['description'] ?? '', $foods);
            $translatedNames = translateArrayENtoIT($namesToTranslate);
            
            foreach ($foods as $i => &$food) {
                if (!empty($translatedNames[$i])) {
                    $food['description'] = $translatedNames[$i];
                }
            }
            unset($food);

            echo json_encode(["status" => "success", "products" => array_map('parseUSDA', $foods)]);
            exit;
        }
    }

    echo json_encode(["status" => "error", "message" => "Nessun risultato trovato"]);
    exit;
}
?>