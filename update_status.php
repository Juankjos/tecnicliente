<?php
// htdocs/tecnicliente/update_status.php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

// Preflight CORS
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

// Leer POST
$idReporte     = isset($_POST['idReporte'])   ? intval($_POST['idReporte']) : 0;
$statusNuevo   = isset($_POST['status'])      ? trim($_POST['status'])      : '';
$fechaInicioReq= isset($_POST['fechaInicio']) ? trim($_POST['fechaInicio']) : null;
$fechaFin      = isset($_POST['fechaFin'])    ? trim($_POST['fechaFin'])    : null;
$comentario    = isset($_POST['comentario'])  ? trim($_POST['comentario'])  : null;
$rate          = isset($_POST['rate'])        ? intval($_POST['rate'])      : null;

if ($idReporte <= 0 || $statusNuevo === '') {
    fail(400, 'Faltan parámetros: idReporte y status');
}

// ⭐ Normaliza el status para comparar sin problemas de mayúsculas/acentos
$norm = mb_strtolower($statusNuevo, 'UTF-8');

// 1) Leer estado actual y FechaInicio
$cur = $mysqli->prepare("SELECT Status, FechaInicio FROM produccion WHERE IDReporte = ?");
if (!$cur) fail(500, 'Prepare (SELECT) falló', $mysqli->error);
$cur->bind_param('i', $idReporte);
if (!$cur->execute()) fail(500, 'Execute (SELECT) falló', $cur->error);
$res = $cur->get_result();
if (!$res || $res->num_rows === 0) fail(404, 'IDReporte no encontrado');
$row = $res->fetch_assoc();
$curStatus = (string)($row['Status'] ?? '');
$curInicio = $row['FechaInicio']; // puede ser null
$cur->close();

// ⭐ Idempotencia: si ya quedó Completado, no tocar (evitas pisar cierres)
if (mb_strtolower($curStatus, 'UTF-8') === 'completado') {
    echo json_encode(['ok' => true, 'skipped' => 'already_completed'], JSON_UNESCAPED_UNICODE);
    exit;
}

// 2) Construir UPDATE
$sets   = ['Status = ?'];   // siempre actualizamos Status
$params = [$statusNuevo];
$types  = 's';

// Lógica de FechaInicio solo al pasar a “En camino” por primera vez
if ($norm === 'en camino') {
    $yaEnCamino   = (mb_strtolower($curStatus, 'UTF-8') === 'en camino');
    $inicioVacio  = ($curInicio === null || $curInicio === '');
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

// ⭐ Si el nuevo estado es Cancelado o Completado, asegura FechaFin
if ($norm === 'cancelado' || $norm === 'completado') {
    if ($fechaFin !== null && $fechaFin !== '') {
        $sets[]   = 'FechaFin = ?';
        $params[] = $fechaFin;
        $types   .= 's';
    } else {
        $sets[] = 'FechaFin = NOW()';
    }
}

// Otros campos opcionales
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

// ⭐ Opcional: evita cambiar si ya está Completado (ya hicimos early-return arriba).
//    Si quisieras reforzarlo en SQL: añade "AND Status <> 'Completado'" al WHERE.
$params[] = $idReporte;
$types   .= 'i';

$sql = "UPDATE produccion SET " . implode(', ', $sets) . " WHERE IDReporte = ?";

$stmt = $mysqli->prepare($sql);
if (!$stmt) fail(500, 'Prepare (UPDATE) falló', $mysqli->error);
if (!$stmt->bind_param($types, ...$params)) fail(500, 'bind_param falló', $stmt->error);
if (!$stmt->execute()) fail(500, 'Execute (UPDATE) falló', $stmt->error);

echo json_encode(['ok' => true, 'rows' => $stmt->affected_rows], JSON_UNESCAPED_UNICODE);

$stmt->close();
$mysqli->close();
