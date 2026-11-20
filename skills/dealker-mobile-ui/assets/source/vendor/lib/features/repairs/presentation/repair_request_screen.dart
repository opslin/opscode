import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/shared/widgets/premium_ui.dart' show A3;
import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show AuctionButton, BottomActionBar, ErrorState, errorText;
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/features/repairs/application/repairs_providers.dart';
import 'package:dealker_vendor/features/repairs/data/offer_draft.dart'
    show groupDevices;
import 'package:dealker_vendor/features/repairs/data/repair_models.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// "Price Accept — vendor gets the customer's repair request": who, what is broken, photos, then Accept / Reject.
class RepairRequestScreen extends ConsumerStatefulWidget {
  const RepairRequestScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<RepairRequestScreen> createState() =>
      _RepairRequestScreenState();
}

class _RepairRequestScreenState extends ConsumerState<RepairRequestScreen> {
  bool _busy = false;

  Future<void> _reject() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reject this request?'),
        content: const Text(
            'The customer is not told. You can move it back to Pending later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep it')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Reject', style: TextStyle(color: RC.red))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(repairsRepositoryProvider).decline(widget.id);
      refreshRepairs(ref, id: widget.id);
      if (mounted) {
        showAppToast(context, 'Request rejected.');
        context.canPop() ? context.pop() : context.go(Routes.repairs);
      }
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(incomingDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: RC.canvas,
      appBar: RepairAppBar(
        title: 'Repair Request',
        onBack: () =>
            context.canPop() ? context.pop() : context.go(Routes.repairs),
      ),
      body: d.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e, 'This request is no longer open.'),
            onRetry: () => ref.invalidate(incomingDetailProvider(widget.id))),
        data: _body,
      ),
      bottomNavigationBar: d.maybeWhen(
        data: (r) => BottomActionBar(
          child: Row(children: [
            Expanded(
              child: AuctionButton(
                  label: 'Reject',
                  outlined: true,
                  danger: true,
                  icon: PhosphorIconsBold.x,
                  onPressed: _busy ? null : _reject),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AuctionButton(
                  label: r.quoted ? 'Change my price' : 'Accept & set price',
                  icon: PhosphorIconsBold.check,
                  onPressed: _busy
                      ? null
                      : () => context.push(Routes.repairPrice(r.id))),
            ),
          ]),
        ),
        orElse: () => null,
      ),
    );
  }

  Widget _body(IncomingRequest r) {
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          HomeCard(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(children: [
                InitialsAvatar(r.firstName, size: 50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.firstName, style: heading(size: 17)),
                        Text('#${r.code}',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.textMuted)),
                      ]),
                ),
                const StatusChip('Pending',
                    kind: ChipKind.amber, icon: PhosphorIconsFill.clock),
              ]),
              if (r.isBulk && (r.businessName ?? '').isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      const StatusChip('BULK', icon: PhosphorIconsFill.stack),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              '${r.businessName} • ${r.items.length} devices',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)))
                    ])),
              const Divider(height: 22, color: RC.line),
              KV('Distance from your shop',
                  r.distanceKm == null ? '—' : kmLabel(r.distanceKm)),
              KV('Area (PIN code)', r.pincode.isEmpty ? '—' : r.pincode),
              KV('Received', shortDate(r.createdAt)),
              KV('Send your price before', shortDate(r.offersCloseAt),
                  color: RC.amber),
              if (r.completedRepairs > 0)
                KV('Repairs done on Dealkr', '${r.completedRepairs}'),
            ]),
          ),
          const SizedBox(height: 14),
          for (final (n, g) in groupDevices(r.items).indexed)
            _DeviceCard(g.first, n + 1, r, qty: g.qty),
          if (r.description.isNotEmpty)
            RepairSection(
              title: 'Customer says',
              art: A3.profile('chat'),
              child: Text(r.description,
                  style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.textSecondary)),
            ),
          if (r.media.isNotEmpty)
            RepairSection(
              title: 'Photos from customer',
              art: A3.profile('camera'),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in r.media)
                  _CustomerPhoto(requestId: r.id, media: m),
              ]),
            ),
          const HintBox(
              'The customer\'s phone number and full address are shown to you only after the customer chooses your shop.',
              icon: PhosphorIconsFill.lockKey),
        ]);
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard(this.item, this.n, this.r, {this.qty = 1});
  final int qty;
  final RepairItem item;
  final int n;
  final IncomingRequest r;

  @override
  Widget build(BuildContext context) => RepairSection(
        title: qty > 1
            ? 'Device $n  ×  $qty phones'
            : (r.items.length > 1 ? 'Device $n' : 'Device'),
        icon: PhosphorIconsFill.deviceMobile,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            DeviceThumb(brand: item.brand, model: item.model, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: heading(size: 16)),
                    if (item.color.isNotEmpty)
                      Text('Colour: ${item.color}',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textSecondary)),
                    if (item.imei.isNotEmpty)
                      Text('IMEI ${item.imei}',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textSecondary)),
                    if (item.warrantyStatus.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: StatusChip(
                            item.warrantyStatus == 'IN_WARRANTY'
                                ? 'Under warranty'
                                : 'Out of warranty',
                            kind: item.warrantyStatus == 'IN_WARRANTY'
                                ? ChipKind.green
                                : ChipKind.grey),
                      ),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          const Text('What is wrong',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted)),
          const SizedBox(height: 8),
          for (final i in item.issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                IssueBadge(i, size: 36),
                const SizedBox(width: 10),
                Expanded(
                    child:
                        Text(issueMeta(i).label, style: heading(size: 14.5))),
              ]),
            ),
          if (item.problemText.isNotEmpty)
            Text(item.problemText,
                style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: AppColors.textSecondary)),
        ]),
      );
}

class _CustomerPhoto extends ConsumerWidget {
  const _CustomerPhoto({required this.requestId, required this.media});
  final String requestId;
  final RequestMedia media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: ref
          .read(repairsRepositoryProvider)
          .incomingMediaUrl(requestId, media.id),
      builder: (_, s) {
        if (media.type == 'VIDEO') {
          return Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
                color: RC.canvas, borderRadius: BorderRadius.circular(12)),
            child: const Icon(PhosphorIconsFill.playCircle,
                color: RC.blue, size: 32),
          );
        }
        if (!s.hasData) {
          return Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                  color: RC.canvas, borderRadius: BorderRadius.circular(12)));
        }
        return EvidenceImage(s.data!, size: 84);
      },
    );
  }
}
