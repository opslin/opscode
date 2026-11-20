import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/core/realtime/live_service.dart';
import 'package:dealker_vendor/features/returns/data/return_models.dart';
import 'package:dealker_vendor/features/returns/data/returns_repository.dart';

final returnsRepositoryProvider =
    Provider<ReturnsRepository>((ref) => ReturnsRepository(ref.watch(dioProvider)));

/// Counts for the Returns tile, the list header and the order-detail banner. Refreshes on live events.
final returnsSummaryProvider = FutureProvider.autoDispose<ReturnSummary>((ref) {
  ref.watch(liveTickProvider);
  return ref.watch(returnsRepositoryProvider).summary();
});

/// Family key = state filter ('' = all, 'open', 'needs_response', 'closed').
final returnsListProvider = FutureProvider.autoDispose.family<ReturnPage, String>((ref, state) {
  ref.watch(liveTickProvider);
  return ref.watch(returnsRepositoryProvider).list(state: state);
});

final returnDetailProvider = FutureProvider.autoDispose.family<ReturnDetail, String>((ref, id) {
  ref.watch(liveTickProvider);
  return ref.watch(returnsRepositoryProvider).detail(id);
});

/// Returns raised on one of the vendor's parcels (seller order id) — shown on the order screen.
final orderReturnsProvider = FutureProvider.autoDispose.family<List<ReturnRow>, String>((ref, sellerOrderId) async {
  ref.watch(liveTickProvider);
  return (await ref.watch(returnsRepositoryProvider).list(sellerOrderId: sellerOrderId, limit: 5)).items;
});
