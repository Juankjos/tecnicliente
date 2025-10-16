<?php
// htdocs/tecnicliente/auth_login.php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/php-error.log');

function fail($code, $msg) {
  http_response_code($code);
  echo json_encode(['ok'=>false,'error'=>$msg], JSON_UNESCAPED_UNICODE);
  exit;
}

$host = "127.0.0.1";
$user = "root";
$pass = "";
$db   = "clientes";

$mysqli = @new mysqli($host, $user, $pass, $db);
if ($mysqli->connect_errno) fail(500, 'Error de conexión');
$mysqli->set_charset('utf8mb4');

// Entrada
$idTec    = isset($_POST['idTec']) ? intval($_POST['idTec']) : 0;
$password = isset($_POST['password']) ? (string)$_POST['password'] : '';

if ($idTec <= 0 || $password === '') fail(400, 'Faltan idTec o password');

$stmt = $mysqli->prepare("SELECT IdTec, PasswordHash, NombreTec, NumTec, Planta FROM tecnicos WHERE IdTec = ?");
if (!$stmt) fail(500, 'Prepare falló');
$stmt->bind_param('i', $idTec);
if (!$stmt->execute()) fail(500, 'Execute falló');
$res = $stmt->get_result();
if (!$res || $res->num_rows === 0) fail(401, 'Técnico no encontrado');

$row = $res->fetch_assoc();
$hash = (string)($row['PasswordHash'] ?? '');

if ($hash === '' || !password_verify($password, $hash)) {
  fail(401, 'Credenciales inválidas');
}

// OK
echo json_encode([
  'ok'      => true,
  'tec'     => [
    'idTec'   => intval($row['IdTec']),
    'nombre'  => (string)$row['NombreTec'],
    'numTec'  => (string)$row['NumTec'],
    'planta'  => (string)$row['Planta'],
  ]
], JSON_UNESCAPED_UNICODE);

$stmt->close();
$mysqli->close();
