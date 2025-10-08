<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

$host = "127.0.0.1";
$user = "root";
$pass = "";
$db   = "clientes";

$idTec       = isset($_GET['idTec']) ? intval($_GET['idTec']) : null;
$idContrato  = isset($_GET['idContrato']) ? $_GET['idContrato'] : null;

if ($idTec === null && $idContrato === null) {
  http_response_code(400);
  echo json_encode(["error" => "Falta idTec o idContrato"]);
  exit;
}

$mysqli = new mysqli($host, $user, $pass, $db);
if ($mysqli->connect_errno) {
  http_response_code(500);
  echo json_encode(["error" => "Error de conexión"]);
  exit;
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
    p.IDReporte       AS id,
    p.IDContrato      AS contrato,
    u.Nombre          AS cliente,
    u.Direccion       AS direccion,
    COALESCE(r.Problema, '') AS orden,
    p.Status          AS estatus,
    p.FechaInicio     AS fecha_inicio,
    p.FechaFin        AS fecha_fin
  FROM produccion p
  JOIN usuarios  u ON u.IDContrato = p.IDContrato
  LEFT JOIN reportes r ON r.IDReporte = p.IDReporte
  /** filtro **/
  /** order **/
";
if ($idContrato !== null) {
  $sql = str_replace('/** filtro **/', "WHERE p.IDContrato = ?", $sql);
} else {
  $sql = str_replace('/** filtro **/', "WHERE p.IDTec = ?", $sql);
}
$sql = str_replace('/** order **/', "ORDER BY (p.Status='En camino') DESC, (p.Status='Completado') DESC, p.IDReporte DESC", $sql);

$stmt = $mysqli->prepare($sql);
if ($idContrato !== null) {
  $stmt->bind_param("s", $idContrato);
} else {
  $stmt->bind_param("i", $idTec);
}
$stmt->execute();
$res = $stmt->get_result();

$out = [];
while ($row = $res->fetch_assoc()) {
  $out[] = [
    "id"        => (int)$row["id"],
    "cliente"   => $row["cliente"],
    "contrato"  => $row["contrato"],
    "direccion" => limpiar_direccion($row["direccion"]),
    "orden"     => $row["orden"],
    "estatus"   => $row["estatus"],     // 'En camino' | 'Completado' | 'Cancelado'
    "inicio"    => $row["fecha_inicio"],// ISO o null
    "fin"       => $row["fecha_fin"],   // ISO o null
  ];
}

echo json_encode($out, JSON_UNESCAPED_UNICODE);

$stmt->close();
$mysqli->close();
