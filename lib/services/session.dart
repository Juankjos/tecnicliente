import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// Ajusta igual que en el resto de la app
const String _BASE_WEB = "http://localhost/tecnicliente";
const String _BASE_EMU = "http://10.0.2.2/tecnicliente";
Uri _apiUri(String path) {
  final base = kIsWeb ? _BASE_WEB : _BASE_EMU;
  return Uri.parse('$base/$path');
}

class Session {
  Session._();
  static final instance = Session._();

  final ValueNotifier<int?> idTec = ValueNotifier<int?>(null);
  final ValueNotifier<String?> nombre = ValueNotifier<String?>(null);
  final ValueNotifier<String?> numTec = ValueNotifier<String?>(null);
  final ValueNotifier<String?> planta = ValueNotifier<String?>(null);

  bool get isLoggedIn => idTec.value != null;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    idTec.value   = sp.getInt('idTec');
    nombre.value  = sp.getString('nombre');
    numTec.value  = sp.getString('numTec');
    planta.value  = sp.getString('planta');
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    if (idTec.value != null) {
      await sp.setInt('idTec', idTec.value!);
      await sp.setString('nombre', nombre.value ?? '');
      await sp.setString('numTec', numTec.value ?? '');
      await sp.setString('planta', planta.value ?? '');
    } else {
      await sp.remove('idTec');
      await sp.remove('nombre');
      await sp.remove('numTec');
      await sp.remove('planta');
    }
  }

  Future<void> logout() async {
    idTec.value = null;
    nombre.value = null;
    numTec.value = null;
    planta.value = null;
    await _save();
  }

  Future<void> login({required int idTec, required String password}) async {
    final uri = _apiUri('auth_login.php');
    final res = await http
        .post(uri, body: {'idTec': '$idTec', 'password': password})
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final m = json.decode(res.body) as Map<String, dynamic>;
    if (m['ok'] != true) {
      throw Exception(m['error'] ?? 'Login inválido');
    }
    final tec = m['tec'] as Map<String, dynamic>;
    this.idTec.value = tec['idTec'] as int;
    nombre.value     = (tec['nombre'] ?? '').toString();
    numTec.value     = (tec['numTec'] ?? '').toString();
    planta.value     = (tec['planta'] ?? '').toString();
    await _save();
  }
}
