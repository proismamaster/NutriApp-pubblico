<?php
/**
 * logout.php — chiude la sessione di QUESTO dispositivo.
 *
 * L'uscita dall'app cancellava solo l'email salvata sul telefono: il gettone
 * restava valido sul server (test di release 19/09). Qui la riga sparisce, e
 * le sessioni degli altri dispositivi restano aperte.
 */

declare(strict_types=1);
require 'db_config.php';
require_once 'auth.php';

header('Content-Type: application/json; charset=utf-8');

chiudiSessione($conn);
echo json_encode(['status' => 'success', 'message' => 'Sessione chiusa.']);
$conn->close();
