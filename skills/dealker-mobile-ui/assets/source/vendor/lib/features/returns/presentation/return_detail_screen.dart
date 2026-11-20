import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/returns/application/returns_providers.dart';
import 'package:dealker_vendor/features/returns/data/return_models.dart';
import 'package:dealker_vendor/features/returns/presentation/respond_sheet.dart';
import 'package:dealker_vendor/features/returns/presentation/returns_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// One customer return: what they asked for and why, their photos, the journey, your answer, and a chat with Dealkr.
class ReturnDetailScreen extends ConsumerWidget {
  const ReturnDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(returnDetailProvider(id));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AuctionAppBar(title: async.asData?.value.row.returnNumber ?? 'Return', subtitle: 'Customer return'),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e, 'Could not load this return.'), onRetry: () => ref.invalidate(returnDetailProvider(id))),
        data: (d) => _Body(d),
      ),
      bottomNavigationBar: async.asData == null ? null : _Actions(async.asData!.value),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions(this.d);
  final ReturnDetail d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = d.chat?.unread ?? 0;
    return BottomActionBar(
      child: Row(children: [
        Expanded(
          child: AuctionButton(
            label: unread > 0 ? 'Chat ($unread new)' : 'Chat with Dealkr',
            icon: PhosphorIconsRegular.chatCircleDots,
            outlined: true,
            onPressed: () async {
              await context.push(Routes.returnChat(d.row.id));
              ref.invalidate(returnDetailProvider(d.row.id));
            },
          ),
        ),
        if (d.canRespond) ...[
          const SizedBox(width: 10),
          Expanded(
            child: AuctionButton(
              label: d.response == null ? 'Answer' : 'Change answer',
              icon: PhosphorIconsFill.paperPlaneTilt,
              onPressed: () async {
                final updated = await showRespondSheet(context, returnId: d.row.id, previous: d.response);
                if (updated != null) {
                  ref.invalidate(returnDetailProvider(d.row.id));
                  ref.invalidate(returnsSummaryProvider);
                  ref.invalidate(returnsListProvider);
                  if (context.mounted) showAppToast(context, 'Your answer was sent to the Dealkr team.');
                }
              },
            ),
          ),
        ],
      ]),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.d);
  final ReturnDetail d;

  @override
  Widget build(BuildContext context) {
    final r = d.row;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        HomeCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text('Order ${r.orderNumber}', style: heading(size: 16))),
              StagePill(r.stage),
            ]),
            const SizedBox(height: 6),
            Text(
                '${d.customerName} asked for this return on ${formatDateTime(r.createdAt)}'
                '${d.deliveredAt == null ? '' : ' · delivered ${shortDate(d.deliveredAt)}'}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35)),
            const SizedBox(height: 10),
            Row(children: [
              const Text('At stake on your parcel', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              Text(formatInr(r.atRisk),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navy)),
            ]),
          ]),
        ),
        if (r.stage == ReturnStage.needsResponse) ...[
          const SizedBox(height: 12),
          _Banner(
            icon: PhosphorIconsFill.warningCircle,
            color: const Color(0xFFB45309),
            bg: AppColors.amberSoft,
            text: 'Dealkr is waiting to hear from you. Tap Answer to agree to the return or dispute it with proof.',
          ),
        ],
        if (r.stage == ReturnStage.rejected) ...[
          const SizedBox(height: 12),
          _Banner(
            icon: PhosphorIconsFill.shieldCheck,
            color: AppColors.rose,
            bg: AppColors.roseSoft,
            text: d.teamNote == null ? 'Dealkr rejected this return. Nothing changes on your side.' : 'Dealkr rejected this return: ${d.teamNote}',
          ),
        ],
        const SizedBox(height: 12),
        _Card('Items in this return', child: Column(children: [for (final l in d.items) _Line(l)])),
        const SizedBox(height: 12),
        _Card('What the customer says', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (r.reasonLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(r.reasonLabel!,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.navy)),
            ),
          Text(r.reason, style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary)),
          if (d.evidence.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 78,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final e in d.evidence) _Proof(e),
              ]),
            ),
          ],
        ])),
        if (d.response != null) ...[
          const SizedBox(height: 12),
          _Card('Your answer', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(d.response!.agreed ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.shieldWarning,
                  size: 18, color: d.response!.agreed ? AppColors.mint : AppColors.rose),
              const SizedBox(width: 6),
              Text(d.response!.agreed ? 'You agreed to the return' : 'You disputed the return',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.navy)),
            ]),
            const SizedBox(height: 6),
            Text(d.response!.note, style: const TextStyle(fontSize: 13.5, height: 1.4)),
            if (d.response!.evidence.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                  height: 78,
                  child: ListView(scrollDirection: Axis.horizontal, children: [for (final e in d.response!.evidence) _Proof(e)])),
            ],
          ])),
        ],
        if (d.pickup != null) ...[
          const SizedBox(height: 12),
          _Card('Pickup', child: _PickupInfo(d.pickup!)),
        ],
        if (d.qc != null) ...[
          const SizedBox(height: 12),
          _Card('Quality check', child: _QcInfo(d.qc!)),
        ],
        const SizedBox(height: 12),
        _Card('Progress', child: Column(children: [
          for (var i = 0; i < d.timeline.length; i++) _Step(d.timeline[i], last: i == d.timeline.length - 1),
        ])),
        const SizedBox(height: 12),
        const Text(
            'Dealkr decides every return, arranges the pickup and handles the refund. You never need to pay or ship anything for a return unless the team asks you in chat.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4)),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.bg, required this.text});
  final IconData icon;
  final Color color;
  final Color bg;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, height: 1.35, color: color, fontWeight: FontWeight.w600))),
        ]),
      );
}

class _Card extends StatelessWidget {
  const _Card(this.title, {required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => HomeCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: heading(size: 15.5)),
          const SizedBox(height: 8),
          child,
        ]),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.l);
  final ReturnLine l;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          ProductThumb(l.image, size: 52),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.25, color: AppColors.navy)),
            const SizedBox(height: 2),
            Text('Qty ${l.quantity} × ${formatInr(l.unitPrice)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          Text(formatInr(l.lineTotal), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
        ]),
      );
}

class _Proof extends StatelessWidget {
  const _Proof(this.e);
  final ReturnEvidence e;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () async {
            if (e.isVideo) {
              await launchUrl(Uri.parse(e.url), mode: LaunchMode.externalApplication);
              return;
            }
            if (!context.mounted) return;
            showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.black,
                insetPadding: const EdgeInsets.all(12),
                child: InteractiveViewer(child: CachedNetworkImage(imageUrl: e.url, fit: BoxFit.contain)),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: e.isVideo
                ? Container(
                    width: 78,
                    height: 78,
                    color: AppColors.navy,
                    child: const Icon(PhosphorIconsFill.playCircle, color: Colors.white, size: 34))
                : CachedNetworkImage(
                    imageUrl: e.url,
                    width: 78,
                    height: 78,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                        width: 78,
                        height: 78,
                        color: const Color(0xFFF1F4FB),
                        child: const Icon(PhosphorIconsRegular.imageBroken, color: AppColors.textMuted)),
                  ),
          ),
        ),
      );
}

class _PickupInfo extends StatelessWidget {
  const _PickupInfo(this.p);
  final ReturnPickup p;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.navy)),
        if (p.courier != null || p.provider != null)
          SummaryRow('Courier', p.courier ?? p.provider!),
        if (p.awb != null) SummaryRow('Tracking no.', p.awb!),
        if (p.scheduledAt != null) SummaryRow('Scheduled', formatDateTime(p.scheduledAt)),
        if (p.receivedAt != null) SummaryRow('Received', formatDateTime(p.receivedAt)),
        if (p.trackingUrl != null)
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse(p.trackingUrl!), mode: LaunchMode.externalApplication),
            icon: const Icon(PhosphorIconsRegular.mapPin, size: 18),
            label: const Text('Track the pickup'),
          ),
      ]);
}

class _QcInfo extends StatelessWidget {
  const _QcInfo(this.q);
  final ReturnQc q;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final c in q.checks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(
                  switch (c.status) {
                    'OK' => PhosphorIconsFill.checkCircle,
                    'MINOR_ISSUE' => PhosphorIconsFill.warning,
                    _ => PhosphorIconsFill.xCircle,
                  },
                  size: 18,
                  color: switch (c.status) {
                    'OK' => AppColors.mint,
                    'MINOR_ISSUE' => AppColors.amber,
                    _ => AppColors.rose,
                  }),
              const SizedBox(width: 8),
              Expanded(child: Text(c.note == null ? c.label : '${c.label} — ${c.note}', style: const TextStyle(fontSize: 13.5))),
            ]),
          ),
        if (q.summary != null) ...[
          const SizedBox(height: 6),
          Text(q.summary!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
        ],
      ]);
}

class _Step extends StatelessWidget {
  const _Step(this.s, {required this.last});
  final ReturnStep s;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final done = s.at != null;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 22,
          child: Column(children: [
            Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.primary : Colors.white,
                border: Border.all(color: s.current ? AppColors.amber : (done ? AppColors.primary : AppColors.borderStrong), width: 2),
              ),
            ),
            if (!last) Expanded(child: Container(width: 2, color: AppColors.cardBorder)),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: done || s.current ? AppColors.navy : AppColors.textMuted)),
              if (s.at != null)
                Text(formatDateTime(s.at), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ]),
          ),
        ),
      ]),
    );
  }
}
