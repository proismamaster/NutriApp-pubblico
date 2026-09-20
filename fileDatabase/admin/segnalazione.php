<?php
/**
 * segnalazione.php — il dettaglio di una segnalazione: le prove a sinistra, la
 * decisione a destra. E' la schermata che fa funzionare tutto il pannello.
 *
 * Ricalcata sulla schermata 2 dei mockup (13/09): foto alte 300px col ruolo
 * come titolo, nota con la barra verde, scheda dei fatti; a destra la tabella
 * a quattro colonne, il pulsante che dice quanti campi accetta, la motivazione
 * che accende il pulsante Rifiuta, e le scorciatoie A / R / S / Spazio.
 *
 * SI ACCETTA CAMPO PER CAMPO, NON TUTTO O NIENTE.
 * Una proposta puo' avere ragione sulle calorie e torto sugli zuccheri. Con la
 * sola scelta "accetto tutto / rifiuto tutto", chi rivede finisce per rifiutare
 * proposte buone al 90%, e chi le manda smette di mandarle. Ogni campo ha la
 * sua casella; si scrive solo cio' che e' spuntato.
 *
 * DOVE FINISCONO I VALORI ACCETTATI
 * Solo in `na_off_products`, e solo se il barcode esiste la'. Per un alimento
 * CREA/USDA o personale la segnalazione si puo' leggere e chiudere, ma NON
 * applicare: quelle tabelle hanno origini e vincoli diversi, e scriverci
 * automaticamente sarebbe una modifica che nessuno ha chiesto. Il pannello lo
 * dice invece di far finta di poterlo fare.
 */

declare(strict_types=1);
require __DIR__ . '/_comune.php';
richiediAccesso();

$id = (int) ($_GET['id'] ?? $_POST['id'] ?? 0);
if ($id <= 0) {
    header('Location: segnalazioni.php');
    exit;
}

/** La segnalazione, con il nome di chi l'ha mandata. */
function caricaSegnalazione(mysqli $conn, int $id): ?array
{
    $stmt = $conn->prepare(
        'SELECT r.*, u.first_name
           FROM na_food_reports r
           LEFT JOIN na_users u ON u.email = r.user_mail
          WHERE r.id = ? LIMIT 1'
    );
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $riga = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $riga ?: null;
}

$seg = caricaSegnalazione($conn, $id);
if ($seg === null) {
    pagina('Segnalazione', '<p class="vuoto">Segnalazione non trovata.</p>', 'segnalazione.php');
    exit;
}

// ---------------------------------------------------------------------------
// Bersaglio della correzione
// ---------------------------------------------------------------------------
$barcode = trim((string) ($seg['barcode'] ?? ''));
$tabella = 'na_off_products';
$applicabile = false;
if ($barcode !== '') {
    $stmt = $conn->prepare('SELECT 1 FROM na_off_products WHERE barcode = ? LIMIT 1');
    $stmt->bind_param('s', $barcode);
    $stmt->execute();
    $applicabile = (bool) $stmt->get_result()->fetch_row();
    $stmt->close();
}

$campiTipo = campiAmmessi($conn, $tabella);
$proposta = [];
if (!empty($seg['proposed_json'])) {
    $decodificato = json_decode((string) $seg['proposed_json'], true);
    if (is_array($decodificato)) {
        // Solo le chiavi che sono colonne vere E nella lista chiusa. Una
        // chiave inventata dall'app finisce qui e si ferma qui.
        foreach ($decodificato as $campo => $valore) {
            if (isset($campiTipo[$campo]) && !is_array($valore)) {
                $proposta[$campo] = $valore;
            }
        }
    }
}
$attuali = $applicabile && $proposta !== []
    ? valoriAttuali($conn, $tabella, 'barcode', $barcode, $proposta)
    : [];

// ---------------------------------------------------------------------------
// Decisione
// ---------------------------------------------------------------------------
$messaggio = null;
$tipoMessaggio = 'esito';

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    richiediToken();
    $azione = (string) ($_POST['azione'] ?? '');

    if ($azione === 'accetta') {
        $scelti = (array) ($_POST['campi'] ?? []);
        $daScrivere = [];
        foreach ($scelti as $campo) {
            $campo = (string) $campo;
            if (isset($proposta[$campo])) {
                $daScrivere[$campo] = $proposta[$campo];
            }
        }

        // Un valore impossibile non si scrive nemmeno se il revisore lo spunta
        // per sbaglio: stesse soglie degli import e degli alimenti degli utenti
        // (decisione del 20/09). Si controlla la riga COME SAREBBE dopo la
        // scrittura, non il singolo campo: 60 g di grassi sono normali, 60 g di
        // grassi insieme a 60 di carboidrati no.
        require_once __DIR__ . '/../limiti_nutrienti.php';
        $impossibile = $daScrivere === []
            ? null
            : erroreNutrienti(array_merge($attuali, $daScrivere));

        if ($impossibile !== null) {
            $messaggio = 'Non scritto: ' . $impossibile . '. Controlla il valore proposto.';
            $tipoMessaggio = 'errore';
        } elseif ($daScrivere === [] && $proposta !== []) {
            $messaggio = 'Nessun campo selezionato: non è stato scritto niente.';
            $tipoMessaggio = 'avviso';
        } else {
            $prima = [];
            $dopo = [];
            if ($daScrivere !== [] && $applicabile) {
                [$prima, $dopo] = applicaValori($conn, $tabella, 'barcode', $barcode, $campiTipo, $daScrivere);
            }

            $accettatoJson = $dopo === [] ? null : json_encode($dopo, JSON_UNESCAPED_UNICODE);
            $stmt = $conn->prepare(
                'UPDATE na_food_reports
                    SET status = "accepted", reviewed_at = NOW(), reviewed_by = ?, accepted_json = ?
                  WHERE id = ?'
            );
            $chi = adminCorrente()['email'];
            $stmt->bind_param('ssi', $chi, $accettatoJson, $id);
            $stmt->execute();
            $stmt->close();

            registra($conn, 'accept', 'food_report', $id, (string) $seg['food_name'], $prima, $dopo);
            $messaggio = $dopo === []
                ? 'Segnalazione accettata (nessun valore da applicare).'
                : count($dopo) . ' valori scritti su ' . $tabella . '.';
            $seg = caricaSegnalazione($conn, $id);
        }
    } elseif ($azione === 'rifiuta') {
        $nota = trim((string) ($_POST['nota'] ?? ''));
        if ($nota === '') {
            // La motivazione la legge l'utente nell'app: un rifiuto muto e' il
            // modo piu' sicuro per non ricevere mai piu' una segnalazione.
            // Il pulsante e' gia' spento senza testo, ma il controllo vero sta
            // qui: un modulo si puo' mandare anche senza passare dal browser.
            $messaggio = 'Scrivi una motivazione: la vedrà chi ha mandato la segnalazione.';
            $tipoMessaggio = 'avviso';
        } else {
            $stmt = $conn->prepare(
                'UPDATE na_food_reports
                    SET status = "rejected", reviewed_at = NOW(), reviewed_by = ?, review_note = ?
                  WHERE id = ?'
            );
            $chi = adminCorrente()['email'];
            $stmt->bind_param('ssi', $chi, $nota, $id);
            $stmt->execute();
            $stmt->close();
            registra($conn, 'reject', 'food_report', $id, (string) $seg['food_name'], null, null, $nota);
            $messaggio = 'Segnalazione rifiutata.';
            $seg = caricaSegnalazione($conn, $id);
        }
    }
}

// ---------------------------------------------------------------------------
// Le prove (colonna sinistra)
// ---------------------------------------------------------------------------
$foto = [];
$stmt = $conn->prepare('SELECT url, role FROM na_report_photos WHERE report_id = ? ORDER BY sort_order, id');
$stmt->bind_param('i', $id);
$stmt->execute();
$res = $stmt->get_result();
while ($r = $res->fetch_assoc()) {
    $foto[] = $r;
}
$stmt->close();

$ruoli = [
    'fronte' => 'Fronte confezione',
    'tabella' => 'Tabella nutrizionale',
    'ingredienti' => 'Ingredienti',
    'altro' => 'Altra foto',
];
$problemi = [
    'valori' => 'valori nutrizionali', 'nome' => 'nome o marca', 'categoria' => 'categoria',
    'immagine' => 'foto', 'duplicato' => 'doppione', 'altro' => 'altro',
];
$fonti = [
    'off' => 'OpenFoodFacts', 'retailer' => 'Supermercato', 'crea' => 'CREA',
    'usda' => 'USDA', 'custom' => 'Alimento personale',
];

$sinistra = '';
if ($foto === []) {
    $sinistra .= '<div class="senza-foto">Nessuna foto allegata: questa segnalazione si può solo prendere in parola</div>';
} else {
    foreach ($foto as $f) {
        $etichetta = $ruoli[$f['role']] ?? 'Foto';
        $sinistra .= '<div class="foto"><div class="titolo"><strong class="taglia">' . e($etichetta) . '</strong>'
            . '<span>clic per ingrandire</span></div>'
            . '<a href="' . e($f['url']) . '" target="_blank" rel="noopener">'
            . '<img src="' . e($f['url']) . '" alt="' . e($etichetta) . '" loading="lazy"></a></div>';
    }
}
if (!empty($seg['note'])) {
    $sinistra .= '<p class="nota-utente">' . nl2br(e((string) $seg['note'])) . '</p>';
}

$fatti = [
    'Alimento' => (string) $seg['food_name'],
    'Codice a barre' => $barcode !== '' ? $barcode : '—',
    'Fonte' => $fonti[$seg['source'] ?? ''] ?? ((string) ($seg['source'] ?: '—')),
    'Problema' => $problemi[$seg['issue']] ?? (string) $seg['issue'],
    'Da' => (string) ($seg['first_name'] ?: 'Anonimo'),
    'Quando' => date('d/m/Y', strtotime((string) $seg['created_at'])) . ' (' . attesa((string) $seg['created_at']) . ')',
];
$sinistra .= '<div class="riquadro fatti">';
foreach ($fatti as $k => $v) {
    $sinistra .= '<div class="riga"><span>' . e($k) . '</span><span class="taglia">' . e($v) . '</span></div>';
}
$sinistra .= '</div>';

// ---------------------------------------------------------------------------
// La decisione (colonna destra)
// ---------------------------------------------------------------------------
$decisa = in_array((string) $seg['status'], ['accepted', 'rejected'], true);

$testaTabella = '<div class="riga testa"><span></span><span>Campo</span>'
    . '<span class="destra">' . ($decisa ? 'Prima' : 'Adesso') . '</span><span class="destra">Proposto</span></div>';

/** Valore da mostrare in una cella: numero all'italiana, testo cosi' com'e'. */
$cella = static fn($v): string => $v === null || $v === '' ? '—' : (is_numeric($v) ? num($v, 2) : (string) $v);

/*
 * La cella pronta per l'HTML. Le foto (18/09: si puo' proporre anche
 * l'immagine del prodotto) si guardano, non si leggono: un indirizzo lungo
 * dentro una colonna stretta non dice niente a chi deve decidere. Si accettano
 * solo gli indirizzi della nostra cartella uploads/, gli stessi che
 * save_food_report.php lascia passare: un altro indirizzo resta testo.
 */
$cellaHtml = static function (string $campo, $v) use ($cella): string {
    $testo = (string) $v;
    if ($campo === 'image_url' && stripos($testo, '/nutriapp/uploads/') !== false) {
        return '<a href="' . e($testo) . '" target="_blank" rel="noopener">'
            . '<img src="' . e($testo) . '" alt="Foto proposta" loading="lazy"'
            . ' style="max-width:90px;max-height:70px;border-radius:8px;display:block;margin-left:auto"></a>';
    }
    return e($cella($v));
};

$destra = '';
if ($messaggio !== null) {
    $destra .= '<div class="' . $tipoMessaggio . '">' . e($messaggio) . '</div>';
}

$intestazione = '';
if ($decisa) {
    // Variante "gia' decisa": sola lettura. Per ogni campo proposto, ✓ se e'
    // stato scritto, — se no (e il valore proposto barrato). "Prima" viene dal
    // registro: dopo l'accettazione il database contiene gia' il valore nuovo,
    // e mostrare quello come "adesso" farebbe sembrare che non sia cambiato
    // niente.
    $accettati = json_decode((string) ($seg['accepted_json'] ?? ''), true);
    $accettati = is_array($accettati) ? $accettati : [];
    $prima = [];
    $stmt = $conn->prepare(
        "SELECT before_json FROM na_review_log
          WHERE target_type = 'food_report' AND target_id = ? AND action = 'accept' AND undone_at IS NULL
          ORDER BY id DESC LIMIT 1"
    );
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $riga = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if ($riga && $riga['before_json']) {
        $prima = json_decode((string) $riga['before_json'], true) ?: [];
    }

    $quando = $seg['reviewed_at'] ? date('d/m/Y', strtotime((string) $seg['reviewed_at'])) : '';
    $chi = (string) ($seg['reviewed_by'] ?? '');
    if ($seg['status'] === 'accepted') {
        $n = count($accettati);
        $intestazione = '<div class="decisa">Accettata da ' . e($chi) . ' il ' . e($quando)
            . ' · ' . $n . ($n === 1 ? ' campo scritto' : ' campi scritti') . '</div>';
    } else {
        $intestazione = '<div class="decisa no">Rifiutata da ' . e($chi) . ' il ' . e($quando) . '</div>';
    }

    if ($proposta === []) {
        $destra .= '<div class="valori-assenti">Nessun valore proposto: c\'è solo il tipo di problema e la nota</div>';
    } else {
        $destra .= '<div class="riquadro decisione">' . $testaTabella;
        foreach ($proposta as $campo => $valore) {
            $scritto = array_key_exists($campo, $accettati);
            $valorePrima = $prima[$campo] ?? ($attuali[$campo] ?? null);
            $destra .= '<div class="riga">'
                . ($scritto ? '<span class="segno-ok">✓</span>' : '<span class="segno-no">—</span>')
                . '<div><div class="campo-nome">' . e(etichettaCampo($campo)) . '</div>'
                . '<div class="colonna-db">' . e($campo) . '</div></div>'
                . '<div class="adesso">' . $cellaHtml($campo, $valorePrima) . '</div>'
                . '<div class="proposto ' . ($scritto ? 'scritto' : 'scartato') . '">' . $cellaHtml($campo, $valore) . '</div>'
                . '</div>';
        }
        $destra .= '</div>';
    }
    if (!empty($seg['review_note'])) {
        $destra .= '<p class="nota-utente" style="margin-top:16px;border-left-color:var(--rosso)">' . e((string) $seg['review_note']) . '</p>';
    }
    $destra .= '<div class="azioni"><a class="bottone" href="registro.php">Annulla decisione</a></div>';
} else {
    if (!$applicabile && $proposta !== []) {
        $destra .= '<div class="avviso">Questo alimento non è in <code>na_off_products</code>'
            . ($barcode === '' ? ' (nessun codice a barre)' : '')
            . ': i valori proposti si possono leggere, ma non applicare automaticamente. '
            . 'Accettando, la segnalazione si chiude senza scrivere niente.</div>';
    }

    $destra .= '<form method="post" id="modulo-decisione">' . campoToken()
        . '<input type="hidden" name="id" value="' . $id . '">';

    if ($proposta === []) {
        $destra .= '<div class="valori-assenti">Nessun valore proposto: c\'è solo il tipo di problema e la nota</div>'
            . '<div class="azioni"><button class="principale" type="submit" name="azione" value="accetta" id="bottone-accetta">Accetta</button></div>';
    } else {
        $destra .= '<div class="riquadro decisione">' . $testaTabella;
        foreach ($proposta as $campo => $valore) {
            $attuale = $attuali[$campo] ?? null;
            $motivo = is_numeric($valore) ? sospetto($campo, $attuale, $valore) : null;
            $destra .= '<label class="riga' . ($motivo !== null ? ' sospetta' : '') . '">'
                // Spuntata per difetto solo se non c'e' niente di sospetto:
                // l'errore piu' comune di chi copia un'etichetta e' la virgola
                // spostata, e deve essere una scelta attiva accettarlo.
                . '<input type="checkbox" name="campi[]" value="' . e($campo) . '"' . ($motivo === null ? ' checked' : '') . '>'
                . '<div><div class="campo-nome">' . e(etichettaCampo($campo)) . '</div>'
                . '<div class="colonna-db">' . e($campo) . '</div>'
                . ($motivo !== null ? '<div class="motivo">' . e($motivo) . '</div>' : '') . '</div>'
                . '<div class="adesso">' . $cellaHtml($campo, $attuale) . '</div>'
                . '<div class="proposto">' . $cellaHtml($campo, $valore) . '</div>'
                . '</label>';
        }
        $destra .= '</div>'
            . '<div class="azioni">'
            . '<button class="principale" type="submit" name="azione" value="accetta" id="bottone-accetta">Accetta i selezionati</button>'
            . '<a class="bottone" href="segnalazioni.php" id="bottone-salta">Salta</a>'
            . '</div>';
    }

    $destra .= '<div class="rifiuto">'
        . '<textarea class="motivazione" id="nota" name="nota" rows="2" maxlength="500" placeholder="Motivazione del rifiuto (la vede l\'utente)"></textarea>'
        . '<button class="rischio" type="submit" name="azione" value="rifiuta" id="bottone-rifiuta">Rifiuta</button>'
        . '</div></form>'
        . '<div class="scorciatoie">A accetta · R rifiuta · S salta · Spazio spunta la riga sotto il mouse</div>';

    // Tutto qui dentro e' solo comodita': il pannello funziona anche senza
    // JavaScript, perche' le regole vere (almeno un campo, motivazione
    // obbligatoria) le controlla il server.
    $destra .= <<<'JS'
<script>
(function () {
  var caselle = Array.prototype.slice.call(document.querySelectorAll('input[name="campi[]"]'));
  var accetta = document.getElementById('bottone-accetta');
  var rifiuta = document.getElementById('bottone-rifiuta');
  var nota = document.getElementById('nota');
  var sottoMouse = null;

  function aggiornaAccetta() {
    if (!caselle.length) return;
    var n = caselle.filter(function (c) { return c.checked; }).length;
    accetta.disabled = n === 0;
    accetta.textContent = n === 0 ? 'Nessun campo selezionato'
      : (n === 1 ? 'Accetta il campo selezionato' : 'Accetta i ' + n + ' selezionati');
  }
  function aggiornaRifiuta() { rifiuta.disabled = nota.value.trim() === ''; }

  caselle.forEach(function (c) {
    c.addEventListener('change', aggiornaAccetta);
    var riga = c.closest('.riga');
    riga.addEventListener('mouseenter', function () { sottoMouse = c; });
    riga.addEventListener('mouseleave', function () { if (sottoMouse === c) sottoMouse = null; });
  });
  nota.addEventListener('input', aggiornaRifiuta);
  aggiornaAccetta();
  aggiornaRifiuta();

  document.addEventListener('keydown', function (ev) {
    var t = (ev.target && ev.target.tagName || '').toLowerCase();
    if (t === 'textarea' || t === 'input' || ev.ctrlKey || ev.metaKey || ev.altKey) return;
    var k = ev.key.toLowerCase();
    if (k === ' ' && sottoMouse) { ev.preventDefault(); sottoMouse.checked = !sottoMouse.checked; aggiornaAccetta(); }
    else if (k === 'a' && !accetta.disabled) { accetta.click(); }
    else if (k === 'r') { if (rifiuta.disabled) { nota.focus(); } else { rifiuta.click(); } }
    else if (k === 's') { location.href = 'segnalazioni.php'; }
  });
})();
</script>
JS;
}

$html = '<a class="torna" href="segnalazioni.php">&larr; tutte le segnalazioni</a>'
    . $intestazione
    . '<div class="due-colonne"><div style="min-width:0">' . $sinistra . '</div><div style="min-width:0">' . $destra . '</div></div>';

pagina('Segnalazione #' . $id, $html, 'segnalazione.php');
