import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';

class _Action {
  const _Action(this.asset, this.label, this.route, {this.go = false});

  /// Custom icon in `assets/icons/`.
  final String asset;
  final String label;
  final String route;

  /// Bottom-nav destinations switch tabs (go); everything else stacks (push).
  final bool go;

  void open(BuildContext context) =>
      go ? context.go(route) : context.push(route);
}

// The tiles on the home grid (the last slot, "More", opens the full list).
const _homeActions = [
  _Action('orders', 'Orders', Routes.orders),
  _Action('my_orders', 'My orders', Routes.myOrders),
  _Action('add_product', 'Add product', Routes.productAdd),
  _Action('bulk_demand', 'Bulk demand', Routes.demand),
  _Action('wholesale', 'B2B market', Routes.wholesale, go: true),
  _Action('auction', 'Auction', Routes.auctions, go: true),
  _Action('repairs', 'Repairs', Routes.repairs, go: true),
  _Action('sell_phone', 'Sell phone', Routes.sellLeads),
  _Action('campaigns', 'Campaigns', Routes.campaigns),
  _Action('wallet', 'Wallet', Routes.wallet),
  _Action('payouts', 'Payouts', Routes.payouts),
];

// Everything the vendor can do, grouped, for the "View all" / "More" sheet.
const _groups = <(String, List<_Action>)>[
  (
    'Sell',
    [
      _Action('my_products', 'My products', Routes.products, go: true),
      _Action('add_product', 'Add product', Routes.productAdd),
      _Action('bulk_upload', 'Bulk upload', Routes.productBulk),
      _Action('orders', 'Orders', Routes.orders),
      _Action('abandoned_carts', 'Abandoned carts', Routes.abandonedCarts),
    ]
  ),
  (
    'Buy',
    [
      _Action('my_orders', 'My orders', Routes.myOrders),
      _Action('wholesale', 'Marketplace', Routes.wholesale, go: true),
      _Action('orders', 'Wholesale orders', Routes.wholesaleOrders),
    ]
  ),
  (
    'Wholesale & demand',
    [
      _Action('bulk_demand', 'Bulk demand', Routes.demand),
      _Action('wholesale', 'Marketplace', Routes.wholesale),
      _Action('orders', 'Wholesale orders', Routes.wholesaleOrders),
    ]
  ),
  (
    'Auctions & services',
    [
      _Action('auction', 'Auctions', Routes.auctions, go: true),
      _Action('create_auction', 'Create auction', Routes.auctionCreate),
      _Action('repairs', 'Repair requests', Routes.repairs),
      _Action('repair_prices', 'Repair prices', Routes.repairPrices),
      _Action('sell_requests', 'Sell-phone requests', Routes.sellLeads),
    ]
  ),
  (
    'Grow & money',
    [
      _Action('campaigns', 'Campaigns', Routes.campaigns, go: true),
      _Action('campaigns', 'Deals', Routes.deals),
      _Action('ad_wallet', 'Ad wallet', Routes.adWallet),
      _Action('wallet', 'Wallet', Routes.wallet),
      _Action('payouts', 'Payouts', Routes.payouts),
      _Action('business_profile', 'Business profile', Routes.businessProfile),
    ]
  ),
];

/// Opens the full, grouped list of everything the vendor can do.
void showAllActions(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 14),
          Text('All actions', style: heading(size: 20, w: FontWeight.w800)),
          for (final (title, items) in _groups) ...[
            const SizedBox(height: 18),
            Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.78,
              children: [
                for (final a in items)
                  _TileShell(
                    asset: a.asset,
                    label: a.label,
                    onTap: () {
                      Navigator.of(sheet).pop();
                      a.open(context);
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return HomeCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: SectionTitle(
              title: 'Quick actions',
              onViewAll: () => showAllActions(context),
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 4,
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.78,
            children: [
              for (final a in _homeActions)
                _TileShell(
                    asset: a.asset,
                    label: a.label,
                    onTap: () => a.open(context)),
              _TileShell(
                  label: 'More',
                  dots: true,
                  onTap: () => showAllActions(context)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TileShell extends StatelessWidget {
  const _TileShell(
      {this.asset,
      required this.label,
      required this.onTap,
      this.dots = false});
  final String? asset;
  final String label;
  final bool dots;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE6ECFA))),
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: dots
                      ? const Center(
                          child: Icon(Icons.more_horiz_rounded,
                              size: 30, color: AppColors.textSecondary))
                      : Image.asset('assets/icons/$asset.png',
                          filterQuality: FilterQuality.high),
                ),
                const SizedBox(height: 6),
                Text(label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: heading(
                        size: 11.5, color: AppColors.navy, w: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
}
