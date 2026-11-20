import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/auctions/presentation/screens/lot_browse.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/home/presentation/widgets/home_bottom_nav.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/premium_ui.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// Auction tab: the vendor's own auctions, and B2B lots from other vendors to bid on.
class AuctionsHubScreen extends ConsumerStatefulWidget {
  const AuctionsHubScreen({super.key});

  @override
  ConsumerState<AuctionsHubScreen> createState() => _AuctionsHubScreenState();
}

class _AuctionsHubScreenState extends ConsumerState<AuctionsHubScreen> {
  int _section = 0; // 0 = My Auctions, 1 = B2B Lots

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const HomeBottomNav(current: NavTab.auction),
      floatingActionButton: _section == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.auctionCreate),
              backgroundColor: kAuctionBlue,
              elevation: 3,
              icon: const Icon(PhosphorIconsBold.plus, color: Colors.white),
              label: const Text('New Auction',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: HeroBanner(
              title: 'Auctions',
              subtitle: 'Sell stock to the highest bidder. Verified vendors and customers bid live.',
              art: 'assets/3d/profile/gavel.png',
              colors: [Color(0xFF6A4DF0), Color(0xFF3B26B8)],
              artSize: 96,
            ),
          ),
          const SizedBox(height: 12),
          _SectionTabs(
              index: _section, onChanged: (i) => setState(() => _section = i)),
          Expanded(
            child: _section == 0 ? const _MyAuctions() : const LotBrowse(),
          ),
        ]),
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['My Auctions', 'B2B Lots'];
    return Container(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.cardBorder))),
      child: Row(children: [
        for (final (i, l) in labels.indexed)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color:
                                i == index ? kAuctionBlue : Colors.transparent,
                            width: 2.5))),
                child: Text(l,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color:
                            i == index ? kAuctionBlue : AppColors.textMuted)),
              ),
            ),
          ),
      ]),
    );
  }
}

// ── My Auctions ───────────────────────────────────────────────────────

class _MyAuctions extends ConsumerStatefulWidget {
  const _MyAuctions();

  @override
  ConsumerState<_MyAuctions> createState() => _MyAuctionsState();
}

class _MyAuctionsState extends ConsumerState<_MyAuctions> {
  MyAuctionTab _tab = MyAuctionTab.all;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(myAuctionsProvider(_tab));
    // "All" carries the per-status counts shown on the chips.
    final counts = ref.watch(myAuctionsProvider(MyAuctionTab.all)).value;

    String chip(MyAuctionTab t) {
      if (counts == null) return t.label;
      final n = t.statuses == null ? counts.all : counts.countOf(t.statuses!);
      return '${t.label} ($n)';
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: SizedBox(
          height: 36,
          child: Row(children: [
            for (final (i, t) in MyAuctionTab.values.indexed)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                  child: _Chip(
                      label: chip(t),
                      selected: t == _tab,
                      onTap: () => setState(() => _tab = t)),
                ),
              ),
          ]),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          color: kAuctionBlue,
          onRefresh: () async {
            refreshMyAuctions(ref);
            await ref.read(myAuctionsProvider(_tab).future);
          },
          child: list.when(skipLoadingOnReload: true, skipError: true, 
            loading: () => const _SkeletonList(),
            error: (e, _) => ListView(children: [
              ErrorState(
                  message: errorText(e, 'Could not load your auctions.'),
                  onRetry: () => ref.invalidate(myAuctionsProvider(_tab)))
            ]),
            data: (data) => data.items.isEmpty
                ? ListView(children: [
                    ArtEmpty(
                      art: 'assets/3d/profile/gavel.png',
                      title: _tab == MyAuctionTab.all
                          ? 'No auctions yet'
                          : 'No ${_tab.label.toLowerCase()} auctions',
                      message:
                          'Create a B2B auction for verified vendors, or a B2C auction for customers.',
                      action: SizedBox(
                          width: 190,
                          child: AuctionButton(
                              label: 'Create Auction',
                              height: 48,
                              icon: PhosphorIconsBold.plus,
                              onPressed: () =>
                                  context.push(Routes.auctionCreate))),
                    )
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: data.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _MyAuctionCard(data.items[i]),
                  ),
          ),
        ),
      ),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? kAuctionBlue : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: selected ? kAuctionBlue : AppColors.border, width: 1.2),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      );
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              height: 150,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F4FB),
                  borderRadius: BorderRadius.circular(16)),
            ),
        ],
      );
}

class _MyAuctionCard extends ConsumerWidget {
  const _MyAuctionCard(this.a);
  final AuctionItem a;

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final actions = <(String, IconData, String)>[
      if (a.canSubmit)
        ('submit', PhosphorIconsRegular.paperPlaneTilt, 'Submit for approval'),
      if (a.canRelist)
        ('relist', PhosphorIconsRegular.arrowsClockwise, 'Relist'),
      if (a.canCancel)
        ('cancel', PhosphorIconsRegular.prohibit, 'Cancel auction'),
    ];
    if (actions.isEmpty) {
      context.push(Routes.auctionDetail(a.id));
      return;
    }
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          for (final (key, icon, label) in [
            ('view', PhosphorIconsRegular.eye, 'View details'),
            ...actions
          ])
            ListTile(
              leading: Icon(icon,
                  color: key == 'cancel' ? AppColors.rose : AppColors.navy),
              title: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          key == 'cancel' ? AppColors.rose : AppColors.navy)),
              onTap: () => Navigator.pop(c, key),
            ),
          const SizedBox(height: 6),
        ]),
      ),
    );
    if (pick == null || !context.mounted) return;
    await runAuctionAction(context, ref, a, pick);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = a.isLive;
    return GestureDetector(
      onTap: () => context.push(Routes.auctionDetail(a.id)),
      child: HomeCard(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ProductThumb(a.cover, size: 62),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: AppColors.navy)),
                    const SizedBox(height: 5),
                    Row(children: [
                      AudienceChip(a.audience),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text('#${a.number}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.textMuted)),
                      ),
                    ]),
                  ]),
            ),
            const SizedBox(width: 8),
            StatusPill(a.status),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color: const Color(0xFFF6F8FE),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              _Stat(live || a.hasBids ? 'Highest bid' : 'Starting price',
                  formatInr(a.highest)),
              _Stat('Bids', '${a.bidCount}'),
              if (a.audience == AuctionAudience.b2b)
                _Stat('Lot', unitsLabel(a.quantity))
              else
                _Stat(
                    live ? 'Ends in' : 'Starts',
                    live
                        ? shortCountdown(a.endsAt, a.serverOffset)
                        : _shortDate(a.startsAt)),
            ]),
          ),
          if (a.status == 'REJECTED' && (a.rejectedReason ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(PhosphorIconsFill.warning,
                    size: 15, color: AppColors.rose),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(a.rejectedReason!,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.rose))),
              ]),
            ),
          const SizedBox(height: 6),
          Row(children: [
            const Text('View Details',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: kAuctionBlue)),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _menu(context, ref),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(PhosphorIconsBold.dotsThreeVertical,
                    size: 20, color: AppColors.textSecondary),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  static String _shortDate(DateTime? t) {
    if (t == null) return '—';
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${t.day} ${m[t.month - 1]}';
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
        ]),
      );
}

/// Shared by the card menu and the detail screen. Confirms destructive
/// actions, calls the API, refreshes lists and reports the outcome.
Future<void> runAuctionAction(
    BuildContext context, WidgetRef ref, AuctionItem a, String action) async {
  final repo = ref.read(auctionRepositoryProvider);
  var waiveReserve = false;
  switch (action) {
    case 'view':
      context.push(Routes.auctionDetail(a.id));
      return;
    case 'cancel':
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Cancel this auction?'),
          content: Text(a.registrationCount > 0
              ? 'Registered bidders will be refunded their fee in full. This cannot be undone.'
              : 'This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep it')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Cancel auction',
                    style: TextStyle(color: AppColors.rose))),
          ],
        ),
      );
      if (ok != true) return;
    case 'endnow':
      final belowReserve =
          a.reservePrice != null && a.highest < a.reservePrice!;
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, setS) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('End now and sell?'),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'The auction closes immediately and the top bid of ${formatInr(a.highest)} becomes the sale price. '
                      'The top bidder then has time to pay. This cannot be undone.'),
                  if (belowReserve) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppColors.amberSoft,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(
                          'The top bid is below your reserve price of ${formatInr(a.reservePrice!)}. '
                          'Without the option below the lot will NOT be sold and every bidder is refunded.',
                          style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: Color(0xFF7A4A07))),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: waiveReserve,
                      onChanged: (v) => setS(() => waiveReserve = v),
                      title: const Text('Sell to the top bidder anyway',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Keep running')),
              TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(
                      belowReserve && !waiveReserve
                          ? 'End (unsold)'
                          : 'End & sell',
                      style: const TextStyle(color: kAuctionBlue))),
            ],
          ),
        ),
      );
      if (go != true) return;
    default:
  }
  try {
    switch (action) {
      case 'cancel':
        await repo.cancel(a.id);
      case 'endnow':
        await repo.endNow(a.id, waiveReserve: waiveReserve);
      case 'submit':
        await repo.submit(a.id);
      case 'relist':
        await repo.relist(a.id);
    }
    refreshMyAuctions(ref);
    ref.invalidate(auctionDetailProvider(a.id));
    if (context.mounted) {
      showAppToast(
          context,
          switch (action) {
            'cancel' => 'Auction cancelled.',
            'endnow' => 'Auction ended. The top bidder can now pay.',
            'submit' => 'Submitted for approval.',
            _ => 'Relisted as a draft — review and submit it.',
          });
    }
  } catch (e) {
    if (context.mounted) showAppToast(context, errorText(e), error: true);
  }
}
