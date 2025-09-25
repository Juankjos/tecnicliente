// lib/state/destination_state.dart
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class DestinationState {
  DestinationState._();
  static final instance = DestinationState._();

  /// Último destino seleccionado en Rutas
  final ValueNotifier<LatLng?> selected = ValueNotifier<LatLng?>(null);

  void set(LatLng? value) => selected.value = value;
}
