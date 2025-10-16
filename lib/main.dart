import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/perfil_page.dart';
import 'pages/ajustes_page.dart';
import 'pages/rutas_page.dart';
import 'pages/login_page.dart';
import 'services/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.instance.load();
  runApp(MyApp(
    initialRoute: Session.instance.isLoggedIn ? '/home' : '/login',
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.initialRoute});
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rutas',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF064E3B)),
      initialRoute: initialRoute,
      routes: {
        '/login': (_)  => const LoginPage(),
        '/home': (_)   => const HomePage(),
        '/perfil': (_) => const PerfilPage(),
        '/ajustes': (_) => const AjustesPage(),
        '/rutas': (_)  => const RutasPage(),
      },
    );
  }
}
