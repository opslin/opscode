import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/wholesale/data/wholesale_models.dart';
import 'package:dealker_vendor/features/wholesale/data/wholesale_repository.dart';

final wholesaleRepositoryProvider = Provider<WholesaleRepository>(
    (ref) => WholesaleRepository(ref.watch(dioProvider)));

typedef WholesaleQuery = ({
  String search,
  String sort,
  String? brand,
  String? condition,
  String? category,
  bool deals
});

final wholesaleListProvider = FutureProvider.autoDispose
    .family<WholesalePage, WholesaleQuery>((ref, q) => ref
        .watch(wholesaleRepositoryProvider)
        .list(
            search: q.search,
            sort: q.sort,
            brand: q.brand,
            condition: q.condition,
            category: q.category,
            deals: q.deals));

final wholesaleCategoriesProvider =
    FutureProvider.autoDispose<List<WholesaleCategory>>(
        (ref) => ref.watch(wholesaleRepositoryProvider).categories());

final wholesaleDetailProvider = FutureProvider.autoDispose
    .family<WholesaleDetail, String>(
        (ref, id) => ref.watch(wholesaleRepositoryProvider).detail(id));
