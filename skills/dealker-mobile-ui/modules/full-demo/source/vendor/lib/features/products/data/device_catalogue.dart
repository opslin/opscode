import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/products/data/product_catalog.dart';

/// One phone/tablet/laptop model from the shared device catalogue (`GET /devices/models`).
class DeviceModel {
  const DeviceModel(
      {required this.name, this.series, this.storages = const <String>[]});

  final String name;
  final String? series;
  final List<String> storages;
}

String? _categoryOf(ProductType t) => switch (t.key) {
      'mobile' => 'Smartphone',
      'tablet' => 'Tablet',
      'laptop' => 'Laptop',
      _ => null,
    };

List<Map<String, dynamic>> _rows(dynamic body) {
  final dynamic d = body is Map ? body['data'] : null;
  return d is List
      ? d.whereType<Map>().map((Map e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];
}

/// Brands for a product type — the same list the customer app uses for Sell and Repair. Falls back to the
/// built-in suggestions when the catalogue is empty or unreachable (typed values are always accepted).
final deviceBrandsProvider = FutureProvider.family<List<String>, ProductType>(
    (Ref ref, ProductType t) async {
  final String? cat = _categoryOf(t);
  if (cat == null) return brandsFor(t);
  try {
    final Response<dynamic> r = await ref.watch(dioProvider).get<dynamic>(
      '/devices/brands',
      queryParameters: <String, dynamic>{'category': cat},
    );
    final List<String> names =
        _rows(r.data).map((Map<String, dynamic> b) => '${b['name']}').toList();
    return names.isEmpty ? brandsFor(t) : names;
  } catch (_) {
    return brandsFor(t);
  }
});

/// Models of one brand (series order kept) with their storage sizes.
final deviceModelsProvider =
    FutureProvider.family<List<DeviceModel>, (ProductType, String)>(
        (Ref ref, (ProductType, String) key) async {
  final ProductType t = key.$1;
  final String brand = key.$2;
  final String? cat = _categoryOf(t);
  if (cat == null || brand.isEmpty)
    return modelsFor(t, brand).map((String n) => DeviceModel(name: n)).toList();
  try {
    final Response<dynamic> r = await ref.watch(dioProvider).get<dynamic>(
      '/devices/models',
      queryParameters: <String, dynamic>{
        'brand': brand,
        'category': cat,
        'limit': 500
      },
    );
    final List<DeviceModel> out = _rows(r.data)
        .map((Map<String, dynamic> m) => DeviceModel(
              name: '${m['name']}',
              series: m['series'] as String?,
              storages: (m['storages'] is List)
                  ? (m['storages'] as List).map((dynamic e) => '$e').toList()
                  : const <String>[],
            ))
        .toList();
    return out.isEmpty
        ? modelsFor(t, brand).map((String n) => DeviceModel(name: n)).toList()
        : out;
  } catch (_) {
    return modelsFor(t, brand).map((String n) => DeviceModel(name: n)).toList();
  }
});

/// Storage options for a chosen model: the catalogue sizes, or the generic list when the model is unknown / typed by hand.
List<String> storagesFor(List<DeviceModel> models, String model) {
  final String key = model.trim().toLowerCase();
  for (final DeviceModel m in models) {
    if (m.name.toLowerCase() == key && m.storages.isNotEmpty) return m.storages;
  }
  return kStorageOptions;
}
