import 'package:flutter/material.dart';

class AjustesPage extends StatefulWidget {
  const AjustesPage({super.key});

  @override
  State<AjustesPage> createState() => _AjustesPageState();
}

class _AjustesPageState extends State<AjustesPage> {
  bool notificaciones = true;
  bool temaOscuro = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          // SwitchListTile(
          //   title: const Text('Notificaciones'),
          //   subtitle: const Text('Recibir avisos y recordatorios'),
          //   value: notificaciones,
          //   onChanged: (v) => setState(() => notificaciones = v),
          // ),
          // const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versión'),
            subtitle: const Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}
