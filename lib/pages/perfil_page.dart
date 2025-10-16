import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/session.dart';

class Tecnico {
  final int id;
  final String nombre;
  final String telefono; // ahora String
  final String planta;

  Tecnico({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.planta,
  });

  factory Tecnico.fromJson(Map<String, dynamic> j) => Tecnico(
        id: j['IdTec'] as int,
        nombre: j['NombreTec'] as String,
        telefono: (j['NumTec'] ?? '').toString(),
        planta: (j['Planta'] ?? '').toString(),
      );
}

// Ajusta según tu opción actual (si usas dev-server o sirves por Apache)
const String BASE_URL = "http://localhost/tecnicliente";
// const String BASE_URL = "http://<TU_IP_LOCAL>/tecnicliente";

Future<Tecnico> fetchTecnicoPorId(int id) async {
  final uri = Uri.parse("$BASE_URL/get_tecnico.php?id=$id");
  final res = await http.get(uri);
  if (res.statusCode != 200) {
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }
  final data = json.decode(res.body) as Map<String, dynamic>;
  return Tecnico.fromJson(data);
}

class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: FutureBuilder<Tecnico>(
        future: fetchTecnicoPorId(Session.instance.idTec.value!),
        builder: (context, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError || !s.hasData) {
            return const Center(child: Text('No se pudo cargar el perfil.'));
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
              _ItemDato(icon: Icons.phone, label: 'Teléfono', value: t.telefono),
              _ItemDato(icon: Icons.location_on, label: 'Planta', value: t.planta), // <- NUEVO
              const SizedBox(height: 24),
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
