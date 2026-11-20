import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/core/utils/server_error.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_extras.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_helpers.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_ui.dart';
import 'package:dealker_app/features/repair/repair_models.dart';
import 'package:dealker_app/features/repair/repair_providers.dart';

/// Screens 11 / 12 — step-by-step status for a pickup & delivery repair or a
/// shop visit. Status only: no map, no live courier position.
class RepairTrackingView extends ConsumerStatefulWidget {
  const RepairTrackingView({
    required this.request,
    required this.onRefresh,
    super.key,
  });

  final RepairRequest request;
  final VoidCallback onRefresh;

  @override
  ConsumerState<RepairTrackingView> createState() => _RepairTrackingViewState();
}

class _RepairTrackingViewState extends ConsumerState<RepairTrackingView> {
  bool _cancelling = false;

  Future<void> _cancel() async {
    final String? reason = await askReason(
      context,
      title: widget.request.isStore ? 'Cancel booking' : 'Cancel pickup',
      reasons: const <String>[
        'Changed my mind',
        'Found a better price',
        'Booked by mistake',
        'Other reason',
      ],
      confirmLabel: 'Cancel booking',
      warning: 'You can’t cancel after the phone is handed over.',
    );
    if (reason == null || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await ref.read(repairApiProvider).cancel(widget.request.id, reason);
      ref.invalidate(repairMineProvider);
      widget.onRefresh();
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
    final RepairRequest r = widget.request;
    final AsyncValue<RepairTracking> trackAsync =
        ref.watch(repairTrackingProvider(r.id));
    final RepairTracking? t = trackAsync.asData?.value;
    // The chosen shop's address comes with the selected quote.
    final RepairOffer? chosen = ref
        .watch(repairOffersProvider('${r.id}|best'))
        .asData
        ?.value
        .offers
        .where((RepairOffer o) => o.selected)
        .firstOrNull;
    final String? shopName =
        t?.shopName ?? r.serviceCenter ?? chosen?.vendorName;
    final bool closed = r.cancelled || (t?.closed ?? false);

    return RepairShell(
      title: 'Track repair',
      step: closed ? null : r.journeyStep,
      onBack: () => context.canPop() ? context.pop() : context.go('/repair'),
      body: RefreshIndicator(
        color: RT.indigo,
        onRefresh: () async => widget.onRefresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(RT.gutter, 14, RT.gutter, 28),
          children: <Widget>[
            _TopCard(request: r, shopName: shopName, phone: t?.shopPhone),
            if (closed) ...<Widget>[
              const SizedBox(height: RT.gap),
              RBand(
                r.note ?? 'This request is closed.',
                kind: BandKind.danger,
                bold: repairStatusLabel(r),
              ),
            ] else if (r.ready) ...<Widget>[
              const SizedBox(height: RT.gap),
              RBand(
                r.isStore
                    ? 'Your phone is ready. Please collect it during shop opening hours.'
                    : 'Your phone is ready and will be delivered to you.',
                kind: BandKind.success,
                icon: PhosphorIconsRegular.check,
              ),
            ],
            if (r.isStore && !closed) ...<Widget>[
              const SizedBox(height: 22),
              Text('Store appointment', style: rtHead(18)),
              const SizedBox(height: 12),
              _StoreCard(
                request: r,
                shopName: shopName,
                address: chosen?.address,
                phone: t?.shopPhone,
              ),
            ],
            const SizedBox(height: 22),
            Text('Repair progress', style: rtHead(18)),
            const SizedBox(height: 12),
            if (t == null && trackAsync.isLoading)
              const RSkeleton(height: 280, radius: 16)
            else if (t == null)
              RErrorView(
                offline: isOfflineError(trackAsync.error ?? ''),
                onRetry: () => ref.invalidate(repairTrackingProvider(r.id)),
              )
            else
              _Timeline(tracking: t, request: r),
            if (t?.courier != null) ...<Widget>[
              const SizedBox(height: 22),
              Text('Courier details', style: rtHead(18)),
              const SizedBox(height: 12),
              _CourierCard(meta: t!.courier!),
            ],
            if (r.serviceCenter != null && !closed) ...<Widget>[
              const SizedBox(height: 22),
              Text('Your technician', style: rtHead(18)),
              const SizedBox(height: 12),
              RepairTechnicianCard(request: r),
            ],
            if (!closed)
              RepairMismatchAlerts(request: r, onChanged: widget.onRefresh),
            if (r.updates.any((RepairUpdate u) => u.checks.isEmpty) &&
                !closed) ...<Widget>[
              const SizedBox(height: 22),
              Text('Repair updates', style: rtHead(18)),
              const SizedBox(height: 12),
              _Updates(request: r),
            ],
            if ((t?.note ?? '').isNotEmpty && !closed) ...<Widget>[
              const SizedBox(height: 22),
              Text('Latest shop update', style: rtHead(18)),
              const SizedBox(height: 12),
              RCard(
                child: Text(
                  t!.note!,
                  style: rtBody(14.5, color: RT.ink, h: 1.4),
                ),
              ),
            ],
            RepairChecksCard(request: r),
            if (!closed) RepairPayNowCard(request: r),
            const SizedBox(height: RT.gap + 4),
            _PaymentSummary(request: r),
            if (r.canCancel && !closed) ...<Widget>[
              const SizedBox(height: 14),
              Center(
                child: _cancelling
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : RLink(
                        r.isStore ? 'Cancel booking' : 'Cancel pickup',
                        onTap: _cancel,
                        color: RT.red,
                      ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                if ((t?.shopPhone ?? '').isNotEmpty)
                  RLink(
                    'Call shop',
                    icon: PhosphorIconsRegular.phone,
                    onTap: () => callPhone(context, t!.shopPhone),
                  )
                else
                  const SizedBox.shrink(),
                RLink(
                  'Support',
                  icon: PhosphorIconsRegular.headset,
                  onTap: () => context.push('/support/chat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({
    required this.request,
    required this.shopName,
    required this.phone,
  });

  final RepairRequest request;
  final String? shopName;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final PillKind kind = request.ready
        ? PillKind.green
        : (request.cancelled ? PillKind.red : PillKind.indigo);
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: RPill(
                  request.ready && request.isStore
                      ? 'Ready for pickup'
                      : repairStatusLabel(request),
                  kind: kind,
                ),
              ),
              const Spacer(),
              if ((phone ?? '').isNotEmpty)
                RLink(
                  'Call shop',
                  icon: PhosphorIconsRegular.phone,
                  onTap: () => callPhone(context, phone),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              RDeviceThumb(request.device, size: 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      request.deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: rtHead(17),
                    ),
                    if ((shopName ?? '').isNotEmpty)
                      Text(
                        shopName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rtBody(13.5),
                      ),
                    if ((request.device?.issuesLabel ?? '').isNotEmpty)
                      Text(
                        'Repair: ${request.device!.issuesLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rtBody(13.5),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Booking ${request.code}', style: rtBody(12, color: RT.muted)),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.request,
    required this.shopName,
    required this.address,
    required this.phone,
  });

  final RepairRequest request;
  final String? shopName;
  final String? address;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final String query = <String>[
      if ((shopName ?? '').isNotEmpty) shopName!,
      if ((address ?? '').isNotEmpty) address!,
    ].join(', ');
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const PhosphorIcon(
                PhosphorIconsRegular.mapPin,
                size: 22,
                color: RT.indigo,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(shopName ?? 'Repair shop', style: rtHead(16)),
                    if ((address ?? '').isNotEmpty)
                      Text(
                        address!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: rtBody(13.5, h: 1.3),
                      ),
                    if (request.appointmentAt != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        '${fmtDay(request.appointmentAt!)} · ${fmtTime(request.appointmentAt!)}',
                        style: rtBody(13.5, color: RT.ink, w: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              if (query.isNotEmpty)
                RLink(
                  'Open in Google Maps',
                  icon: PhosphorIconsRegular.arrowBendUpRight,
                  onTap: () => openMaps(context, query),
                ),
              if ((phone ?? '').isNotEmpty)
                RLink(
                  'Call shop',
                  icon: PhosphorIconsRegular.phone,
                  onTap: () => callPhone(context, phone),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.tracking, required this.request});

  final RepairTracking tracking;
  final RepairRequest request;

  String _sub(TrackStep s) {
    if (s.done) {
      final String at = s.at == null ? '' : fmtDateTime(s.at!);
      return switch (s.key) {
        'PICKUP_SCHEDULED' when request.pickupSlot != null =>
          'Pickup · ${fmtDay(request.pickupSlot!)}, ${fmtTime(request.pickupSlot!)}',
        'APPOINTMENT_BOOKED' when request.appointmentAt != null =>
          '${fmtDay(request.appointmentAt!)} · ${fmtTime(request.appointmentAt!)}',
        'COMPLETED' => at,
        _ => at,
      };
    }
    if (s.current) {
      return switch (s.key) {
        'ACCEPTED' => 'The shop will confirm your booking',
        'PICKUP_SCHEDULED' => request.pickupSlot != null
            ? 'Pickup · ${fmtDay(request.pickupSlot!)}, ${fmtTime(request.pickupSlot!)}'
            : 'Pickup being arranged',
        'PICKED_UP' => 'Courier is collecting your phone',
        'APPOINTMENT_BOOKED' => request.appointmentAt != null
            ? '${fmtDay(request.appointmentAt!)} · ${fmtTime(request.appointmentAt!)}'
            : 'Waiting for the shop to confirm',
        'INSPECTION' => 'The shop is checking your phone',
        'IN_REPAIR' => 'Repair in progress',
        'QC_PENDING' => 'Final quality checks',
        'OUT_FOR_DELIVERY' => 'On its way to you',
        'READY_FOR_DELIVERY' => 'Ready to collect',
        _ => 'In progress',
      };
    }
    return 'Not started';
  }

  @override
  Widget build(BuildContext context) {
    final List<TrackStep> steps = tracking.steps;
    return RCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < steps.length; i++)
            _TimelineRow(
              step: steps[i],
              sub: _sub(steps[i]),
              last: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.sub,
    required this.last,
  });

  final TrackStep step;
  final String sub;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final bool done = step.done;
    final bool cur = step.current;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 30,
            child: Column(
              children: <Widget>[
                if (done)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: RT.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: PhosphorIcon(
                        PhosphorIconsBold.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  )
                else if (cur)
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: RT.indigo.withValues(alpha: 0.18),
                    ),
                    child: Center(
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: RT.indigo,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFC9CDE0),
                        width: 1.6,
                      ),
                    ),
                  ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: done ? const Color(0xFFA8D5B5) : RT.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    step.label,
                    style: rtHead(
                      15,
                      color: cur ? RT.indigo : RT.ink,
                      w: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: rtBody(
                      12.5,
                      color: done || cur ? RT.grey : RT.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourierCard extends StatelessWidget {
  const _CourierCard({required this.meta});

  final Map<String, dynamic> meta;

  @override
  Widget build(BuildContext context) {
    final String? name = '${meta['courier'] ?? ''}'.trim().isEmpty
        ? null
        : '${meta['courier']}'.trim();
    final String? id = '${meta['trackingId'] ?? ''}'.trim().isEmpty
        ? null
        : '${meta['trackingId']}'.trim();
    final String? url = '${meta['trackingUrl'] ?? ''}'.trim().isEmpty
        ? null
        : '${meta['trackingUrl']}'.trim();
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const RIconTile(
                PhosphorIconsRegular.truck,
                size: 46,
                iconSize: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (name != null) Text(name, style: rtHead(16)),
                    if (id != null) Text('Tracking ID $id', style: rtBody(13)),
                  ],
                ),
              ),
              if (id != null)
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tracking ID copied')),
                    );
                  },
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.copy,
                    size: 20,
                    color: RT.indigo,
                  ),
                ),
            ],
          ),
          if (url != null) ...<Widget>[
            const SizedBox(height: 4),
            RLink(
              'Track on courier site',
              trailingChevron: true,
              onTap: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentSummary extends StatefulWidget {
  const _PaymentSummary({required this.request});

  final RepairRequest request;

  @override
  State<_PaymentSummary> createState() => _PaymentSummaryState();
}

class _PaymentSummaryState extends State<_PaymentSummary> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final RepairMoney m = widget.request.money;
    if (m.approvedTotal <= 0 && m.amountPaid <= 0) {
      return const SizedBox.shrink();
    }
    return RCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => setState(() => _open = !_open),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Payment summary', style: rtHead(15.5)),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        if (m.approvedTotal > 0)
                          'Quote ${rupees(m.approvedTotal)}',
                        if (m.amountPaid > 0) 'Paid ${rupees(m.amountPaid)}',
                      ].join(' · '),
                      style: rtBody(13),
                    ),
                  ],
                ),
              ),
              PhosphorIcon(
                _open ? PhosphorIconsBold.caretUp : PhosphorIconsBold.caretDown,
                size: 16,
                color: RT.ink,
              ),
            ],
          ),
          if (_open) ...<Widget>[
            const Divider(height: 22, color: RT.border),
            if (m.approvedTotal > 0)
              _row('Repair quote', rupees(m.approvedTotal)),
            if (m.amountPaid > 0) _row('Paid so far', rupees(m.amountPaid)),
            _row('Balance due', rupees(m.amountDue), bold: true),
            const SizedBox(height: 4),
            Text(
              'Pay in the app, or pay the shop — they mark it as paid.',
              style: rtBody(12, color: RT.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String l, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l,
                style: rtBody(
                  14,
                  color: bold ? RT.ink : RT.grey,
                  w: bold ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              v,
              style: rtHead(14.5, w: bold ? FontWeight.w800 : FontWeight.w700),
            ),
          ],
        ),
      );
}

/// The shop's progress notes — one line per repair ("Battery replacement completed"), the part used,
/// and the photos it took.
class _Updates extends StatelessWidget {
  const _Updates({required this.request});

  final RepairRequest request;

  @override
  Widget build(BuildContext context) {
    final List<RepairUpdate> list = request.updates.reversed
        .where((RepairUpdate u) => u.checks.isEmpty)
        .take(8)
        .toList(growable: false);
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final (int i, RepairUpdate u) in list.indexed) ...<Widget>[
            if (i > 0) const Divider(height: 22, color: RT.border),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: u.done ? RT.greenTint : RT.tint,
                    shape: BoxShape.circle,
                  ),
                  child: PhosphorIcon(
                    u.done
                        ? PhosphorIconsBold.check
                        : PhosphorIconsRegular.wrench,
                    size: 18,
                    color: u.done ? RT.green : RT.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        u.label,
                        style: rtHead(14.5, w: FontWeight.w700, h: 1.3),
                      ),
                      if (u.partName != null)
                        Text(
                          'Part: ${u.partName}'
                          '${(u.partWarrantyDays ?? 0) > 0 ? ' · ${u.partWarrantyDays} days warranty' : ''}',
                          style: rtBody(13),
                        ),
                      if (u.at != null)
                        Text(fmtDate(u.at!),
                            style: rtBody(12, color: RT.muted)),
                      if (u.before.isNotEmpty || u.after.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _PhotoGroup(
                                  'Before', u.before, request.mediaUrls),
                              const SizedBox(width: 12),
                              _PhotoGroup('After', u.after, request.mediaUrls),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (request.progressPhotos.isNotEmpty &&
              !list.any((RepairUpdate u) =>
                  u.before.isNotEmpty || u.after.isNotEmpty)) ...<Widget>[
            const SizedBox(height: 14),
            Text('Photos from the shop', style: rtHead(14, w: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 78,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  for (final String url in request.progressPhotos)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          webImageSource(_absoluteUrl(url)),
                          width: 78,
                          height: 78,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 78,
                            height: 78,
                            color: RT.field,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Signed evidence links come relative to the API host.
String _absoluteUrl(String u) =>
    u.startsWith('http') ? u : '${Uri.parse(ApiConstants.baseUrl).origin}$u';

class _PhotoGroup extends StatelessWidget {
  const _PhotoGroup(this.title, this.ids, this.urls);

  final String title;
  final List<String> ids;
  final Map<String, String> urls;

  @override
  Widget build(BuildContext context) {
    final List<String> shown = <String>[
      for (final String id in ids)
        if (urls[id] != null) urls[id]!
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: rtHead(12, color: RT.grey, w: FontWeight.w700)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final String u in shown)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  webImageSource(repairAbsoluteUrl(u)),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(width: 64, height: 64, color: RT.field),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
