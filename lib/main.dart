import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/perfil_page.dart';
import 'pages/ajustes_page.dart';
import 'pages/rutas_page.dart'; // 👈 NUEVO

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rutas Técnico',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF064E3B),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomePage(),
        '/perfil': (_) => const PerfilPage(),
        '/ajustes': (_) => const AjustesPage(),
        '/rutas': (_) => const RutasPage(), // 👈 NUEVO
      },
    );
  }
}
