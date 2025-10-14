<?php
// htdocs/tecnicliente/update_status.php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/php-error.log');

function fail($code, $msg, $detail=null) {
    http_response_code($code);
    $out = ['ok' => false, 'error' => $msg];
    if ($detail) $out['detail'] = $detail;
    echo json_encode($out, JSON_UNESCAPED_UNICODE);
    exit;
}

$host = "127.0.0.1";
$user = "root";
$pass = "";
$db   = "clientes";

$mysqli = @new mysqli($host, $user, $pass, $db);
if ($mysqli->connect_errno) fail(500, 'Error de conexión', $mysqli->connect_error);
$mysqli->set_charset('utf8mb4');

// --- Leer POST ---
$idReporte      = isset($_POST['idReporte'])   ? intval($_POST['idReporte']) : 0;
$statusNuevo    = isset($_POST['status'])      ? trim($_POST['status'])      : '';
$fechaInicioReq = isset($_POST['fechaInicio']) ? trim($_POST['fechaInicio']) : null;
$fechaFin       = isset($_POST['fechaFin'])    ? trim($_POST['fechaFin'])    : null;
$comentario     = isset($_POST['comentario'])  ? trim($_POST['comentario'])  : null;
$rate           = isset($_POST['rate'])        ? intval($_POST['rate'])      : null;

if ($idReporte <= 0 || $statusNuevo === '') {
    fail(400, 'Faltan parámetros: idReporte y status');
}

$norm = mb_strtolower($statusNuevo, 'UTF-8');

// 1) Lee estado actual + FechaInicio + IDProd
$cur = $mysqli->prepare("SELECT IDProd, Status, FechaInicio FROM produccion WHERE IDReporte = ?");
if (!$cur) fail(500, 'Prepare (SELECT) falló', $mysqli->error);
$cur->bind_param('i', $idReporte);
if (!$cur->execute()) fail(500, 'Execute (SELECT) falló', $cur->error);
$res = $cur->get_result();
if (!$res || $res->num_rows === 0) fail(404, 'IDReporte no encontrado en produccion');
$row = $res->fetch_assoc();
$idProd    = (int)$row['IDProd'];
$curStatus = (string)($row['Status'] ?? '');
$curInicio = $row['FechaInicio']; // puede ser null
$cur->close();

// Idempotencia: si ya está Completado, no toques
if (mb_strtolower($curStatus, 'UTF-8') === 'completado') {
    echo json_encode(['ok' => true, 'skipped' => 'already_completed'], JSON_UNESCAPED_UNICODE);
    exit;
}

// 2) Transacción
$mysqli->begin_transaction();

try {
    // 2.a Construye UPDATE
    $sets   = ['Status = ?'];
    $params = [$statusNuevo];
    $types  = 's';

    // FechaInicio al primer paso a "En camino"
    if ($norm === 'en camino') {
        $yaEnCamino  = (mb_strtolower($curStatus, 'UTF-8') === 'en camino');
        $inicioVacio = ($curInicio === null || $curInicio === '');
        if (!$yaEnCamino && $inicioVacio) {
            if ($fechaInicioReq !== null && $fechaInicioReq !== '') {
                $sets[]   = 'FechaInicio = ?';
                $params[] = $fechaInicioReq;
                $types   .= 's';
            } else {
                $sets[] = 'FechaInicio = NOW()';
            }
        }
    }

    // FechaFin si Cancelado/Completado
    if ($norm === 'cancelado' || $norm === 'completado') {
        if ($fechaFin !== null && $fechaFin !== '') {
            $sets[]   = 'FechaFin = ?';
            $params[] = $fechaFin;
            $types   .= 's';
        } else {
            $sets[] = 'FechaFin = NOW()';
        }
    }

    // Opcionales
    if ($comentario !== null && $comentario !== '') {
        $sets[]   = 'Comentario = ?';
        $params[] = $comentario;
        $types   .= 's';
    }
    if ($rate !== null) {
        $sets[]   = 'Rate = ?';
        $params[] = $rate;
        $types   .= 'i';
    }

    $params[] = $idReporte;
    $types   .= 'i';

    $sql = "UPDATE produccion SET " . implode(', ', $sets) . " WHERE IDReporte = ?";

    $stmt = $mysqli->prepare($sql);
    if (!$stmt) throw new Exception('Prepare (UPDATE) falló: ' . $mysqli->error);
    if (!$stmt->bind_param($types, ...$params)) throw new Exception('bind_param (UPDATE) falló: ' . $stmt->error);
    if (!$stmt->execute()) throw new Exception('Execute (UPDATE) falló: ' . $stmt->error);

    // 2.b Si Cancelado => inserta en cancelados con IDProd (FK correcta)
    $canceladosInserted = 0;
    if ($norm === 'cancelado') {
        $motivo = ($comentario !== null && $comentario !== '') ? $comentario : 'Cancelado sin motivo';
        $ins = $mysqli->prepare("INSERT INTO cancelados (IDProd, Motivo) VALUES (?, ?)");
        if (!$ins) throw new Exception('Prepare (INSERT cancelados) falló: ' . $mysqli->error);
        if (!$ins->bind_param('is', $idProd, $motivo)) throw new Exception('bind_param (cancelados) falló: ' . $ins->error);
        if (!$ins->execute()) throw new Exception('Execute (INSERT cancelados) falló: ' . $ins->error);
        $canceladosInserted = $ins->affected_rows;
        $ins->close();
    }

    $mysqli->commit();

    echo json_encode([
        'ok' => true,
        'rows_updated' => $stmt->affected_rows,
        'cancelados' => [
            'attempted' => ($norm === 'cancelado'),
            'inserted'  => ($canceladosInserted > 0),
            'rows'      => $canceladosInserted,
            'idProd'    => $idProd
        ]
    ], JSON_UNESCAPED_UNICODE);

    $stmt->close();

} catch (Throwable $ex) {
    $mysqli->rollback();
    fail(500, 'Transacción falló', $ex->getMessage());
}

$mysqli->close();
