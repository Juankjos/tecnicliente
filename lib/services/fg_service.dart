// lib/services/fg_service.dart
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'fg_entry.dart'; // trae startCallback()

class FgService {
  static Future<void> start({
    required int reportId,
    required int? tecId,
    String serverUrl = 'http://127.0.0.1:3001',
    int intervalMs = 5000, // ← int en milisegundos
  }) async {
    // Guarda datos (valores no nulos)
    await FlutterForegroundTask.saveData(key: 'reportId', value: reportId);
    await FlutterForegroundTask.saveData(key: 'tecId', value: tecId ?? -1);
    await FlutterForegroundTask.saveData(key: 'serverUrl', value: serverUrl);

    // 1) Inicializa opciones de notificación y del foreground task
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'rutas_track',
        channelName: 'Rastreo en curso',
        channelDescription: 'Ubicación en primer plano para rutas',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        // Si quieres sonido/vibración, súbele la importancia/priority y habilítalos.
        playSound: false,
        enableVibration: false,
        // Otras opciones disponibles según tu versión del plugin...
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(intervalMs),
        allowWakeLock: true,
        autoRunOnBoot: false,
      ),
    );

    // 2) Arranca el servicio (aquí NO van las opciones, solo el contenido de la notificación)
    await FlutterForegroundTask.startService(
      callback: startCallback, // top-level @pragma('vm:entry-point')
      notificationTitle: 'Rastreando ruta',
      notificationText: 'Servicio activo (toca para volver a la app)',
      // En 9.x los botones y el icono van aquí:
      notificationIcon: NotificationIcon(
        metaDataName: 'ic_launcher', // nombre del ícono (p.ej. mipmap/ic_launcher)
      ),
      notificationButtons: const [
        NotificationButton(id: 'stop', text: 'Detener'),
      ],
    );
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}
