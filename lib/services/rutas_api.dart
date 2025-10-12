// lib/services/rutas_api.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/ruta.dart';

typedef BuildUri = Uri Function(String pathWithQuery);

class RutasApi {
  final BuildUri _buildUri;
  const RutasApi(this._buildUri);

  // ---------- Helpers de logging ----------
  void _log(String msg) {
    // Usa debug console en Flutter / DevTools
    // ignore: avoid_print
    print('[RutasApi] $msg');
  }

  String _sample(String s, [int n = 400]) {
    if (s.length <= n) return s;
    return s.substring(0, n) + '...<truncated>';
  }

  // ---------- Lecturas ----------
  Future<List<Ruta>> fetchPorContrato(String idContrato) async {
    final uri = _buildUri('get_rutas.php?idContrato=$idContrato');
    return _getLista(uri);
  }

  Future<List<Ruta>> fetchPorTecnico(int idTec) async {
    final uri = _buildUri('get_rutas.php?idTec=$idTec');
    return _getLista(uri);
  }

  Future<List<Ruta>> _getLista(Uri uri) async {
    _log('GET $uri');
    http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 15));
    } on SocketException catch (e) {
      _log('SocketException: $e');
      rethrow;
    } on HttpException catch (e) {
      _log('HttpException: $e');
      rethrow;
    } on FormatException catch (e) {
      _log('FormatException (antes de decode): $e');
      rethrow;
    } on Exception catch (e) {
      _log('Generic Exception: $e');
      rethrow;
    }

    _log('status=${res.statusCode}');
    _log('headers=${res.headers}');
    _log('body-sample=${_sample(res.body)}');

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${_sample(res.body)}');
    }

    final body = res.body.trimLeft();

    // Si viene HTML (típico de error PHP), lo señalamos pronto
    if (body.startsWith('<')) {
      throw FormatException('Respuesta no-JSON (HTML detectado): ${_sample(body)}');
    }

    dynamic decoded;
    try {
      decoded = json.decode(body);
    } on FormatException catch (e) {
      _log('JSON decode error: $e');
      _log('JSON body raw sample: ${_sample(body)}');
      rethrow;
    }

    if (decoded is! List) {
      throw FormatException('Se esperaba arreglo JSON, pero llegó: ${decoded.runtimeType}');
    }

    return decoded
        .map<Ruta>((e) => Ruta.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ---------- Escrituras (estatus) ----------
  Future<void> cambiarEstatus({
    required int idReporte,
    required String status,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? comentario,
    int? rate,
  }) async {
    String? _fmt(DateTime? dt) =>
        dt == null ? null : dt.toIso8601String().substring(0, 19).replaceAll('T', ' ');
    
    final uri = _buildUri('update_status.php');

    final body = {
      'idReporte': '$idReporte',
      'status': status,
      if (fechaInicio != null) 'fechaInicio': _fmt(fechaInicio)!,
      if (fechaFin != null) 'fechaFin': _fmt(fechaFin)!,
      if (comentario != null) 'comentario': comentario,
      if (rate != null) 'rate': '$rate',
    };

    _log('POST $uri body=$body');

    http.Response res;
    try {
      res = await http.post(uri, body: body).timeout(const Duration(seconds: 15));
    } on Exception catch (e) {
      _log('POST exception: $e');
      rethrow;
    }

    _log('POST status=${res.statusCode}');
    _log('POST headers=${res.headers}');
    _log('POST body-sample=${_sample(res.body)}');

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${_sample(res.body)}');
    }

    // Si tu PHP devuelve {"ok":true}
    try {
      final m = json.decode(res.body) as Map<String, dynamic>;
      if (m['ok'] != true) {
        throw Exception('Backend respondió error: ${m['error'] ?? 'desconocido'}');
      }
    } catch (_) {
      // Si no devuelves JSON, puedes comentar esta validación.
      _log('POST no devolvió JSON válido; se continua sin validar.');
    }
  }
}
