import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/demand/application/demand_providers.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/demand_common.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';

const _steps = ['Placed', 'Paid', 'Packed', 'Shipped', 'Delivered'];

/// How far an order has got (index into [_steps]); null for cancelled / refunded.
int? _stage(String status) => switch (status) {
      'PENDING_PAYMENT' => 0,
      'PAID' => 1,
      'PACKED' => 2,
      'DISPATCHED' => 3,
      'DELIVERED' || 'COMPLETED' => 4,
      'DISPUTED' => 3,
      _ => null,
    };

/// Everything you bought from other vendors, with where each order is. Tap one for the full timeline.
class WholesaleOrdersScreen extends ConsumerStatefulWidget {
  const WholesaleOrdersScreen({super.key});

  @override
  ConsumerState<WholesaleOrdersScreen> createState() =>
      _WholesaleOrdersScreenState();
}

class _WholesaleOrdersScreenState extends ConsumerState<WholesaleOrdersScreen> {
  String _bucket = 'active'; // active | done

  Future<void> _refresh() async {
    ref.invalidate(demandOrdersProvider);
    await ref
        .read(demandOrdersProvider(('buying', _bucket)).future)
        .catchError((_) => const OrderPage(items: [], total: 0));
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(demandOrdersProvider(('buying', _bucket)));
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(Routes.home),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy)),
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Wholesale orders',
              style: heading(size: 19, w: FontWeight.w800)),
          const Text('What you bought from other vendors',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        actions: [
          IconButton(
              tooltip: 'Marketplace',
              onPressed: () => context.go(Routes.wholesale),
              icon: const Icon(PhosphorIconsRegular.storefront,
                  color: AppColors.primary)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: AppColors.cardBorder))),
            child: Row(children: [
              for (final (k, label) in [
                ('active', 'In progress'),
                ('done', 'Completed')
              ])
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _bucket = k),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: _bucket == k
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  width: 2.5))),
                      child: Text(label,
                          style: heading(
                              size: 14,
                              color: _bucket == k
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              w: FontWeight.w700)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: list.when(skipLoadingOnReload: true, skipError: true, 
          loading: () => ListView(
              padding: const EdgeInsets.all(14),
              children: const [
                CardSkeleton(height: 170),
                SizedBox(height: 12),
                CardSkeleton(height: 170)
              ]),
          error: (e, _) => ListView(children: [
            SizedBox(
                height: 420,
                child: ErrorState(
                    message: errorText(e, 'Could not load your orders.'),
                    onRetry: () => ref.invalidate(demandOrdersProvider)))
          ]),
          data: (page) => page.items.isEmpty
              ? ListView(children: [
                  SizedBox(
                    height: 460,
                    child: EmptyState(
                      icon: PhosphorIconsRegular.package,
                      title: _bucket == 'active'
                          ? 'No orders in progress'
                          : 'No completed orders yet',
                      message: _bucket == 'active'
                          ? 'Stock you buy from the B2B Marketplace shows up here, with every step until it reaches you.'
                          : 'Orders you have received and confirmed appear here.',
                      action: TextButton(
                          onPressed: () => context.go(Routes.wholesale),
                          child: const Text('Browse marketplace')),
                    ),
                  )
                ])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                  children: [
                    for (final o in page.items) ...[
                      _OrderCard(o, onChanged: () {
                        ref
                          ..invalidate(demandOrdersProvider)
                          ..invalidate(demandSummaryProvider);
                      }),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(this.o, {required this.onChanged});
  final DemandOrder o;
  final VoidCallback onChanged;

  (String, Color, Color) get _chip => switch (o.status) {
        'PENDING_PAYMENT' => (
            'Payment pending',
            const Color(0xFFD97706),
            AppColors.amberSoft
          ),
        'PAID' => (
            'Paid · awaiting packing',
            AppColors.primary,
            const Color(0xFFE5EEFF)
          ),
        'PACKED' => ('Packed', AppColors.primary, const Color(0xFFE5EEFF)),
        'DISPATCHED' => ('On the way', AppColors.violet, AppColors.violetSoft),
        'DELIVERED' => (
            'Delivered · confirm receipt',
            AppColors.mint,
            AppColors.mintSoft
          ),
        'COMPLETED' => ('Completed', AppColors.mint, AppColors.mintSoft),
        'DISPUTED' => ('Issue reported', AppColors.rose, AppColors.roseSoft),
        'CANCELLED' => (
            'Cancelled',
            AppColors.textSecondary,
            const Color(0xFFEFF1F6)
          ),
        'REFUNDED' => ('Refunded', AppColors.violet, AppColors.violetSoft),
        _ => (o.status, AppColors.textSecondary, const Color(0xFFEFF1F6)),
      };

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = _chip;
    final stage = _stage(o.status);
    final unpaid = o.status == 'PENDING_PAYMENT';
    return GestureDetector(
      onTap: () async {
        await context.push(Routes.demandOrder(o.id));
        onChanged();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('Order ${o.orderNumber}',
                    style: heading(size: 14.5, w: FontWeight.w800))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(8)),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(PhosphorIconsFill.storefront,
                size: 14, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Expanded(
                child: Text(o.sellerName,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(4),
              child: AnyImage(o.thumbnail, fit: BoxFit.contain, radius: 8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: heading(size: 13.5)),
                    const SizedBox(height: 3),
                    Text('${o.quantity} × ${formatInr(o.unitPrice)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ]),
            ),
            Text(formatInr(o.subtotal),
                style: heading(size: 16, w: FontWeight.w800)),
          ]),
          if (stage != null) ...[
            const SizedBox(height: 14),
            _Progress(stage),
          ],
          if (o.status == 'DISPATCHED' && (o.awb ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('${o.courierName ?? 'Courier'} · ${o.awb}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Text(timeAgoShort(o.createdAt),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textMuted)),
            const Spacer(),
            if (unpaid)
              GestureDetector(
                onTap: () async {
                  await context.push(Routes.demandPay(o.requirementId));
                  onChanged();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(11)),
                  child: Text('Pay now',
                      style: heading(
                          size: 13, color: Colors.white, w: FontWeight.w700)),
                ),
              )
            else
              Row(children: [
                Text('Track order',
                    style: heading(
                        size: 13,
                        color: AppColors.primary,
                        w: FontWeight.w700)),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.primary),
              ]),
          ]),
        ]),
      ),
    );
  }
}

String timeAgoShort(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

/// Placed → Paid → Packed → Shipped → Delivered.
class _Progress extends StatelessWidget {
  const _Progress(this.stage);
  final int stage;

  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: Container(
                        height: 2.5,
                        color: i == 0
                            ? Colors.transparent
                            : (i <= stage
                                ? AppColors.mint
                                : AppColors.cardBorder))),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= stage ? AppColors.mint : Colors.white,
                    border: Border.all(
                        color: i <= stage
                            ? AppColors.mint
                            : AppColors.borderStrong,
                        width: 1.6),
                  ),
                  child: i <= stage
                      ? const Icon(Icons.check_rounded,
                          size: 12, color: Colors.white)
                      : null,
                ),
                Expanded(
                    child: Container(
                        height: 2.5,
                        color: i == _steps.length - 1
                            ? Colors.transparent
                            : (i < stage
                                ? AppColors.mint
                                : AppColors.cardBorder))),
              ]),
              const SizedBox(height: 5),
              Text(_steps[i],
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          i == stage ? FontWeight.w800 : FontWeight.w500,
                      color:
                          i <= stage ? AppColors.navy : AppColors.textMuted)),
            ]),
          ),
        ],
      ]);
}
