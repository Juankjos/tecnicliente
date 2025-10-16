import 'package:flutter/material.dart';
import '../services/session.dart';                 // 👈 para cerrar sesión
import '../state/destination_state.dart';         // 👈 para limpiar la ruta activa

class TopMenu extends StatelessWidget {
  const TopMenu({super.key});

  Future<bool> _confirmarSalida(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cerrar sesión'),
            content: const Text('¿Seguro que deseas cerrar sesión?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sí, salir'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MenuOption>(
      tooltip: 'Abrir menú',
      padding: const EdgeInsets.only(right: 12),
      onSelected: (value) async {
        switch (value) {
          case _MenuOption.perfil:
            Navigator.of(context).pushNamed('/perfil');
            break;
          case _MenuOption.ajustes:
            Navigator.of(context).pushNamed('/ajustes');
            break;
          case _MenuOption.rutas:
            Navigator.of(context).pushNamed('/rutas');
            break;
          case _MenuOption.salir:
            final ok = await _confirmarSalida(context);
            if (!ok) return;

            // 🧹 limpia estado de navegación/ruta activa
            DestinationState.instance.clear();

            // 🔐 cierra sesión persistida
            await Session.instance.logout();

            if (context.mounted) {
              // navega a login y limpia el stack
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            }
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: _MenuOption.perfil, child: Text('Perfil')),
        const PopupMenuItem(value: _MenuOption.rutas, child: Text('Rutas')),
        const PopupMenuItem(value: _MenuOption.ajustes, child: Text('Ajustes')),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuOption.salir,
          child: Row(
            children: const [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Salir', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Text(
          'Menú',
          style: TextStyle(
            color: Color.fromARGB(255, 8, 95, 176),
            fontWeight: FontWeight.w600,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }
}

enum _MenuOption { perfil, ajustes, rutas, salir }
