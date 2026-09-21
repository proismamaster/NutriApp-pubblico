<?php
/**
 * segnalazioni_ricette.php — le segnalazioni sulle ricette pubbliche (21/09).
 *
 * TRE CODE, TRE PAGINE, PERCHE' SONO TRE COSE DIVERSE:
 *  - segnalazioni.php: un DATO di un alimento e' sbagliato;
 *  - problemi.php: il PROGRAMMA non va;
 *  - qui: una RICETTA pubblicata da una persona ha qualcosa che non va
 *    (contenuto inadatto, copiata, consigli pericolosi, pubblicita').
 *
 * Chi rivede ha tre azioni: lasciare aperta, accettare (e in quel caso
 * ritirare la ricetta da "Consigliate", che e' l'unica cosa che serve fare),
 * rifiutare con il motivo. La nota la legge chi ha segnalato in "Le mie
 * segnalazioni", quindi rifiutare senza scriverla non si puo'.
 *
 * ACCETTARE RITIRA LA RICETTA: senza, accettare sarebbe solo un'etichetta
 * messa su una riga, e la ricetta segnalata resterebbe pubblica. La ricetta
 * non viene MAI cancellata — resta all'autore, solo non e' piu' consigliata.
 *
 * Ogni decisione passa dal registro e si annulla da li', come tutte le altre.
 *
 * Richiede la migrazione fileDatabase/migrations/2026-09-21_segnalazioni_ricette.sql.
 */

declare(strict_types=1);
require __DIR__ . '/_comune.php';
richiediAccesso();

$messaggio = null;
$tipoMessaggio = 'esito';
$tabellaPronta = colonnaEsiste($conn, 'na_recipe_reports', 'status');

$tipiProblema = [
    'contenuto' => 'contenuto inadatto',
    'valori' => 'valori sbagliati',
    'copia' => 'copiata da altri',
    'pericolosa' => 'consigli pericolosi',
    'spam' => 'pubblicita o spam',
    'altro' => 'altro',
];
$statiSegnalazione = ['pending' => 'Aperte', 'accepted' => 'Accettate', 'rejected' => 'Rifiutate', 'tutti' => 'Tutte'];

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    richiediToken();
    $id = (int) ($_POST['id'] ?? 0);
    $nuovo = (string) ($_POST['stato'] ?? '');
    $nota = mb_substr(trim((string) ($_POST['nota'] ?? '')), 0, 255);
    $ritira = ($_POST['ritira'] ?? '') === '1';

    if (!$tabellaPronta) {
        $messaggio = 'Migrazione mancante: eseguire 2026-09-21_segnalazioni_ricette.sql su phpMyAdmin.';
        $tipoMessaggio = 'avviso';
    } elseif (!in_array($nuovo, ['pending', 'accepted', 'rejected'], true)) {
        $messaggio = 'Stato non valido.';
        $tipoMessaggio = 'avviso';
    } elseif ($nuovo === 'rejected' && $nota === '') {
        // Rifiutare senza dire perche' lascia chi ha segnalato senza risposta.
        $messaggio = 'Scrivi perché la rifiuti: lo legge chi l\'ha segnalata.';
        $tipoMessaggio = 'avviso';
    } else {
        $stmt = $conn->prepare(
            'SELECT recipe_id, recipe_name, status, review_note, reviewed_by, reviewed_at
               FROM na_recipe_reports WHERE id = ? LIMIT 1'
        );
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $riga = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$riga) {
            $messaggio = 'Segnalazione non trovata.';
            $tipoMessaggio = 'avviso';
        } else {
            $chi = adminCorrente()['email'];
            $notaSalvata = $nota === '' ? null : $nota;
            $stmt = $conn->prepare(
                'UPDATE na_recipe_reports
                    SET status = ?, review_note = ?, reviewed_by = ?, reviewed_at = NOW()
                  WHERE id = ?'
            );
            $stmt->bind_param('sssi', $nuovo, $notaSalvata, $chi, $id);
            $stmt->execute();
            $stmt->close();

            registra(
                $conn,
                ['pending' => 'reopen', 'accepted' => 'accept', 'rejected' => 'reject'][$nuovo],
                'recipe_report',
                $id,
                mb_substr((string) $riga['recipe_name'], 0, 80),
                ['status' => $riga['status'], 'review_note' => $riga['review_note'], 'reviewed_by' => $riga['reviewed_by'], 'reviewed_at' => $riga['reviewed_at']],
                ['status' => $nuovo, 'review_note' => $notaSalvata],
                $notaSalvata
            );

            $messaggio = 'Segnalazione #' . $id . ' segnata come ' . strtolower($statiSegnalazione[$nuovo] ?? $nuovo) . '.';

            // Accettare una segnalazione senza togliere la ricetta da
            // "Consigliate" la lascerebbe pubblica: la casella e' spuntata per
            // difetto nel modulo, ma resta una scelta di chi rivede.
            if ($nuovo === 'accepted' && $ritira) {
                $idRicetta = (int) $riga['recipe_id'];
                $stmt = $conn->prepare("SELECT recipe_name, shared_status FROM na_recipes WHERE id = ? LIMIT 1");
                $stmt->bind_param('i', $idRicetta);
                $stmt->execute();
                $ricetta = $stmt->get_result()->fetch_assoc();
                $stmt->close();

                if (!$ricetta) {
                    $messaggio .= ' La ricetta non esiste più: niente da ritirare.';
                } elseif (($ricetta['shared_status'] ?? '') !== 'approved') {
                    $messaggio .= ' La ricetta non era più pubblica.';
                } else {
                    $stmt = $conn->prepare(
                        "UPDATE na_recipes
                            SET shared_status = 'rejected', reviewed_by = ?, reviewed_at = NOW(), review_note = ?
                          WHERE id = ?"
                    );
                    $motivo = $notaSalvata ?? ('Ritirata dopo una segnalazione (#' . $id . ').');
                    $stmt->bind_param('ssi', $chi, $motivo, $idRicetta);
                    $stmt->execute();
                    $stmt->close();
                    registra(
                        $conn, 'withdraw', 'recipe', $idRicetta, mb_substr((string) $ricetta['recipe_name'], 0, 80),
                        ['shared_status' => 'approved'], ['shared_status' => 'rejected'], $motivo
                    );
                    $messaggio .= ' Ricetta ritirata da Consigliate.';
                }
            }
        }
    }
}

$stato = (string) ($_GET['stato'] ?? 'pending');
if (!isset($statiSegnalazione[$stato])) {
    $stato = 'pending';
}
$tipo = (string) ($_GET['tipo'] ?? '');
if ($tipo !== '' && !isset($tipiProblema[$tipo])) {
    $tipo = '';
}
$cerca = testoCercato();

$colonneOrdine = [
    'data' => ['Data', 'r.created_at'],
    'ricetta' => ['Ricetta', 'r.recipe_name'],
    'tipo' => ['Problema', 'r.issue'],
    'stato' => ['Stato', 'r.status'],
];
[$ordine, $ordinaPer, $verso] = ordinamento($colonneOrdine, 'data', 'desc');

$voci = '';
if ($tabellaPronta) {
    $dove = [];
    $tipi = '';
    $par = [];
    if ($stato !== 'tutti') {
        $dove[] = 'r.status = ?';
        $tipi .= 's';
        $par[] = $stato;
    }
    if ($tipo !== '') {
        $dove[] = 'r.issue = ?';
        $tipi .= 's';
        $par[] = $tipo;
    }
    if ($cerca !== '') {
        $campiCerca = [
            'r.recipe_name', 'r.issue', 'r.note', 'r.review_note', 'r.user_mail', 'r.author_mail',
            'u.first_name', 'u.last_name', 'CAST(r.id AS CHAR)', 'CAST(r.recipe_id AS CHAR)',
        ];
        $dove[] = '(' . implode(' LIKE ? OR ', $campiCerca) . ' LIKE ?)';
        $tipi .= str_repeat('s', count($campiCerca));
        array_push($par, ...array_fill(0, count($campiCerca), comeLike($cerca)));
    }

    // COLLATION dichiarata nel JOIN, come in problemi.php: le tabelle delle
    // segnalazioni e na_users non hanno la stessa, e MySQL risponde "Illegal
    // mix of collations" (lezione del 13/09).
    $sql = "SELECT r.id, r.recipe_id, r.recipe_name, r.issue, r.note, r.status, r.created_at,
                   r.reviewed_at, r.reviewed_by, r.review_note, r.user_mail,
                   u.first_name, u.last_name, ric.shared_status
              FROM na_recipe_reports r
              LEFT JOIN na_users u ON u.email = r.user_mail COLLATE utf8mb4_general_ci
              LEFT JOIN na_recipes ric ON ric.id = r.recipe_id"
        . ($dove === [] ? '' : ' WHERE ' . implode(' AND ', $dove))
        . " ORDER BY $ordine, r.id DESC LIMIT 300";
    $stmt = $conn->prepare($sql);
    if ($tipi !== '') {
        $stmt->bind_param($tipi, ...$par);
    }
    $stmt->execute();
    $res = $stmt->get_result();

    while ($r = $res->fetch_assoc()) {
        $idSegnalazione = (int) $r['id'];
        $nome = trim((string) $r['first_name'] . ' ' . (string) $r['last_name']);
        $statoRicetta = (string) ($r['shared_status'] ?? '');

        $opzioni = '';
        foreach (['pending' => 'Aperta', 'accepted' => 'Accettata', 'rejected' => 'Rifiutata'] as $v => $et) {
            $opzioni .= '<option value="' . $v . '"' . ($v === $r['status'] ? ' selected' : '') . '>' . $et . '</option>';
        }

        $dettagli = '<div class="corpo-problema">'
            . '<p class="testo-problema">' . ((string) $r['note'] === ''
                ? '<span class="secondario">Nessuna nota: solo il motivo scelto.</span>'
                : nl2br(e((string) $r['note']))) . '</p>'
            . '<div class="fatti-problema">'
            . '<span><b>Ricetta:</b> #' . (int) $r['recipe_id'] . ' · '
            . ($statoRicetta === '' ? 'non esiste più' : e($statoRicetta)) . '</span>'
            . '<span><b>Segnalata da:</b> ' . e($nome !== '' ? $nome : (string) $r['user_mail']) . '</span>'
            . ($r['reviewed_by'] ? '<span><b>Rivista da:</b> ' . e(nomeAdmin($conn, (string) $r['reviewed_by']))
                . ' il ' . e(date('d/m/Y H:i', strtotime((string) $r['reviewed_at']))) . '</span>' : '')
            . '</div>'
            . '<form method="post" class="gestisci-problema">' . campoToken()
            . '<input type="hidden" name="id" value="' . $idSegnalazione . '">'
            . '<label><span>Stato</span><select name="stato">' . $opzioni . '</select></label>'
            . '<label class="largo"><span>Risposta per chi ha segnalato</span>'
            . '<textarea name="nota" maxlength="255" rows="2" placeholder="Obbligatoria per rifiutare">'
            . e((string) $r['review_note']) . '</textarea></label>'
            . ($statoRicetta === 'approved'
                ? '<label><span>Accettando</span><span class="secondario">'
                    . '<input type="checkbox" name="ritira" value="1" checked> ritira da Consigliate</span></label>'
                : '')
            . '<button class="principale" type="submit">Salva</button>'
            . '</form></div>';

        $voci .= '<details class="problema" id="sr' . $idSegnalazione . '"><summary class="riga">'
            . '<span class="taglia" style="font-weight:600">' . e((string) $r['recipe_name']) . '</span>'
            . '<span class="secondario" style="font-size:12.5px">' . e($tipiProblema[$r['issue']] ?? (string) $r['issue']) . '</span>'
            . '<span class="taglia" style="font-size:12.5px">' . e($nome !== '' ? $nome : 'Anonimo') . '</span>'
            . '<span class="secondario cifre ' . ($r['status'] === 'pending' ? classeAttesa((string) $r['created_at']) : '') . '" style="font-size:12.5px">'
            . e(date('d/m/Y', strtotime((string) $r['created_at']))) . '</span>'
            . pastiglia((string) $r['status'])
            . '</summary>' . $dettagli . '</details>';
    }
    $stmt->close();
}

$elencoOpzioni = static function (array $valori, string $scelto): string {
    $out = '';
    foreach ($valori as $valore => $etichetta) {
        $out .= '<option value="' . e((string) $valore) . '"' . ((string) $valore === $scelto ? ' selected' : '') . '>' . e($etichetta) . '</option>';
    }
    return $out;
};

$filtri = '<form class="filtri" method="get">'
    . campoCerca($cerca, 'ricetta, motivo, persona, numero')
    . '<label><span>Stato</span><select name="stato">' . $elencoOpzioni($statiSegnalazione, $stato) . '</select></label>'
    . '<label><span>Problema</span><select name="tipo">' . $elencoOpzioni(['' => 'Tutti i problemi'] + $tipiProblema, $tipo) . '</select></label>'
    . sceltaOrdinamento($colonneOrdine, $ordinaPer, $verso)
    . '<button class="principale" type="submit">Filtra</button>'
    . '</form>';

$intestazioni = [['Ricetta', 'ricetta'], ['Problema', 'tipo'], ['Da', null], ['Data', 'data'], ['Stato', 'stato']];

$html = ($messaggio !== null ? '<div class="' . $tipoMessaggio . '">' . e($messaggio) . '</div>' : '')
    . (!$tabellaPronta
        ? '<div class="avviso">Migrazione del 21/09 non eseguita: eseguire '
            . 'fileDatabase/migrations/2026-09-21_segnalazioni_ricette.sql su phpMyAdmin.</div>'
        : '')
    . $filtri
    . '<p class="riepilogo">Clic su una segnalazione per leggerla e deciderne l\'esito.</p>'
    . '<div class="riquadro problemi">'
    . testaOrdinabile($intestazioni, $ordinaPer, $verso)
    . ($voci === '' ? '<div class="vuoto">Nessuna segnalazione con questi filtri</div>' : $voci)
    . '</div>';

pagina('Segnalazioni ricette', $html, 'segnalazioni_ricette.php');
