import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/demand/application/demand_providers.dart';
import 'package:dealker_vendor/features/my_orders/data/my_orders_models.dart';

/// Everything the vendor bought or sent for repair, from the three places it lives:
/// wholesale orders (`/orders?role=buying`), auction lots won (`/auctions/my`) and repair requests (`/repairs/mine`).
/// One section failing never hides the others.
final myOrdersProvider = FutureProvider.autoDispose<MyOrdersData>((ref) async {
  final demand = ref.watch(demandRepositoryProvider);
  final auctions = ref.watch(auctionRepositoryProvider);
  final dio = ref.watch(dioProvider);
  final failed = <String>[];

  Future<List<MyOrderEntry>> guard(
      String name, Future<List<MyOrderEntry>> Function() f) async {
    try {
      return await f();
    } catch (_) {
      failed.add(name);
      return const [];
    }
  }

  final parts = await Future.wait([
    guard('Wholesale', () async {
      final active = await demand.orders(role: 'buying', bucket: 'active');
      final done = await demand.orders(role: 'buying', bucket: 'done');
      return [...active.items, ...done.items]
          .map(MyOrderEntry.wholesale)
          .toList();
    }),
    guard('Auctions', () async {
      final lots = await auctions.myLots();
      return lots.items
          .where((l) => l.my.isWinner)
          .map(MyOrderEntry.auction)
          .toList();
    }),
    guard('Repairs', () async {
      final res = await dio.get<Map<String, dynamic>>('/repairs/mine',
          queryParameters: {'limit': 50});
      final data = res.data?['data'];
      final rows = data is Map ? data['items'] : data;
      return ((rows as List?) ?? const [])
          .whereType<Map>()
          .map((m) => MyOrderEntry.repair(m.cast<String, dynamic>()))
          .toList();
    }),
  ]);

  final all = parts.expand((e) => e).toList()
    ..sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
  return MyOrdersData(entries: all, failed: failed);
});
