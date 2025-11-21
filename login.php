<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

$host = "167.99.163.209";
$user = "root";
$pass = "";
$db   = "clientes";

$mysqli = @new mysqli($host, $user, $pass, $db);
if ($mysqli->connect_errno) {
  http_response_code(500);
  echo json_encode(['ok'=>false,'error'=>'Error de conexión']); exit;
}
$mysqli->set_charset('utf8mb4');

$idTec    = isset($_POST['idTec']) ? intval($_POST['idTec']) : 0;
$password = isset($_POST['password']) ? $_POST['password'] : '';

if ($idTec <= 0 || $password === '') {
  http_response_code(400);
  echo json_encode(['ok'=>false,'error'=>'Faltan credenciales']); exit;
}

// Tabla ejemplo: tecnicos(IDTec INT PK, Nombre VARCHAR(100), PassHash VARCHAR(255))
$stmt = $mysqli->prepare("SELECT Nombre, PassHash FROM tecnicos WHERE IDTec = ?");
$stmt->bind_param('i', $idTec);
$stmt->execute();
$res = $stmt->get_result();
if (!$res || $res->num_rows === 0) {
  echo json_encode(['ok'=>false,'error'=>'IDTec no encontrado']); exit;
}
$row = $res->fetch_assoc();
$hash = $row['PassHash'];

if (!password_verify($password, $hash)) {
  echo json_encode(['ok'=>false,'error'=>'Contraseña inválida']); exit;
}

echo json_encode(['ok'=>true, 'idTec'=>$idTec, 'nombre'=>$row['Nombre']], JSON_UNESCAPED_UNICODE);
