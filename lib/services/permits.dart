// lib/services/permits.dart
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class Permits {
  /// Pide permisos de notificaciones (Android 13+),
  /// ubicación (incl. background) y desactiva optimización de batería.
  static Future<bool> requestLocationWithBackground() async {
    // ---------- Notificaciones (Android 13+) ----------
    final notif = await Permission.notification.request();
    print('[permits] notification: $notif');
    if (!notif.isGranted && !notif.isLimited) {
      // Si niega notificaciones, muchos OEM matan el FGS rápido.
      // No forzamos, sólo lo dejamos registrado.
    }

    // ---------- Ubicación foreground ----------
    final loc = await Geolocator.requestPermission();
    print('[permits] location (fg): $loc');

    if (loc == LocationPermission.deniedForever) {
      print('[permits] location deniedForever, abriendo settings');
      await openAppSettings();
      return false;
    }
    if (loc == LocationPermission.denied) {
      print('[permits] location denied');
      return false;
    }

    // ---------- Ubicación background (Android 10+) ----------
    final bg = await Permission.locationAlways.request();
    print('[permits] locationAlways: $bg');

    if (!bg.isGranted) {
      // En algunos OEM, "Permitir siempre" se configura en ajustes.
      // Aquí podrías decidir forzar ajustes si lo necesitas:
      // await openAppSettings();
      // return false;
      print('[permits] locationAlways no concedido completamente (se puede dejar seguir pero ojo)');
    }

    // ---------- Ignorar optimización de batería (muy importante para FGS) ----------
    final battery = await Permission.ignoreBatteryOptimizations.request();
    print('[permits] ignoreBatteryOptimizations: $battery');

    // No forzamos fallo si el usuario no quiere,
    // pero al menos lo dejamos registrado para depurar.
    return true;
  }
}
