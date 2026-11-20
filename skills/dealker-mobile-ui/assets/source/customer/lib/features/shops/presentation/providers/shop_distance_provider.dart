import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/features/addresses/presentation/providers/address_provider.dart';

/// The customer's pinned location (default saved address with coordinates), or null.
typedef ShopOrigin = ({double lat, double lng, String? addressId});

final shopOriginProvider = Provider<ShopOrigin?>((Ref ref) {
  final addresses = ref.watch(addressProvider).asData?.value;
  if (addresses == null || addresses.isEmpty) return null;
  bool pinned(dynamic e) => e.latitude != 0 || e.longitude != 0;
  final pinnedOnes = addresses.where(pinned).toList();
  if (pinnedOnes.isEmpty) return null;
  final a =
      pinnedOnes.firstWhere((e) => e.isDefault, orElse: () => pinnedOnes.first);
  return (lat: a.latitude, lng: a.longitude, addressId: a.id);
});

class ShopDistance {
  const ShopDistance({required this.km, this.minutes, this.road = true});
  final double km;
  final int? minutes;
  final bool road;

  String get label =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
}

/// Road distance from the customer's pin to vendor shops, shown on product boxes.
/// Shop ids are collected for ~120 ms and fetched in one request; the server saves each
/// (address, shop) pair so the map API is never called twice for the same pair.
class ShopDistanceNotifier extends Notifier<Map<String, ShopDistance>> {
  final Set<String> _asked = <String>{};
  final Set<String> _pending = <String>{};
  Timer? _timer;

  @override
  Map<String, ShopDistance> build() {
    ref.watch(shopOriginProvider); // a new address starts from scratch
    _asked.clear();
    _pending.clear();
    _timer?.cancel();
    _timer = null;
    ref.onDispose(() => _timer?.cancel());
    return const <String, ShopDistance>{};
  }

  void request(String? shopId) {
    if (shopId == null || shopId.isEmpty) return;
    if (!_asked.add(shopId)) return;
    _pending.add(shopId);
    _timer ??= Timer(const Duration(milliseconds: 120), _flush);
  }

  Future<void> _flush() async {
    _timer = null;
    final ShopOrigin? origin = ref.read(shopOriginProvider);
    final List<String> ids = _pending.toList();
    _pending.clear();
    if (origin == null || ids.isEmpty) return;
    for (int i = 0; i < ids.length; i += 40) {
      final List<String> chunk =
          ids.sublist(i, i + 40 > ids.length ? ids.length : i + 40);
      try {
        final response = await ref.read(dioClientProvider).get<dynamic>(
          '/discovery/distances',
          queryParameters: <String, dynamic>{
            'lat': origin.lat,
            'lng': origin.lng,
            'shopIds': chunk.join(','),
            if (origin.addressId != null) 'addressId': origin.addressId,
          },
        );
        final data = (response.data as Map)['data'];
        if (data is! Map) continue;
        final next = Map<String, ShopDistance>.from(state);
        data.forEach((dynamic k, dynamic v) {
          if (v is Map && v['km'] is num) {
            next['$k'] = ShopDistance(
              km: (v['km'] as num).toDouble(),
              minutes: (v['minutes'] as num?)?.toInt(),
              road: v['method'] == 'ROAD',
            );
          }
        });
        state = next;
      } catch (_) {
        for (final String id in chunk) {
          _asked.remove(id); // try again next time the card is built
        }
      }
    }
  }
}

final shopDistanceProvider =
    NotifierProvider<ShopDistanceNotifier, Map<String, ShopDistance>>(
        ShopDistanceNotifier.new);
