import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/lot_cards.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/core/utils/polling.dart';

const _sorts = [
  ('ending', 'Ending soon'),
  ('new', 'Newly listed'),
  ('price_asc', 'Price: low to high'),
  ('price_desc', 'Price: high to low'),
  ('bids', 'Most bids'),
];

const _bands = <(String, num?, num?)>[
  ('Under ₹10,000', null, 10000),
  ('₹10,000 – ₹50,000', 10000, 50000),
  ('₹50,000 – ₹1,00,000', 50000, 100000),
  ('₹1,00,000 – ₹5,00,000', 100000, 500000),
  ('Above ₹5,00,000', 500000, null),
];

/// B2B lots a vendor can bid on — the customer Auctions page, for vendors:
/// Live · Upcoming · Ended · My Bids, banner, category tiles, filters, grid.
class LotBrowse extends ConsumerStatefulWidget {
  const LotBrowse({super.key});

  @override
  ConsumerState<LotBrowse> createState() => _LotBrowseState();
}

class _LotBrowseState extends ConsumerState<LotBrowse> {
  LotQuery _q = const LotQuery();
  bool _myBids = false;
  final _search = TextEditingController();
  Timer? _debounce;
  Timer? _poll;
  // optimistic heart state: id → on
  final Map<String, bool> _watch = {};

  @override
  void initState() {
    super.initState();
    // Prices and end times move: refresh quietly while the page is open.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !_myBids && screenActive(context)) {
        ref.invalidate(lotsProvider(_q));
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _poll?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _set(LotQuery q) => setState(() {
        _q = q;
        _myBids = false;
      });

  Future<void> _refresh() async {
    if (_myBids) {
      ref.invalidate(myLotsProvider);
      await ref.read(myLotsProvider.future);
    } else {
      ref.invalidate(lotsProvider(_q));
      await ref.read(lotsProvider(_q).future);
    }
  }

  Future<void> _open(LotView l) async {
    await context.push(Routes.lotDetail(l.id));
    if (mounted) await _refresh();
  }

  Future<void> _toggleWatch(LotView l) async {
    final on = !(_watch[l.id] ?? l.watching);
    setState(() => _watch[l.id] = on);
    try {
      await ref.read(auctionRepositoryProvider).watchLot(l.id, on: on);
      if (on && l.isUpcoming && mounted) {
        showAppToast(context, "We'll remind you when it starts.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _watch[l.id] = !on);
        showAppToast(context, errorText(e, 'Could not update.'), error: true);
      }
    }
  }

  LotView _w(LotView l) => _watch.containsKey(l.id)
      ? LotView.fromJson({..._raw(l), 'watching': _watch[l.id]},
          offset: l.serverOffset)
      : l;

  // LotView has no toJson; rebuild just enough to flip the heart.
  Map<String, dynamic> _raw(LotView l) => {
        'id': l.id,
        'auction_number': l.number,
        'title': l.title,
        'description': l.description,
        'image_url': l.imageUrl,
        'images': l.images,
        'status': l.status,
        'quantity': l.quantity,
        'unit_price': l.unitPrice,
        'seller': {'name': l.sellerName},
        'start_price': l.startPrice,
        'current_price': l.currentPrice,
        'min_next_bid': l.minNextBid,
        'increment': l.increment,
        'reserve_status': l.reserveStatus,
        'registration_fee': l.registrationFee,
        'fee_policy': l.feePolicy,
        'bid_count': l.bidCount,
        'bidder_count': l.bidderCount,
        'starts_at': l.startsAt?.toUtc().toIso8601String(),
        'ends_at': l.endsAt?.toUtc().toIso8601String(),
        'final_price': l.finalPrice,
        'leader_alias': l.leaderAlias,
        'view_count': l.viewCount,
        'badge': l.badge,
        'category_name': l.categoryName,
        'video_url': l.videoUrl,
        'my': {
          'registered': l.my.registered,
          'is_leading': l.my.isLeading,
          'my_max': l.my.myMax,
          'is_winner': l.my.isWinner,
          'fee_paid': l.my.feePaid,
          'amount_due': l.my.amountDue,
        },
      };

  @override
  Widget build(BuildContext context) {
    final lots = _myBids ? null : ref.watch(lotsProvider(_q));
    final counts = lots?.value?.counts ?? const <String, int>{};
    return Column(children: [
      _tabs(counts),
      Expanded(child: _myBids ? _myBody() : _body(lots!)),
    ]);
  }

  Widget _tabs(Map<String, int> counts) {
    Widget tab(String key, String label, {int? count}) {
      final on = !_myBids && _q.tab == key;
      return InkWell(
        onTap: () => _set(_q.copyWith(tab: key, categoryId: null, brand: null)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: on ? kLotIndigo : Colors.transparent, width: 3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: jakarta(15,
                    w: FontWeight.w700, color: on ? kLotIndigo : kLotMuted)),
            if (count != null) ...[
              const SizedBox(width: 6),
              on
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                          color: kLotIndigo,
                          borderRadius: BorderRadius.circular(9)),
                      child: Text('$count',
                          style: jakarta(11, color: Colors.white)))
                  : Text('$count',
                      style: jakarta(14,
                          w: FontWeight.w600, color: const Color(0xFF8A93AB))),
            ],
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: kLotBorder))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        tab('live', 'Live', count: counts['live']),
        tab('upcoming', 'Upcoming', count: counts['upcoming']),
        tab('ended', 'Ended', count: counts['ended']),
        InkWell(
          onTap: () => setState(() => _myBids = true),
          child: Container(
            padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: _myBids ? kLotIndigo : Colors.transparent,
                        width: 3))),
            child: Text('My Bids',
                style: jakarta(15,
                    w: FontWeight.w700,
                    color: _myBids ? kLotIndigo : kLotMuted)),
          ),
        ),
      ]),
    );
  }

  Widget _body(AsyncValue<LotList> lots) {
    final live = _q.tab == 'live';
    return RefreshIndicator(
      color: kLotIndigo,
      onRefresh: _refresh,
      child: lots.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => lots.value == null
            ? const Center(child: CircularProgressIndicator(color: kLotIndigo))
            : const SizedBox.shrink(),
        error: (e, _) => ListView(children: [
          ErrorState(
              message: errorText(e, 'Could not load B2B lots.'),
              onRetry: () => ref.invalidate(lotsProvider(_q)))
        ]),
        data: (d) => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (live && !_q.hasFilters) SliverToBoxAdapter(child: _banner()),
            if (d.categories.isNotEmpty)
              SliverToBoxAdapter(child: _categories(d)),
            SliverToBoxAdapter(child: _chips(d)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Text('${d.total} lot${d.total == 1 ? '' : 's'}',
                    style: jakarta(19)),
              ),
            ),
            if (d.items.isEmpty)
              SliverToBoxAdapter(child: _empty())
            else
              _grid(d.items),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.fromLTRB(32, 30, 32, 30),
        child: _q.hasFilters
            ? Column(children: [
                Text('No lots match your filters',
                    style: jakarta(17), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: () => _set(LotQuery(tab: _q.tab)),
                    child: const Text('Clear filters')),
              ])
            : EmptyState(
                icon: PhosphorIconsRegular.buildings,
                title:
                    'No ${_q.tab == 'ended' ? 'recently ended' : _q.tab} lots',
                message:
                    'Business lots listed by other verified vendors show up here for you to bid on.'),
      );

  Widget _banner() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
              aspectRatio: 1200 / 448,
              child: Image.asset('assets/images/auction_banner.jpg',
                  fit: BoxFit.cover)),
        ),
      );

  Widget _categories(LotList d) {
    ({IconData icon, Color bg, Color fg}) look(String name, int i) {
      final n = name.toLowerCase();
      if (n.contains('mobile') || n.contains('phone')) {
        return (
          icon: PhosphorIconsFill.deviceMobile,
          bg: const Color(0xFFE3EDFF),
          fg: const Color(0xFF2F6BFF)
        );
      }
      if (n.contains('laptop') || n.contains('computer')) {
        return (
          icon: PhosphorIconsFill.laptop,
          bg: const Color(0xFFFFE4E8),
          fg: const Color(0xFFE5395A)
        );
      }
      if (n.contains('access') || n.contains('audio') || n.contains('head')) {
        return (
          icon: PhosphorIconsFill.headphones,
          bg: const Color(0xFFDDF5E4),
          fg: const Color(0xFF16A34A)
        );
      }
      if (n.contains('electr')) {
        return (
          icon: PhosphorIconsFill.cpu,
          bg: const Color(0xFFFFEBD6),
          fg: const Color(0xFFF08A1C)
        );
      }
      if (n.contains('part') || n.contains('repair')) {
        return (
          icon: PhosphorIconsFill.wrench,
          bg: const Color(0xFFEBE5FF),
          fg: kLotIndigo
        );
      }
      const fgs = [
        Color(0xFF2F6BFF),
        Color(0xFFE5395A),
        Color(0xFF16A34A),
        Color(0xFFF08A1C),
        kLotIndigo
      ];
      final c = fgs[i % fgs.length];
      return (
        icon: PhosphorIconsFill.package,
        bg: c.withValues(alpha: .12),
        fg: c
      );
    }

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        itemCount: d.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = d.categories[i];
          final on = _q.categoryId == c.id;
          final l = look(c.name, i);
          return GestureDetector(
            onTap: () => _set(_q.copyWith(categoryId: on ? null : c.id)),
            child: Container(
              width: 78,
              decoration: BoxDecoration(
                color: on ? kLotIndigoSoft : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: on ? kLotIndigo : kLotBorder, width: on ? 1.5 : 1),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: l.bg, borderRadius: BorderRadius.circular(12)),
                      child: Icon(l.icon, size: 22, color: l.fg),
                    ),
                    const SizedBox(height: 6),
                    Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dm(12, color: kLotInk, w: FontWeight.w700)),
                  ]),
            ),
          );
        },
      ),
    );
  }

  Widget _chips(LotList d) {
    Widget chip(String label,
            {required bool on,
            required VoidCallback onTap,
            bool arrow = false,
            VoidCallback? onClear}) =>
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: on ? kLotIndigoSoft : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: on ? kLotIndigo : const Color(0xFFC9CFE3),
                    width: 1.2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label,
                    style: dm(14,
                        color: on ? kLotIndigo : const Color(0xFF2B2F52),
                        w: FontWeight.w700)),
                if (on && onClear != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                      onTap: onClear,
                      child: const Icon(PhosphorIconsBold.x,
                          size: 13, color: kLotIndigo)),
                ] else if (arrow) ...[
                  const SizedBox(width: 4),
                  const Icon(PhosphorIconsBold.caretDown,
                      size: 13, color: Color(0xFF2B2F52)),
                ],
              ]),
            ),
          ),
        );

    final sortOn = _q.sort != 'ending';
    final bandLabel = _bands
        .where((b) => b.$2 == _q.min && b.$3 == _q.max)
        .map((b) => b.$1)
        .firstOrNull;
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 9, 6, 9),
        children: [
          chip(sortOn ? _sorts.firstWhere((s) => s.$1 == _q.sort).$2 : 'Sort',
              on: sortOn,
              arrow: true,
              onTap: () async {
                final v = await _pick<String>(
                    'Sort by', _q.sort, [for (final s in _sorts) (s.$1, s.$2)]);
                if (v != null) _set(_q.copyWith(sort: v));
              },
              onClear: () => _set(_q.copyWith(sort: 'ending'))),
          chip(_q.brand ?? 'Brand',
              on: _q.brand != null,
              arrow: true,
              onTap: () async {
                if (d.brands.isEmpty && _q.brand == null) {
                  showAppToast(context, 'No brands to filter yet.');
                  return;
                }
                final v = await _pick<String>('Brand', _q.brand, [
                  for (final b in d.brands) (b.name, '${b.name}  (${b.count})')
                ]);
                if (v != null) _set(_q.copyWith(brand: v));
              },
              onClear: () => _set(_q.copyWith(brand: null))),
          chip(bandLabel ?? 'Price Range',
              on: bandLabel != null,
              arrow: true,
              onTap: () async {
                final v = await _pick<int>('Price range', null,
                    [for (final (i, b) in _bands.indexed) (i, b.$1)]);
                if (v != null) {
                  _set(_q.copyWith(min: _bands[v].$2, max: _bands[v].$3));
                }
              },
              onClear: () => _set(_q.copyWith(min: null, max: null))),
        ],
      ),
    );
  }

  Future<T?> _pick<T>(String title, T? selected, List<(T, String)> options) =>
      showModalBottomSheet<T>(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        builder: (c) => SafeArea(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .7),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                      child: Text(title, style: jakarta(18))),
                  Flexible(
                    child: ListView(shrinkWrap: true, children: [
                      for (final o in options)
                        ListTile(
                          title: Text(o.$2,
                              style: dm(15,
                                  color: kLotInk,
                                  w: o.$1 == selected
                                      ? FontWeight.w800
                                      : FontWeight.w600)),
                          trailing: o.$1 == selected
                              ? const Icon(Icons.check_rounded,
                                  color: kLotIndigo)
                              : null,
                          onTap: () => Navigator.pop(c, o.$1),
                        ),
                    ]),
                  ),
                ]),
          ),
        ),
      );

  Widget _grid(List<LotView> items) {
    final rows = (items.length + 1) ~/ 2;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      sliver: SliverList.separated(
        itemCount: rows,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, r) {
          Widget card(LotView l) => LotGridCard(
                key: ValueKey(l.id),
                l: _w(l),
                onOpen: () => _open(l),
                onWatch: () => _toggleWatch(l),
                onExpired: () => ref.invalidate(lotsProvider(_q)),
              );
          final a = items[r * 2];
          final b = r * 2 + 1 < items.length ? items[r * 2 + 1] : null;
          return IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: card(a)),
              const SizedBox(width: 12),
              Expanded(child: b == null ? const SizedBox.shrink() : card(b)),
            ]),
          );
        },
      ),
    );
  }

  // ── My Bids ──────────────────────────────────────────────────────────

  Widget _myBody() {
    final my = ref.watch(myLotsProvider);
    return RefreshIndicator(
      color: kLotIndigo,
      onRefresh: _refresh,
      child: my.when(skipLoadingOnReload: true, skipError: true, 
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kLotIndigo)),
        error: (e, _) => ListView(children: [
          ErrorState(
              message: errorText(e, 'Could not load your bids.'),
              onRetry: () => ref.invalidate(myLotsProvider))
        ]),
        data: (d) => d.items.isEmpty
            ? ListView(children: const [
                EmptyState(
                    icon: PhosphorIconsRegular.gavel,
                    title: 'No bids yet',
                    message:
                        'Lots you register for or bid on will be listed here.')
              ])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                itemCount: d.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final l = d.items[i];
                  return _MyBidRow(l: l, onOpen: () => _open(l));
                },
              ),
      ),
    );
  }
}

class _MyBidRow extends StatelessWidget {
  const _MyBidRow({required this.l, required this.onOpen});
  final LotView l;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final live = l.isLive && !l.overByClock;
    final lead = l.my.isLeading;
    final tag = l.my.isWinner
        ? ('You won', const Color(0xFF15803D), const Color(0xFFDDF5E4))
        : live
            ? (lead
                ? (
                    "You're winning",
                    const Color(0xFF15803D),
                    const Color(0xFFDDF5E4)
                  )
                : (
                    "You're outbid",
                    const Color(0xFF8A5A00),
                    const Color(0xFFFFF0C2)
                  ))
            : null;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kLotBorder),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ProductThumb(l.cover, size: 80, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(14.5, h: 1.25)),
              const SizedBox(height: 6),
              Text(live ? 'Current bid' : 'Final', style: dm(12.5)),
              Text(formatInr(l.finalPrice ?? l.currentPrice),
                  style: jakarta(21)),
              if (live)
                Ticking((_) => Text(timeLeftLabel(l.timeLeft ?? Duration.zero),
                    style: dm(12, color: kLotLive, w: FontWeight.w700))),
              if (tag != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: tag.$3, borderRadius: BorderRadius.circular(8)),
                  child: Text(tag.$1, style: jakarta(10.5, color: tag.$2)),
                ),
              ],
            ]),
          ),
          const Icon(PhosphorIconsRegular.caretRight, size: 20, color: kLotInk),
        ]),
      ),
    );
  }
}
