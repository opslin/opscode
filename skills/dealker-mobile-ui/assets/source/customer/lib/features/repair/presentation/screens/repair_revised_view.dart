import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/core/utils/server_error.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_helpers.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_ui.dart';
import 'package:dealker_app/features/repair/repair_models.dart';
import 'package:dealker_app/features/repair/repair_providers.dart';

/// Screen 13 — the shop inspected the phone and sent a different price. The
/// customer accepts it or declines and takes the phone back.
class RepairRevisedView extends ConsumerStatefulWidget {
  const RepairRevisedView({required this.request, super.key});

  final RepairRequest request;

  @override
  ConsumerState<RepairRevisedView> createState() => _RepairRevisedViewState();
}

class _RepairRevisedViewState extends ConsumerState<RepairRevisedView> {
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(repairApiProvider).approveEstimate(widget.request.id);
      ref.invalidate(repairRequestProvider(widget.request.id));
      ref.invalidate(repairTrackingProvider(widget.request.id));
      ref.invalidate(repairMineProvider);
    } catch (e) {
      if (mounted) setState(() => _error = ServerError.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final double fee =
        ref.read(repairConfigProvider).asData?.value.diagnosticFee ?? 0;
    final String? reason = await askReason(
      context,
      title: 'Decline new price',
      question: 'Why are you declining?',
      reasons: const <String>[
        'Too expensive',
        'Found a better price',
        'I don’t want the extra repair',
        'Other reason',
      ],
      confirmLabel: 'Decline & return phone',
      warning: fee > 0
          ? 'The shop returns your phone. A diagnostic fee of ${rupees(fee)} may apply.'
          : 'The shop returns your phone.',
    );
    if (reason == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(repairApiProvider)
          .rejectEstimate(widget.request.id, reason);
      ref.invalidate(repairRequestProvider(widget.request.id));
      ref.invalidate(repairTrackingProvider(widget.request.id));
      ref.invalidate(repairMineProvider);
    } catch (e) {
      if (mounted) setState(() => _error = ServerError.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final RepairRequest r = widget.request;
    final RepairQuote? q = r.pendingQuote;
    final RepairOffer? chosen = ref
        .watch(repairOffersProvider('${r.id}|best'))
        .asData
        ?.value
        .offers
        .where((RepairOffer o) => o.selected)
        .firstOrNull;
    final double? original = chosen?.total ?? r.agreedTotal;
    final double? revised = q?.total;
    final double? delta =
        original != null && revised != null ? revised - original : null;
    final double fee =
        ref.watch(repairConfigProvider).asData?.value.diagnosticFee ?? 0;

    // Lines that are new or priced differently from the original quote.
    final List<OfferLine> before = chosen?.lines ?? const <OfferLine>[];
    final List<OfferLine> changed = <OfferLine>[
      for (final OfferLine l in q?.lines ?? const <OfferLine>[])
        if (!before.any(
          (OfferLine b) =>
              b.description == l.description &&
              b.unitPrice == l.unitPrice &&
              b.qty == l.qty,
        ))
          l,
    ];
    final List<OfferLine> shown =
        changed.isEmpty ? (q?.lines ?? const <OfferLine>[]) : changed;

    return RepairShell(
      title: 'Review revised price',
      step: RepairStep.repair,
      onBack: () => context.canPop() ? context.pop() : context.go('/repair'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(RT.gutter, 14, RT.gutter, 24),
        children: <Widget>[
          const RBand(
            'The shop updated its price after inspecting your phone. Review the changes before it continues.',
            kind: BandKind.warn,
          ),
          const SizedBox(height: RT.gap),
          RCard(
            child: Row(
              children: <Widget>[
                RDeviceThumb(r.device, size: 62),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(r.deviceName, style: rtHead(16.5)),
                      const SizedBox(height: 2),
                      Text(
                        r.device?.diagnosis ??
                            q?.note ??
                            'Price updated after inspection',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: rtBody(13.5, h: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Price comparison', style: rtHead(18)),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              if (original != null)
                Expanded(
                  child: _PriceBox(
                    label: 'Original quote',
                    value: rupees(original),
                    strong: false,
                  ),
                ),
              if (original != null) const SizedBox(width: 10),
              Expanded(
                child: _PriceBox(
                  label: 'Revised price',
                  value: revised == null ? '—' : rupees(revised),
                  strong: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              if (delta != null && delta != 0)
                RPill(
                  delta > 0
                      ? 'Increase ${rupees(delta)}'
                      : 'Decrease ${rupees(-delta)}',
                  kind: delta > 0 ? PillKind.red : PillKind.green,
                ),
              const Spacer(),
              if ((r.serviceCenter ?? chosen?.vendorName) != null)
                Flexible(
                  child: Text(
                    'Shop: ${r.serviceCenter ?? chosen!.vendorName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: rtBody(13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text('What changed?', style: rtHead(18)),
          const SizedBox(height: 12),
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int i = 0; i < shown.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 22, color: RT.border),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          shown[i].description,
                          style: rtHead(15, w: FontWeight.w700, h: 1.3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(rupees(shown[i].amount), style: rtHead(15)),
                    ],
                  ),
                ],
                if ((q?.note ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(q!.note!, style: rtBody(13.5, h: 1.4)),
                ],
              ],
            ),
          ),
          if (q?.validUntil != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Reply by ${fmtDateTime(q!.validUntil!)}',
              style: rtBody(13, color: RT.amber, w: FontWeight.w600),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: RT.gap),
            RBand(_error!, kind: BandKind.danger),
          ],
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: RButton(
                  label: 'Decline & return phone',
                  maxLines: 2,
                  outline: true,
                  danger: true,
                  height: RT.buttonHeight,
                  onTap: _busy ? null : _decline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RButton(
                  label: 'Accept new price',
                  maxLines: 2,
                  loading: _busy,
                  onTap: _busy ? null : _accept,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            fee > 0
                ? 'Decline if you do not want the extra repair. A diagnostic fee of ${rupees(fee)} may apply.'
                : 'Decline if you do not want the extra repair.',
            textAlign: TextAlign.center,
            style: rtBody(11.5, color: RT.muted),
          ),
        ],
      ),
    );
  }
}

class _PriceBox extends StatelessWidget {
  const _PriceBox({
    required this.label,
    required this.value,
    required this.strong,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: strong ? RT.tint : const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: strong ? RT.indigo.withValues(alpha: 0.5) : RT.border,
          width: strong ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: <Widget>[
          Text(label, style: rtBody(13, color: RT.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: rtHead(strong ? 25 : 21, color: strong ? RT.ink : RT.grey),
          ),
        ],
      ),
    );
  }
}
