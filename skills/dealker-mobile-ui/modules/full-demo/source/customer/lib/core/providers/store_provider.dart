import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/core/models/store_model.dart';

class _SelectedStoreNotifier extends Notifier<StoreModel> {
  @override
  StoreModel build() => fallbackStore;

  void select(StoreModel store) => state = store;
}

class _SelectedCategoryNotifier extends Notifier<String> {
  // '' is a sentinel meaning "no explicit tab picked yet" — consumers
  // resolve it to the store's admin-configured default tab (falling back to
  // 'all', then the first tab) once that store's tabs have loaded. A real
  // tabKey/CategoryModel.id is never empty, so this can't collide.
  @override
  String build() => '';

  void select(String id) {
    // Guard against re-selecting the same tab so providers don't re-fire.
    if (state == id) return;
    state = id;
  }
}

final selectedStoreProvider =
    NotifierProvider<_SelectedStoreNotifier, StoreModel>(
  _SelectedStoreNotifier.new,
);

final selectedCategoryIdProvider =
    NotifierProvider<_SelectedCategoryNotifier, String>(
  _SelectedCategoryNotifier.new,
);

/// Top-of-home store tiles, from `GET /theme/stores`. Empty list on failure
/// (the home then shows no store row rather than invented stores).
final storesProvider = FutureProvider<List<StoreModel>>((Ref ref) async {
  final Dio dio = ref.watch(dioClientProvider);
  final Response<dynamic> response = await dio.get<dynamic>(
    ApiConstants.themeStores,
  );
  final dynamic body = response.data;
  final dynamic data = body is Map ? body['data'] : null;
  final dynamic rows = data is Map ? data['stores'] : null;
  if (rows is! List) return const <StoreModel>[];
  final List<StoreModel> stores = <StoreModel>[
    for (final dynamic row in rows)
      if (row is Map) StoreModel.fromJson(Map<String, dynamic>.from(row)),
  ];
  // Make the selected store the first real one once known.
  final StoreModel selected = ref.read(selectedStoreProvider);
  if (stores.isNotEmpty && !stores.any((StoreModel s) => s.id == selected.id)) {
    ref.read(selectedStoreProvider.notifier).select(stores.first);
  }
  return stores;
});
