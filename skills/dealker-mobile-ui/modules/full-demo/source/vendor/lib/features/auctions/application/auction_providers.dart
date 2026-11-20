import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/auctions/application/create_draft.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/auctions/data/auction_repository.dart';
import 'package:dealker_vendor/features/auctions/data/demo_auction_repository.dart';
import 'package:dealker_vendor/features/home/application/home_providers.dart';

final auctionRepositoryProvider = Provider<AuctionRepository>(
  (ref) => demoHome
      ? _demoRepo ??= DemoAuctionRepository()
      : AuctionRepository(ref.watch(dioProvider)),
);
DemoAuctionRepository? _demoRepo; // keeps demo data alive across rebuilds

enum MyAuctionTab {
  all('All', null),
  live('Live', AuctionStatuses.live),
  upcoming('Upcoming', AuctionStatuses.upcoming),
  completed('Completed', AuctionStatuses.completed);

  const MyAuctionTab(this.label, this.statuses);
  final String label;
  final List<String>? statuses;
}

final auctionRulesProvider = FutureProvider.autoDispose<AuctionRules>(
  (ref) => ref.watch(auctionRepositoryProvider).rules(),
);

final productSearchProvider =
    FutureProvider.autoDispose.family<List<ProductOption>, String>(
  (ref, q) => ref.watch(auctionRepositoryProvider).products(q: q),
);

final myAuctionsProvider =
    FutureProvider.autoDispose.family<AuctionList, MyAuctionTab>(
  (ref, tab) =>
      ref.watch(auctionRepositoryProvider).list(statuses: tab.statuses),
);

final auctionDetailProvider =
    FutureProvider.autoDispose.family<AuctionDetail, String>(
  (ref, id) => ref.watch(auctionRepositoryProvider).detail(id),
);

final lotsProvider = FutureProvider.autoDispose.family<LotList, LotQuery>(
  (ref, q) => ref.watch(auctionRepositoryProvider).lots(query: q),
);

final myLotsProvider = FutureProvider.autoDispose<LotList>(
  (ref) => ref.watch(auctionRepositoryProvider).myLots(),
);

final lotProvider = FutureProvider.autoDispose.family<LotView, String>(
  (ref, id) => ref.watch(auctionRepositoryProvider).lot(id),
);

final lotBidsProvider =
    FutureProvider.autoDispose.family<List<BidEntry>, String>(
  (ref, id) => ref.watch(auctionRepositoryProvider).lotBids(id),
);

final consentTextProvider = FutureProvider.autoDispose<String>(
  (ref) => ref.watch(auctionRepositoryProvider).consentText(),
);

final createDraftProvider =
    NotifierProvider.autoDispose<CreateDraftNotifier, CreateDraft>(
        CreateDraftNotifier.new);

/// Refresh everything that lists the vendor's own auctions (and the home block).
void refreshMyAuctions(WidgetRef ref) {
  ref
    ..invalidate(myAuctionsProvider)
    ..invalidate(auctionStatsProvider)
    ..invalidate(liveAuctionsProvider);
}

/// The seller order for a won auction (null until the buyer has paid).
final saleOrderProvider = FutureProvider.autoDispose.family<SaleOrder?, String>(
  (ref, orderId) => ref.watch(auctionRepositoryProvider).saleOrder(orderId),
);

/// Lots this vendor has won and still has to pay for (full detail, so the amount due and the deadline are known).
/// The cart lists these next to wholesale stock.
final wonLotsToPayProvider = FutureProvider.autoDispose<List<LotView>>((ref) async {
  final repo = ref.watch(auctionRepositoryProvider);
  final mine = await repo.myLots();
  final won = mine.items
      .where((l) => l.status == 'AWAITING_PAYMENT' && l.my.isWinner)
      .toList();
  return Future.wait(won.map((l) => repo.lot(l.id)));
});

/// Ids of the lots this vendor won and still has to pay for. One list call, no per-lot detail requests: the header
/// cart badge only needs a count, and used to trigger 1 + N requests on every home load via [wonLotsToPayProvider].
final wonLotIdsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final mine = await ref.watch(auctionRepositoryProvider).myLots();
  return [
    for (final l in mine.items)
      if (l.status == 'AWAITING_PAYMENT' && l.my.isWinner) l.id
  ];
});

/// Wins the vendor took out of the cart view. The win itself is untouched (still payable from the lot
/// page until its deadline); this only decides whether the Cart lists it.
class DismissedWins extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void dismiss(String id) => state = {...state, id};
  void restore(String id) => state = {...state}..remove(id);
}

final dismissedWinsProvider =
    NotifierProvider<DismissedWins, Set<String>>(DismissedWins.new);

/// Wins shown in the Cart (not removed by the vendor).
final cartWinsProvider = Provider.autoDispose<List<LotView>>((ref) {
  final gone = ref.watch(dismissedWinsProvider);
  final all = ref.watch(wonLotsToPayProvider).asData?.value ?? const <LotView>[];
  return all.where((l) => !gone.contains(l.id)).toList();
});

/// How many won lots the Cart lists (badge in the home header) - cheap, see [wonLotIdsProvider].
final cartWinsCountProvider = Provider.autoDispose<int>((ref) {
  final gone = ref.watch(dismissedWinsProvider);
  final ids = ref.watch(wonLotIdsProvider).asData?.value ?? const <String>[];
  return ids.where((id) => !gone.contains(id)).length;
});
