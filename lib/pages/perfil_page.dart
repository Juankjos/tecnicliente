import 'dart:convert';
// import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/session.dart';

class Tecnico {
  final int id;
  final String nombre;
  final String telefono;
  final String planta;

  Tecnico({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.planta,
  });

  factory Tecnico.fromJson(Map<String, dynamic> j) => Tecnico(
        id: (j['IdTec'] ?? j['id'] ?? j['idtec']) is String
            ? int.tryParse(j['IdTec'] ?? j['id'] ?? j['idtec']) ?? 0
            : (j['IdTec'] ?? j['id'] ?? j['idtec'] ?? 0) as int,
        nombre: (j['NombreTec'] ?? j['nombre'] ?? '').toString(),
        telefono: (j['NumTec'] ?? j['telefono'] ?? '').toString(),
        planta: (j['Planta'] ?? j['planta'] ?? '').toString(),
      );
}

// ---- Ajusta tu base como en el resto de pantallas
// const String _BASE_WEB = "http://localhost/tecnicliente";
// const String _BASE_EMU = "http://127.0.0.1/tecnicliente";
const String _BASE_DEV_ADB = "http://127.0.0.1:8080/tecnicliente";
Uri _apiUri(String pathWithQuery) {
  // final base = kIsWeb ? _BASE_WEB : _BASE_EMU;
  // return Uri.parse('$base/$pathWithQuery');
  return Uri.parse('$_BASE_DEV_ADB/$pathWithQuery');
}

Future<Tecnico> _fetchTecnicoActual() async {
  final id = Session.instance.idTec.value;
  if (id == null) {
    throw StateError('No hay sesión activa (idTec=null). Inicia sesión de nuevo.');
  }

  final uri = _apiUri('get_tecnico.php?id=$id');
  // ignore: avoid_print
  print('[Perfil] GET $uri');

  final res = await http.get(uri).timeout(const Duration(seconds: 12));

  // ignore: avoid_print
  print('[Perfil] status=${res.statusCode}');
  // ignore: avoid_print
  // print('[Perfil] body=${res.body.length > 300 ? res.body.substring(0, 300) + "...<trunc>" : res.body}');

  if (res.statusCode != 200) {
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }

  final body = res.body.trim();
  if (body.isEmpty || body.startsWith('<')) {
    throw FormatException('Respuesta no JSON (vacía o HTML): $body');
  }

  final decoded = json.decode(body);

  // Soporta: { ... }  ó  [ { ... } ]
  if (decoded is Map<String, dynamic>) {
    return Tecnico.fromJson(decoded);
  } else if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
    return Tecnico.fromJson((decoded.first as Map).cast<String, dynamic>());
  } else {
    throw FormatException('Formato JSON inesperado: ${decoded.runtimeType}');
  }
}

class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: FutureBuilder<Tecnico>(
        future: _fetchTecnicoActual(),
        builder: (context, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No se pudo cargar el perfil.\n\n${s.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!s.hasData) {
            return const Center(child: Text('Perfil no disponible.'));
          }

          final t = s.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48)),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  t.nombre,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              _ItemDato(icon: Icons.badge, label: 'ID Técnico', value: '${t.id}'),
              _ItemDato(icon: Icons.phone, label: 'Teléfono', value: t.telefono.isEmpty ? '—' : t.telefono),
              _ItemDato(icon: Icons.factory, label: 'Planta', value: t.planta.isEmpty ? '—' : t.planta),
            ],
          );
        },
      ),
    );
  }
}

class _ItemDato extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ItemDato({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}
