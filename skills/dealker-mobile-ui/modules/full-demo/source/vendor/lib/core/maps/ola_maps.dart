import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Ola Maps, called straight from the app with the key kept in the git-ignored `.env`
/// (`OLA_MAPS_API_KEY`). Map tiles and address lookups fall back to OpenStreetMap / the phone's
/// own geocoder when the key is empty.
class OlaMaps {
  OlaMaps._();

  static const String _base = 'https://api.olamaps.io';
  static const String _style = 'default-light-standard';

  static String get key => (dotenv.maybeGet('OLA_MAPS_API_KEY') ?? '').trim();
  static bool get enabled => key.isNotEmpty;

  /// Raster tile template for flutter_map.
  static String get tileUrl => enabled
      ? '$_base/tiles/v1/styles/$_style/{z}/{x}/{y}.png?api_key=$key'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _base,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Reverse geocode -> {street, sub, city, state, pin, formatted}; null when unavailable.
  static Future<Map<String, String>?> reverse(double lat, double lng) async {
    if (!enabled) return null;
    try {
      final r = await _dio.get<dynamic>('/places/v1/reverse-geocode',
          queryParameters: {'latlng': '$lat,$lng', 'api_key': key});
      final data = r.data;
      final results = data is Map ? data['results'] : null;
      if (results is! List || results.isEmpty) return null;
      final first = Map<String, dynamic>.from(results.first as Map);
      final comps = (first['address_components'] is List)
          ? (first['address_components'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      String by(List<String> types) {
        for (final t in types) {
          for (final c in comps) {
            final ty = c['types'];
            if (ty is List && ty.contains(t)) {
              final v = '${c['long_name'] ?? ''}'.trim();
              if (v.isNotEmpty) return v;
            }
          }
        }
        return '';
      }

      return {
        'street': by(['route']),
        'sub': by(['sublocality', 'sublocality_level_1', 'neighborhood']),
        'city': by(['locality', 'administrative_area_level_2']),
        'state': by(['administrative_area_level_1']),
        'pin': by(['postal_code']),
        'formatted': '${first['formatted_address'] ?? ''}'.trim(),
      };
    } catch (_) {
      return null;
    }
  }
}
