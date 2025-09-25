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
          SwitchListTile(
            title: const Text('Notificaciones'),
            subtitle: const Text('Recibir avisos y recordatorios'),
            value: notificaciones,
            onChanged: (v) => setState(() => notificaciones = v),
          ),
          SwitchListTile(
            title: const Text('Tema oscuro'),
            subtitle: const Text('Cambiar apariencia de la app'),
            value: temaOscuro,
            onChanged: (v) => setState(() => temaOscuro = v),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de'),
            subtitle: const Text('Versión 1.0.0'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Demo con Menú',
              applicationVersion: '1.0.0',
              applicationIcon: const Icon(Icons.apps),
              children: const [
                Text('App de ejemplo en Flutter con menú desplegable.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
