// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'pages/home_page.dart';
import 'pages/perfil_page.dart';
import 'pages/ajustes_page.dart';
import 'pages/rutas_page.dart';
import 'pages/login_page.dart';
import 'services/session.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 (BACKGROUND) Mensaje FCM: ${message.messageId}');
}

Future<void> _initFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;

  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  debugPrint('🔔 Permiso de notificaciones: ${settings.authorizationStatus}');

  final token = await messaging.getToken();
  debugPrint('🔥 Token FCM (solo log) = $token');

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final type = message.data['type'];          // 'chat'
    final reportId = message.data['reportId'];  // string
    final fromRole = message.data['from_role']; // 'client'
    debugPrint('📩 (FOREGROUND) Título: ${message.notification?.title}');
    debugPrint('📩 (FOREGROUND) Cuerpo: ${message.notification?.body}');
    debugPrint('📩 (FOREGROUND) Data: ${message.data}');
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('🧭 Notificación clicada. Data: ${message.data}');
    // Aquí luego decides si navegas al chat, etc.
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Session.instance.load();

  // Solo configurar listeners de FCM (no registrar token aquí)
  await _initFirebaseMessaging();

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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF064E3B),
      ),
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
