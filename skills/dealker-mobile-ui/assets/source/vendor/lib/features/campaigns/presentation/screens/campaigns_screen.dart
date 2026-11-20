import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/campaigns/application/campaign_providers.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';
import 'package:dealker_vendor/features/campaigns/presentation/widgets/campaign_common.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_bottom_nav.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/premium_ui.dart';

/// Campaigns tab — the vendor's sponsored ads, ad wallet and 30-day results.
class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({super.key});

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends ConsumerState<CampaignsScreen> {
  CampaignTab _tab = CampaignTab.all;

  Future<void> _refresh() async {
    ref
      ..invalidate(campaignsProvider)
      ..invalidate(adsOverviewProvider);
    await ref
        .read(campaignsProvider(_tab).future)
        .catchError((_) => const CampaignList(items: [], total: 0, counts: {}));
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(adsOverviewProvider);
    final list = ref.watch(campaignsProvider(_tab));
    // Tab counts come from the unfiltered list so they never jump around.
    final counts =
        ref.watch(campaignsProvider(CampaignTab.all)).asData?.value.counts;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AuctionAppBar(
        title: 'Campaigns',
        subtitle: counts == null
            ? 'Sponsored ads'
            : '${CampaignTab.all.count(counts)} ${CampaignTab.all.count(counts) == 1 ? 'campaign' : 'campaigns'}',
        onBack: () => context.go(Routes.home),
        actions: [
          IconButton(
              tooltip: 'Ad wallet',
              onPressed: () => context.push(Routes.adWallet),
              icon: const Icon(PhosphorIconsRegular.wallet,
                  color: AppColors.navy)),
        ],
      ),
      bottomNavigationBar: const HomeBottomNav(current: NavTab.campaigns),
      // The empty state carries its own "Create Campaign" button; a second
      // floating one would sit on top of it.
      floatingActionButton: counts != null && CampaignTab.all.count(counts) == 0
          ? null
          : _CreateFab(onTap: () => context.push(Routes.campaignCreate)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            overview.when(skipLoadingOnReload: true, skipError: true, 
              loading: () => const _OverviewSkeleton(),
              error: (e, _) => AdNotice(
                  message: errorText(e, 'Could not load your ad summary.'),
                  icon: PhosphorIconsFill.warningCircle,
                  color: AppColors.rose,
                  bg: AppColors.roseSoft,
                  action: TextButton(
                      onPressed: () => ref.invalidate(adsOverviewProvider),
                      child: const Text('Retry'))),
              data: (o) => _Overview(o),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: CampaignTab.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final t = CampaignTab.values[i];
                  return _TabPill(
                    label: t.label,
                    count: counts == null ? null : t.count(counts),
                    selected: _tab == t,
                    onTap: () => setState(() => _tab = t),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            list.when(skipLoadingOnReload: true, skipError: true, 
              loading: () => Column(children: const [
                _CardSkeleton(),
                SizedBox(height: 12),
                _CardSkeleton(),
              ]),
              error: (e, _) => SizedBox(
                height: 300,
                child: ErrorState(
                    message: errorText(e, 'Could not load your campaigns.'),
                    onRetry: () => ref.invalidate(campaignsProvider)),
              ),
              data: (page) => page.items.isEmpty
                  ? _Empty(
                      tab: _tab,
                      onCreate: () => context.push(Routes.campaignCreate))
                  : Column(children: [
                      for (final c in page.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CampaignCard(
                              c: c,
                              onTap: () =>
                                  context.push(Routes.campaignDetail(c.id))),
                        ),
                    ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateFab extends StatelessWidget {
  const _CreateFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: kAdBlue,
        elevation: 4,
        shadowColor: kAdBlue.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(PhosphorIconsBold.plus, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Create Campaign',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5)),
            ]),
          ),
        ),
      );
}

class _TabPill extends StatelessWidget {
  const _TabPill(
      {required this.label,
      required this.count,
      required this.selected,
      required this.onTap});
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? kAdBlue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? kAdBlue : AppColors.border, width: 1.2),
          ),
          child: Text(count == null ? label : '$label ($count)',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textSecondary)),
        ),
      );
}

/// Wallet hero + 30-day result tiles.
class _Overview extends StatelessWidget {
  const _Overview(this.o);
  final AdsOverview o;

  @override
  Widget build(BuildContext context) {
    final w = o.wallet;
    final t = o.totals;
    return Column(children: [
      GestureDetector(
        onTap: () => context.push(Routes.adWallet),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: kAdGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: kAdBlue.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
                right: -2,
                top: 18,
                child: Art3D(A3.sell('paid'), size: 88, float: true)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(PhosphorIconsFill.wallet,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              const Text('Ad wallet',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(PhosphorIconsBold.plus, size: 13, color: kAdBlue),
                  SizedBox(width: 4),
                  Text('Add money',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: kAdBlue)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Text(formatInr(w.balance),
                style:
                    heading(size: 32, color: Colors.white, w: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
                w.activeCampaigns == 0
                    ? 'No campaigns running'
                    : '${w.activeCampaigns} live · ${formatInr(w.dailyCommitment)} daily budget',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            if (w.lowBalance) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10)),
                child: const Row(children: [
                  Icon(PhosphorIconsFill.warning,
                      size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Balance is low — ads stop when it runs out.',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ],
          ]),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
            child: StatTile(
                label: 'Ad spend',
                value: formatInr(t.spend),
                hint: 'last ${o.days} days',
                icon: PhosphorIconsFill.coins)),
        const SizedBox(width: 10),
        Expanded(
            child: StatTile(
                label: 'Clicks',
                value: compact(t.clicks),
                hint: '${compact(t.impressions)} views',
                icon: PhosphorIconsFill.cursorClick,
                color: AppColors.violet,
                bg: AppColors.violetSoft)),
        const SizedBox(width: 10),
        Expanded(
            child: StatTile(
                label: 'Orders',
                value: '${t.orders}',
                hint: t.sales > 0 ? '${formatInr(t.sales)} sales' : 'from ads',
                icon: PhosphorIconsFill.shoppingBag,
                color: AppColors.mint,
                bg: AppColors.mintSoft)),
      ])),
    ]);
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.c, required this.onTap});
  final CampaignItem c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final live = c.status == CampaignStatus.active;
    final note = switch (c.status) {
      CampaignStatus.rejected => c.rejectedReason,
      CampaignStatus.suspended => c.suspendedReason,
      CampaignStatus.paused when c.pausedReason == 'OUT_OF_FUNDS' =>
        'Paused — your ad wallet ran out of money.',
      _ => null,
    };
    return GestureDetector(
      onTap: onTap,
      child: HomeCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: heading(size: 16.5)),
                    const SizedBox(height: 4),
                    Text('${c.number}  ·  ${dateRange(c.startsOn, c.endsOn)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ]),
            ),
            const SizedBox(width: 8),
            CampaignStatusPill(c.status),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            TargetingChip(c.targeting),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  '${c.productCount} ${c.productCount == 1 ? 'product' : 'products'}'
                  '${c.targeting == Targeting.manual ? '  ·  ${c.keywordCount} keywords' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary)),
            ),
            const SizedBox(width: 8),
            Text('${inr2(c.defaultBid)}/click',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
          ]),
          if (live) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: UsageBar(c.todayUsed)),
              const SizedBox(width: 10),
              Text(
                  '${formatInr(c.spentToday)} / ${formatInr(c.dailyBudget)} today',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ],
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(PhosphorIconsFill.info,
                  size: 16, color: AppColors.rose),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(note,
                      style: const TextStyle(
                          fontSize: 12.5, height: 1.3, color: AppColors.rose))),
            ]),
          ],
          if (c.impressions > 0 || c.clicks > 0) ...[
            const Divider(height: 22),
            Row(children: [
              _Mini('Views', compact(c.impressions)),
              _Mini('Clicks', compact(c.clicks)),
              _Mini('CTR', percent(c.ctr)),
              _Mini('Spend', formatInr(c.spend)),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: heading(size: 15)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ]),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.tab, required this.onCreate});
  final CampaignTab tab;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => ArtEmpty(
        art: tab == CampaignTab.all ? A3.extra('megaphone') : A3.cart('calendar'),
        title: tab == CampaignTab.all
            ? 'Run your first campaign'
            : 'No ${tab.label.toLowerCase()} campaigns',
        message: tab == CampaignTab.all
            ? 'Promote your products at the top of search and reach more shoppers. You only pay when someone taps your ad.'
            : 'Campaigns in this state will show up here.',
        action: tab == CampaignTab.all
            ? SizedBox(
                width: 220,
                child: AuctionButton(
                    label: 'Create Campaign',
                    icon: PhosphorIconsBold.plus,
                    height: 48,
                    onPressed: onCreate))
            : null,
      );
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: 150,
        decoration: BoxDecoration(
            color: const Color(0xFFEFF2FA),
            borderRadius: BorderRadius.circular(14)),
      );
}

class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
            height: 128,
            decoration: BoxDecoration(
                color: const Color(0xFFEFF2FA),
                borderRadius: BorderRadius.circular(20))),
        const SizedBox(height: 12),
        Row(children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
                child: Container(
                    height: 84,
                    decoration: BoxDecoration(
                        color: const Color(0xFFEFF2FA),
                        borderRadius: BorderRadius.circular(14)))),
          ],
        ]),
      ]);
}
