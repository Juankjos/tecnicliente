import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class DestinationState {
  DestinationState._();
  static final instance = DestinationState._();

  /// Coordenadas del destino seleccionado (o null si no hay)
  final ValueNotifier<LatLng?> selected = ValueNotifier<LatLng?>(null);

  /// Dirección textual del destino seleccionado (o null si no hay)
  final ValueNotifier<String?> address = ValueNotifier<String?>(null);

  /// Mantén compatibilidad con tu código existente
  void set(LatLng? value) {
    selected.value = value;
    if (value == null) address.value = null;
  }

  /// Nuevo: establece coordenadas y dirección juntas
  void setWithAddress(LatLng? value, String? addr) {
    selected.value = value;
    address.value = addr;
  }
}
