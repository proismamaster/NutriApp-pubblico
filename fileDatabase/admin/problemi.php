<?php
/**
 * problemi.php — le segnalazioni dei problemi dell'APP (15/09).
 *
 * Diverse da segnalazioni.php: quelle dicono che un DATO e' sbagliato, queste
 * che il PROGRAMMA non va (bug, sincronizzazione, idee). Arrivano da "Segnala
 * un problema" in Impostazioni e stanno in `na_reports`. Fino a oggi si
 * leggevano solo da phpMyAdmin: nessuno sapeva quali fossero gia' state viste.
 *
 * Tre stati: aperto (da guardare), risolto, chiuso (non si fa, con il perche').
 * La nota la vede chi ha segnalato, in "Le mie segnalazioni". Ogni cambio di
 * stato passa dal registro e si annulla da li'.
 *
 * COLLATION: na_reports e' utf8mb4_unicode_ci (migrazione del 05/09),
 * na_users utf8mb4_general_ci. Il JOIN dichiara la collation, altrimenti MySQL
 * risponde "Illegal mix of collations" (lezione del 13/09).
 */

declare(strict_types=1);
require __DIR__ . '/_comune.php';
richiediAccesso();

$messaggio = null;
$tipoMessaggio = 'esito';
$haStato = colonnaEsiste($conn, 'na_reports', 'status');
$haTipo = colonnaEsiste($conn, 'na_reports', 'kind');

$tipiProblema = ['bug' => 'Bug', 'data' => 'Dati', 'sync' => 'Sincronizzazione', 'idea' => 'Idea', 'other' => 'Altro'];
$statiProblema = ['open' => 'Aperti', 'resolved' => 'Risolti', 'closed' => 'Chiusi', 'tutti' => 'Tutti'];

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    richiediToken();
    $id = (int) ($_POST['id'] ?? 0);
    $nuovo = (string) ($_POST['stato'] ?? '');
    $nota = mb_substr(trim((string) ($_POST['nota'] ?? '')), 0, 500);

    if (!$haStato) {
        $messaggio = 'Migrazione mancante: eseguire 2026-09-15_community_ricette_pannello.sql su phpMyAdmin.';
        $tipoMessaggio = 'avviso';
    } elseif (!in_array($nuovo, ['open', 'resolved', 'closed'], true)) {
        $messaggio = 'Stato non valido.';
        $tipoMessaggio = 'avviso';
    } elseif ($nuovo === 'closed' && $nota === '') {
        // Chiudere senza dire perche' lascia chi ha segnalato senza risposta.
        $messaggio = 'Scrivi perché lo chiudi: lo legge chi l\'ha segnalato.';
        $tipoMessaggio = 'avviso';
    } else {
        $stmt = $conn->prepare('SELECT problem_description, status, admin_note, handled_by, handled_at FROM na_reports WHERE id = ? LIMIT 1');
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
            $stmt = $conn->prepare('UPDATE na_reports SET status = ?, admin_note = ?, handled_by = ?, handled_at = NOW() WHERE id = ?');
            $stmt->bind_param('sssi', $nuovo, $notaSalvata, $chi, $id);
            $stmt->execute();
            $stmt->close();

            $azione = ['open' => 'reopen', 'resolved' => 'resolve', 'closed' => 'close'][$nuovo];
            registra(
                $conn, $azione, 'app_report', $id, mb_substr((string) $riga['problem_description'], 0, 80),
                ['status' => $riga['status'], 'admin_note' => $riga['admin_note'], 'handled_by' => $riga['handled_by'], 'handled_at' => $riga['handled_at']],
                ['status' => $nuovo, 'admin_note' => $notaSalvata],
                $notaSalvata
            );
            $messaggio = 'Problema #' . $id . ' segnato come ' . strtolower(pastigliaTesto($nuovo)) . '.';
        }
    }
}

/** Il testo della pastiglia di uno stato, per i messaggi. */
function pastigliaTesto(string $stato): string
{
    return ['open' => 'Aperto', 'resolved' => 'Risolto', 'closed' => 'Chiuso'][$stato] ?? $stato;
}

$stato = (string) ($_GET['stato'] ?? 'open');
if (!isset($statiProblema[$stato]) || !$haStato) {
    $stato = $haStato ? 'open' : 'tutti';
}
$tipo = (string) ($_GET['tipo'] ?? '');
if ($tipo !== '' && !isset($tipiProblema[$tipo])) {
    $tipo = '';
}
$cerca = testoCercato();

$dove = [];
$tipi = '';
$par = [];
if ($stato !== 'tutti') {
    $dove[] = 'r.status = ?';
    $tipi .= 's';
    $par[] = $stato;
}
if ($tipo !== '' && $haTipo) {
    $dove[] = 'r.kind = ?';
    $tipi .= 's';
    $par[] = $tipo;
}
if ($cerca !== '') {
    $campiCerca = ['r.problem_description', 'r.user_email', 'u.first_name', 'u.last_name', 'CAST(r.id AS CHAR)'];
    if ($haTipo) {
        array_push($campiCerca, 'r.kind', 'r.screen', 'r.contact_email', 'r.diagnostics');
    }
    if ($haStato) {
        array_push($campiCerca, 'r.admin_note', 'r.handled_by');
    }
    $dove[] = '(' . implode(' LIKE ? OR ', $campiCerca) . ' LIKE ?)';
    $tipi .= str_repeat('s', count($campiCerca));
    array_push($par, ...array_fill(0, count($campiCerca), comeLike($cerca)));
}

$colonneOrdine = [
    'data' => ['Data', 'r.created_at'],
    'da' => ['Chi ha segnalato', 'u.first_name'],
];
if ($haTipo) {
    $colonneOrdine['tipo'] = ['Tipo', 'r.kind'];
    $colonneOrdine['schermata'] = ['Schermata', 'r.screen'];
}
if ($haStato) {
    $colonneOrdine['stato'] = ['Stato', 'r.status'];
}
[$ordine, $ordinaPer, $verso] = ordinamento($colonneOrdine, 'data', 'desc');

$colonne = 'r.id, r.problem_description, r.user_email, r.created_at, u.first_name, u.last_name'
    . ($haTipo ? ', r.kind, r.screen, r.contact_email, r.diagnostics' : ", NULL AS kind, NULL AS screen, NULL AS contact_email, NULL AS diagnostics")
    . ($haStato ? ', r.status, r.admin_note, r.handled_by, r.handled_at' : ", 'open' AS status, NULL AS admin_note, NULL AS handled_by, NULL AS handled_at");
$sql = "SELECT $colonne
          FROM na_reports r
          LEFT JOIN na_users u ON u.email = r.user_email COLLATE utf8mb4_general_ci"
    . ($dove === [] ? '' : ' WHERE ' . implode(' AND ', $dove))
    . " ORDER BY $ordine, r.id DESC LIMIT 300";
$stmt = $conn->prepare($sql);
if ($tipi !== '') {
    $stmt->bind_param($tipi, ...$par);
}
$stmt->execute();
$res = $stmt->get_result();

$voci = '';
while ($r = $res->fetch_assoc()) {
    $nome = trim((string) $r['first_name'] . ' ' . (string) $r['last_name']);
    $descrizione = (string) $r['problem_description'];
    $idProblema = (int) $r['id'];

    $dettagli = '<div class="corpo-problema">'
        . '<p class="testo-problema">' . nl2br(e($descrizione)) . '</p>'
        . '<div class="fatti-problema">'
        . ($r['contact_email'] ? '<span><b>Contatto:</b> ' . e((string) $r['contact_email']) . '</span>' : '')
        . ($r['diagnostics'] ? '<span><b>Dispositivo:</b> ' . e((string) $r['diagnostics']) . '</span>' : '')
        . ($r['handled_by'] ? '<span><b>Gestito da:</b> ' . e(nomeAdmin($conn, (string) $r['handled_by']))
            . ' il ' . e(date('d/m/Y H:i', strtotime((string) $r['handled_at']))) . '</span>' : '')
        . '</div>';

    if ($haStato) {
        $opzioni = '';
        foreach (['open' => 'Aperto', 'resolved' => 'Risolto', 'closed' => 'Chiuso'] as $v => $et) {
            $opzioni .= '<option value="' . $v . '"' . ($v === $r['status'] ? ' selected' : '') . '>' . $et . '</option>';
        }
        $dettagli .= '<form method="post" class="gestisci-problema">' . campoToken()
            . '<input type="hidden" name="id" value="' . $idProblema . '">'
            . '<label><span>Stato</span><select name="stato">' . $opzioni . '</select></label>'
            . '<label class="largo"><span>Risposta per chi ha segnalato</span>'
            . '<textarea name="nota" maxlength="500" rows="2" placeholder="Obbligatoria per chiudere">' . e((string) $r['admin_note']) . '</textarea></label>'
            . '<button class="principale" type="submit">Salva</button>'
            . '</form>';
    }
    $dettagli .= '</div>';

    $voci .= '<details class="problema" id="p' . $idProblema . '"><summary class="riga">'
        . '<span class="taglia" style="font-weight:600">' . e(mb_substr($descrizione, 0, 140)) . '</span>'
        . '<span class="secondario" style="font-size:12.5px">' . e($tipiProblema[$r['kind'] ?? ''] ?? '—') . '</span>'
        . '<span class="secondario taglia" style="font-size:12.5px">' . e((string) ($r['screen'] ?: '—')) . '</span>'
        . '<span class="taglia" style="font-size:12.5px">' . e($nome !== '' ? $nome : 'Anonimo') . '</span>'
        . '<span class="secondario cifre ' . ($r['status'] === 'open' ? classeAttesa((string) $r['created_at']) : '') . '" style="font-size:12.5px">'
        . e(date('d/m/Y', strtotime((string) $r['created_at']))) . '</span>'
        . pastiglia((string) $r['status'])
        . '</summary>' . $dettagli . '</details>';
}
$stmt->close();

$opzioni = static function (array $valori, string $scelto): string {
    $out = '';
    foreach ($valori as $valore => $etichetta) {
        $out .= '<option value="' . e((string) $valore) . '"' . ((string) $valore === $scelto ? ' selected' : '') . '>' . e($etichetta) . '</option>';
    }
    return $out;
};

$filtri = '<form class="filtri" method="get">'
    . campoCerca($cerca, 'testo, persona, schermata, dispositivo')
    . ($haStato ? '<label><span>Stato</span><select name="stato">' . $opzioni($statiProblema, $stato) . '</select></label>' : '')
    . '<label><span>Tipo</span><select name="tipo">' . $opzioni(['' => 'Tutti i tipi'] + $tipiProblema, $tipo) . '</select></label>'
    . sceltaOrdinamento($colonneOrdine, $ordinaPer, $verso)
    . '<button class="principale" type="submit">Filtra</button>'
    . '</form>';

$intestazioni = [
    ['Problema', null], ['Tipo', $haTipo ? 'tipo' : null], ['Schermata', $haTipo ? 'schermata' : null],
    ['Da', 'da'], ['Data', 'data'], ['Stato', $haStato ? 'stato' : null],
];

$html = ($messaggio !== null ? '<div class="' . $tipoMessaggio . '">' . e($messaggio) . '</div>' : '')
    . (!$haStato ? '<div class="avviso">Migrazione del 15/09 non eseguita: si leggono i problemi ma non si possono gestire.</div>' : '')
    . $filtri
    . '<p class="riepilogo">Clic su un problema per leggerlo per intero e cambiarne lo stato.</p>'
    . '<div class="riquadro problemi">'
    . testaOrdinabile($intestazioni, $ordinaPer, $verso)
    . ($voci === '' ? '<div class="vuoto">Nessun problema con questi filtri</div>' : $voci)
    . '</div>';

pagina('Problemi dell\'app', $html, 'problemi.php');
