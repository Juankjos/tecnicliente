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

// ---- Leer POST ----
$idReporte      = isset($_POST['idReporte'])   ? intval($_POST['idReporte']) : 0;
$statusNuevo    = isset($_POST['status'])      ? trim($_POST['status'])      : '';
$fechaInicioReq = isset($_POST['fechaInicio']) ? trim($_POST['fechaInicio']) : null;
$fechaFin       = isset($_POST['fechaFin'])    ? trim($_POST['fechaFin'])    : null;
// OJO: 'comentario' SOLO se usará para tabla cancelados (Motivo), no para produccion.Comentario
$motivoCancel   = isset($_POST['comentario'])  ? trim($_POST['comentario'])  : null;
$rate           = isset($_POST['rate'])        ? intval($_POST['rate'])      : null;

if ($idReporte <= 0 || $statusNuevo === '') {
    fail(400, 'Faltan parámetros: idReporte y status');
}

$norm = mb_strtolower($statusNuevo, 'UTF-8');

// ---- Estado actual ----
$cur = $mysqli->prepare("SELECT Status, FechaInicio FROM produccion WHERE IDReporte = ?");
if (!$cur) fail(500, 'Prepare (SELECT) falló', $mysqli->error);
$cur->bind_param('i', $idReporte);
if (!$cur->execute()) fail(500, 'Execute (SELECT) falló', $cur->error);
$res = $cur->get_result();
if (!$res || $res->num_rows === 0) fail(404, 'IDReporte no encontrado');
$row = $res->fetch_assoc();
$curStatus = (string)($row['Status'] ?? '');
$curInicio = $row['FechaInicio'];
$cur->close();

// Si ya está Completado, no tocar
if (mb_strtolower($curStatus, 'UTF-8') === 'completado') {
    echo json_encode(['ok' => true, 'skipped' => 'already_completed'], JSON_UNESCAPED_UNICODE);
    exit;
}

// ---- Construir UPDATE produccion (sin escribir Comentario aquí) ----
$sets   = ['Status = ?'];
$params = [$statusNuevo];
$types  = 's';

// FechaInicio sólo la primera vez que pasa a En camino
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

// Si Cancelado/Completado, asegura FechaFin
if ($norm === 'cancelado' || $norm === 'completado') {
    if ($fechaFin !== null && $fechaFin !== '') {
        $sets[]   = 'FechaFin = ?';
        $params[] = $fechaFin;
        $types   .= 's';
    } else {
        $sets[] = 'FechaFin = NOW()';
    }
}

// (Opcional) Rate sí puede ir a produccion si lo usas allí
if ($rate !== null) {
    $sets[]   = 'Rate = ?';
    $params[] = $rate;
    $types   .= 'i';
}

$params[] = $idReporte;
$types   .= 'i';

$sql = "UPDATE produccion SET " . implode(', ', $sets) . " WHERE IDReporte = ?";
$stmt = $mysqli->prepare($sql);
if (!$stmt) fail(500, 'Prepare (UPDATE) falló', $mysqli->error);
if (!$stmt->bind_param($types, ...$params)) fail(500, 'bind_param falló', $stmt->error);
if (!$stmt->execute()) fail(500, 'Execute (UPDATE) falló', $stmt->error);

// ---- Registro histórico solo cuando se cancela ----
if ($norm === 'cancelado') {
    // Si no viene motivo, pon uno por defecto
    $motivo = ($motivoCancel !== null && $motivoCancel !== '') ? $motivoCancel : 'Cancelado sin motivo';

    // IMPORTANTE: IDProd es FK a produccion.IDProd; aquí sólo tenemos IDReporte.
    // Insertamos buscando el IDProd por IDReporte para respetar la FK.
    $q = $mysqli->prepare("SELECT IDProd FROM produccion WHERE IDReporte = ?");
    if (!$q) fail(500, 'Prepare (SELECT IDProd) falló', $mysqli->error);
    $q->bind_param('i', $idReporte);
    if (!$q->execute()) fail(500, 'Execute (SELECT IDProd) falló', $q->error);
    $res2 = $q->get_result();
    $idProd = null;
    if ($res2 && $res2->num_rows > 0) {
        $idProd = (int)$res2->fetch_assoc()['IDProd'];
    }
    $q->close();

    if ($idProd === null) {
        fail(500, 'No se pudo resolver IDProd para insertar en cancelados');
    }

    $ins = $mysqli->prepare("INSERT INTO cancelados (IDProd, Motivo) VALUES (?, ?)");
    if (!$ins) fail(500, 'Prepare (INSERT cancelados) falló', $mysqli->error);
    if (!$ins->bind_param('is', $idProd, $motivo)) fail(500, 'bind_param (cancelados) falló', $ins->error);
    if (!$ins->execute()) fail(500, 'Execute (INSERT cancelados) falló', $ins->error);
    $ins->close();
}

echo json_encode(['ok' => true, 'rows' => $stmt->affected_rows], JSON_UNESCAPED_UNICODE);

$stmt->close();
$mysqli->close();
