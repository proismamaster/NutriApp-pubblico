<?php
/*
 * Prova delle due funzioni pure di save_recipe.php / update_recipe.php, quelle
 * che decidono COME i valori di un ingrediente finiscono nel database.
 *
 * PERCHE' ESISTE (2026-09-07): da quando l'elenco delle colonne arriva da
 * `SHOW COLUMNS` invece che da un elenco scritto a mano, il punto delicato e'
 * la traduzione tipo-SQL -> lettera di bind_param. Sbagliarla non produce un
 * errore: produce dati corrotti in silenzio (un 'd' su una colonna testuale
 * scrive un numero al posto del testo). Qui si prova senza database.
 *
 * Come si lancia, dalla cartella fileDatabase/:
 *     php test_tipi_bind.php
 * Stampa "TUTTO OK" ed esce con 0 se va bene, altrimenti elenca cosa non torna
 * ed esce con 1 — quindi si puo' mettere in una pipeline senza leggerne l'output.
 */

// Le funzioni da provare vivono dentro l'endpoint, che pero' all'inclusione
// si connetterebbe al database e leggerebbe php://input. Le ricopiamo qui NO:
// le estraiamo dal sorgente, cosi' la prova fallisce se qualcuno le cambia
// solo di la' — che e' esattamente il tipo di divergenza che vogliamo evitare.
$sorgente = file_get_contents(__DIR__ . '/save_recipe.php');
foreach (['tipoBindDaTipoSql', 'parametriIngrediente'] as $nomeFunzione) {
    if (!preg_match('/\nfunction ' . $nomeFunzione . '\(.*?\n\}/s', $sorgente, $m)) {
        fwrite(STDERR, "Funzione $nomeFunzione non trovata in save_recipe.php\n");
        exit(1);
    }
    eval($m[0]);
}

$errori = [];

function verifica(string $descrizione, $atteso, $ottenuto): void {
    global $errori;
    if ($atteso !== $ottenuto) {
        $errori[] = sprintf("%s\n   atteso:  %s\n   ottenuto: %s",
            $descrizione, var_export($atteso, true), var_export($ottenuto, true));
    }
}

// ---- tipi interi ----
foreach (['int(11)', 'INT', 'tinyint unsigned', 'TINYINT(1)', 'smallint(5)',
          'mediumint(9)', 'bigint(20) unsigned'] as $t) {
    verifica("$t deve essere intero", 'i', tipoBindDaTipoSql($t));
}

// ---- tipi con la virgola ----
foreach (['double', 'DOUBLE', 'float', 'decimal(10,2)', 'numeric(8,3)', 'real'] as $t) {
    verifica("$t deve essere decimale", 'd', tipoBindDaTipoSql($t));
}

// ---- tutto il resto e' testo ----
foreach (['varchar(500)', 'TEXT', 'longtext', 'date', 'datetime', 'timestamp',
          'enum(\'a\',\'b\')', 'json', 'blob'] as $t) {
    verifica("$t deve essere testo", 's', tipoBindDaTipoSql($t));
}

// Trappola vera: "integer" inizia per "int" ma anche "interval" no — qui
// contano i tipi che MySQL restituisce davvero, e nessuno di questi deve
// diventare numerico per sbaglio.
verifica('varbinary non e` un numero', 's', tipoBindDaTipoSql('varbinary(255)'));
verifica('point non e` un numero', 's', tipoBindDaTipoSql('point'));

// ---- costruzione dei parametri ----
$colonne = ['food_name' => 's', 'unit' => 's', 'weight_g' => 'd',
            'calories' => 'd', 'nova_group' => 'i', 'allergens' => 's'];

[$tipi, $valori] = parametriIngrediente(42, [
    'food_name' => 'Croissant crema',
    'weight_g'  => '100',      // arriva come stringa dal JSON
    'calories'  => 430.5,
    'nova_group' => '4',
], $colonne);

verifica('la stringa dei tipi inizia con recipe_id intero', 'i', $tipi[0]);
verifica('un tipo per colonna, piu` recipe_id', 1 + count($colonne), strlen($tipi));
verifica('stessa quantita` di tipi e valori', strlen($tipi), count($valori));
verifica('la stringa dei tipi e` quella attesa', 'issddis', $tipi);
verifica('recipe_id passa per primo', 42, $valori[0]);
verifica('il nome passa come testo', 'Croissant crema', $valori[1]);
verifica('unit assente diventa g, non stringa vuota', 'g', $valori[2]);
verifica('il peso arrivato come stringa diventa numero', 100.0, $valori[3]);
verifica('le calorie restano decimali', 430.5, $valori[4]);
verifica('nova_group diventa intero vero', 4, $valori[5]);
verifica('una colonna testuale assente diventa stringa vuota', '', $valori[6]);

// Ingrediente vuoto: non deve rompere, deve dare valori neutri.
[$tipi2, $valori2] = parametriIngrediente(7, [], $colonne);
verifica('anche un ingrediente vuoto produce tutti i parametri',
    1 + count($colonne), count($valori2));
verifica('senza calorie si scrive 0, non null', 0.0, $valori2[4]);

if ($errori) {
    fwrite(STDERR, count($errori) . " controlli falliti:\n\n" . implode("\n\n", $errori) . "\n");
    exit(1);
}
echo "TUTTO OK — " . (count($colonne) + 30) . " controlli passati\n";
