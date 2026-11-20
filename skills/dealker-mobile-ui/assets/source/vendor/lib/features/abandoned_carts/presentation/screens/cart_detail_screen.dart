import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/abandoned_carts/application/cart_providers.dart';
import 'package:dealker_vendor/features/abandoned_carts/data/cart_models.dart';
import 'package:dealker_vendor/features/abandoned_carts/presentation/widgets/cart_common.dart';
import 'package:dealker_vendor/features/abandoned_carts/presentation/widgets/send_coupon_sheet.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// The vendor's slice of one abandoned cart: their items, the timeline, and the reminder action.
class CartDetailScreen extends ConsumerWidget {
  const CartDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(cartDetailProvider(id));
    return detail.when(skipLoadingOnReload: true, skipError: true, 
      loading: () => const Scaffold(
          appBar: AuctionAppBar(title: 'Cart Details'),
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          appBar: const AuctionAppBar(title: 'Cart Details'),
          body: ErrorState(
              message: errorText(e, 'Could not load this cart.'),
              onRetry: () => ref.invalidate(cartDetailProvider(id)))),
      data: (d) => Scaffold(
        backgroundColor: Colors.white,
        appBar: const AuctionAppBar(title: 'Cart Details'),
        bottomNavigationBar: _Footer(d: d),
        body: RefreshIndicator(
          color: kCartViolet,
          onRefresh: () async {
            refreshCarts(ref, id: id);
            await ref.read(cartDetailProvider(id).future).catchError((_) => d);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              _Header(d: d),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: Text('Your items (${d.items.length})',
                        style: heading(size: 17))),
                Text(formatInr(d.total), style: heading(size: 17)),
              ]),
              const SizedBox(height: 10),
              HomeCard(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  for (final (i, l) in d.items.indexed) ...[
                    if (i > 0) const Divider(height: 22),
                    _Line(l, onCoupon: d.open && d.couponRules.canSend ? () => showSendCouponSheet(context, cart: d, line: l) : null),
                  ],
                ]),
              ),
              if (d.open && !d.couponRules.canSend && d.couponRules.message != null) ...[
                const SizedBox(height: 10),
                Text(d.couponRules.message!, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              ],
              if (d.coupons.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Coupons you sent', style: heading(size: 17)),
                const SizedBox(height: 10),
                for (final c in d.coupons) _CouponTile(c: c, onCancel: c.active ? () async {
                  try {
                    await ref.read(cartRepositoryProvider).cancelCoupon(d.id, c.id);
                    refreshCarts(ref, id: d.id);
                  } catch (e) {
                    if (context.mounted) showAppToast(context, errorText(e, 'Could not cancel the coupon.'));
                  }
                } : null),
              ],
              const SizedBox(height: 10),
              const AdNotice(
                message:
                    'You only see your own products. Items from other sellers in this cart stay private.',
                icon: PhosphorIconsFill.lockSimple,
              ),
              const SizedBox(height: 18),
              Text('Recovery timeline', style: heading(size: 17)),
              const SizedBox(height: 12),
              _Timeline(d: d),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.d});
  final CartDetail d;

  @override
  Widget build(BuildContext context) => HomeCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CartAvatar(d.customer, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                    child: Text(d.customer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: heading(size: 18))),
                const SizedBox(width: 8),
                ChannelChip(d.channel),
              ]),
              const SizedBox(height: 4),
              Text('Left ${humanIdle(d.abandonedAt).toLowerCase()}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              const Text(
                  'Contact details are private — reminders go through the app.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ]),
          ),
        ]),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.l, {this.onCoupon});
  final CartLine l;
  final VoidCallback? onCoupon;

  @override
  Widget build(BuildContext context) => Column(children: [
        _row(),
        if (onCoupon != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onCoupon,
              icon: const Icon(PhosphorIconsFill.tag, size: 16),
              label: const Text('Send coupon'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kCartViolet,
                side: const BorderSide(color: kCartViolet),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ]);

  Widget _row() => Row(children: [
        ProductThumb(l.thumbnail, size: 56, radius: 12),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, height: 1.25)),
            const SizedBox(height: 3),
            Text('${formatInr(l.unitPrice)}  ·  Qty ${l.quantity}',
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary)),
            if (l.outOfStock)
              const _Tag('Out of stock', AppColors.rose, AppColors.roseSoft)
            else if (l.lowStock)
              _Tag('Only ${l.stock} left', const Color(0xFFB45309),
                  AppColors.amberSoft),
          ]),
        ),
        const SizedBox(width: 8),
        Text(formatInr(l.lineTotal), style: heading(size: 15)),
      ]);
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.fg, this.bg);
  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ),
      );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.d});
  final CartDetail d;

  static (String, IconData, Color) _look(TimelineEntry e) => switch (e.kind) {
        'DETECTED' => (
            'Cart abandoned',
            PhosphorIconsFill.shoppingCart,
            kCartViolet
          ),
        'MY_REMINDER' => (
            'Reminder sent (notification)',
            PhosphorIconsFill.bellRinging,
            const Color(0xFF3B6FE0)
          ),
        'RECOVERED' => (
            'Customer came back to the cart',
            PhosphorIconsFill.arrowUUpLeft,
            const Color(0xFFB45309)
          ),
        'CONVERTED' => (
            'Order placed',
            PhosphorIconsFill.checkCircle,
            AppColors.mint
          ),
        'EXPIRED' => (
            'Cart expired',
            PhosphorIconsFill.clockCountdown,
            AppColors.textMuted
          ),
        _ => (e.kind, PhosphorIconsFill.circle, AppColors.textMuted),
      };

  @override
  Widget build(BuildContext context) {
    final entries = d.timeline;
    final pending = d.open;
    final total = entries.length + (pending ? 1 : 0);
    return Column(children: [
      for (final (i, e) in entries.indexed)
        _Step(
          icon: _look(e).$2,
          color: _look(e).$3,
          title: _look(e).$1,
          subtitle: humanIdle(e.at),
          last: i == total - 1,
        ),
      if (pending)
        const _Step(
          icon: PhosphorIconsRegular.circle,
          color: AppColors.textMuted,
          title: 'Not recovered yet',
          subtitle: '',
          last: true,
          hollow: true,
        ),
    ]);
  }
}

class _Step extends StatelessWidget {
  const _Step(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.last,
      this.hollow = false});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool last;
  final bool hollow;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 30,
            child: Column(children: [
              Icon(icon, size: 22, color: color),
              if (!last)
                Expanded(
                    child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        color: AppColors.cardBorder)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color:
                                hollow ? AppColors.textMuted : AppColors.navy)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textMuted)),
                  ]),
            ),
          ),
        ]),
      );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.d});
  final CartDetail d;

  @override
  Widget build(BuildContext context) {
    final r = d.reminder;
    if (!d.open && r.message == null) return const SizedBox.shrink();
    return BottomActionBar(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!r.canRemind && r.message != null) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(PhosphorIconsFill.info,
                size: 17, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
                child: Text(r.message!,
                    style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textSecondary))),
          ]),
          const SizedBox(height: 10),
        ],
        CartButton(
          label: r.sent > 0 && r.canRemind
              ? 'Send another reminder'
              : 'Send Reminder',
          icon: PhosphorIconsBold.paperPlaneTilt,
          onPressed: r.canRemind
              ? () => context.push(Routes.abandonedCartRemind(d.id))
              : null,
        ),
        if (r.sent > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${r.sent} of ${r.max} reminders used for this cart',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
      ]),
    );
  }
}

class _CouponTile extends StatelessWidget {
  const _CouponTile({required this.c, this.onCancel});
  final SentCoupon c;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (c.status) {
      'ACTIVE' => (AppColors.mint, AppColors.mintSoft),
      'USED' => (kCartViolet, AppColors.violetSoft),
      _ => (AppColors.textMuted, const Color(0xFFEFF1F6)),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Icon(PhosphorIconsFill.tag, color: fg, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${c.label} · ${c.code}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(c.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            if (c.validUntil != null && c.active)
              Text('Valid till ${c.validUntil!.day}/${c.validUntil!.month}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
            child: Text(switch (c.status) { 'ACTIVE' => 'Active', 'USED' => 'Used', 'EXPIRED' => 'Expired', _ => 'Cancelled' },
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg)),
          ),
          if (onCancel != null)
            TextButton(onPressed: onCancel, style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)), child: const Text('Cancel', style: TextStyle(fontSize: 12))),
        ]),
      ]),
    );
  }
}
