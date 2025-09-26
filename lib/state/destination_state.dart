import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class DestinationState {
  DestinationState._();
  static final instance = DestinationState._();

  /// Coordenadas del destino seleccionado
  final ValueNotifier<LatLng?> selected = ValueNotifier<LatLng?>(null);

  /// Dirección textual del destino seleccionado
  final ValueNotifier<String?> address = ValueNotifier<String?>(null);

  /// Contrato de la ruta seleccionada
  final ValueNotifier<String?> contract = ValueNotifier<String?>(null);

  /// Cliente de la ruta seleccionada
  final ValueNotifier<String?> client = ValueNotifier<String?>(null);

  /// Mantén compatibilidad con tu código existente
  void set(LatLng? value) {
    selected.value = value;
    if (value == null) {
      address.value = null;
      contract.value = null;
      client.value = null;
    }
  }

  /// Establece coordenadas y metadatos de la ruta
  void setWithDetails(
    LatLng? value, {
    String? address,
    String? contract,
    String? client,
  }) {
    selected.value = value;
    this.address.value = address;
    this.contract.value = contract;
    this.client.value = client;
  }

  /// Compatibilidad con versiones previas (usa setWithDetails en lo nuevo)
  @Deprecated('Usa setWithDetails en su lugar')
  void setWithAddress(LatLng? value, String? addr) {
    setWithDetails(value, address: addr);
  }
}
