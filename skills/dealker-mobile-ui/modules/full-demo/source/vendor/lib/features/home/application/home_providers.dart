import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/core/realtime/live_service.dart';
import 'package:dealker_vendor/features/home/data/demo_home_repository.dart';
import 'package:dealker_vendor/features/home/data/home_models.dart';
import 'package:dealker_vendor/features/home/data/home_repository.dart';

/// DEMO switch: `.env` DEMO_HOME=true shows sample data (see demo_home_repository.dart).
bool get demoHome => dotenv.env['DEMO_HOME'] == 'true';

/// Watches the live tick on purpose: every home block depends on this, so a socket event (new order,
/// sell offer ...) rebuilds the repository and all blocks refetch together. It watches the GATED tick, so
/// nothing refetches while another screen is on top of the home (see homeLiveTickProvider).
final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  ref.watch(homeLiveTickProvider);
  return demoHome ? DemoHomeRepository() : HomeRepository(ref.watch(dioProvider));
});

// One provider per block so a failure in one never blanks the page.
final allOrdersProvider =
    FutureProvider.autoDispose<PagedTotal<SellerOrderRow>>(
  (ref) => ref.watch(homeRepositoryProvider).sellerOrders(),
);

/// Orders waiting for the seller to confirm (backend status ORDER_PLACED).
final newOrdersProvider =
    FutureProvider.autoDispose<PagedTotal<SellerOrderRow>>(
  (ref) => ref
      .watch(homeRepositoryProvider)
      .sellerOrders(status: 'ORDER_PLACED', limit: 3),
);

final openRequirementsProvider =
    FutureProvider.autoDispose<PagedTotal<B2bRequirementRow>>(
  (ref) => ref
      .watch(homeRepositoryProvider)
      .b2bRequirements(scope: 'open', limit: 3),
);

final quotedRequirementsProvider =
    FutureProvider.autoDispose<PagedTotal<B2bRequirementRow>>(
  (ref) => ref.watch(homeRepositoryProvider).b2bRequirements(scope: 'quoted'),
);

final pendingSellRequestsProvider =
    FutureProvider.autoDispose<PagedTotal<SellRequestRow>>(
  (ref) => ref.watch(homeRepositoryProvider).pendingSellRequests(),
);

final walletSummaryProvider = FutureProvider.autoDispose<WalletSummary>(
  (ref) => ref.watch(homeRepositoryProvider).walletSummary(),
);

final auctionStatsProvider = FutureProvider.autoDispose<AuctionStats>(
  (ref) => ref.watch(homeRepositoryProvider).auctionStats(),
);

final liveAuctionsProvider = FutureProvider.autoDispose<List<AuctionRow>>(
  (ref) => ref.watch(homeRepositoryProvider).liveAuctions(),
);

final activeCampaignsProvider = FutureProvider.autoDispose<List<CampaignRow>>(
  (ref) => ref.watch(homeRepositoryProvider).activeCampaigns(),
);

void refreshHome(WidgetRef ref) {
  ref
    ..invalidate(allOrdersProvider)
    ..invalidate(newOrdersProvider)
    ..invalidate(openRequirementsProvider)
    ..invalidate(quotedRequirementsProvider)
    ..invalidate(pendingSellRequestsProvider)
    ..invalidate(walletSummaryProvider)
    ..invalidate(auctionStatsProvider)
    ..invalidate(liveAuctionsProvider)
    ..invalidate(activeCampaignsProvider);
}
