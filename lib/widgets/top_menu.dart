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
          case _MenuOption.perfil:
            Navigator.of(context).pushNamed('/perfil');
            break;
          case _MenuOption.ajustes:
            Navigator.of(context).pushNamed('/ajustes');
            break;
          case _MenuOption.rutas: // 👈 NUEVO
            Navigator.of(context).pushNamed('/rutas');
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: _MenuOption.perfil, child: Text('Perfil')),
        PopupMenuItem(value: _MenuOption.rutas, child: Text('Rutas')),
        PopupMenuItem(value: _MenuOption.ajustes, child: Text('Ajustes')),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,                // fondo blanco
          borderRadius: BorderRadius.circular(20), // bordes redondeados
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Text(
          'Menú',
          style: TextStyle(
            color: Color.fromARGB(255, 8, 95, 176), // color solicitado
            fontWeight: FontWeight.w600,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }


}

// 👇 agrega el nuevo valor 'rutas'
enum _MenuOption { perfil, ajustes, rutas}
