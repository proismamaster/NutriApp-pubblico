-- Tabella per memorizzare gli alimenti salvati dagli utenti nella loro libreria personale
CREATE TABLE IF NOT EXISTS na_custom_foods (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_mail VARCHAR(255) NOT NULL,
    food_name VARCHAR(255) NOT NULL,
    barcode VARCHAR(50) DEFAULT NULL,
    base_weight_g DOUBLE DEFAULT 100.0,
    -- Macronutrienti
    calories DOUBLE DEFAULT 0,
    proteins DOUBLE DEFAULT 0,
    carbs DOUBLE DEFAULT 0,
    fats DOUBLE DEFAULT 0,
    water DOUBLE DEFAULT 0,
    fibers DOUBLE DEFAULT 0,
    sugars DOUBLE DEFAULT 0,
    -- Grassi
    saturated_fats DOUBLE DEFAULT 0,
    monounsaturated_fats DOUBLE DEFAULT 0,
    polyunsaturated_fats DOUBLE DEFAULT 0,
    trans_fats DOUBLE DEFAULT 0,
    cholesterol DOUBLE DEFAULT 0,
    -- Vitamine
    vit_a DOUBLE DEFAULT 0, vit_b1 DOUBLE DEFAULT 0, vit_b2 DOUBLE DEFAULT 0,
    vit_b3 DOUBLE DEFAULT 0, vit_b5 DOUBLE DEFAULT 0, vit_b6 DOUBLE DEFAULT 0,
    vit_b7 DOUBLE DEFAULT 0, vit_b9 DOUBLE DEFAULT 0, vit_b11 DOUBLE DEFAULT 0,
    vit_b12 DOUBLE DEFAULT 0, vit_c DOUBLE DEFAULT 0, vit_d DOUBLE DEFAULT 0,
    vit_e DOUBLE DEFAULT 0, vit_k DOUBLE DEFAULT 0, biotin DOUBLE DEFAULT 0,
    -- Minerali
    sodium DOUBLE DEFAULT 0, arsenic DOUBLE DEFAULT 0, boron DOUBLE DEFAULT 0,
    calcium DOUBLE DEFAULT 0, chloride DOUBLE DEFAULT 0, choline DOUBLE DEFAULT 0,
    chromium DOUBLE DEFAULT 0, cobalt DOUBLE DEFAULT 0, copper DOUBLE DEFAULT 0,
    fluoride DOUBLE DEFAULT 0, fluorine DOUBLE DEFAULT 0, iodine DOUBLE DEFAULT 0,
    iron DOUBLE DEFAULT 0, magnesium DOUBLE DEFAULT 0, manganese DOUBLE DEFAULT 0,
    molybdenum DOUBLE DEFAULT 0, phosphorus DOUBLE DEFAULT 0, potassium DOUBLE DEFAULT 0,
    selenium DOUBLE DEFAULT 0, silicon DOUBLE DEFAULT 0, sulfur DOUBLE DEFAULT 0,
    tin DOUBLE DEFAULT 0, vanadium DOUBLE DEFAULT 0, zinc DOUBLE DEFAULT 0,
    is_favorite TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX (user_mail)
);