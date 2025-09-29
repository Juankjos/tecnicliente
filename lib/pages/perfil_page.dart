import 'package:flutter/material.dart';

class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(
            radius: 48,
            child: Icon(Icons.person, size: 48),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Alfonso Enriquez Juarez',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 24),
          const _ItemDato(icon: Icons.email, label: 'Correo', value: 'Sin Correo'),
          const _ItemDato(icon: Icons.phone, label: 'Teléfono', value: '+52 378 711 4606'),
          const _ItemDato(icon: Icons.location_on, label: 'Ubicación', value: 'Tepatitlán, Jalisco'),
          const SizedBox(height: 24),
        ],
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
