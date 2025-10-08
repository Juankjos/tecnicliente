import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ruta.dart';

typedef BuildUri = Uri Function(String pathWithQuery);

class RutasApi {
  final BuildUri _buildUri;
  const RutasApi(this._buildUri);

  Future<List<Ruta>> fetchPorContrato(String idContrato) async {
    final uri = _buildUri('get_rutas.php?idContrato=$idContrato');
    return _getLista(uri);
  }

  Future<List<Ruta>> fetchPorTecnico(int idTec) async {
    final uri = _buildUri('get_rutas.php?idTec=$idTec');
    return _getLista(uri);
  }

  Future<List<Ruta>> _getLista(Uri uri) async {
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = json.decode(res.body) as List<dynamic>;
    return data.map((e) => Ruta.fromMap(e as Map<String, dynamic>)).toList();
    }
}
