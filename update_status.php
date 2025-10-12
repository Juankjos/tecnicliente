<?php
// htdocs/tecnicliente/update_status.php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

// Manejo de preflight CORS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
  http_response_code(204);
  exit;
}

// No imprimir HTML de errores (rompe el JSON)
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
if ($mysqli->connect_errno) {
  fail(500, 'Error de conexión', $mysqli->connect_error);
}
$mysqli->set_charset('utf8mb4');

// Lee POST
$idReporte   = isset($_POST['idReporte']) ? intval($_POST['idReporte']) : 0;
$status      = isset($_POST['status']) ? trim($_POST['status']) : '';
$fechaInicio = isset($_POST['fechaInicio']) ? trim($_POST['fechaInicio']) : null;
$fechaFin    = isset($_POST['fechaFin']) ? trim($_POST['fechaFin']) : null;
$comentario  = isset($_POST['comentario']) ? trim($_POST['comentario']) : null;
$rate        = isset($_POST['rate']) ? intval($_POST['rate']) : null;

if ($idReporte <= 0 || $status === '') {
  fail(400, 'Faltan parámetros: idReporte y status son requeridos');
}

// Construye UPDATE dinámico
$sets = ['Status = ?'];
$params = [$status];
$types  = 's';

if ($fechaInicio !== null && $fechaInicio !== '') {
  $sets[] = 'FechaInicio = ?';
  $params[] = $fechaInicio; $types .= 's';
}
if ($fechaFin !== null && $fechaFin !== '') {
  $sets[] = 'FechaFin = ?';
  $params[] = $fechaFin; $types .= 's';
}
if ($comentario !== null) {
  $sets[] = 'Comentario = ?';
  $params[] = $comentario; $types .= 's';
}
if ($rate !== null) {
  $sets[] = 'Rate = ?';
  $params[] = $rate; $types .= 'i';
}

$params[] = $idReporte; $types .= 'i';
$sql = "UPDATE produccion SET " . implode(', ', $sets) . " WHERE IDReporte = ?";

$stmt = $mysqli->prepare($sql);
if (!$stmt) fail(500, 'Prepare falló', $mysqli->error);

if (!$stmt->bind_param($types, ...$params)) fail(500, 'bind_param falló', $stmt->error);
if (!$stmt->execute()) fail(500, 'Execute falló', $stmt->error);

echo json_encode(['ok' => true, 'rows' => $stmt->affected_rows], JSON_UNESCAPED_UNICODE);

$stmt->close();
$mysqli->close();
