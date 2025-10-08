
enum RutaStatus { pendiente, enCamino, completada }

extension RutaStatusX on RutaStatus {
  String get label {
    switch (this) {
      case RutaStatus.pendiente: return 'Pendiente';
      case RutaStatus.enCamino:  return 'En Camino';
      case RutaStatus.completada:return 'Completada';
    }
  }

  static RutaStatus fromDb(String s) {
    final t = s.toLowerCase();
    if (t.startsWith('complet')) return RutaStatus.completada;
    if (t.startsWith('en camino')) return RutaStatus.enCamino;
    // 'Cancelado' u otros -> lo tratamos como pendiente para listado
    return RutaStatus.pendiente;
  }
}

class Ruta {
  final int id;
  final String cliente;
  final String contrato;
  final String direccion;
  final String orden;
  final RutaStatus estatus;
  final DateTime? fechaHoraInicio;
  final DateTime? fechaHoraFin;

  const Ruta({
    required this.id,
    required this.cliente,
    required this.contrato,
    required this.direccion,
    required this.orden,
    required this.estatus,
    this.fechaHoraInicio,
    this.fechaHoraFin,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null || (v is String && v.isEmpty)) return null;
    return DateTime.parse(v as String);
  }

  factory Ruta.fromMap(Map<String, dynamic> e) => Ruta(
        id: e['id'] as int,
        cliente: (e['cliente'] ?? '').toString(),
        contrato: (e['contrato'] ?? '').toString(),
        direccion: (e['direccion'] ?? '').toString(),
        orden: (e['orden'] ?? '').toString(),
        estatus: RutaStatusX.fromDb((e['estatus'] ?? '').toString()),
        fechaHoraInicio: _parseDate(e['inicio']),
        fechaHoraFin: _parseDate(e['fin']),
      );
}
