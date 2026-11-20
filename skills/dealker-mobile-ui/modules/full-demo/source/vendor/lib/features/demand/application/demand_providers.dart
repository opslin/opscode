import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';
import 'package:dealker_vendor/features/demand/data/demand_repository.dart';
import 'package:dealker_vendor/features/demand/data/demo_demand_repository.dart';
import 'package:dealker_vendor/features/home/application/home_providers.dart';

final demandRepositoryProvider = Provider<DemandRepository>(
  (ref) => demoHome
      ? _demoRepo ??= DemoDemandRepository()
      : DemandRepository(ref.watch(dioProvider)),
);
DemandRepository? _demoRepo; // keeps demo data alive across rebuilds

/// Counts for the hub tabs, home banner and bell badge.
final demandSummaryProvider = FutureProvider.autoDispose<DemandSummary>(
  (ref) => ref.watch(demandRepositoryProvider).summary(),
);

/// A list of requirements: ([scope], [tab]) — see [DemandRepository.requirements].
typedef ReqQuery = (String scope, String? tab);

final requirementsProvider =
    FutureProvider.autoDispose.family<RequirementPage, ReqQuery>(
  (ref, q) =>
      ref.watch(demandRepositoryProvider).requirements(scope: q.$1, tab: q.$2),
);

final requirementDetailProvider =
    FutureProvider.autoDispose.family<RequirementDetail, String>(
  (ref, id) => ref.watch(demandRepositoryProvider).detail(id),
);

final matchProvider = FutureProvider.autoDispose.family<MatchResult, String>(
  (ref, id) => ref.watch(demandRepositoryProvider).match(id),
);

typedef OrderQuery = (String role, String? bucket);

final demandOrdersProvider =
    FutureProvider.autoDispose.family<OrderPage, OrderQuery>(
  (ref, q) =>
      ref.watch(demandRepositoryProvider).orders(role: q.$1, bucket: q.$2),
);

final orderDetailProvider =
    FutureProvider.autoDispose.family<OrderDetail, String>(
  (ref, id) => ref.watch(demandRepositoryProvider).orderDetail(id),
);

final demandWalletProvider = FutureProvider.autoDispose<WalletInfo>(
  (ref) => ref.watch(demandRepositoryProvider).wallet(),
);

/// Refresh everything the demand flow shows (hub tabs, counts, open screens).
void refreshDemand(WidgetRef ref) {
  ref
    ..invalidate(demandSummaryProvider)
    ..invalidate(requirementsProvider)
    ..invalidate(requirementDetailProvider)
    ..invalidate(matchProvider)
    ..invalidate(demandOrdersProvider)
    ..invalidate(orderDetailProvider)
    ..invalidate(demandWalletProvider)
    // The home screen's Quotes tile and "needs action" list read the same requirements.
    ..invalidate(openRequirementsProvider)
    ..invalidate(quotedRequirementsProvider);
}
