import 'package:flutter/material.dart';

class TopMenu extends StatelessWidget {
  const TopMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MenuOption>(
      tooltip: 'Abrir menú',
      padding: const EdgeInsets.only(right: 12),
      onSelected: (value) async {
        switch (value) {
          case _MenuOption.inicio:
            Navigator.of(context).popUntil((route) => route.isFirst);
            _showSnack(context, 'Inicio');
            break;
          case _MenuOption.perfil:
            Navigator.of(context).pushNamed('/perfil');
            break;
          case _MenuOption.ajustes:
            Navigator.of(context).pushNamed('/ajustes');
            break;
          case _MenuOption.rutas: // 👈 NUEVO
            Navigator.of(context).pushNamed('/rutas');
            break;
          case _MenuOption.salir:
            final salir = await _confirmarSalir(context);
            if (salir == true) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: _MenuOption.inicio, child: Text('Inicio')),
        PopupMenuItem(value: _MenuOption.perfil, child: Text('Perfil')),
        PopupMenuItem(value: _MenuOption.ajustes, child: Text('Ajustes')),
        PopupMenuItem(value: _MenuOption.rutas, child: Text('Rutas')), // 👈 NUEVO
        PopupMenuItem(value: _MenuOption.salir, child: Text('Salir')),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'Menú',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }

  static void _showSnack(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Seleccionaste: $label'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  static Future<bool?> _confirmarSalir(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('¿Deseas salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }
}

// 👇 agrega el nuevo valor 'rutas'
enum _MenuOption { inicio, perfil, ajustes, rutas, salir }
