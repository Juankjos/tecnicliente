import 'dart:convert';
import 'package:http/http.dart' as http;

typedef BuildUri = Uri Function(String pathWithQuery);

class AuthApi {
  final BuildUri _buildUri;
  const AuthApi(this._buildUri);

  Future<(int idTec, String? nombre)> login({
    required int idTec,
    required String password,
  }) async {
    final uri = _buildUri('login.php');
    final res = await http.post(uri, body: {
      'idTec': '$idTec',
      'password': password,
    }).timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final m = json.decode(res.body) as Map<String, dynamic>;
    if (m['ok'] != true) {
      throw Exception(m['error'] ?? 'Credenciales inválidas');
    }
    final nombre = (m['nombre'] as String?) ?? '';
    final id = (m['idTec'] as num).toInt();
    return (id, nombre.isEmpty ? null : nombre);
  }
}
