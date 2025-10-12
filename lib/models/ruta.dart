// lib/models/ruta.dart
enum RutaStatus { pendiente, enCamino, completada }

extension RutaStatusX on RutaStatus {
  String get label {
    switch (this) {
      case RutaStatus.pendiente:
        return 'Pendiente';
      case RutaStatus.enCamino:
        return 'En Camino';
      case RutaStatus.completada:
        return 'Completada';
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
  final int id; // ← Debe ser IDReporte en tu BD
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

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    return int.tryParse(s) ?? 0;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    // Soporta 'YYYY-MM-DD HH:MM:SS' (MySQL) y ISO8601
    final iso = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  factory Ruta.fromMap(Map<String, dynamic> e) => Ruta(
        // Acepta varias claves posibles para IDReporte
        id: _asInt(e['id'] ?? e['IDReporte'] ?? e['id_reporte'] ?? e['idreporte']),
        cliente: (e['cliente'] ?? e['Cliente'] ?? e['Nombre'] ?? '').toString(),
        contrato: (e['contrato'] ?? e['Contrato'] ?? e['IDContrato'] ?? '').toString(),
        direccion: (e['direccion'] ?? e['Direccion'] ?? '').toString(),
        orden: (e['orden'] ?? e['Orden'] ?? e['Problema'] ?? '').toString(),
        estatus: RutaStatusX.fromDb(
          (e['estatus'] ?? e['status'] ?? e['Status'] ?? '').toString(),
        ),
        fechaHoraInicio: _parseDate(e['inicio'] ?? e['FechaInicio']),
        fechaHoraFin: _parseDate(e['fin'] ?? e['FechaFin']),
      );
}
