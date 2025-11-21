<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

$host = "167.99.163.209";
$user = "root";
$pass = ""; // o el que uses en XAMPP
$db   = "clientes";

$id = isset($_GET['id']) ? intval($_GET['id']) : 0;
if ($id <= 0) {
  http_response_code(400);
  echo json_encode(["error" => "ID inválido"]);
  exit;
}

$mysqli = new mysqli($host, $user, $pass, $db);
if ($mysqli->connect_errno) {
  http_response_code(500);
  echo json_encode(["error" => "Error de conexión"]);
  exit;
}

$stmt = $mysqli->prepare("SELECT IdTec, NombreTec, NumTec, Planta FROM tecnicos WHERE IdTec = ?");
$stmt->bind_param("i", $id);
$stmt->execute();
$result = $stmt->get_result();

if ($row = $result->fetch_assoc()) {
  echo json_encode([
    "IdTec" => (int)$row["IdTec"],
    "NombreTec" => $row["NombreTec"],
    "NumTec" => $row["NumTec"],
    "Planta"     => $row["Planta"],
  ], JSON_UNESCAPED_UNICODE);
} else {
  http_response_code(404);
  echo json_encode(["error" => "No encontrado"]);
}

$stmt->close();
$mysqli->close();
