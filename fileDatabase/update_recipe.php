<?php
/*
 * PERCHE' QUESTO BLOCCO (2026-09-07): questo file rispondeva HTTP 500 nudo,
 * senza corpo, ogni volta che si salvava o modificava una ricetta. Il motivo
 * vero: `recipe_ingredient_columns.php` non era mai stato caricato via FTP,
 * quindi `require` andava in errore fatale PRIMA di qualunque riga capace di
 * rispondere. Dall'app si vedeva solo "Errore salvataggio ricetta", e ci sono
 * volute tre sessioni per arrivarci — due delle quali passate a ipotizzare
 * colonne mancanti che invece c'erano.
 *
 * Da qui in poi qualunque errore fatale (include mancante, metodo chiamato su
 * false, ArgumentCountError) torna come JSON leggibile invece che come 500
 * muto. Il gestore e' scritto QUI DENTRO e non in un file condiviso di
 * proposito: un file condiviso e' esattamente cio' che mancava, e importarne
 * un altro per gestire gli import mancanti si sarebbe rotto allo stesso modo.
 */
header('Content-Type: application/json; charset=utf-8');

register_shutdown_function(function () {
    $e = error_get_last();
    if ($e === null || !in_array($e['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR], true)) {
        return;
    }
    // 200 di proposito: il client legge il messaggio dal corpo JSON, e con un
    // 500 lo butterebbe via mostrando di nuovo un errore senza spiegazione.
    http_response_code(200);
    echo json_encode([
        "status"  => "error",
        "message" => "Errore fatale PHP: " . $e['message'] . " (" . basename($e['file']) . ":" . $e['line'] . ")",
    ]);
});

/**
 * Percorso di un file obbligatorio; se non c'e', ferma lo script con un
 * messaggio utile invece di lasciarlo morire di errore fatale.
 *
 * NON fa il require: lo restituisce e basta. Vedi la riga sotto per il
 * perche', che e' la parte importante.
 */
function percorsoFileRichiesto(string $nome): string {
    $percorso = __DIR__ . '/' . $nome;
    if (!is_file($percorso)) {
        http_response_code(200);
        echo json_encode([
            "status"  => "error",
            "message" => "File mancante sul server: $nome — va caricato via FTP nella stessa cartella di questo script.",
        ]);
        exit;
    }
    return $percorso;
}

/*
 * IL require STA QUI, AL LIVELLO PRINCIPALE, E NON DENTRO UNA FUNZIONE.
 *
 * In PHP le variabili definite da un file incluso finiscono nello scope di
 * DOVE si trova il `require`. Metterlo dentro una funzione — come era scritto
 * il 07/09 — significa che $conn di db_config.php nasce e muore dentro quella
 * funzione, e qui sotto resta null: "Call to a member function
 * begin_transaction() on null". Errore mio, segnalato da Ismail con lo
 * screenshot dell'errore vero.
 */
require percorsoFileRichiesto('db_config.php');
require_once percorsoFileRichiesto('auth.php');
/*
 * COLONNE LETTE DAL DATABASE, NON DA UN ELENCO SCRITTO A MANO (2026-09-07).
 *
 * Prima l'elenco stava in `recipe_ingredient_columns.php`, condiviso fra
 * questo file e l'altro endpoint per non poter divergere. Buona idea, con un
 * difetto grave scoperto sul campo: quel file non e' mai arrivato sul server,
 * e `require` di un file assente e' un errore fatale — il salvataggio delle
 * ricette e' rimasto rotto per settimane con un HTTP 500 muto, e nemmeno
 * dopo aver caricato i due endpoint la cosa si e' sistemata, perche' il file
 * mancante era un terzo.
 *
 * Ora le colonne le chiediamo a MySQL, che e' l'unico posto dove la verita'
 * sta per definizione. Vantaggi oltre a togliere un file da caricare:
 *  - se una colonna non e' ancora stata creata sul server, viene semplicemente
 *    saltata invece di far fallire tutto l'INSERT ("colonna sconosciuta");
 *  - l'elenco non puo' piu' divergere dallo schema reale, ne' fra i due
 *    endpoint, perche' nessuno dei due lo scrive.
 *
 * Scriviamo SOLO le colonne che l'app manda davvero (piu' food_name/unit/
 * weight_g): cosi' colonne gestite dal database — id, timestamp con valore
 * predefinito — restano intatte invece di ricevere '' o 0.
 */

/**
 * Lettera di bind_param corrispondente a un tipo SQL.
 *
 * Sbagliarla non da' errore, corrompe: un 'd' su una colonna testuale scrive
 * un numero al posto del testo, e viceversa. Tenuta separata apposta per
 * poterla provare senza database (vedi test_tipi_bind.php).
 */
function tipoBindDaTipoSql(string $tipoSql): string {
    $t = strtolower($tipoSql);
    if (preg_match('/^(tiny|small|medium|big)?int/', $t)) return 'i';
    if (preg_match('/^(double|float|decimal|numeric|real)/', $t)) return 'd';
    return 's';
}

/** Colonne di na_recipe_ingredients con il tipo da usare in bind_param. */
function colonneIngredienteDalDb(mysqli $conn): array {
    static $cache = null;
    if ($cache !== null) return $cache;

    $res = $conn->query("SHOW COLUMNS FROM `na_recipe_ingredients`");
    if (!$res) {
        throw new Exception("Impossibile leggere le colonne di na_recipe_ingredients: " . $conn->error);
    }
    $cache = [];
    while ($r = $res->fetch_assoc()) {
        $nome = $r['Field'];
        if ($nome === 'id' || $nome === 'recipe_id') continue;      // gestite a parte
        if (stripos($r['Extra'] ?? '', 'auto_increment') !== false) continue;
        $cache[$nome] = tipoBindDaTipoSql($r['Type']);
    }
    $res->free();
    if (!$cache) throw new Exception("na_recipe_ingredients non ha colonne utilizzabili.");
    return $cache;
}

/**
 * Colonne da scrivere: quelle che esistono nel database E che l'app manda,
 * piu' le tre sempre presenti. L'ordine e' fisso per tutti gli ingredienti,
 * cosi' basta preparare l'INSERT una volta sola.
 */
function colonneDaScrivere(mysqli $conn, array $ingredienti): array {
    $disponibili = colonneIngredienteDalDb($conn);
    $usate = ['food_name' => true, 'unit' => true, 'weight_g' => true];
    foreach ($ingredienti as $ing) {
        if (!is_array($ing)) continue;
        foreach (array_keys($ing) as $k) $usate[$k] = true;
    }
    $scelte = [];
    foreach ($disponibili as $col => $tipo) {
        if (isset($usate[$col])) $scelte[$col] = $tipo;
    }
    return $scelte;
}

/** Tipi e valori per bind_param, nell'ordine di $colonne. */
function parametriIngrediente(int $recipe_id, array $ing, array $colonne): array {
    $types = "i";
    $values = [$recipe_id];
    foreach ($colonne as $col => $t) {
        $types .= $t;
        if ($t === 'i')      $values[] = intval($ing[$col] ?? 0);
        elseif ($t === 'd')  $values[] = floatval($ing[$col] ?? 0);
        else                 $values[] = (string)($ing[$col] ?? ($col === 'unit' ? 'g' : ''));
    }
    return [$types, $values];
}

$jsonData = file_get_contents('php://input');
$data = json_decode($jsonData, true);

// Controlliamo i dati minimi obbligatori
if (!isset($data['id']) || !isset($data['user_mail'])) {
    die(json_encode(["status" => "error", "message" => "Dati minimi (id, user_mail) mancanti."]));
}

//FORZIAMO L'ID A ESSERE UN NUMERO INTERO
$recipe_id = intval($data['id']); 
// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$user_mail = emailAutenticata($conn, (string) ($data['user_mail'] ?? ''));

$conn->begin_transaction();

try {
    // Se è un toggle dei preferiti (pochi campi passati)
    if (isset($data['is_favorite']) && (!isset($data['ingredients']) || empty($data['ingredients']))) {
        $is_fav = (int)$data['is_favorite'];
        $sql_recipe = "UPDATE na_recipes SET is_favorite = ? WHERE id = ? AND user_mail = ?";
        $stmt_recipe = $conn->prepare($sql_recipe);
        if (!$stmt_recipe) throw new Exception("Errore Prepare Preferito: " . $conn->error);
        $stmt_recipe->bind_param("iis", $is_fav, $recipe_id, $user_mail);
        $stmt_recipe->execute();
        $stmt_recipe->close();
    } else {
        // Una ricetta approvata e' del database (15/09, decisione di Ismail):
        // l'autore non la modifica piu'. Nessuna scrittura fatta finora, quindi
        // basta chiudere la transazione.
        $colonnaStato = $conn->query("SHOW COLUMNS FROM na_recipes LIKE 'shared_status'");
        if ($colonnaStato && $colonnaStato->num_rows > 0) {
            $controllo = $conn->prepare('SELECT shared_status FROM na_recipes WHERE id = ? AND user_mail = ?');
            $controllo->bind_param('is', $recipe_id, $user_mail);
            $controllo->execute();
            $rigaStato = $controllo->get_result()->fetch_assoc();
            $controllo->close();
            if (($rigaStato['shared_status'] ?? '') === 'approved') {
                $conn->rollback();
                echo json_encode([
                    "status" => "error",
                    "message" => "Questa ricetta e' pubblica e fa parte del database: non si modifica piu'. Se contiene un errore, segnalala.",
                    "reason" => "locked",
                ]);
                $conn->close();
                exit;
            }
        }

        // Update completo
        $recipe_name = $data['recipe_name'];
        $image_url = $data['image_url'] ?? '';
        $portion = $data['portion'] ?? '1';
        $notes = $data['notes'] ?? '';
        $is_fav = (int)($data['is_favorite'] ?? 0);
        $ingredients = $data['ingredients'];

        // Aggiorniamo la ricetta principale
        $sql_recipe = "UPDATE na_recipes SET recipe_name = ?, `portion` = ?, `notes` = ?, is_favorite = ?, image_url = ? WHERE id = ? AND user_mail = ?";
        $stmt_recipe = $conn->prepare($sql_recipe);
        if (!$stmt_recipe) throw new Exception("Errore Prepare Ricetta: " . $conn->error);
        
        $stmt_recipe->bind_param("sssisis", $recipe_name, $portion, $notes, $is_fav, $image_url, $recipe_id, $user_mail);
        if (!$stmt_recipe->execute()) throw new Exception("Errore Execute Ricetta: " . $stmt_recipe->error);
        $stmt_recipe->close();

        // Cancelliamo i vecchi ingredienti
        $sql_del_ing = "DELETE FROM na_recipe_ingredients WHERE recipe_id = ?";
        $stmt_del_ing = $conn->prepare($sql_del_ing);
        if (!$stmt_del_ing) throw new Exception("Errore Prepare Cancellazione: " . $conn->error);
        $stmt_del_ing->bind_param("i", $recipe_id);
        $stmt_del_ing->execute();
        $stmt_del_ing->close();

        // Inseriamo la nuova lista di ingredienti aggiornata.
        // FIX 2026-07-24 (bug reale trovato): prima si salvavano SOLO
        // calories/carbs/proteins/fats, perdendo silenziosamente acqua/
        // fibre/zuccheri/grassi dettagliati/vitamine/minerali ad ogni
        // modifica ricetta. Oggi l'elenco arriva dal database stesso
        // (vedi colonneIngredienteDalDb).
        $colonne = colonneDaScrivere($conn, $ingredients);
        $placeholders = implode(', ', array_fill(0, count($colonne) + 1, '?'));
        $columnList = 'recipe_id, ' . implode(', ', array_map(fn($c) => "`$c`", array_keys($colonne)));
        $sql_ingredient = "INSERT INTO na_recipe_ingredients ($columnList) VALUES ($placeholders)";
        $stmt_ingredient = $conn->prepare($sql_ingredient);
        if (!$stmt_ingredient) throw new Exception("Errore Prepare Ingrediente: " . $conn->error);

        foreach ($ingredients as $ing) {
            [$types, $values] = parametriIngrediente($recipe_id, $ing, $colonne);
            $stmt_ingredient->bind_param($types, ...$values);
            if (!$stmt_ingredient->execute()) {
                throw new Exception("Errore Execute Ingrediente: " . $stmt_ingredient->error);
            }
        }
        $stmt_ingredient->close();
    }

    $conn->commit();
    echo json_encode(["status" => "success", "message" => "Ricetta aggiornata con successo"]);

} catch (Throwable $e) {
    $conn->rollback();
    echo json_encode(["status" => "error", "message" => "Errore DB: " . $e->getMessage()]);
}
$conn->close();
?>