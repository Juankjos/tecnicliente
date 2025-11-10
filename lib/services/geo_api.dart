import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GeoCandidate {
  final String label;
  final double lat;
  final double lon;
  final double score; // relevance 0..1

  GeoCandidate({required this.label, required this.lat, required this.lon, required this.score});
}

class GeoApi {
  // Crea un token de Mapbox (público) y restringe por dominio.
  // https://account.mapbox.com/
  final String mapboxToken;

  GeoApi(this.mapboxToken);

  // Normaliza abreviaturas típicas MX para mejorar el hit-rate
  String _normalize(String q) {
    final r = q
        .replaceAll(RegExp(r'\bC\.\b', caseSensitive: false), 'Calle ')
        .replaceAll(RegExp(r'\bAv\.\b', caseSensitive: false), 'Avenida ')
        .replaceAll(RegExp(r'\bColonia\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bCiudad\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return r;
  }

  // Intenta varias variantes: original, +ciudad por defecto, +alternas
  Future<List<GeoCandidate>> searchSmart({
    required String rawQuery,
    String? cityFromDb, // opcional, si quieres segundo intento
    ({double lat, double lon})? proximity,
    int limit = 5,
    String country = 'mx',
    String language = 'es',
  }) async {
    final q1 = _normalize(rawQuery);
    // Solo probamos:
    // 1) La dirección exacta de BD (normalizada).
    // 2) (Opcional) La dirección + ciudad proveniente de BD si no estaba incluida.
    final candidates = <String>{
      q1,
      if (cityFromDb != null &&
          cityFromDb.trim().isNotEmpty &&
          !q1.toLowerCase().contains(cityFromDb.toLowerCase()))
        '$q1 $cityFromDb',
    }.toList();

    for (final q in candidates) {
      final list = await _mapboxForward(
        q,
        limit: limit,
        country: country,
        language: language,
        proximity: proximity,
      );
      if (list.isNotEmpty) return list;
    }
    return const <GeoCandidate>[];
  }

  Future<List<GeoCandidate>> _mapboxForward(
    String query, {
    int limit = 5,
    String country = 'mx',
    String language = 'es',
    ({double lat, double lon})? proximity,
  }) async {
    final encoded = Uri.encodeComponent(query);
    final params = <String, String>{
      'access_token': mapboxToken,
      'limit': '$limit',
      'country': country,
      'language': language,
      'autocomplete': 'true',
      'fuzzyMatch': 'true',
      'types': 'address,place,locality,neighborhood,poi,street',
    };
    if (proximity != null) {
      params['proximity'] = '${proximity.lon},${proximity.lat}'; // lon,lat
    }

    final uri = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json')
      .replace(queryParameters: params);

    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw HttpException('Geocoding ${res.statusCode}: ${res.body}');
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    final features = (body['features'] as List?) ?? const [];
    return features.map((f) {
      final center = (f['center'] as List).cast<num>();
      final relevance = (f['relevance'] as num?)?.toDouble() ?? 0.0;
      return GeoCandidate(
        label: (f['place_name'] ?? '').toString(),
        lon: center[0].toDouble(),
        lat: center[1].toDouble(),
        score: relevance,
      );
    }).toList();
  }
}
