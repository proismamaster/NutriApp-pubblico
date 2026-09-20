<?php
/**
 * translate_text.php — traduzione automatica (es. ingredienti OpenFoodFacts
 * scritti in lingua diversa da quella dell'app) verso la lingua scelta
 * dall'utente, richiesta 2026-07-24.
 *
 * Provider: MyMemory (https://mymemory.translated.net), gratuito, nessuna
 * registrazione richiesta (query verificate manualmente il 2026-07-24,
 * vedi vault PROBLEMS.md). Copre le 4 lingue dell'app (it/en/ar/zh) e
 * supporta il rilevamento automatico della lingua sorgente con
 * `langpair=autodetect|<target>` (non documentato ufficialmente ma
 * verificato funzionante: testato francese->italiano e italiano->arabo).
 *
 * Strategia di traduzione FRASE PER FRASE (split sulla virgola) invece che
 * sull'intero blob di ingredienti, per due motivi:
 *  1. MyMemory limita il parametro `q` a 500 byte: le liste ingredienti
 *     OpenFoodFacts spesso li superano.
 *  2. Tantissimi prodotti diversi condividono le stesse singole voci
 *     ("zucchero", "sale", "olio di girasole", ...): cachando per singola
 *     frase invece che per prodotto intero, la cache si scalda in fretta e
 *     la stragrande maggioranza delle richieste dopo un po' di utilizzo
 *     sono cache hit, niente vera chiamata esterna (rispetta il limite
 *     gratuito giornaliero di MyMemory anche a scala).
 *
 * Se la lingua rilevata coincide gia' con quella target, torniamo il testo
 * originale invece della "traduzione" di MyMemory (che a volte riformula
 * leggermente anche quando source==target — risultato confuso da mostrare).
 *
 * Richiede la tabella na_translation_cache (vedi CREATE TABLE in
 * PROBLEMS.md) prima di poter essere usata.
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

require_once 'db_config.php';

$text = trim($_GET['text'] ?? '');
$target = strtolower(trim($_GET['target'] ?? ''));
$validTargets = ['it', 'en', 'ar', 'zh'];

if ($text === '' || !in_array($target, $validTargets, true)) {
    echo json_encode(["status" => "error", "message" => "Parametri mancanti o non validi"]);
    exit;
}

if (!isset($conn) || $conn->connect_error) {
    echo json_encode(["status" => "error", "message" => "Errore di connessione al database MySQLi"]);
    exit;
}

/**
 * La cache è un'ottimizzazione, NON un requisito: se la tabella
 * na_translation_cache non esiste ancora (migrazione non eseguita), la
 * traduzione deve funzionare lo stesso, solo senza risparmiare chiamate.
 * Prima questa mancanza faceva fallire l'intera richiesta in silenzio e
 * l'utente vedeva il testo non tradotto senza capire perché.
 */
function cacheAvailable(mysqli $conn): bool {
    static $available = null;
    if ($available === null) {
        $res = @$conn->query("SHOW TABLES LIKE 'na_translation_cache'");
        $available = ($res !== false && $res->num_rows > 0);
    }
    return $available;
}

function getCachedPhrase(mysqli $conn, string $hash, string $target): ?array {
    if (!cacheAvailable($conn)) return null;
    $stmt = @$conn->prepare("SELECT translated_text, detected_lang FROM na_translation_cache WHERE text_hash = ? AND target_lang = ?");
    if (!$stmt) return null;
    $stmt->bind_param("ss", $hash, $target);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

function setCachedPhrase(mysqli $conn, string $hash, string $target, string $translated, string $detected): void {
    if (!cacheAvailable($conn)) return;
    $stmt = @$conn->prepare("INSERT INTO na_translation_cache (text_hash, target_lang, translated_text, detected_lang)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE translated_text = VALUES(translated_text), detected_lang = VALUES(detected_lang)");
    if (!$stmt) return;
    $stmt->bind_param("ssss", $hash, $target, $translated, $detected);
    $stmt->execute();
    $stmt->close();
}

/**
 * GET su un URL esterno. Prova prima cURL (quasi sempre disponibile) e solo
 * dopo file_get_contents: su molti hosting condivisi `allow_url_fopen` è
 * disattivato, e in quel caso file_get_contents da solo fallirebbe sempre —
 * causa molto probabile di "la traduzione non parte" pur con il file
 * caricato correttamente sul server.
 */
function httpGet(string $url): ?string {
    if (function_exists('curl_init')) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 8,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_USERAGENT      => 'NutriApp/1.0',
        ]);
        $body = curl_exec($ch);
        $ok = ($body !== false && curl_getinfo($ch, CURLINFO_HTTP_CODE) === 200);
        curl_close($ch);
        if ($ok) return $body;
    }
    if (ini_get('allow_url_fopen')) {
        $ctx = stream_context_create(['http' => ['timeout' => 8, 'ignore_errors' => true]]);
        $body = @file_get_contents($url, false, $ctx);
        if ($body !== false) return $body;
    }
    return null;
}

/**
 * Traduce una singola frase via MyMemory. Ritorna [testo_finale, lingua_rilevata].
 * In caso di errore di rete/timeout ritorna la frase originale invariata,
 * cosi' l'utente vede comunque il testo (mai peggio di prima) invece di un
 * campo vuoto o un errore.
 *
 * [$sourceLang] e' 'autodetect' di default, ma puo' essere un codice lingua
 * esplicito (vedi $sharedSourceLang sotto): frammenti brevi e comuni come
 * "sale" o "aromi" (splittati dalla lista ingredienti sulla virgola) sono
 * anche parole inglesi valide o troppo corte per un autodetect affidabile
 * quando interrogate isolate — MyMemory le classifica a volte gia' come
 * lingua target e le lascia invariate. Passando la lingua sorgente gia'
 * nota (rilevata su un frammento piu' lungo/affidabile della stessa lista)
 * si evita di re-indovinarla frammento per frammento.
 */
function translateChunk(string $chunk, string $target, string $contactEmail, string $sourceLang = 'autodetect'): array {
    $url = "https://api.mymemory.translated.net/get?"
        . "q=" . urlencode($chunk)
        . "&langpair=" . urlencode("$sourceLang|$target")
        . "&de=" . urlencode($contactEmail);

    $raw = httpGet($url);
    if ($raw === null) {
        return [$chunk, ''];
    }
    $json = json_decode($raw, true);
    $detected = strtolower(substr((string)($json['responseData']['detectedLanguage'] ?? ''), 0, 2));
    $translated = $json['responseData']['translatedText'] ?? $chunk;

    if ($detected === $target) {
        // Gia' nella lingua giusta: non mostriamo la riformulazione di
        // MyMemory, teniamo il testo originale dell'utente/prodotto.
        return [$chunk, $detected];
    }
    return [$translated, $detected];
}

try {
    $parts = array_values(array_filter(array_map('trim', explode(',', $text)), fn($p) => $p !== ''));
    $translatedParts = [];
    $anyDifferent = false;
    $detectedOverall = '';
    // Email di contatto per la quota gratuita piu' alta di MyMemory (50k
    // parole/giorno invece di 5k) — vedi doc ufficiale MyMemory, parametro 'de'.
    $contactEmail = 'ismailbarakat68@gmail.com';

    // Lingua sorgente condivisa fra i frammenti di QUESTA stessa lista
    // ingredienti: rilevata una sola volta (sul primo frammento non gia' in
    // cache, di solito il piu' lungo/affidabile) e poi riusata esplicitamente
    // per tutti i frammenti successivi, invece di far autodetectare ognuno
    // per conto suo — vedi commento su translateChunk().
    $sharedSourceLang = null;

    foreach ($parts as $part) {
        $hash = hash('sha256', $part . '|' . $target);
        $cached = getCachedPhrase($conn, $hash, $target);
        if ($cached !== null) {
            $translatedParts[] = $cached['translated_text'];
            if ($cached['translated_text'] !== $part) $anyDifferent = true;
            if ($cached['detected_lang']) {
                $detectedOverall = $cached['detected_lang'];
                if ($sharedSourceLang === null) $sharedSourceLang = $cached['detected_lang'];
            }
            continue;
        }

        // MyMemory rifiuta 'q' oltre 500 byte: tagliamo per sicurezza (raro
        // che capiti a livello di singola voce, ma alcune diciture OFF sono
        // lunghe frasi con percentuali e sotto-ingredienti tra parentesi).
        $safePart = (strlen($part) > 480) ? substr($part, 0, 480) : $part;

        // Se la lingua sorgente e' gia' nota ed e' proprio quella target,
        // il frammento e' gia' nella lingua giusta: nessuna chiamata da fare,
        // stesso short-circuit di translateChunk() ma applicato una volta
        // sola per l'intera lista invece che frammento per frammento.
        if ($sharedSourceLang !== null && $sharedSourceLang === $target) {
            $translatedParts[] = $part;
            continue;
        }

        $sourceLangForThisPart = $sharedSourceLang ?? 'autodetect';
        [$translated, $detected] = translateChunk($safePart, $target, $contactEmail, $sourceLangForThisPart);
        setCachedPhrase($conn, $hash, $target, $translated, $detected);

        if ($sharedSourceLang === null && $detected !== '') {
            $sharedSourceLang = $detected;
        }

        $translatedParts[] = $translated;
        if ($translated !== $part) $anyDifferent = true;
        if ($detected) $detectedOverall = $detected;
    }

    echo json_encode([
        "status" => "success",
        "translated_text" => implode(', ', $translatedParts),
        "same_language" => !$anyDifferent,
        "detected_lang" => $detectedOverall,
        // Diagnostica: se la traduzione non parte, aprire questo endpoint
        // dal browser (…/translate_text.php?text=Zucker&target=it) e guardare
        // qui — dice se la cache è attiva e se le chiamate uscenti passano.
        "debug" => [
            "cache_enabled" => cacheAvailable($conn),
            "curl_available" => function_exists('curl_init'),
            "allow_url_fopen" => (bool)ini_get('allow_url_fopen'),
        ],
    ]);
} catch (Exception $e) {
    echo json_encode(["status" => "error", "message" => "Errore: " . $e->getMessage()]);
}

$conn->close();
