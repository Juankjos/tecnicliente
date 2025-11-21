<?php
// htdocs/tecnicliente/get_rutas.php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

// Evita que PHP imprima HTML de errores (que rompe el JSON)
error_reporting(E_ALL);
ini_set('display_errors', 0);

function json_fail(int $code, string $msg, string $detail = null) {
  http_response_code($code);
  $out = ['ok' => false, 'error' => $msg];
  if ($detail !== null) $out['detail'] = $detail;
  echo json_encode($out, JSON_UNESCAPED_UNICODE);
  exit;
}

$host = "167.99.163.209";
$user = "root";
$pass = "";
$db   = "clientes";

$idTec      = isset($_GET['idTec']) ? intval($_GET['idTec']) : null;
$idContrato = isset($_GET['idContrato']) ? trim($_GET['idContrato']) : null;

if ($idTec === null && ($idContrato === null || $idContrato === '')) {
  json_fail(400, 'Falta idTec o idContrato');
}

$mysqli = @new mysqli($host, $user, $pass, $db);
if ($mysqli->connect_errno) {
  json_fail(500, 'Error de conexión', $mysqli->connect_error);
}
$mysqli->set_charset('utf8mb4');

// Normaliza dirección: quita etiquetas "Colonia"/"Ciudad" y colapsa duplicados
function limpiar_direccion($dirRaw) {
  $dir = trim(preg_replace('/\s+/', ' ', (string)$dirRaw));

  // Caso específico: "... Colonia X Ciudad X" -> "... X"
  if (preg_match('/^(.*)\s+Colonia\s+(.+)\s+Ciudad\s+(.+)$/iu', $dir, $m)) {
    $pre = trim($m[1]); $col = trim($m[2]); $ciu = trim($m[3]);
    if (mb_strtolower($col,'UTF-8') === mb_strtolower($ciu,'UTF-8')) {
      return trim($pre . ' ' . $ciu);
    }
  }

  // Limpieza genérica
  $dir = preg_replace('/\b(Colonia|Col\.?|Ciudad|Cd\.?)\b\s*/iu', '', $dir);
  $dir = trim(preg_replace('/\s+/', ' ', $dir));
  return $dir;
}

$sql = "
  SELECT
    p.IDReporte             AS IDReporte,
    p.IDContrato            AS IDContrato,
    u.Nombre                AS Nombre,
    u.Direccion             AS Direccion,
    COALESCE(r.Problema, '') AS Problema,
    p.Status                AS Status,
    p.FechaInicio           AS FechaInicio,
    p.FechaFin              AS FechaFin
  FROM produccion p
  JOIN usuarios  u ON u.IDContrato = p.IDContrato
  LEFT JOIN reportes r ON r.IDReporte = p.IDReporte
  /** filtro **/
  ORDER BY (p.Status='En camino') DESC, (p.Status='Completado') DESC, p.IDReporte DESC
";

if ($idContrato !== null && $idContrato !== '') {
  $sql = str_replace('/** filtro **/', "WHERE p.IDContrato = ?", $sql);
  $types = "s"; $params = [$idContrato];
} else {
  $sql = str_replace('/** filtro **/', "WHERE p.IDTec = ?", $sql);
  $types = "i"; $params = [$idTec];
}

$stmt = $mysqli->prepare($sql);
if (!$stmt) {
  json_fail(500, 'Prepare falló', $mysqli->error);
}
if (!$stmt->bind_param($types, ...$params)) {
  json_fail(500, 'bind_param falló', $stmt->error);
}
if (!$stmt->execute()) {
  json_fail(500, 'Execute falló', $stmt->error);
}
$res = $stmt->get_result();
if (!$res) {
  json_fail(500, 'get_result falló', $stmt->error);
}

$out = [];
while ($row = $res->fetch_assoc()) {
  $out[] = [
    // Claves que tu app espera (y tu Ruta.fromMap admite flexible)
    "IDReporte"   => (int)$row["IDReporte"],
    "cliente"     => $row["Nombre"]     ?? '',
    "contrato"    => $row["IDContrato"] ?? '',
    "direccion"   => limpiar_direccion($row["Direccion"] ?? ''),
    "orden"       => $row["Problema"]   ?? '',
    "status"      => $row["Status"]     ?? '',
    "FechaInicio" => $row["FechaInicio"],
    "FechaFin"    => $row["FechaFin"],
  ];
}

echo json_encode($out, JSON_UNESCAPED_UNICODE);

$stmt->close();
$mysqli->close();
