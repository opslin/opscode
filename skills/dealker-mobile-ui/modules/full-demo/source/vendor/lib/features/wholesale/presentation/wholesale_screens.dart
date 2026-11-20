import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/wholesale/application/cart_provider.dart';
import 'package:dealker_vendor/features/wholesale/application/device_selection.dart';
import 'package:dealker_vendor/features/wholesale/application/wholesale_providers.dart';
import 'package:dealker_vendor/features/wholesale/data/condition_report.dart';
import 'package:dealker_vendor/features/wholesale/data/wholesale_models.dart';
import 'package:dealker_vendor/features/wholesale/presentation/condition_blocks.dart';
import 'package:dealker_vendor/features/wholesale/presentation/device_condition.dart';
import 'package:dealker_vendor/shared/widgets/fullscreen_image_viewer.dart';
import 'package:dealker_vendor/routing/route_names.dart';

/// One wholesale listing: gallery, bulk price, seller, quantity (never below the
/// MOQ), add to cart or buy now.
class WholesaleDetailScreen extends ConsumerStatefulWidget {
  const WholesaleDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<WholesaleDetailScreen> createState() =>
      _WholesaleDetailScreenState();
}

class _WholesaleDetailScreenState extends ConsumerState<WholesaleDetailScreen> {
  int? _qty;
  DeviceSelection? _sel;
  bool _busy = false;
  int _page = 0;

  /// "Buy in bulk" = put exactly this quantity in the cart and go to it: the Cart is the one place
  /// where the order is placed and paid (UPI / cards / netbanking via Razorpay, or the wallet).
  @override
  void dispose() {
    _sel?.dispose();
    super.dispose();
  }

  void _setQty(int q) {
    setState(() => _qty = q);
    _sel?.setQty(q);
  }

  Future<void> _buy(WholesaleItem it, int qty) async {
    final cart = ref.read(wholesaleCartProvider.notifier);
    final devices = _sel?.sorted;
    if (cart.qtyOf(it.id) > 0) {
      cart.setQty(it.id, qty);
      if (devices != null) cart.setDevices(it.id, devices);
    } else {
      cart.add(it, qty, devices);
    }
    await context.push(Routes.wholesaleCart);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(wholesaleDetailProvider(widget.id));
    final cartCount = ref.watch(wholesaleCartProvider).length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Column(children: [
          Container(
            padding: EdgeInsets.fromLTRB(
                4, MediaQuery.paddingOf(context).top + 4, 8, 6),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFEEF0F6)))),
            child: Row(children: [
              IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy)),
              Expanded(
                child: Text('Product details',
                    style: heading(size: 18, w: FontWeight.w800)),
              ),
              IconButton(
                onPressed: () => context.push(Routes.wholesaleCart),
                icon: Badge(
                  isLabelVisible: cartCount > 0,
                  label: Text('$cartCount'),
                  backgroundColor: AppColors.rose,
                  child: const Icon(PhosphorIconsRegular.shoppingCart,
                      color: AppColors.navy),
                ),
              ),
            ]),
          ),
          Expanded(
            child: detail.when(skipLoadingOnReload: true, skipError: true, 
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                  message: errorText(e, 'This listing is no longer available.'),
                  onRetry: () =>
                      ref.invalidate(wholesaleDetailProvider(widget.id))),
              data: _content,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _content(WholesaleDetail d) {
    final it = d.item;
    final maxQty = it.stock;
    final soldOut = maxQty < it.moq;
    final qty = (_qty ?? it.moq).clamp(it.moq, soldOut ? it.moq : maxQty);
    final total = it.price * qty;
    final imgs = d.images.isNotEmpty
        ? d.images
        : [if (it.thumbnail != null) it.thumbnail!];
    final off = (it.discountPct ?? 0) > 0 ? it.discountPct!.round() : null;
    final showRetail = it.retailPrice != null && it.retailPrice! > it.price;
    final cond = conditionBadge(it.condition);
    final report = d.productId == null
        ? null
        : ref.watch(conditionReportProvider(d.productId!)).asData?.value;
    if (_sel == null && report != null && report.isUsed && d.productId != null) {
      _sel = DeviceSelection(ref.read(dioProvider), d.productId!, qty)..init();
    }
    final inCart = ref.watch(
        wholesaleCartProvider.select((l) => l.any((x) => x.item.id == it.id)));

    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          children: [
            Container(
              color: Colors.white,
              child: Column(children: [
                SizedBox(
                  height: 300,
                  child: Stack(children: [
                    PageView(
                      onPageChanged: (i) => setState(() => _page = i),
                      children: [
                        for (var i = 0; i < imgs.length; i++)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => FullscreenImageViewer.open(context,
                                images: imgs, initialIndex: i),
                            child: AnyImage(imgs[i], fit: BoxFit.contain, radius: 14),
                          ),
                      ],
                    ),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: _Chip(conditionBadge(it.condition), _tierFg(it.condition),
                          _tierBg(it.condition)),
                    ),
                    const Positioned(
                      right: 8,
                      bottom: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.zoom_out_map_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    if (off != null)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: _Chip('$off% OFF', Colors.white, AppColors.mint),
                      ),
                  ]),
                ),
                if (imgs.length > 1) ...[
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 0; i < imgs.length; i++)
                      Container(
                        width: i == _page ? 18 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                            color: i == _page
                                ? AppColors.primary
                                : AppColors.cardBorder,
                            borderRadius: BorderRadius.circular(3)),
                      ),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            HomeCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.name, style: heading(size: 19)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      if ((it.brand ?? '').isNotEmpty)
                        _Chip(it.brand!, AppColors.textSecondary,
                            const Color(0xFFEFF1F6)),
                      if (cond.isNotEmpty)
                        _Chip(cond, _tierFg(it.condition), _tierBg(it.condition)),
                    ]),
                    const SizedBox(height: 12),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(formatInr(it.price),
                          style: heading(size: 28, w: FontWeight.w800)),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 4),
                        child: Text('/ unit',
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                    ]),
                    if (showRetail)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('${formatInr(it.retailPrice!)} retail',
                            style: const TextStyle(
                                color: AppColors.textMuted,
                                decoration: TextDecoration.lineThrough)),
                      ),
                    const SizedBox(height: 4),
                    const Text('GST invoice provided with the order',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ]),
            ),
            const SizedBox(height: 12),
            HomeCard(
              child: Column(children: [
                SummaryRow('Minimum order', '${it.moq} units'),
                SummaryRow('In stock', '${it.stock} units'),
                if (it.storage != null && it.storage!.isNotEmpty)
                  SummaryRow('Storage', it.storage!),
                if (it.batteryHealth != null)
                  SummaryRow('Battery health', '${it.batteryHealth!.round()}%'),
                if (d.warranty != null && d.warranty!.isNotEmpty)
                  SummaryRow('Warranty', d.warranty!),
                if (d.handlingDays != null)
                  SummaryRow('Dispatch in', '${d.handlingDays} days'),
              ]),
            ),
            if (report != null) ...[
              const SizedBox(height: 12),
              TrustChips(report: report),
            ],
            if (_sel != null) DeviceConditionBlock(selection: _sel!, name: it.name),
            if (report != null) QcSummaryCard(report: report, name: it.name),
            if (report != null) ConditionBlock(report: report),
            if (report != null) InBoxBlock(report: report),
            HighlightsBlock(
                lines: d.highlights.isNotEmpty
                    ? d.highlights
                    : [for (final r in d.specs.take(5)) '${r.label}: ${r.value}']),
            SpecsBlock(rows: d.specs),
            const SizedBox(height: 12),
            HomeCard(
              child: Row(children: [
                const CircleAvatar(
                    backgroundColor: Color(0xFFE5EEFF),
                    child: Icon(PhosphorIconsFill.storefront,
                        color: AppColors.primary, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                              child: Text(it.seller.name,
                                  style: heading(size: 15.5))),
                          const SizedBox(width: 5),
                          const Icon(PhosphorIconsFill.sealCheck,
                              size: 16, color: AppColors.primary),
                        ]),
                        const SizedBox(height: 2),
                        Text(
                            [
                              if (it.seller.city != null) it.seller.city!,
                              if (it.seller.rating != null &&
                                  it.seller.rating! > 0)
                                '★ ${it.seller.rating!.toStringAsFixed(1)}'
                                    '${it.seller.reviews > 0 ? ' (${it.seller.reviews})' : ''}',
                            ].join(' · '),
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.textMuted)),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            const HomeCard(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              child: Row(children: [
                _Trust(PhosphorIconsFill.wallet, 'Pay from\nDealker wallet',
                    AppColors.primary),
                _Trust(PhosphorIconsFill.shieldCheck,
                    'Held safely until\nyou confirm', AppColors.mint),
                _Trust(PhosphorIconsFill.fileText, 'GST invoice\nwith order',
                    AppColors.violet),
              ]),
            ),
            if ((d.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Seller note', style: heading(size: 15)),
              const SizedBox(height: 4),
              Text(d.notes!,
                  style: const TextStyle(
                      height: 1.4, color: AppColors.textSecondary)),
            ],
            if ((d.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('About this item', style: heading(size: 15)),
              const SizedBox(height: 4),
              Text(d.description!,
                  style: const TextStyle(
                      height: 1.4, color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.cardBorder))),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              IconButton.filledTonal(
                  onPressed: qty > it.moq ? () => _setQty(qty - 1) : null,
                  icon: const Icon(PhosphorIconsBold.minus)),
              SizedBox(
                  width: 60,
                  child: Center(
                      child: Text('$qty',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)))),
              IconButton.filledTonal(
                  onPressed: qty < maxQty ? () => _setQty(qty + 1) : null,
                  icon: const Icon(PhosphorIconsBold.plus)),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$qty unit${qty == 1 ? '' : 's'} =',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
                Text(formatInr(total),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              ]),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: soldOut
                      ? null
                      : inCart
                          ? () => context.push(Routes.wholesaleCart)
                          : () => ref
                              .read(wholesaleCartProvider.notifier)
                              .add(it, qty, _sel?.sorted),
                  icon: Icon(
                      inCart
                          ? PhosphorIconsFill.shoppingCart
                          : PhosphorIconsRegular.shoppingCart,
                      size: 18),
                  label: Text(inCart ? 'View cart' : 'Add to cart'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: AppColors.primary,
                      backgroundColor:
                          inCart ? const Color(0xFFEAF0FF) : Colors.transparent,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AuctionButton(
                    label: soldOut ? 'Out of stock' : 'Buy in bulk',
                    loading: _busy,
                    onPressed: soldOut ? null : () => _buy(it, qty)),
              ),
            ]),
          ]),
        ),
      ),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.fg, this.bg);
  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: fg)),
      );
}

class _Trust extends StatelessWidget {
  const _Trust(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary, height: 1.25)),
        ]),
      );
}

Color _tierFg(String? c) => switch (conditionTier(c)) {
      ConditionTier.brandNew => c == 'OPEN_BOX' ? const Color(0xFF0E7C7C) : const Color(0xFF14A241),
      ConditionTier.refurbished => const Color(0xFF1B5BF2),
      ConditionTier.used => const Color(0xFFB45309),
    };

Color _tierBg(String? c) => switch (conditionTier(c)) {
      ConditionTier.brandNew => c == 'OPEN_BOX' ? const Color(0xFFDDF6F2) : const Color(0xFFE3F7EA),
      ConditionTier.refurbished => const Color(0xFFE5EEFF),
      ConditionTier.used => const Color(0xFFFFF1CF),
    };
