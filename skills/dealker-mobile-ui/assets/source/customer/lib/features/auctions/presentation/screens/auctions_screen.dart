import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/auctions/application/auction_browse.dart';
import 'package:dealker_app/features/auctions/data/auction_repository.dart';
import 'package:dealker_app/features/auctions/data/auction_view.dart';
import 'package:dealker_app/features/auctions/presentation/widgets/auction_actions.dart';
import 'package:dealker_app/features/auctions/presentation/widgets/auction_cards.dart';
import 'package:dealker_app/features/auctions/presentation/widgets/auction_ui.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_state.dart';
import 'package:dealker_app/routing/route_names.dart';
import 'package:dealker_app/shared/widgets/web_storefront_footer.dart';

/// Keeps auction cards usable at desktop sizes without changing native grids.
int auctionGridColumns(double width, {required bool isWeb}) =>
    isWeb ? (width / 300).floor().clamp(2, 4) : 2;

enum _MyFilter { all, live, upcoming, ended }

/// The Auctions page: Live · Upcoming · Ended · My Bids, on a white canvas.
class AuctionsScreen extends ConsumerStatefulWidget {
  const AuctionsScreen({super.key});

  @override
  ConsumerState<AuctionsScreen> createState() => _AuctionsScreenState();
}

class _AuctionsScreenState extends ConsumerState<AuctionsScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  Timer? _poll;
  bool _searching = false;
  bool _gridView = true;
  _MyFilter _my = _MyFilter.all;
  bool _alertsOn = false;
  bool _alertsBusy = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        ref.read(auctionBrowseProvider.notifier).loadMore();
      }
    });
    // Bids move prices and end times: refresh quietly while the page is open.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      final BrowseState s = ref.read(auctionBrowseProvider);
      if (mounted && !s.loading && s.tab != AuctionTab.myBids) {
        ref.read(auctionBrowseProvider.notifier).softRefresh();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _poll?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  AuctionBrowse get _n => ref.read(auctionBrowseProvider.notifier);

  Future<void> _refresh() async {
    await _n.refresh();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(
        const Duration(milliseconds: 450), () => _n.apply(query: v.trim()));
  }

  Future<void> _notifyMe() async {
    final AuthGateController gate = ref.read(authGateControllerProvider);
    final bool ok = await gate.protectRoute(context,
        route: '/auctions',
        title: 'Log in to get alerts',
        message: 'We will tell you when new auctions go live.');
    if (!ok || !mounted) return;
    setState(() => _alertsBusy = true);
    try {
      final AuctionRepository repo = ref.read(auctionRepositoryProvider);
      final bool next = !_alertsOn;
      await repo.setNewAuctionAlerts(on: next);
      if (!mounted) return;
      setState(() => _alertsOn = next);
      AppToast.show(
          context,
          next
              ? "We'll notify you when new auctions go live."
              : 'New-auction alerts are off.');
    } catch (_) {
      if (mounted) AppToast.show(context, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _alertsBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final BrowseState s = ref.watch(auctionBrowseProvider);
    // Logging in or out changes "You're winning", hearts and My Bids: reload.
    ref.listen<AuthState>(authStateProvider, (AuthState? prev, AuthState next) {
      if ((prev is AuthAuthenticated) != (next is AuthAuthenticated)) {
        ref.invalidate(auctionBrowseProvider);
      }
    });
    final AuctionActions actions =
        buildAuctionActions(context, ref, refresh: _refresh);
    final bool myBids = s.tab == AuctionTab.myBids;
    final Widget body =
        myBids ? _myBidsBody(s, actions) : _browseBody(s, actions);
    final bool bar =
        myBids && s.activeBidCount > 0 && s.bidsFailure == LoadFailure.none;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(children: <Widget>[
          _appBar(s),
          _tabs(s),
          Expanded(
            child: Stack(children: <Widget>[
              Positioned.fill(child: body),
              if (bar)
                Positioned(
                    left: 16.w,
                    right: 16.w,
                    bottom: 12.h + MediaQuery.paddingOf(context).bottom,
                    child: _bidsBar(s)),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────

  Widget _appBar(BrowseState s) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 8.w, 0),
      child: SizedBox(
        height: 52.h,
        child: Row(children: <Widget>[
          IconButton(
            icon: Icon(PhosphorIconsRegular.arrowLeft,
                color: AU.ink, size: 24.sp),
            onPressed: () => _searching
                ? _closeSearch()
                : (context.canPop() ? context.pop() : context.go('/home')),
          ),
          Expanded(
            child: _searching
                ? TextField(
                    controller: _search,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearch,
                    style: dm(15.sp, color: AU.ink, w: FontWeight.w600),
                    decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search auctions',
                        hintStyle: dm(15.sp)),
                  )
                : Text('Auctions', style: jakarta(19.sp)),
          ),
          if (!_searching)
            IconButton(
                icon: Icon(PhosphorIconsRegular.magnifyingGlass,
                    color: AU.ink, size: 24.sp),
                onPressed: () => setState(() => _searching = true)),
          if (_searching && _search.text.isNotEmpty)
            IconButton(
                icon: Icon(PhosphorIconsRegular.x, color: AU.ink, size: 22.sp),
                onPressed: () {
                  _search.clear();
                  _n.apply(query: '');
                }),
          _heart(s.counts.watching),
          IconButton(
              icon: Icon(PhosphorIconsRegular.bell, color: AU.ink, size: 24.sp),
              onPressed: () => context.push(RouteNames.notifications)),
        ]),
      ),
    );
  }

  void _closeSearch() {
    _search.clear();
    setState(() => _searching = false);
    if (ref.read(auctionBrowseProvider).query.isNotEmpty) _n.apply(query: '');
  }

  Widget _heart(int n) => InkResponse(
        onTap: () async {
          final bool ok = await ref
              .read(authGateControllerProvider)
              .protectRoute(context,
                  route: '/auctions/watching',
                  title: 'Log in to see your watchlist',
                  message: 'Please log in to watch auctions.');
          if (ok && mounted) await context.push('/auctions/watching');
          if (mounted) _n.softRefresh();
        },
        radius: 24.w,
        child: Padding(
          padding: EdgeInsets.all(10.w),
          child: Stack(clipBehavior: Clip.none, children: <Widget>[
            Icon(PhosphorIconsFill.heart, color: AU.live, size: 24.sp),
            if (n > 0)
              Positioned(
                right: -8.w,
                top: -8.h,
                child: Container(
                  constraints: BoxConstraints(minWidth: 17.w, minHeight: 17.w),
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  decoration: BoxDecoration(
                      color: AU.live,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5)),
                  alignment: Alignment.center,
                  child: Text(n > 99 ? '99+' : '$n',
                      style: jakarta(9.5.sp, color: Colors.white)),
                ),
              ),
          ]),
        ),
      );

  Widget _tabs(BrowseState s) {
    Widget tab(AuctionTab t, String label, int? count) {
      final bool on = s.tab == t;
      return InkWell(
        onTap: () => _n.setTab(t),
        child: Container(
          padding: EdgeInsets.fromLTRB(2.w, 10.h, 2.w, 10.h),
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: on ? AU.indigo : Colors.transparent, width: 3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Text(label,
                style: jakarta(15.sp,
                    w: FontWeight.w700, color: on ? AU.indigo : AU.muted)),
            if (count != null) ...<Widget>[
              SizedBox(width: 6.w),
              on
                  ? Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                      decoration: BoxDecoration(
                          color: AU.indigo,
                          borderRadius: BorderRadius.circular(9.r)),
                      child: Text('$count',
                          style: jakarta(11.sp, color: Colors.white)),
                    )
                  : Text('$count',
                      style:
                          jakarta(14.sp, w: FontWeight.w600, color: AU.grey)),
            ],
          ]),
        ),
      );
    }

    final int? bids =
        s.bidsLoaded && ref.read(authGateControllerProvider).isAuthenticated
            ? s.activeBidCount
            : null;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AU.border))),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            tab(AuctionTab.live, 'Live', s.counts.live),
            tab(AuctionTab.upcoming, 'Upcoming', s.counts.upcoming),
            tab(AuctionTab.ended, 'Ended', s.counts.ended),
            tab(AuctionTab.myBids, 'My Bids',
                s.tab == AuctionTab.myBids ? bids : null),
          ]),
    );
  }

  // ── browse tabs ────────────────────────────────────────────────────────────

  Widget _browseBody(BrowseState s, AuctionActions actions) {
    if (s.failure != LoadFailure.none && s.items.isEmpty) {
      return _stateBg(s.failure == LoadFailure.offline
          ? StateView(
              art: const CloudArt(offline: true),
              title: "You're offline",
              body: 'Check your internet connection to view auctions',
              button: StateButton(label: 'Try again', onTap: _refresh),
            )
          : StateView(
              art: const CloudArt(offline: false),
              title: "Couldn't load auctions",
              body: 'Please check your connection and try again.',
              button: StateButton(
                  label: 'Retry',
                  icon: PhosphorIconsRegular.arrowClockwise,
                  onTap: _refresh),
            ));
    }
    if (!s.loading && s.items.isEmpty && !s.hasFilters)
      return _stateBg(_emptyState(s));

    final bool live = s.tab == AuctionTab.live;
    final bool filtered = s.hasFilters || s.sort != AuctionSort.ending;
    final String? policy = s.items.isEmpty ? null : s.items.first.feePolicy;
    return RefreshIndicator(
      color: AU.indigo,
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          if (live && !s.hasFilters) SliverToBoxAdapter(child: _banner()),
          if (s.categories.isNotEmpty && s.tab != AuctionTab.myBids)
            SliverToBoxAdapter(child: _categories(s)),
          SliverPersistentHeader(
              pinned: true,
              delegate: _ChipsHeader(child: _chips(s), height: 56.h)),
          if (live) SliverToBoxAdapter(child: _trust(policy)),
          if (live && !filtered && s.endingSoon.length > 1) ...<Widget>[
            SliverToBoxAdapter(
                child: _sectionHead('Ending soon', 'See all', () {
              _scroll.animateTo(0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut);
            })),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 216.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: s.endingSoon.length,
                  separatorBuilder: (_, __) => SizedBox(width: 12.w),
                  itemBuilder: (_, int i) =>
                      EndingSoonCard(a: s.endingSoon[i], actions: actions),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(child: _resultsHead(s)),
          if (s.loading && s.items.isEmpty)
            _skeletonGrid()
          else if (s.items.isEmpty)
            SliverToBoxAdapter(child: _noMatches())
          else if (_gridView)
            _grid(s.items, actions)
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
              sliver: SliverList.separated(
                itemCount: s.items.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (_, int i) =>
                    AuctionRowCard(a: s.items[i], actions: actions),
              ),
            ),
          SliverToBoxAdapter(child: _listFoot(s)),
          if (kIsWeb &&
              MediaQuery.sizeOf(context).width >= 700 &&
              !s.hasMore &&
              !s.loadingMore)
            SliverToBoxAdapter(
                child: WebStorefrontFooter(onNavigate: context.go)),
        ],
      ),
    );
  }

  Widget _stateBg(Widget child) =>
      Container(color: AU.band, width: double.infinity, child: child);

  Widget _emptyState(BrowseState s) {
    switch (s.tab) {
      case AuctionTab.live:
        return StateView(
          art: const EmptyBoxArt(),
          title: 'No live auctions right now',
          body:
              "Turn on reminders and we'll notify you when new auctions are listed.",
          button: StateButton(
              label: _alertsOn ? 'Notifications on' : 'Notify me',
              icon: _alertsOn
                  ? PhosphorIconsFill.bellRinging
                  : PhosphorIconsRegular.bell,
              busy: _alertsBusy,
              onTap: _notifyMe),
        );
      case AuctionTab.upcoming:
        return StateView(
          art: const EmptyBoxArt(),
          title: 'No upcoming auctions',
          body:
              "Turn on reminders and we'll notify you when new auctions are listed.",
          button: StateButton(
              label: _alertsOn ? 'Notifications on' : 'Notify me',
              icon: _alertsOn
                  ? PhosphorIconsFill.bellRinging
                  : PhosphorIconsRegular.bell,
              busy: _alertsBusy,
              onTap: _notifyMe),
        );
      default:
        return StateView(
          art: const EmptyBoxArt(),
          title: 'No ended auctions yet',
          body: 'Results from the last 7 days appear here.',
          button: StateButton(
              label: 'See live auctions',
              onTap: () => _n.setTab(AuctionTab.live)),
        );
    }
  }

  Widget _noMatches() => Padding(
        padding: EdgeInsets.fromLTRB(32.w, 40.h, 32.w, 40.h),
        child: Column(children: <Widget>[
          Text('No auctions match your filters',
              style: jakarta(17.sp), textAlign: TextAlign.center),
          SizedBox(height: 6.h),
          Text('Try changing or clearing the filters.',
              style: dm(14.sp), textAlign: TextAlign.center),
          SizedBox(height: 16.h),
          StateButton(
              label: 'Clear filters',
              onTap: () {
                _search.clear();
                _n.clearFilters();
                _n.apply(query: '');
              }),
        ]),
      );

  Widget _banner() => Padding(
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: AspectRatio(
              aspectRatio: 1200 / 448,
              child: Image.asset('assets/images/auction_banner.jpg',
                  fit: BoxFit.cover)),
        ),
      );

  /// Category tiles (Mobiles · Laptops · …): only categories that have auctions in this tab.
  Widget _categories(BrowseState s) {
    ({IconData icon, Color bg, Color fg}) look(String name, int i) {
      final String n = name.toLowerCase();
      if (n.contains('mobile') || n.contains('phone'))
        return (
          icon: PhosphorIconsFill.deviceMobile,
          bg: const Color(0xFFE3EDFF),
          fg: const Color(0xFF2F6BFF)
        );
      if (n.contains('laptop') || n.contains('computer'))
        return (
          icon: PhosphorIconsFill.laptop,
          bg: const Color(0xFFFFE4E8),
          fg: const Color(0xFFE5395A)
        );
      if (n.contains('access') || n.contains('audio') || n.contains('head'))
        return (
          icon: PhosphorIconsFill.headphones,
          bg: const Color(0xFFDDF5E4),
          fg: const Color(0xFF16A34A)
        );
      if (n.contains('electr'))
        return (
          icon: PhosphorIconsFill.cpu,
          bg: const Color(0xFFFFEBD6),
          fg: const Color(0xFFF08A1C)
        );
      if (n.contains('part') || n.contains('repair'))
        return (
          icon: PhosphorIconsFill.wrench,
          bg: const Color(0xFFEBE5FF),
          fg: AU.indigo
        );
      const List<Color> fgs = <Color>[
        Color(0xFF2F6BFF),
        Color(0xFFE5395A),
        Color(0xFF16A34A),
        Color(0xFFF08A1C),
        AU.indigo
      ];
      return (
        icon: PhosphorIconsFill.package,
        bg: fgs[i % fgs.length].withValues(alpha: .12),
        fg: fgs[i % fgs.length]
      );
    }

    return SizedBox(
      height: 92.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
        itemCount: s.categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 10.w),
        itemBuilder: (_, int i) {
          final ({String id, String name, int count}) c = s.categories[i];
          final bool on = s.categoryId == c.id;
          final ({IconData icon, Color bg, Color fg}) l = look(c.name, i);
          return InkWell(
            borderRadius: BorderRadius.circular(16.r),
            onTap: () => _n.apply(categoryId: on ? null : c.id),
            child: Container(
              width: 78.w,
              decoration: BoxDecoration(
                color: on ? AU.indigoSoft : Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                    color: on ? AU.indigo : AU.border, width: on ? 1.5 : 1),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 38.w,
                      height: 38.w,
                      decoration: BoxDecoration(
                          color: l.bg,
                          borderRadius: BorderRadius.circular(12.r)),
                      child: Icon(l.icon, size: 22.sp, color: l.fg),
                    ),
                    SizedBox(height: 6.h),
                    Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dm(12.sp, color: AU.ink, w: FontWeight.w700)),
                  ]),
            ),
          );
        },
      ),
    );
  }

  Widget _chips(BrowseState s) {
    Widget chip(String label,
            {required bool on,
            required VoidCallback onTap,
            bool arrow = false,
            VoidCallback? onClear}) =>
        Padding(
          padding: EdgeInsets.only(right: 10.w),
          child: InkWell(
            borderRadius: BorderRadius.circular(22.r),
            onTap: onTap,
            child: Container(
              height: 38.h,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: on ? AU.indigoSoft : Colors.white,
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(
                    color: on ? AU.indigo : AU.chipBorder, width: 1.2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Text(label,
                    style: dm(14.sp,
                        color: on ? AU.indigo : const Color(0xFF2B2F52),
                        w: FontWeight.w700)),
                if (on && onClear != null) ...<Widget>[
                  SizedBox(width: 6.w),
                  InkWell(
                      onTap: onClear,
                      child: Icon(PhosphorIconsBold.x,
                          size: 13.sp, color: AU.indigo))
                ] else if (arrow) ...<Widget>[
                  SizedBox(width: 4.w),
                  Icon(PhosphorIconsBold.caretDown,
                      size: 13.sp, color: const Color(0xFF2B2F52))
                ],
              ]),
            ),
          ),
        );

    final bool ended = s.tab == AuctionTab.ended;
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(16.w, 9.h, 6.w, 9.h),
      children: <Widget>[
        chip(s.sort == AuctionSort.ending ? 'Sort' : s.sort.label,
            on: s.sort != AuctionSort.ending && !ended,
            arrow: true, onTap: () async {
          final AuctionSort? v = await pickOne<AuctionSort>(context,
              title: 'Sort by',
              selected: s.sort,
              options: <({AuctionSort value, String label, String? trailing})>[
                for (final AuctionSort o in AuctionSort.values)
                  (value: o, label: o.label, trailing: null),
              ]);
          if (v != null) _n.apply(sort: v);
        },
            onClear: s.sort == AuctionSort.ending
                ? null
                : () => _n.apply(sort: AuctionSort.ending)),
        chip(s.brand == null ? 'Brand' : s.brand!,
            on: s.brand != null,
            arrow: true,
            onTap: () async {
              if (s.brands.isEmpty && s.brand == null) {
                AppToast.show(context, 'No brands to filter yet.');
                return;
              }
              final String? v = await pickOne<String>(context,
                  title: 'Brand',
                  selected: s.brand,
                  clearLabel: s.brand == null ? null : 'Show all brands',
                  options: <({String value, String label, String? trailing})>[
                    for (final ({String name, int count}) b in s.brands)
                      (value: b.name, label: b.name, trailing: '${b.count}'),
                  ]);
              if (v != null) {
                _n.apply(brand: v);
              } else if (s.brand != null) {
                _n.apply(brand: null);
              }
            },
            onClear: () => _n.apply(brand: null)),
        chip(_priceLabel(s),
            on: s.min != null || s.max != null,
            arrow: true,
            onTap: () async {
              final ({num? min, num? max})? v =
                  await pickOne<({num? min, num? max})>(context,
                      title: 'Price',
                      selected: (min: s.min, max: s.max),
                      clearLabel:
                          (s.min != null || s.max != null) ? 'Any price' : null,
                      options: _priceBands);
              if (v != null) {
                _n.apply(min: v.min, max: v.max);
              } else if (s.min != null || s.max != null) {
                _n.apply(min: null, max: null);
              }
            },
            onClear: () => _n.apply(min: null, max: null)),
        if (!ended)
          chip('Registration open',
              on: s.registrationOpen,
              onTap: () => _n.apply(registrationOpen: !s.registrationOpen)),
      ],
    );
  }

  static final List<
          ({({num? min, num? max}) value, String label, String? trailing})>
      _priceBands =
      <({({num? min, num? max}) value, String label, String? trailing})>[
    (value: (min: null, max: 10000), label: 'Under ₹10,000', trailing: null),
    (
      value: (min: 10000, max: 25000),
      label: '₹10,000 – ₹25,000',
      trailing: null
    ),
    (
      value: (min: 25000, max: 50000),
      label: '₹25,000 – ₹50,000',
      trailing: null
    ),
    (
      value: (min: 50000, max: 100000),
      label: '₹50,000 – ₹1,00,000',
      trailing: null
    ),
    (value: (min: 100000, max: null), label: 'Above ₹1,00,000', trailing: null),
  ];

  String _priceLabel(BrowseState s) {
    if (s.min == null && s.max == null) return 'Price';
    for (final ({
      ({num? min, num? max}) value,
      String label,
      String? trailing
    }) b in _priceBands) {
      if (b.value.min == s.min && b.value.max == s.max) return b.label;
    }
    return 'Price';
  }

  Widget _trust(String? policy) => Padding(
        padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 6.h),
        child: Container(
          padding: EdgeInsets.fromLTRB(12.w, 11.h, 12.w, 11.h),
          decoration: BoxDecoration(
              color: const Color(0xFFF3F5FD),
              borderRadius: BorderRadius.circular(14.r)),
          child: Row(children: <Widget>[
            Icon(PhosphorIconsFill.shieldCheck,
                size: 26.sp, color: const Color(0xFF1FA463)),
            SizedBox(width: 10.w),
            Expanded(
              child: Text.rich(TextSpan(children: <InlineSpan>[
                TextSpan(
                    text:
                        'Verified sellers · Registration fee is deducted from price if you win. ',
                    style: dm(12.5.sp, color: const Color(0xFF3F4663), h: 1.4)),
                if (policy != null)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: InkWell(
                      onTap: () => showFeePolicy(context, policy),
                      child: Text('Fee policy ›',
                          style: dm(12.5.sp,
                              color: AU.indigo, w: FontWeight.w800)),
                    ),
                  ),
              ])),
            ),
          ]),
        ),
      );

  Widget _sectionHead(String title, String? action, VoidCallback? onAction) =>
      Padding(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
        child: Row(children: <Widget>[
          Expanded(child: Text(title, style: jakarta(20.sp))),
          if (action != null)
            InkWell(
                onTap: onAction,
                child: Row(children: <Widget>[
                  Text(action,
                      style: dm(14.sp, color: AU.indigo, w: FontWeight.w800)),
                  Icon(PhosphorIconsBold.caretRight,
                      size: 13.sp, color: AU.indigo)
                ])),
        ]),
      );

  Widget _resultsHead(BrowseState s) {
    Widget toggle(IconData icon, bool on, VoidCallback tap) => InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(8.r),
          child: Padding(
              padding: EdgeInsets.all(7.w),
              child:
                  Icon(icon, size: 21.sp, color: on ? AU.navy : AU.chipBorder)),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 18.h, 10.w, 8.h),
      child: Row(children: <Widget>[
        Expanded(
            child: Text(
                s.loading && s.items.isEmpty
                    ? 'Auctions'
                    : '${s.total} auction${s.total == 1 ? '' : 's'}',
                style: jakarta(19.sp))),
        toggle(PhosphorIconsFill.squaresFour, _gridView,
            () => setState(() => _gridView = true)),
        toggle(PhosphorIconsRegular.list, !_gridView,
            () => setState(() => _gridView = false)),
      ]),
    );
  }

  Widget _grid(List<AuctionView> items, AuctionActions actions) {
    return SliverLayoutBuilder(builder: (context, constraints) {
      final columns =
          auctionGridColumns(constraints.crossAxisExtent, isWeb: kIsWeb);
      final rows = (items.length + columns - 1) ~/ columns;
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
        sliver: SliverList.separated(
          itemCount: rows,
          separatorBuilder: (_, __) => SizedBox(height: 12.h),
          itemBuilder: (_, r) => IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) SizedBox(width: 12.w),
                  Expanded(
                      child: r * columns + column >= items.length
                          ? const SizedBox.shrink()
                          : AuctionCard(
                              key: ValueKey<String>(
                                  items[r * columns + column].id),
                              a: items[r * columns + column],
                              actions: actions)),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _skeletonGrid() =>
      SliverLayoutBuilder(builder: (context, constraints) {
        final columns =
            auctionGridColumns(constraints.crossAxisExtent, isWeb: kIsWeb);
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
          sliver: SliverList.separated(
            itemCount: 2,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (_, __) => SizedBox(
              height: 330.h,
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) SizedBox(width: 12.w),
                      const Expanded(child: AuctionCardSkeleton()),
                    ],
                  ]),
            ),
          ),
        );
      });

  Widget _listFoot(BrowseState s) {
    if (s.loadingMore) {
      return Padding(
          padding: EdgeInsets.all(20.h),
          child: const DealkerPageLoader());
    }
    if (s.items.isEmpty || s.hasMore) return SizedBox(height: 24.h);
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 22.h, 16.w, 30.h),
      child: Column(children: <Widget>[
        Text("You've seen all auctions", style: dm(13.sp)),
        TextButton(
            onPressed: () => _scroll.animateTo(0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut),
            child: Text('Back to top',
                style: dm(14.sp, color: AU.indigo, w: FontWeight.w800))),
      ]),
    );
  }

  // ── My Bids ────────────────────────────────────────────────────────────────

  Widget _myBidsBody(BrowseState s, AuctionActions actions) {
    if (!ref.read(authGateControllerProvider).isAuthenticated) {
      return _stateBg(StateView(
        art: const EmptyBoxArt(),
        title: 'Log in to see your bids',
        body: 'Your bids, reminders and results show up here.',
        button: StateButton(
            label: 'Log in',
            onTap: () async {
              final bool ok = await ref
                  .read(authGateControllerProvider)
                  .protectRoute(context,
                      route: '/auctions',
                      title: 'Log in to see your bids',
                      message: 'Please log in to take part in auctions.');
              if (ok && mounted) _n.refresh();
            }),
      ));
    }
    if (s.bidsFailure != LoadFailure.none) {
      return _stateBg(s.bidsFailure == LoadFailure.offline
          ? StateView(
              art: const CloudArt(offline: true),
              title: "You're offline",
              body: 'Check your internet connection to view auctions',
              button: StateButton(label: 'Try again', onTap: _refresh))
          : StateView(
              art: const CloudArt(offline: false),
              title: "Couldn't load auctions",
              body: 'Please check your connection and try again.',
              button: StateButton(
                  label: 'Retry',
                  icon: PhosphorIconsRegular.arrowClockwise,
                  onTap: _refresh)));
    }
    if (s.loading && !s.bidsLoaded) {
      return ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Bone(height: 150.h, radius: 16))
          ]);
    }
    final List<AuctionView> live =
        s.bids.where((AuctionView a) => a.isLive && !a.isOverByClock).toList();
    final List<AuctionView> up =
        s.bids.where((AuctionView a) => a.isUpcoming).toList();
    final List<AuctionView> ended =
        s.bids.where((AuctionView a) => a.isEnded || a.isOverByClock).toList();
    if (s.bids.isEmpty) {
      return _stateBg(StateView(
        art: const EmptyBoxArt(),
        title: 'No bids yet',
        body: 'Join an auction and your bids will show up here.',
        button: StateButton(
            label: 'See live auctions',
            onTap: () => _n.setTab(AuctionTab.live)),
      ));
    }
    Widget chip(String label, int n, _MyFilter f) {
      final bool on = _my == f;
      return Padding(
        padding: EdgeInsets.only(right: 8.w),
        child: InkWell(
          borderRadius: BorderRadius.circular(22.r),
          onTap: () => setState(() => _my = f),
          child: Container(
            height: 40.h,
            padding: EdgeInsets.symmetric(horizontal: 15.w),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: on ? AU.indigo : AU.pillGrey,
                borderRadius: BorderRadius.circular(22.r)),
            child: Text('$label $n',
                style: jakarta(13.5.sp,
                    w: FontWeight.w700,
                    color: on ? Colors.white : const Color(0xFF3F4663))),
          ),
        ),
      );
    }

    final bool showLive = _my == _MyFilter.all || _my == _MyFilter.live;
    final bool showUp = _my == _MyFilter.all || _my == _MyFilter.upcoming;
    final bool showEnded = _my == _MyFilter.all || _my == _MyFilter.ended;
    Widget section(String title, List<AuctionView> rows) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Padding(
              padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 10.h),
              child: Text(title, style: jakarta(19.sp))),
          for (final AuctionView a in rows)
            Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                child: AuctionRowCard(a: a, actions: actions)),
        ]);
    return RefreshIndicator(
      color: AU.indigo,
      onRefresh: _refresh,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 100.h),
        children: <Widget>[
          SizedBox(
            height: 40.h + 24.h,
            child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(16.w, 14.h, 6.w, 10.h),
                children: <Widget>[
                  chip('All', s.bids.length, _MyFilter.all),
                  chip('Live', live.length, _MyFilter.live),
                  chip('Upcoming', up.length, _MyFilter.upcoming),
                  chip('Ended', ended.length, _MyFilter.ended),
                ]),
          ),
          if (showLive && live.isNotEmpty) section('Your active bids', live),
          if (showUp && up.isNotEmpty) section('Upcoming', up),
          if (showEnded && ended.isNotEmpty) section('Ended', ended),
        ],
      ),
    );
  }

  Widget _bidsBar(BrowseState s) {
    final int outbid = s.bids.where((AuctionView a) => a.isOutbid).length;
    final int active =
        s.bids.where((AuctionView a) => a.isLive && !a.isOverByClock).length;
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 10.w, 10.h),
      decoration: BoxDecoration(
        color: AU.navy,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(children: <Widget>[
        Icon(PhosphorIconsRegular.bell, color: Colors.white, size: 22.sp),
        SizedBox(width: 10.w),
        Expanded(
          child: Text.rich(TextSpan(children: <InlineSpan>[
            TextSpan(
                text: '$active active bid${active == 1 ? '' : 's'}',
                style: jakarta(14.5.sp, color: Colors.white)),
            if (outbid > 0)
              TextSpan(
                  text: '   $outbid outbid',
                  style: dm(13.sp,
                      color: const Color(0xFFFFB45C), w: FontWeight.w700)),
          ])),
        ),
        SizedBox(
          height: 44.h,
          child: FilledButton(
            onPressed: () => _scroll.animateTo(0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AU.ink,
                padding: EdgeInsets.symmetric(horizontal: 18.w),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r))),
            child: Text('View my bids', style: jakarta(14.sp)),
          ),
        ),
      ]),
    );
  }
}

/// Pinned chip row under the tabs.
class _ChipsHeader extends SliverPersistentHeaderDelegate {
  _ChipsHeader({required this.child, required this.height});
  final Widget child;
  final double height;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: Colors.white, child: child);
  @override
  bool shouldRebuild(covariant _ChipsHeader old) => true;
}
