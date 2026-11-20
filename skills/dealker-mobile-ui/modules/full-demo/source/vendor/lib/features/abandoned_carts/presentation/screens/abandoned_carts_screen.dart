import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/abandoned_carts/application/cart_providers.dart';
import 'package:dealker_vendor/features/abandoned_carts/data/cart_models.dart';
import 'package:dealker_vendor/features/abandoned_carts/presentation/widgets/cart_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/core/utils/polling.dart';

/// Abandoned carts that contain this vendor's products — B2C and B2B.
class AbandonedCartsScreen extends ConsumerStatefulWidget {
  const AbandonedCartsScreen({super.key});

  @override
  ConsumerState<AbandonedCartsScreen> createState() =>
      _AbandonedCartsScreenState();
}

class _AbandonedCartsScreenState extends ConsumerState<AbandonedCartsScreen> {
  CartChannel _channel = CartChannel.all;
  bool _openOnly = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // New abandoned carts appear on their own while the vendor is watching.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && screenActive(context)) refreshCarts(ref);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    refreshCarts(ref);
    await ref
        .read(
            cartListProvider(CartQuery(channel: _channel, openOnly: _openOnly))
                .future)
        .catchError((_) => const CartPage(items: [], total: 0));
  }

  @override
  Widget build(BuildContext context) {
    final q = CartQuery(channel: _channel, openOnly: _openOnly);
    final summary = ref.watch(cartSummaryProvider(_channel));
    final list = ref.watch(cartListProvider(q));
    final idle = summary.asData?.value.idleMinutes ?? 30;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AuctionAppBar(
        title: 'Abandoned Carts',
        subtitle: 'Shoppers who left your products behind',
        onBack: () =>
            context.canPop() ? context.pop() : context.go(Routes.home),
      ),
      body: RefreshIndicator(
        color: kCartViolet,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            _MonitorStrip(idleMinutes: idle),
            const SizedBox(height: 12),
            _ChannelTabs(
                value: _channel,
                onChanged: (c) => setState(() => _channel = c)),
            const SizedBox(height: 14),
            summary.when(skipLoadingOnReload: true, skipError: true, 
              loading: () => const _KpiSkeleton(),
              error: (e, _) => AdNotice(
                  message: errorText(e, 'Could not load your cart numbers.'),
                  icon: PhosphorIconsFill.warningCircle,
                  color: AppColors.rose,
                  bg: AppColors.roseSoft,
                  action: TextButton(
                      onPressed: () => ref.invalidate(cartSummaryProvider),
                      child: const Text('Retry'))),
              data: (s) => _Kpis(s),
            ),
            const SizedBox(height: 20),
            Row(children: [
              const Icon(PhosphorIconsFill.lightning,
                  color: kCartViolet, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Carts to follow up', style: heading(size: 17))),
              _StateToggle(
                  openOnly: _openOnly,
                  onChanged: (v) => setState(() => _openOnly = v)),
            ]),
            const SizedBox(height: 10),
            list.when(skipLoadingOnReload: true, skipError: true, 
              loading: () => Column(children: const [
                _RowSkeleton(),
                SizedBox(height: 10),
                _RowSkeleton(),
                SizedBox(height: 10),
                _RowSkeleton(),
              ]),
              error: (e, _) => SizedBox(
                height: 280,
                child: ErrorState(
                    message: errorText(e, 'Could not load abandoned carts.'),
                    onRetry: () => ref.invalidate(cartListProvider)),
              ),
              data: (page) => page.items.isEmpty
                  ? _Empty(openOnly: _openOnly, channel: _channel, idle: idle)
                  : Column(children: [
                      for (final r in page.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CartCard(
                              row: r,
                              onTap: () => context
                                  .push(Routes.abandonedCartDetail(r.id))),
                        ),
                    ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitorStrip extends StatelessWidget {
  const _MonitorStrip({required this.idleMinutes});
  final int idleMinutes;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.mintSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.mint.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
                color: AppColors.mint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          const Text('LIVE MONITORING',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: Color(0xFF166534))),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Auto-refresh · carts show after $idleMinutes min idle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
        ]),
      );
}

class _ChannelTabs extends StatelessWidget {
  const _ChannelTabs({required this.value, required this.onChanged});
  final CartChannel value;
  final ValueChanged<CartChannel> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: const Color(0xFFF0F2FB),
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          for (final c in CartChannel.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: c == value ? AppColors.violetGradient : null,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(c.label,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: c == value
                              ? Colors.white
                              : AppColors.textSecondary)),
                ),
              ),
            ),
        ]),
      );
}

class _Kpis extends StatelessWidget {
  const _Kpis(this.s);
  final CartSummary s;

  Widget _tile(String label, String value, IconData icon, Color c, Color bg,
          double? change,
          {bool goodWhenUp = true}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: c),
          ),
          const SizedBox(height: 10),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: heading(size: 24, w: FontWeight.w800))),
          const SizedBox(height: 4),
          ChangeBadge(change, goodWhenUp: goodWhenUp),
        ]),
      );

  @override
  Widget build(BuildContext context) => Column(children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
                child: _tile(
                    'Abandoned carts',
                    '${s.carts}',
                    PhosphorIconsFill.shoppingCart,
                    kCartViolet,
                    AppColors.violetSoft,
                    s.cartsChange,
                    goodWhenUp: false)),
            const SizedBox(width: 12),
            Expanded(
                child: _tile(
                    'Pending cart value',
                    formatInr(s.pendingValue),
                    PhosphorIconsFill.currencyInr,
                    kCartViolet,
                    AppColors.violetSoft,
                    s.valueChange,
                    goodWhenUp: false)),
          ]),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
                child: _tile(
                    'Recovered orders',
                    '${s.recoveredOrders}',
                    PhosphorIconsFill.checkCircle,
                    AppColors.mint,
                    AppColors.mintSoft,
                    s.ordersChange)),
            const SizedBox(width: 12),
            Expanded(
                child: _tile(
                    'Recovery rate',
                    percent(s.recoveryRate),
                    PhosphorIconsFill.percent,
                    kCartViolet,
                    AppColors.violetSoft,
                    s.rateChange)),
          ]),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
              'Last ${s.days} days · only your products'
              '${s.orderedAfterReminder > 0 ? ' · ${s.orderedAfterReminder} ordered after your reminder' : ''}',
              style:
                  const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ),
      ]);
}

class _StateToggle extends StatelessWidget {
  const _StateToggle({required this.openOnly, required this.onChanged});
  final bool openOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (label, v) in const [('Open', true), ('All', false)])
          GestureDetector(
            onTap: () => onChanged(v),
            child: Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: openOnly == v ? kCartViolet : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: openOnly == v ? kCartViolet : AppColors.border),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: openOnly == v
                          ? Colors.white
                          : AppColors.textSecondary)),
            ),
          ),
      ]);
}

class _CartCard extends StatelessWidget {
  const _CartCard({required this.row, required this.onTap});
  final CartRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: HomeCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            CartAvatar(row.customer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(row.customer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: heading(size: 15.5)),
                      ),
                      const SizedBox(width: 8),
                      ChannelChip(row.channel),
                    ]),
                    const SizedBox(height: 3),
                    Text(
                        '${humanIdle(row.abandonedAt)}  ·  ${formatInr(row.value)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 1),
                    Text(row.productLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textMuted)),
                    const SizedBox(height: 5),
                    CartStateLine(row),
                  ]),
            ),
            const SizedBox(width: 6),
            const Icon(PhosphorIconsRegular.caretRight,
                size: 18, color: AppColors.textMuted),
          ]),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(
      {required this.openOnly, required this.channel, required this.idle});
  final bool openOnly;
  final CartChannel channel;
  final int idle;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 320,
        child: EmptyState(
          icon: PhosphorIconsRegular.shoppingCart,
          title: openOnly ? 'No abandoned carts right now' : 'Nothing here yet',
          message: openOnly
              ? 'When a shopper leaves your ${channel == CartChannel.all ? '' : '${channel.label} '}products in their cart for $idle minutes, it will show up here so you can remind them.'
              : 'Carts that contain your products will appear here.',
        ),
      );
}

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var r = 0; r < 2; r++) ...[
          if (r > 0) const SizedBox(height: 12),
          Row(children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                  child: Container(
                      height: 118,
                      decoration: BoxDecoration(
                          color: const Color(0xFFEFF2FA),
                          borderRadius: BorderRadius.circular(16)))),
            ],
          ]),
        ],
      ]);
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) => Container(
      height: 84,
      decoration: BoxDecoration(
          color: const Color(0xFFEFF2FA),
          borderRadius: BorderRadius.circular(14)));
}
