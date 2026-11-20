import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/features/repair_book/repair_tokens.dart';
import 'package:dealker_vendor/features/repair_book/shims/server_error.dart';
import 'package:dealker_vendor/features/repair_book/presentation/widgets/repair_extras.dart';
import 'package:dealker_vendor/features/repair_book/presentation/widgets/repair_helpers.dart';
import 'package:dealker_vendor/features/repair_book/presentation/widgets/repair_ui.dart';
import 'package:dealker_vendor/features/repair_book/repair_models.dart';
import 'package:dealker_vendor/features/repair_book/repair_providers.dart';

/// Right after the customer submits: every nearby shop that can fix the phone,
/// nearest first. They tap one to see it or choose it and book.
class RepairQuotesScreen extends ConsumerStatefulWidget {
  const RepairQuotesScreen({required this.repairId, super.key});

  final String repairId;

  @override
  ConsumerState<RepairQuotesScreen> createState() => _RepairShopsScreenState();
}

class _RepairShopsScreenState extends ConsumerState<RepairQuotesScreen> {
  bool _deviceOpen = false;
  bool _cancelling = false;

  String get _key => '${widget.repairId}|best';

  Future<void> _cancel() async {
    final String? reason = await askReason(
      context,
      title: 'Cancel request',
      reasons: const <String>[
        'Changed my mind',
        'Found a better price',
        'Booked by mistake',
        'Other reason',
      ],
      confirmLabel: 'Cancel request',
    );
    if (reason == null || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await ref.read(repairApiProvider).cancel(widget.repairId, reason);
      ref.invalidate(repairMineProvider);
      ref.invalidate(repairRequestProvider(widget.repairId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ServerError.from(e).message)));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RepairOffers> offersAsync =
        ref.watch(repairOffersProvider(_key));
    final RepairRequest? req =
        ref.watch(repairRequestProvider(widget.repairId)).asData?.value;
    final RepairOffers? data = offersAsync.asData?.value;
    final List<RepairOffer> shops =
        List<RepairOffer>.of(data?.usable ?? const <RepairOffer>[])
          ..sort((RepairOffer a, RepairOffer b) =>
              (a.distanceKm ?? double.infinity)
                  .compareTo(b.distanceKm ?? double.infinity));

    Future<void> refresh() async {
      ref.invalidate(repairOffersProvider(_key));
      await ref.read(repairOffersProvider(_key).future).catchError(
            (Object _) => RepairOffers.fromJson(const <String, dynamic>{}),
          );
    }

    return RepairShell(
      title: shops.isEmpty ? 'Shops near you' : 'Shops near you (${shops.length})',
      step: RepairStep.quotes,
      onBack: () => context.canPop() ? context.pop() : context.go('/repair'),
      body: offersAsync.isLoading && data == null
          ? const RSkeletonCards(count: 3, cardHeight: 200)
          : offersAsync.hasError && data == null
              ? RErrorView(
                  offline: isOfflineError(offersAsync.error!),
                  onRetry: () => ref.invalidate(repairOffersProvider(_key)),
                )
              : RefreshIndicator(
                  color: RT.indigo,
                  onRefresh: refresh,
                  child: ListView(
                    padding:
                        const EdgeInsets.fromLTRB(RT.gutter, 14, RT.gutter, 28),
                    children: <Widget>[
                      if (req != null)
                        _DeviceStrip(
                          request: req,
                          open: _deviceOpen,
                          onToggle: () =>
                              setState(() => _deviceOpen = !_deviceOpen),
                        ),
                      const SizedBox(height: 16),
                      const RBand(
                        'Prices are shown up front. Your phone number and full address are shared only after you choose a shop.',
                        kind: BandKind.success,
                      ),
                      const SizedBox(height: 20),
                      if (shops.isEmpty)
                        _NoShopsYet(
                          closesAt: data?.offersCloseAt,
                          onRefresh: refresh,
                        )
                      else ...<Widget>[
                        Text('Pick a shop you like', style: rtHead(20)),
                        const SizedBox(height: 2),
                        Text('Closest shops first. Tap “Choose shop” to book.', style: rtBody(13)),
                        const SizedBox(height: 12),
                        for (final RepairOffer o in shops)
                          Padding(
                            padding: const EdgeInsets.only(bottom: RT.gap),
                            child: _ShopCard(
                              offer: o,
                              request: req,
                              repairId: widget.repairId,
                            ),
                          ),
                      ],
                      if (req?.canCancel ?? false) ...<Widget>[
                        const SizedBox(height: 14),
                        Center(
                          child: _cancelling
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : RLink(
                                  'Cancel request',
                                  onTap: _cancel,
                                  color: RT.red,
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _DeviceStrip extends StatelessWidget {
  const _DeviceStrip({
    required this.request,
    required this.open,
    required this.onToggle,
  });

  final RepairRequest request;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final RepairDevice? d = request.device;
    return RCard(
      onTap: onToggle,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              RDeviceThumb(request.device, size: 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(request.deviceName, style: rtHead(16.5)),
                    if (request.isBulk &&
                        (request.businessName ?? '').isNotEmpty)
                      Text(request.businessName!,
                          style:
                              rtBody(13.5, color: RT.blue, w: FontWeight.w600)),
                    if ((d?.issuesLabel ?? '').isNotEmpty)
                      Text(
                          request.isBulk
                              ? issuesText(request.allIssues)
                              : d!.issuesLabel,
                          style: rtBody(13.5)),
                  ],
                ),
              ),
              PhosphorIcon(
                open ? PhosphorIconsBold.caretUp : PhosphorIconsBold.caretDown,
                size: 16,
                color: RT.ink,
              ),
            ],
          ),
          if (open) ...<Widget>[
            const Divider(height: 22, color: RT.border),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String k in d?.issues ?? const <String>[])
                  RChip(issueProblemName(k), selected: true, height: 30),
              ],
            ),
            if ((d?.description ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(d!.description!, style: rtBody(13.5, h: 1.4)),
            ],
          ],
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.offer,
    required this.request,
    required this.repairId,
  });

  final RepairOffer offer;
  final RepairRequest? request;
  final String repairId;

  @override
  Widget build(BuildContext context) {
    final String area = shopArea(offer.address);
    return RCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ShopTile(size: 62, seed: offer.id),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      offer.vendorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rtHead(16.5),
                    ),
                    if (area.isNotEmpty || offer.distanceLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: <Widget>[
                            const PhosphorIcon(
                              PhosphorIconsRegular.mapPin,
                              size: 14,
                              color: RT.grey,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                <String>[
                                  if (offer.distanceLabel != null)
                                    '${offer.distanceLabel} away',
                                  if (area.isNotEmpty) area,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: rtBody(13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (offer.hasRating)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: <Widget>[
                            const PhosphorIcon(
                              PhosphorIconsFill.star,
                              size: 14,
                              color: RT.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              offer.rating!.toStringAsFixed(1),
                              style: rtHead(13.5, color: RT.green),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${compactCount(offer.ratingCount)} reviews)',
                              style: rtBody(13),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: <Widget>[
              for (final String k in request?.allIssues ?? const <String>[])
                RChip(issueTileName(k, k), height: 30, compact: true),
              if (offer.shopVisit)
                const RChip(
                  'Store visit',
                  icon: PhosphorIconsRegular.storefront,
                  height: 30,
                  compact: true,
                ),
              if (offer.pickupDelivery)
                const RChip(
                  'Pickup',
                  icon: PhosphorIconsRegular.truck,
                  height: 30,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    RepairOfferPrice(offer),
                    const SizedBox(height: 2),
                    Text(
                      (request?.isBulk ?? false) &&
                              (request?.devices.isNotEmpty ?? false)
                          ? '${rupees(offer.total / request!.devices.length)} per device · ${request!.devices.length} devices'
                          : 'Price you pay · parts, work and tax included',
                      style: rtBody(12.5),
                    ),
                  ],
                ),
              ),
              if (offer.timeLabel != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text('Ready in', style: rtBody(12.5)),
                    Text(offer.timeLabel!, style: rtHead(15)),
                  ],
                ),
            ],
          ),
          if (offer.warrantyLabel != null) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                const PhosphorIcon(
                  PhosphorIconsRegular.shieldCheck,
                  size: 16,
                  color: RT.grey,
                ),
                const SizedBox(width: 6),
                Text('${offer.warrantyLabel} warranty', style: rtBody(13)),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: RButton(
                  label: 'View shop',
                  outline: true,
                  height: 48,
                  onTap: () =>
                      context.push('/repair/$repairId/quotes/${offer.id}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RButton(
                  label: 'Choose shop',
                  height: 48,
                  onTap: () =>
                      context.push('/repair/$repairId/book/${offer.id}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nothing to pick yet: say what is happening, in plain words, with a clear next step.
class _NoShopsYet extends StatelessWidget {
  const _NoShopsYet({required this.closesAt, required this.onRefresh});

  final DateTime? closesAt;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: RT.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x141B3C8C),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Image.asset('assets/3d/sell/looking.png', width: 120, height: 120),
          const SizedBox(height: 8),
          Text('Looking for shops near you', style: rtHead(19)),
          const SizedBox(height: 6),
          Text(
            'Repair shops that can fix this phone will send you a price here. Prices appear as soon as a shop replies.',
            textAlign: TextAlign.center,
            style: rtBody(14, h: 1.4),
          ),
          if (closesAt != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: RT.amberTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const PhosphorIcon(
                    PhosphorIconsFill.timer,
                    size: 16,
                    color: RT.amber,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Shops can reply until ${fmtDate(closesAt!)}',
                    style: rtBody(12.5, color: RT.amber, w: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          RButton(
            label: 'Check again',
            outline: true,
            expand: false,
            height: 46,
            onTap: onRefresh,
          ),
        ],
      ),
    );
  }
}
