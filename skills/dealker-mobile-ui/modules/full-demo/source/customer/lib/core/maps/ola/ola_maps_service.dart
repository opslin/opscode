import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as device;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/core/maps/geo_point.dart';
import 'package:dealker_app/core/maps/route_model.dart';
import 'package:dealker_app/core/network/api_client.dart';
import 'package:dealker_app/core/utils/haversine.dart';

part 'ola_maps_service.g.dart';

@riverpod
OlaMapsService olaMapsService(Ref ref) {
  return OlaMapsService(ref.watch(apiClientProvider));
}

/// Cached copy of [OlaMapsService.getStyle], shared by every widget that
/// just needs a style URL to render a map (e.g. static preview thumbnails)
/// without each one triggering its own backend round-trip.
@Riverpod(keepAlive: true)
Future<OlaMapsStyle> olaMapsStyle(Ref ref) {
  return ref.watch(olaMapsServiceProvider).getStyle();
}

/// A style URL fetched from the backend, plus whether it issued one
/// (unset until an admin saves a working key from the dashboard).
class OlaMapsStyle {
  const OlaMapsStyle({required this.configured, this.styleUrl});

  final bool configured;
  final String? styleUrl;
}

/// One forward-geocode candidate — used for the address-picker search box,
/// where a query can match several places.
class OlaPlaceSuggestion {
  const OlaPlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.point,
  });

  final String title;
  final String subtitle;
  final GeoPoint point;
}

/// Ola Maps access, entirely proxied through the Dealkr backend
/// (`/maps/ola/*`) so the provider's API key never ships inside the app
/// build — rotating it is a backend-only change, no app release needed.
/// Replaces the free OSM/Nominatim/OSRM stack in [MapsService] app-wide.
class OlaMapsService {
  OlaMapsService(this._apiClient);

  static const double _fallbackMetersPerSecond = 6.5;

  final ApiClient _apiClient;

  static const String _olaBase = 'https://api.olamaps.io';
  static const String _olaStyle = 'default-light-standard';

  /// True when the Ola key is built into the app, so calls go straight to Ola Maps.
  static bool get _direct => ApiConstants.olaMapsApiKey.isNotEmpty;

  static final Dio _ola = Dio(
    BaseOptions(
      baseUrl: _olaBase,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
      queryParameters: <String, dynamic>{'api_key': ApiConstants.olaMapsApiKey},
    ),
  );

  /// Ola's encoded polyline (precision 5) -> points.
  static List<GeoPoint> _decodePolyline(String encoded) {
    final List<GeoPoint> points = <GeoPoint>[];
    int index = 0;
    int lat = 0;
    int lng = 0;
    while (index < encoded.length) {
      for (int axis = 0; axis < 2; axis++) {
        int shift = 0;
        int result = 0;
        int byte;
        do {
          byte = encoded.codeUnitAt(index++) - 63;
          result |= (byte & 0x1f) << shift;
          shift += 5;
        } while (byte >= 0x20 && index < encoded.length);
        final int delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
        if (axis == 0) {
          lat += delta;
        } else {
          lng += delta;
        }
      }
      points.add(GeoPoint(lat: lat / 1e5, lng: lng / 1e5));
    }
    return points;
  }

  Future<OlaMapsStyle> getStyle() async {
    if (_direct) {
      return OlaMapsStyle(
        configured: true,
        styleUrl:
            '$_olaBase/tiles/vector/v1/styles/$_olaStyle/style.json?api_key=${ApiConstants.olaMapsApiKey}',
      );
    }
    try {
      final response = await _apiClient.getOlaMapsStyleUrl();
      final data = _extractData(response.data);
      return OlaMapsStyle(
        configured: data['configured'] == true,
        styleUrl: (data['styleUrl'] as String?)?.trim(),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('OlaMapsService.getStyle exception: $error');
        debugPrint('$stackTrace');
      }
      return const OlaMapsStyle(configured: false);
    }
  }

  Future<GeoPoint?> geocodeAddress(String address) async {
    final suggestions = await search(address);
    return suggestions.isEmpty ? null : suggestions.first.point;
  }

  /// All forward-geocode candidates for a query — for the address-picker
  /// search box, where "Park Street" should offer more than one match.
  Future<List<OlaPlaceSuggestion>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const <OlaPlaceSuggestion>[];
    }

    try {
      final Map<String, dynamic> result;
      if (_direct) {
        final Response<dynamic> r = await _ola.get<dynamic>(
          '/places/v1/geocode',
          queryParameters: <String, dynamic>{
            'address': trimmed,
            'api_key': ApiConstants.olaMapsApiKey,
          },
        );
        result = _asMap(r.data);
      } else {
        final response = await _apiClient.getOlaMapsGeocode(trimmed);
        result = _asMap(_extractData(response.data)['result']);
      }
      final results = _asList(result['geocodingResults']);

      return results
          .map(_asMap)
          .map(_suggestionFromResult)
          .whereType<OlaPlaceSuggestion>()
          .toList(growable: false);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('OlaMapsService.search exception: $error');
        debugPrint('$stackTrace');
      }
      return const <OlaPlaceSuggestion>[];
    }
  }

  OlaPlaceSuggestion? _suggestionFromResult(Map<String, dynamic> result) {
    final location = _asMap(_asMap(result['geometry'])['location']);
    final lat = _toDouble(location['lat']);
    final lng = _toDouble(location['lng']);
    if (lat == null || lng == null) {
      return null;
    }

    final formatted = (result['formatted_address'] as String?)?.trim() ?? '';
    final name = (result['name'] as String?)?.trim() ?? '';
    final title = name.isNotEmpty
        ? name
        : (formatted.isNotEmpty
            ? formatted.split(',').first.trim()
            : 'Selected place');

    return OlaPlaceSuggestion(
      title: title,
      subtitle: formatted,
      point: GeoPoint(lat: lat, lng: lng),
    );
  }

  /// Driving route between two points, via the backend's Ola Directions
  /// proxy. Never returns null for a valid origin/destination — falls back
  /// to a straight line (matching the old OSRM-backed MapsService.getRoute
  /// contract) so callers never have to special-case "no route".
  Future<RouteModel?> getRoute(GeoPoint origin, GeoPoint destination) async {
    if (!origin.isValid || !destination.isValid) {
      return null;
    }

    try {
      if (_direct) {
        final Response<dynamic> r = await _ola.post<dynamic>(
          '/routing/v1/directions',
          queryParameters: <String, dynamic>{
            'origin': '${origin.lat},${origin.lng}',
            'destination': '${destination.lat},${destination.lng}',
            'api_key': ApiConstants.olaMapsApiKey,
          },
        );
        final Map<String, dynamic> body = _asMap(r.data);
        final List<dynamic> routes = _asList(body['routes']);
        if (routes.isEmpty) return _straightLineFallback(origin, destination);
        final Map<String, dynamic> route = _asMap(routes.first);
        final List<dynamic> legs = _asList(route['legs']);
        final Map<String, dynamic> leg =
            legs.isEmpty ? <String, dynamic>{} : _asMap(legs.first);
        final dynamic enc = route['overview_polyline'];
        final List<GeoPoint> pts =
            enc is String ? _decodePolyline(enc) : const <GeoPoint>[];
        final num? dist = _distOrDur(leg['distance']);
        final num? dur = _distOrDur(leg['duration']);
        if (pts.isEmpty || dist == null || dur == null) {
          return _straightLineFallback(origin, destination);
        }
        return RouteModel(
          points: pts,
          distanceMeters: dist.round(),
          durationSeconds: dur.round(),
        );
      }
      final response = await _apiClient.getOlaMapsDirections(
        origin.lat,
        origin.lng,
        destination.lat,
        destination.lng,
      );
      final data = _extractData(response.data);
      final result = _asMap(data['result']);

      final points = _asList(result['points'])
          .map(_asMap)
          .map((point) {
            final lat = _toDouble(point['lat']);
            final lng = _toDouble(point['lng']);
            return lat != null && lng != null
                ? GeoPoint(lat: lat, lng: lng)
                : null;
          })
          .whereType<GeoPoint>()
          .toList(growable: false);
      final distanceMeters = (result['distanceMeters'] as num?)?.round();
      final durationSeconds = (result['durationSeconds'] as num?)?.round();

      if (points.isEmpty || distanceMeters == null || durationSeconds == null) {
        return _straightLineFallback(origin, destination);
      }

      return RouteModel(
        points: points,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('OlaMapsService.getRoute exception: $error');
        debugPrint('$stackTrace');
      }
      return _straightLineFallback(origin, destination);
    }
  }

  RouteModel _straightLineFallback(GeoPoint origin, GeoPoint destination) {
    final distanceMeters = Haversine.distanceInMeters(
      startLatitude: origin.lat,
      startLongitude: origin.lng,
      endLatitude: destination.lat,
      endLongitude: destination.lng,
    ).round();
    final safeDistance = distanceMeters <= 0 ? 1 : distanceMeters.toDouble();
    return RouteModel(
      points: <GeoPoint>[origin, destination],
      distanceMeters: distanceMeters,
      durationSeconds: (safeDistance / _fallbackMetersPerSecond).ceil(),
    );
  }

  /// Ola first; when Ola Maps isn't configured/enabled in the dashboard yet (or is down) the phone's
  /// own geocoder fills in, so "use my location" still saves a real address instead of failing.
  Future<ReverseGeocodeResult?> reverseGeocode(GeoPoint point) async {
    final ReverseGeocodeResult? fromOla = await _reverseGeocodeOla(point);
    if (fromOla != null || !point.isValid) {
      return fromOla;
    }
    try {
      final List<device.Placemark> marks =
          await device.placemarkFromCoordinates(point.lat, point.lng);
      if (marks.isEmpty) return null;
      final device.Placemark m = marks.first;
      String? clean(String? v) =>
          (v == null || v.trim().isEmpty) ? null : v.trim();
      final List<String> parts = <String?>[
        clean(m.name),
        clean(m.subLocality),
        clean(m.locality),
        clean(m.administrativeArea),
        clean(m.postalCode),
      ].whereType<String>().toList();
      return ReverseGeocodeResult(
        displayName: parts.isEmpty ? null : parts.join(', '),
        addressLine1: clean(m.thoroughfare) ?? clean(m.name),
        addressLine2: clean(m.subLocality),
        city: clean(m.locality) ?? clean(m.subAdministrativeArea),
        state: clean(m.administrativeArea),
        pincode: clean(m.postalCode),
      );
    } catch (_) {
      return null;
    }
  }

  Future<ReverseGeocodeResult?> _reverseGeocodeOla(GeoPoint point) async {
    if (!point.isValid) {
      return null;
    }

    try {
      final Map<String, dynamic> result;
      if (_direct) {
        final Response<dynamic> r = await _ola.get<dynamic>(
          '/places/v1/reverse-geocode',
          queryParameters: <String, dynamic>{
            'latlng': '${point.lat},${point.lng}',
            'api_key': ApiConstants.olaMapsApiKey,
          },
        );
        result = _asMap(r.data);
      } else {
        final response = await _apiClient.getOlaMapsReverseGeocode(
          point.lat,
          point.lng,
        );
        result = _asMap(_extractData(response.data)['result']);
      }
      final results = _asList(result['results']);
      if (results.isEmpty) {
        return null;
      }

      final first = _asMap(results.first);
      final components = _asList(first['address_components'])
          .map(_asMap)
          .toList(growable: false);

      final road = _componentByType(components, 'route');
      var subLocality = _componentByType(components, 'sublocality');
      if (subLocality.isEmpty) {
        subLocality = _componentByType(components, 'sublocality_level_1');
      }
      var city = _componentByType(components, 'locality');
      if (city.isEmpty) {
        city = _componentByType(components, 'administrative_area_level_2');
      }
      final state = _componentByType(components, 'administrative_area_level_1');
      final pincode = _componentByType(components, 'postal_code');

      // Ola doesn't always tag a component `landmark` explicitly — when it
      // doesn't, the nearest named place (POI/premise/neighbourhood) is the
      // closest thing to a landmark in the response, checked in that order.
      var landmark = '';
      for (final type in const <String>[
        'landmark',
        'point_of_interest',
        'premise',
        'establishment',
        'neighborhood',
      ]) {
        landmark = _componentByType(components, type);
        if (landmark.isNotEmpty) break;
      }

      return ReverseGeocodeResult(
        displayName: (first['formatted_address'] as String?)?.trim(),
        addressLine1: road.isEmpty ? null : road,
        addressLine2: subLocality.isEmpty ? null : subLocality,
        city: city.isEmpty ? null : city,
        state: state.isEmpty ? null : state,
        pincode: pincode.isEmpty ? null : pincode,
        landmark: landmark.isEmpty ? null : landmark,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('OlaMapsService.reverseGeocode exception: $error');
        debugPrint('$stackTrace');
      }
      return null;
    }
  }

  /// Ola returns leg distance/duration either as a number or as {value: n}.
  num? _distOrDur(dynamic v) {
    if (v is num) return v;
    if (v is Map && v['value'] is num) return v['value'] as num;
    return null;
  }

  String _componentByType(List<Map<String, dynamic>> components, String type) {
    for (final component in components) {
      final types = _asList(component['types']);
      if (types.contains(type)) {
        return (component['long_name'] as String?)?.trim() ?? '';
      }
    }
    return '';
  }

  Map<String, dynamic> _extractData(dynamic raw) {
    final payload = _asMap(raw);
    return _asMap(payload['data']);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List<dynamic>) {
      return value;
    }
    if (value is List) {
      return List<dynamic>.from(value);
    }
    return const <dynamic>[];
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }
}

class ReverseGeocodeResult {
  const ReverseGeocodeResult({
    this.displayName,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.pincode,
    this.landmark,
  });

  final String? displayName;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? pincode;
  final String? landmark;
}
