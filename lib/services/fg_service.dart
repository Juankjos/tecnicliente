// lib/services/fg_service.dart
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'fg_entry.dart'; // trae startCallback()

class FgService {
  static Future<void> start({
    required int reportId,
    required int? tecId,
    String serverUrl = 'http://127.0.0.1:3001',
    int intervalMs = 5000,
  }) async {
    print('[fg-service] start() reportId=$reportId tecId=$tecId');

    await FlutterForegroundTask.saveData(key: 'reportId', value: reportId);
    await FlutterForegroundTask.saveData(key: 'tecId', value: tecId ?? -1);
    await FlutterForegroundTask.saveData(key: 'serverUrl', value: serverUrl);

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'rutas_track',
        channelName: 'Rastreo en curso',
        channelDescription: 'Ubicación en primer plano para rutas',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(intervalMs),
        allowWakeLock: true,
        autoRunOnBoot: false,
      ),
    );

    await FlutterForegroundTask.startService(
      callback: startCallback, // top-level @pragma('vm:entry-point')
      notificationTitle: 'Rastreando ruta',
      notificationText: 'Servicio activo (toca para volver a la app)',

      notificationIcon: const NotificationIcon(
  metaDataName: 'com.rutas.service.NOTIF_ICON',
),

      notificationButtons: const [
        NotificationButton(id: 'stop', text: 'Detener'),
      ],
    );

    print('[fg-service] startService lanzado');
  }

  static Future<void> stop() async {
    print('[fg-service] stop() llamado');
    await FlutterForegroundTask.stopService();
  }
}
