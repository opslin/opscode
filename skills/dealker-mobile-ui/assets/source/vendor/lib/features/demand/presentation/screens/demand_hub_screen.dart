import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/demand/application/demand_providers.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/demand_cards.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/demand_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/premium_ui.dart';
import 'package:dealker_vendor/core/utils/polling.dart';

enum HubTab {
  demand('Demand'),
  offers('My Offers'),
  requests('My Requests'),
  orders('Orders');

  const HubTab(this.label);
  final String label;

  static HubTab parse(String? v) =>
      HubTab.values.firstWhere((t) => t.name == v, orElse: () => HubTab.demand);
}

/// Demand & Notifications — what buyers need right now, my offers, what I am buying, and the orders
/// that follow. Refreshes itself every 30 s so new demand shows up while the vendor is looking.
class DemandHubScreen extends ConsumerStatefulWidget {
  const DemandHubScreen({super.key, this.initialTab = HubTab.demand});
  final HubTab initialTab;

  @override
  ConsumerState<DemandHubScreen> createState() => _DemandHubScreenState();
}

class _DemandHubScreenState extends ConsumerState<DemandHubScreen> {
  late HubTab _tab = widget.initialTab;
  String _scope = 'open'; // open | new | matched
  String _offerTab = 'active'; // active | pending | closed
  String _role = 'buying'; // buying | selling
  String _bucket = 'active'; // active | done
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && screenActive(context)) _refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  ReqQuery get _reqQuery => switch (_tab) {
        HubTab.demand => (_scope, null),
        HubTab.offers => ('quoted', _offerTab),
        _ => ('mine', null),
      };

  Future<void> _refresh() async {
    ref
      ..invalidate(demandSummaryProvider)
      ..invalidate(requirementsProvider)
      ..invalidate(demandOrdersProvider);
    try {
      await ref.read(demandSummaryProvider.future);
    } catch (_) {}
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.home);

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(demandSummaryProvider).asData?.value;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: AuctionAppBar(
        title: 'Demand & Notifications',
        subtitle: 'Real buyers · real requirements',
        onBack: _back,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(PhosphorIconsRegular.arrowsClockwise,
                color: AppColors.navy, size: 22),
          ),
        ],
      ),
      floatingActionButton:
          _PostFab(onTap: () => context.push(Routes.demandPost)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            _Hero(
                summary: summary,
                onActions: () => setState(() => _tab = HubTab.orders)),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.push(Routes.wholesale),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD5E2FF))),
                child: Row(children: [
                  const Art3D('assets/3d/new/cartons.png', size: 40),
                  const SizedBox(width: 10),
                  const Expanded(
                      child: Text(
                          'Browse wholesale stock — buy directly from other vendors',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13.5))),
                  const Icon(PhosphorIconsBold.caretRight,
                      size: 16, color: AppColors.textMuted),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            _TabRow(
              current: _tab,
              summary: summary,
              onChanged: (t) => setState(() => _tab = t),
            ),
            const SizedBox(height: 12),
            ..._body(summary),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(DemandSummary? s) => switch (_tab) {
        HubTab.demand => [
            _chips([
              ('All', s?.open, 'open'),
              ('New', s?.newCount, 'new'),
              ('Matches for me', s?.matched, 'matched'),
            ], _scope, (v) => setState(() => _scope = v)),
            const SizedBox(height: 12),
            _RequirementList(
                query: _reqQuery, kind: _ListKind.demand, scope: _scope),
          ],
        HubTab.offers => [
            _chips([
              ('Active', s?.offers.active, 'active'),
              ('Pending', s?.offers.pending, 'pending'),
              ('Closed', s?.offers.closed, 'closed'),
            ], _offerTab, (v) => setState(() => _offerTab = v)),
            const SizedBox(height: 12),
            _RequirementList(
                query: _reqQuery, kind: _ListKind.offers, scope: _offerTab),
          ],
        HubTab.requests => [
            _RequirementList(
                query: _reqQuery, kind: _ListKind.requests, scope: 'mine'),
          ],
        HubTab.orders => [
            _Segment(
              labels: const ['Buying', 'Selling'],
              index: _role == 'buying' ? 0 : 1,
              // Buying: orders to pay or confirm · Selling: orders to pack and dispatch.
              badges: [
                (s?.toPay ?? 0) + (s?.toReceive ?? 0),
                s?.toDispatch ?? 0
              ],
              onChanged: (i) =>
                  setState(() => _role = i == 0 ? 'buying' : 'selling'),
            ),
            const SizedBox(height: 10),
            _chips([
              (
                'In progress',
                _role == 'buying' ? s?.buyingActive : s?.sellingActive,
                'active'
              ),
              ('Completed', null, 'done'),
            ], _bucket, (v) => setState(() => _bucket = v)),
            const SizedBox(height: 12),
            _OrderList(role: _role, bucket: _bucket),
          ],
      };

  Widget _chips(List<(String, int?, String)> items, String selected,
          ValueChanged<String> on) =>
      SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => PillTab(
            label: items[i].$1,
            count: items[i].$2,
            selected: selected == items[i].$3,
            onTap: () => on(items[i].$3),
          ),
        ),
      );
}

// ── hero ─────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.summary, required this.onActions});
  final DemandSummary? summary;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        gradient: kDemandGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: kDemandNavy.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Live demand',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                  s == null
                      ? '···'
                      : '${s.open} open requirement${s.open == 1 ? '' : 's'}',
                  style: heading(
                      size: 22, color: Colors.white, w: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('Real buyers looking for stock right now',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.8))),
            ]),
          ),
          Art3D('assets/3d/sell/offer.png', size: 82, float: true),
        ]),
        const SizedBox(height: 11),
        Row(children: [
          _Mini(
              label: 'New',
              value: s?.newCount,
              icon: PhosphorIconsFill.sparkle),
          const SizedBox(width: 8),
          _Mini(
              label: 'Matches',
              value: s?.matched,
              icon: PhosphorIconsFill.checkCircle),
          const SizedBox(width: 8),
          _Mini(
              label: 'Urgent',
              value: s?.urgent,
              icon: PhosphorIconsFill.lightning),
        ]),
        if (s != null && s.actionsDue > 0) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onActions,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(11)),
              child: Row(children: [
                const Icon(PhosphorIconsFill.warningCircle,
                    size: 18, color: AppColors.navy),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(_actionText(s),
                      style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy)),
                ),
                const Icon(PhosphorIconsBold.caretRight,
                    size: 15, color: AppColors.navy),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  static String _actionText(DemandSummary s) {
    final parts = [
      if (s.toDispatch > 0) '${s.toDispatch} to dispatch',
      if (s.toPay > 0) '${s.toPay} to pay',
      if (s.toReceive > 0) '${s.toReceive} to confirm',
    ];
    return 'Action needed: ${parts.join(' · ')}';
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, required this.icon});
  final String label;
  final int? value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11)),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600)),
                    Text(value == null ? '—' : '$value',
                        style: heading(
                            size: 19, color: Colors.white, w: FontWeight.w800)),
                  ]),
            ),
            Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.8)),
          ]),
        ),
      );
}

// ── tabs ─────────────────────────────────────────────────────────────────

class _TabRow extends StatelessWidget {
  const _TabRow(
      {required this.current, required this.summary, required this.onChanged});
  final HubTab current;
  final DemandSummary? summary;
  final ValueChanged<HubTab> onChanged;

  int? _count(HubTab t) => switch (t) {
        HubTab.demand => summary?.open,
        HubTab.offers => summary?.offers.active,
        HubTab.requests => summary?.myTotal,
        HubTab.orders => summary?.ordersActive,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder)),
        child: Row(children: [
          for (final t in HubTab.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: current == t ? kDemandBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(t.label,
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: current == t
                                  ? Colors.white
                                  : AppColors.textSecondary)),
                    ),
                    const SizedBox(height: 2),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(_count(t) == null ? '—' : '${_count(t)}',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: current == t
                                  ? Colors.white70
                                  : AppColors.textMuted)),
                      if (t == HubTab.orders &&
                          (summary?.actionsDue ?? 0) > 0 &&
                          current != t) ...[
                        const SizedBox(width: 4),
                        Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                                color: AppColors.rose, shape: BoxShape.circle)),
                      ],
                    ]),
                  ]),
                ),
              ),
            ),
        ]),
      );
}

class _Segment extends StatelessWidget {
  const _Segment(
      {required this.labels,
      required this.index,
      required this.onChanged,
      this.badges = const []});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final List<int> badges;

  @override
  Widget build(BuildContext context) => Row(children: [
        for (final (i, l) in labels.indexed)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                height: 42,
                margin: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == index ? kDemandBlueSoft : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: i == index ? kDemandBlue : AppColors.border,
                      width: 1.2),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(l,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: i == index
                              ? kDemandBlue
                              : AppColors.textSecondary)),
                  if (i < badges.length && badges[i] > 0) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                          color: AppColors.rose,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('${badges[i]}',
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
      ]);
}

// ── lists ────────────────────────────────────────────────────────────────

enum _ListKind { demand, offers, requests }

class _RequirementList extends ConsumerWidget {
  const _RequirementList(
      {required this.query, required this.kind, required this.scope});
  final ReqQuery query;
  final _ListKind kind;
  final String scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(requirementsProvider(query));
    return list.when(skipLoadingOnReload: true, skipError: true, 
      loading: () => Column(
          children: const [CardSkeleton(), CardSkeleton(), CardSkeleton()]),
      error: (e, _) => SizedBox(
        height: 320,
        child: ErrorState(
            message: errorText(e, 'Could not load demand.'),
            onRetry: () => ref.invalidate(requirementsProvider)),
      ),
      data: (page) {
        if (page.items.isEmpty) return _empty(context);
        return Column(children: [
          for (final r in page.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: switch (kind) {
                _ListKind.demand =>
                  DemandCard(r: r, onTap: () => _open(context, ref, r)),
                _ListKind.offers =>
                  OfferCard(r: r, onTap: () => _open(context, ref, r)),
                _ListKind.requests =>
                  RequestCard(r: r, onTap: () => _open(context, ref, r)),
              },
            ),
        ]);
      },
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Requirement r) async {
    await context.push(Routes.demandView(r.id));
    ref
      ..invalidate(demandSummaryProvider)
      ..invalidate(requirementsProvider);
  }

  Widget _empty(BuildContext context) {
    switch (kind) {
      case _ListKind.demand:
        final matches = scope == 'matched';
        return EmptyState(
          icon: matches
              ? PhosphorIconsRegular.package
              : PhosphorIconsRegular.bellSimple,
          title: switch (scope) {
            'new' => "You're all caught up",
            'matched' => 'No matches for your stock yet',
            _ => 'No open demand right now',
          },
          message: switch (scope) {
            'new' =>
              'New buying requirements show up here the moment buyers post them.',
            'matched' =>
              'When a buyer asks for a model you have in stock, it appears here with how many you can supply.',
            _ =>
              "We'll alert you as soon as verified buyers post what they need.",
          },
          action: matches
              ? SizedBox(
                  width: 190,
                  child: AuctionButton(
                      label: 'Add a product',
                      height: 46,
                      onPressed: () => context.push(Routes.productAdd)))
              : null,
        );
      case _ListKind.offers:
        return EmptyState(
          icon: PhosphorIconsRegular.handshake,
          title: switch (scope) {
            'pending' => 'No offers waiting',
            'closed' => 'No closed offers',
            _ => 'No active offers'
          },
          message:
              'Answer a buying requirement and track the buyer’s response here.',
        );
      case _ListKind.requests:
        return EmptyState(
          icon: PhosphorIconsRegular.megaphoneSimple,
          title: 'Need stock?',
          message:
              'Post what you want to buy. Verified sellers send you offers, you pick the best price.',
          action: SizedBox(
              width: 190,
              child: AuctionButton(
                  label: 'Post demand',
                  height: 46,
                  onPressed: () => context.push(Routes.demandPost))),
        );
    }
  }
}

class _OrderList extends ConsumerWidget {
  const _OrderList({required this.role, required this.bucket});
  final String role;
  final String bucket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(demandOrdersProvider((role, bucket)));
    return list.when(skipLoadingOnReload: true, skipError: true, 
      loading: () => Column(children: const [
        CardSkeleton(height: 120),
        CardSkeleton(height: 120)
      ]),
      error: (e, _) => SizedBox(
        height: 320,
        child: ErrorState(
            message: errorText(e, 'Could not load orders.'),
            onRetry: () => ref.invalidate(demandOrdersProvider)),
      ),
      data: (page) => page.items.isEmpty
          ? EmptyState(
              icon: PhosphorIconsRegular.package,
              title: bucket == 'active'
                  ? 'No orders in progress'
                  : 'No completed orders',
              message: role == 'buying'
                  ? 'Orders appear here once you accept a seller’s offer.'
                  : 'When a buyer accepts your offer, the order shows up here.',
            )
          : Column(children: [
              for (final o in page.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OrderCard(
                    o: o,
                    buying: role == 'buying',
                    onTap: () async {
                      await context.push(Routes.demandOrder(o.id));
                      ref
                        ..invalidate(demandSummaryProvider)
                        ..invalidate(demandOrdersProvider);
                    },
                  ),
                ),
            ]),
    );
  }
}

class _PostFab extends StatelessWidget {
  const _PostFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: kDemandBlue,
        elevation: 4,
        shadowColor: kDemandBlue.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(PhosphorIconsBold.plus, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Post demand',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5)),
            ]),
          ),
        ),
      );
}
