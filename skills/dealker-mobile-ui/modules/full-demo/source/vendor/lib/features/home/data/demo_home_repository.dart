import 'package:dio/dio.dart';

import 'package:dealker_vendor/features/home/data/home_models.dart';
import 'package:dealker_vendor/features/home/data/home_repository.dart';

/// DEMO ONLY — returns made-up numbers so the home layout can be reviewed
/// without a vendor login. Active only when `.env` has `DEMO_HOME=true`
/// (never set in production). Delete this file + the switch in
/// `home_providers.dart` / `auth_controller.dart` when real data is verified.
class DemoHomeRepository extends HomeRepository {
  DemoHomeRepository() : super(Dio());

  @override
  Future<PagedTotal<SellerOrderRow>> sellerOrders(
      {String? status, int limit = 1}) async {
    if (status == null) return const PagedTotal(items: [], total: 18);
    return PagedTotal(items: [
      SellerOrderRow(
        id: 'o1',
        number: 'DK-2084',
        itemCount: 1,
        status: 'ORDER_PLACED',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ], total: 6);
  }

  @override
  Future<PagedTotal<B2bRequirementRow>> b2bRequirements(
      {required String scope, int limit = 1}) async {
    if (scope == 'quoted') return const PagedTotal(items: [], total: 12);
    return PagedTotal(items: [
      B2bRequirementRow(
        id: 'r1',
        productName: 'iPhone 13',
        quantity: 50,
        city: 'Delhi',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ], total: 8);
  }

  @override
  Future<PagedTotal<SellRequestRow>> pendingSellRequests(
          {int limit = 3}) async =>
      PagedTotal(items: [
        SellRequestRow(
          id: 's1',
          model: 'iPhone 14 Pro',
          condition: 'Grade A',
          expectedPrice: 31500,
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
      ], total: 4);

  @override
  Future<WalletSummary> walletSummary() async =>
      const WalletSummary(available: 24850, nextPayout: 6200, paid: 428750);

  @override
  Future<AuctionStats> auctionStats() async =>
      const AuctionStats(live: 6, endingSoon: 2);

  @override
  Future<List<AuctionRow>> liveAuctions({int limit = 2}) async => [
        AuctionRow(
          id: 'a1',
          title: 'iPhone 13 128GB Space Black',
          imageUrl: null,
          bidCount: 18,
          endsAt: DateTime.now().add(const Duration(minutes: 24, seconds: 16)),
          audience: 'B2C',
        ),
      ];

  @override
  Future<List<CampaignRow>> activeCampaigns({int limit = 2}) async => const [
        CampaignRow(
            id: 'c1',
            name: 'Diwali Mobile Boost',
            status: 'ACTIVE',
            spentToday: 320,
            dailyBudget: 1000)
      ];
}
