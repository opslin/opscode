import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_extras.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_helpers.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_ui.dart';
import 'package:dealker_app/features/repair/repair_models.dart';
import 'package:dealker_app/features/repair/repair_providers.dart';

/// Finds one quote of a request in the (cached) offers list.
RepairOffer? offerById(RepairOffers? offers, String id) =>
    offers?.offers.where((RepairOffer o) => o.id == id).firstOrNull;

/// Screen 07 — one shop and exactly what its price includes.
class RepairShopScreen extends ConsumerWidget {
  const RepairShopScreen({
    required this.repairId,
    required this.offerId,
    super.key,
  });

  final String repairId;
  final String offerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RepairOffers> offers =
        ref.watch(repairOffersProvider('$repairId|best'));
    final RepairRequest? req =
        ref.watch(repairRequestProvider(repairId)).asData?.value;
    final RepairOffer? o = offerById(offers.asData?.value, offerId);

    if (o == null) {
      return RepairShell(
        title: 'Shop details',
        step: RepairStep.quotes,
        body: offers.hasError
            ? RErrorView(
                offline: isOfflineError(offers.error!),
                onRetry: () =>
                    ref.invalidate(repairOffersProvider('$repairId|best')),
              )
            : offers.isLoading
                ? const RSkeletonCards(count: 2, cardHeight: 220)
                : const RStateView(
                    icon: PhosphorIconsRegular.storefront,
                    title: 'Shop not found',
                    message: 'This shop is no longer available.',
                  ),
      );
    }

    final String area = shopArea(o.address);
    final String sub = <String>[
      if (area.isNotEmpty) area,
      if (o.distanceLabel != null) o.distanceLabel!,
    ].join(' · ');
    final double taxes = o.taxAmount ?? 0;

    return RepairShell(
      title: 'Shop details',
      step: RepairStep.quotes,
      bottom: Row(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Repair price', style: rtBody(12.5)),
              Text(rupees(o.total), style: rtHead(20)),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: RButton(
              label: o.usable ? 'Choose this shop' : 'Shop unavailable',
              onTap: o.usable
                  ? () => context.push('/repair/$repairId/book/$offerId')
                  : null,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(RT.gutter, 14, RT.gutter, 24),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const ShopTile(size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(o.vendorName, style: rtHead(21, h: 1.15)),
                    if (sub.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(sub, style: rtBody(13.5)),
                    ],
                    if (o.hasRating) ...<Widget>[
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          const PhosphorIcon(
                            PhosphorIconsFill.star,
                            size: 15,
                            color: RT.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            o.rating!.toStringAsFixed(1),
                            style: rtHead(14, color: RT.green),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${compactCount(o.ratingCount)})',
                            style: rtBody(13.5),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Repair price', style: rtHead(18)),
          const SizedBox(height: 12),
          RCard(
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'For ${req?.deviceName ?? 'your phone'}',
                        style: rtBody(14),
                      ),
                    ),
                    if (o.usable)
                      const RPill(
                        'Available',
                        kind: PillKind.green,
                        dot: false,
                      )
                    else
                      const RPill('Expired', kind: PillKind.red),
                  ],
                ),
                const Divider(height: 24, color: RT.border),
                for (final OfferLine l in o.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            l.qty > 1
                                ? '${l.description} × ${l.qty.round()}'
                                : l.description,
                            style: rtBody(14.5, h: 1.3),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(rupees(l.amount), style: rtHead(14.5)),
                      ],
                    ),
                  ),
                if (taxes > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: <Widget>[
                        Expanded(child: Text('Taxes', style: rtBody(14.5))),
                        Text(rupees(taxes), style: rtHead(14.5)),
                      ],
                    ),
                  ),
                const Divider(height: 24, color: RT.border),
                Row(
                  children: <Widget>[
                    Expanded(child: Text('Total price', style: rtHead(17))),
                    RepairOfferPrice(o),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Price may change only after inspection and your approval.',
                    style: rtBody(12.5, h: 1.35),
                  ),
                ),
                if (o.validUntil != null && o.usable) ...<Widget>[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Valid until ${fmtDateTime(o.validUntil!)}',
                      style: rtBody(12.5, color: RT.muted),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (o.timeLabel != null || o.warrantyLabel != null) ...<Widget>[
            const SizedBox(height: 24),
            Text('What’s included', style: rtHead(18)),
            const SizedBox(height: 12),
            RCard(
              child: Row(
                children: <Widget>[
                  if (o.timeLabel != null)
                    Expanded(
                      child: _IncludeTile(
                        icon: PhosphorIconsRegular.clock,
                        title: o.timeLabel!,
                        sub: 'Estimated repair time',
                      ),
                    ),
                  if (o.warrantyLabel != null)
                    Expanded(
                      child: _IncludeTile(
                        icon: PhosphorIconsRegular.shieldCheck,
                        title: o.warrantyLabel!,
                        sub: 'Repair warranty',
                      ),
                    ),
                ],
              ),
            ),
          ],
          if ((o.note ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: RT.gap),
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Shop’s note', style: rtHead(15.5)),
                  const SizedBox(height: 6),
                  Text(o.note!, style: rtBody(14, h: 1.45)),
                ],
              ),
            ),
          ],
          if (o.hasRating) ...<Widget>[
            const SizedBox(height: 24),
            Text('Customer reviews', style: rtHead(18)),
            const SizedBox(height: 12),
            RCard(
              child: Row(
                children: <Widget>[
                  Text(
                    '${o.rating!.toStringAsFixed(1)} out of 5',
                    style: rtHead(16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '· ${compactCount(o.ratingCount)} review${o.ratingCount == 1 ? '' : 's'}',
                    style: rtBody(13.5),
                  ),
                  const Spacer(),
                  if (o.rating! >= 4.5)
                    const RPill(
                      'Highly rated',
                      kind: PillKind.green,
                      dot: false,
                    ),
                ],
              ),
            ),
          ],
          if (o.shopVisit || o.pickupDelivery) ...<Widget>[
            const SizedBox(height: 24),
            Text('Available appointment types', style: rtHead(18)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (o.shopVisit)
                  const RChip(
                    'Store visit',
                    icon: PhosphorIconsRegular.storefront,
                    selected: true,
                    height: 38,
                  ),
                if (o.pickupDelivery)
                  const RChip(
                    'Pickup & delivery',
                    icon: PhosphorIconsRegular.truck,
                    selected: true,
                    height: 38,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _IncludeTile extends StatelessWidget {
  const _IncludeTile({
    required this.icon,
    required this.title,
    required this.sub,
  });

  final PhosphorIconData icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PhosphorIcon(icon, size: 22, color: RT.indigo),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: rtHead(15.5)),
              Text(sub, style: rtBody(12.5)),
            ],
          ),
        ),
      ],
    );
  }
}
