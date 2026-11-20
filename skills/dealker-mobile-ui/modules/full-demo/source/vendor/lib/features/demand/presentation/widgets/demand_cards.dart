import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/demand_common.dart';

class _CardShell extends StatelessWidget {
  const _CardShell(
      {required this.child, required this.onTap, this.tint, this.border});
  final Widget child;
  final VoidCallback onTap;
  final Color? tint;
  final Color? border;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: HomeCard(
            padding: const EdgeInsets.all(12),
            color: tint ?? Colors.white,
            border: border,
            child: child),
      );
}

/// Thumbnail with a small flame badge when the demand is urgent.
class _Thumb extends StatelessWidget {
  const _Thumb(this.url, {this.urgent = false, this.size = 58});
  final String? url;
  final bool urgent;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(clipBehavior: Clip.none, children: [
          ProductThumb(url, size: size, radius: 14),
          if (urgent)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                    color: AppColors.rose,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(PhosphorIconsFill.fire,
                    size: 12, color: Colors.white),
              ),
            ),
        ]),
      );
}

/// A buyer's requirement as a seller sees it in the Demand list.
class DemandCard extends StatelessWidget {
  const DemandCard({super.key, required this.r, required this.onTap});
  final Requirement r;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = priceRange(r);
    final fresh = r.isNew;
    final m = r.myMatch;
    return _CardShell(
      onTap: onTap,
      tint: r.urgent ? const Color(0xFFFFF6F6) : null,
      border: r.urgent ? const Color(0xFFFAD0D0) : null,
      child: Row(children: [
        _Thumb(r.thumbnail, urgent: r.urgent),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (fresh) ...[
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: r.urgent ? AppColors.rose : kDemandBlue,
                        shape: BoxShape.circle)),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  r.urgent
                      ? 'Urgent buying requirement'
                      : (fresh
                          ? 'New buying requirement'
                          : 'Buying requirement'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: r.urgent
                          ? AppColors.rose
                          : (fresh ? kDemandBlue : AppColors.textMuted)),
                ),
              ),
              if (r.bulk && !r.urgent) ...[
                const SizedBox(width: 6),
                const Icon(PhosphorIconsFill.stack,
                    size: 12, color: kAmberText),
              ],
            ]),
            const SizedBox(height: 3),
            Text(requirementTitle(r),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: heading(size: 16.5)),
            const SizedBox(height: 4),
            Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: pcs(r.quantityNeeded),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: AppColors.navy)),
                  if (price != null) TextSpan(text: '  ·  $price'),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, color: AppColors.textSecondary)),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(PhosphorIconsRegular.mapPin,
                  size: 12.5, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  [
                    if (r.deliveryCity != null) r.deliveryCity!,
                    timeAgo(r.createdAt)
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ]),
            if (m != null &&
                m.level != MatchLevel.none &&
                r.myQuote == null) ...[
              const SizedBox(height: 7),
              m.level == MatchLevel.exact
                  ? Pill('You have ${m.stock} in stock',
                      fg: AppColors.mint,
                      bg: AppColors.mintSoft,
                      icon: PhosphorIconsFill.checkCircle)
                  : const Pill('Similar stock',
                      fg: kAmberText,
                      bg: AppColors.amberSoft,
                      icon: PhosphorIconsFill.info),
            ],
          ]),
        ),
        const Icon(PhosphorIconsRegular.caretRight,
            size: 18, color: AppColors.textMuted),
      ]),
    );
  }
}

/// A seller's own offer ("My Offers").
class OfferCard extends StatelessWidget {
  const OfferCard({super.key, required this.r, required this.onTap});
  final Requirement r;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = r.myQuote!;
    final toShip = r.myOrders
        .where((o) =>
            o.status == OrderStatus.paid || o.status == OrderStatus.packed)
        .length;
    return _CardShell(
      onTap: onTap,
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Thumb(r.thumbnail, size: 54),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(requirementTitle(r),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: heading(size: 15.5))),
                const SizedBox(width: 6),
                OfferStatePill(r.offerState),
              ]),
              const SizedBox(height: 4),
              Text('Required: ${pcs(r.quantityNeeded)}',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary)),
              Text('Your offer: ${pcs(q.quantityOffered)}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Text.rich(TextSpan(children: [
            TextSpan(
                text: formatInr(q.unitPrice),
                style:
                    heading(size: 18, color: kDemandBlue, w: FontWeight.w800)),
            const TextSpan(
                text: ' /pc',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ])),
          const Spacer(),
          if (toShip > 0)
            const Pill('Dispatch now',
                fg: kAmberText,
                bg: AppColors.amberSoft,
                icon: PhosphorIconsFill.truck)
          else
            Text(timeAgo(r.createdAt),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }
}

/// A requirement I posted ("My Requests").
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.r, required this.onTap});
  final Requirement r;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = priceRange(r);
    final offers = r.quoteCount ?? 0;
    return _CardShell(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Thumb(r.thumbnail, urgent: r.isUrgent, size: 54),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(requirementTitle(r),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: heading(size: 15.5))),
                const SizedBox(width: 6),
                ReqStatusPill(r.status),
              ]),
              const SizedBox(height: 4),
              Text(
                  [pcs(r.quantityNeeded), if (price != null) price]
                      .join('  ·  '),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              if (r.quantityAwarded > 0)
                Text('${r.quantityAwarded} of ${r.quantityNeeded} awarded',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mint)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(PhosphorIconsFill.users,
              size: 15, color: offers > 0 ? kDemandBlue : AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              offers == 0
                  ? (r.isOpen
                      ? 'No offers yet · ${closesIn(r.responseDeadline).toLowerCase()}'
                      : 'No offers received')
                  : '$offers offer${offers == 1 ? '' : 's'}${r.bestPrice == null ? '' : '  ·  best ${formatInr(r.bestPrice!)}/pc'}',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: offers > 0 ? FontWeight.w700 : FontWeight.w500,
                  color: offers > 0 ? AppColors.navy : AppColors.textMuted),
            ),
          ),
          if (r.isOpen && offers > 0)
            const Text('Select sellers',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: kDemandBlue)),
        ]),
      ]),
    );
  }
}

/// An order in "Orders" (buying or selling).
class OrderCard extends StatelessWidget {
  const OrderCard(
      {super.key, required this.o, required this.buying, required this.onTap});
  final DemandOrder o;
  final bool buying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final other = buying ? o.sellerName : o.buyerName;
    return _CardShell(
      onTap: onTap,
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Thumb(o.thumbnail, size: 54),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  o.productName +
                      (o.storage == null || o.productName.contains(o.storage!)
                          ? ''
                          : ' ${o.storage}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: heading(size: 15.5)),
              const SizedBox(height: 3),
              Text('${pcs(o.quantity)} × ${formatInr(o.unitPrice)}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(buying ? 'From $other' : 'To $other',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatInr(o.subtotal),
                style: heading(size: 16, w: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(buying ? 'You pay' : 'Order value',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          OrderStatusPill(o, buyer: buying),
          const Spacer(),
          Text('${o.orderNumber}  ·  ${timeAgo(o.createdAt)}',
              style:
                  const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }
}
