// lib/services/fg_entry.dart
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'fg_task.dart';

@pragma('vm:entry-point') // importante para que el VM lo encuentre en background
void startCallback() {
  FlutterForegroundTask.setTaskHandler(TrackTaskHandler());
}
