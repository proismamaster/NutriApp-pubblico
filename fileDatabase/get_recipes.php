<?php
require 'db_config.php';
require_once 'auth.php';

if (!isset($_GET['user_mail'])) {
    die(json_encode(["status" => "error", "message" => "user_mail mancante."]));
}

// Identita' dal gettone di sessione, non dal parametro: chiunque poteva
// indicare l'email di un altro utente (test di release 19/09).
$user_mail = emailAutenticata($conn, (string) ($_GET['user_mail'] ?? ''));
$recipes = [];

/*
 * `shared_status` solo se la colonna c'e' (migrazione 2026-09-12).
 *
 * PERCHE' COSI' E NON UN require CONDIVISO: se il server e' indietro con le
 * migrazioni, chiederla nella SELECT fa fallire la query e l'utente perde
 * l'elenco delle PROPRIE ricette per una funzione che non ha nemmeno usato.
 * E il controllo sta qui dentro, senza importare il file comune della
 * community: un file in piu' da caricare via FTP e' cio' che il 07/09 ha
 * tenuto giu' il salvataggio ricette per tre sessioni.
 */
$haCondivisione = false;
$colonne = $conn->query("SHOW COLUMNS FROM na_recipes LIKE 'shared_status'");
if ($colonne && $colonne->num_rows > 0) {
    $haCondivisione = true;
}

// Migrazione 2026-09-15: ricette tolte dall'autore dopo l'approvazione (restano
// pubbliche, non sono piu' sue) e categorie. Stesso controllo, stessa ragione.
$haCategorie = false;
$colonne = $conn->query("SHOW COLUMNS FROM na_recipes LIKE 'author_removed_at'");
if ($colonne && $colonne->num_rows > 0) {
    $haCategorie = true;
}

$sql_recipes = "SELECT id, recipe_name, `portion`, `notes`, is_favorite, image_url"
    . ($haCondivisione ? ", shared_status" : "")
    . ($haCategorie ? ", meal_types, course, diet_tags" : "")
    . " FROM na_recipes WHERE user_mail = ?"
    . ($haCategorie ? " AND author_removed_at IS NULL" : "")
    . " ORDER BY creation_date DESC";
$stmt_recipes = $conn->prepare($sql_recipes);
$stmt_recipes->bind_param("s", $user_mail);
$stmt_recipes->execute();
$result_recipes = $stmt_recipes->get_result();

while ($recipe_row = $result_recipes->fetch_assoc()) {
    $recipe_id = $recipe_row['id'];
    $recipe = [
        "id" => $recipe_id,
        "recipe_name" => $recipe_row['recipe_name'],
        "image_url" => $recipe_row['image_url'] ?? '',
        "portion" => $recipe_row['portion'],
        "notes" => $recipe_row['notes'],
        "is_favorite" => (int)$recipe_row['is_favorite'],
        // 'private' quando la colonna non c'e': e' la verita' su un server
        // dove la condivisione non esiste ancora, non un valore inventato.
        "shared_status" => $recipe_row['shared_status'] ?? 'private',
        "meal_types" => $recipe_row['meal_types'] ?? '',
        "course" => $recipe_row['course'] ?? '',
        "diet_tags" => $recipe_row['diet_tags'] ?? '',
        "ingredients" => []
    ];

    $sql_ingredients = "SELECT * FROM na_recipe_ingredients WHERE recipe_id = ?";
    $stmt_ingredients = $conn->prepare($sql_ingredients);
    $stmt_ingredients->bind_param("i", $recipe_id);
    $stmt_ingredients->execute();
    $result_ingredients = $stmt_ingredients->get_result();
    
    while ($ing_row = $result_ingredients->fetch_assoc()) {
        $recipe["ingredients"][] = $ing_row;
    }
    $stmt_ingredients->close();
    $recipes[] = $recipe;

}

$stmt_recipes->close();
$conn->close();
echo json_encode($recipes);
?>