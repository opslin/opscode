import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/constants/storage_keys.dart';
import 'package:dealker_app/core/storage/hive_service.dart';
import 'package:dealker_app/core/utils/resilient_location.dart';

/// Location-first storefront bootstrap for guests: converts the device's
/// location (and PIN, when the geocoder returns one) into the short-lived
/// storefront token from `POST /storefront/resolve-location`, and stores it
/// for [StorefrontTokenInterceptor]. Returns true when a serviceable shop was
/// resolved. Never throws — on any failure the previous token (if any) is
/// kept and the app falls back to its normal empty/unavailable states.
bool shouldRequestGuestLocation({required bool isWeb, required LocationPermission permission}) =>
    !isWeb && permission == LocationPermission.denied;

Future<bool> bootstrapGuestStorefront() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (shouldRequestGuestLocation(isWeb: kIsWeb, permission: permission)) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return false;
    }

    final Position position = await getResilientCurrentPosition();

    String? pincode;
    try {
      // The platform geocoder has no timeout of its own and can stall for many seconds.
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude)
              .timeout(const Duration(seconds: 3));
      pincode =
          placemarks.map((Placemark p) => p.postalCode?.trim()).firstWhere(
                (String? v) => v != null && v.isNotEmpty,
                orElse: () => null,
              );
    } catch (_) {
      // Coordinates alone still resolve radius-based stores.
    }

    final response = await Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    ).post<Map<String, dynamic>>(
      '/storefront/resolve-location',
      data: <String, dynamic>{
        'lat': position.latitude,
        'lng': position.longitude,
        if (pincode != null) 'pincode': pincode,
      },
    );

    final data = response.data?['data'];
    if (data is Map && data['serviceable'] == true) {
      final token = data['storefrontToken'];
      if (token is String && token.isNotEmpty) {
        await HiveService.settingsBox.put(StorageKeys.storefrontToken, token);
        return true;
      }
    }
    // Not serviceable here: drop any stale token so the old shop's catalogue
    // isn't shown for a place we don't deliver to.
    await HiveService.settingsBox.delete(StorageKeys.storefrontToken);
    return false;
  } catch (_) {
    return false;
  }
}
