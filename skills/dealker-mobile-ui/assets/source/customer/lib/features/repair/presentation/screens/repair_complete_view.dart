import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/core/utils/server_error.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_extras.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_helpers.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_ui.dart';
import 'package:dealker_app/features/repair/repair_models.dart';
import 'package:dealker_app/features/repair/repair_providers.dart';

const List<String> _tags = <String>['Good service', 'On time', 'Fair price'];

/// Screen 14 — repaired: what was paid, the warranty, and a rating for the shop.
class RepairCompleteView extends ConsumerStatefulWidget {
  const RepairCompleteView({required this.request, super.key});

  final RepairRequest request;

  @override
  ConsumerState<RepairCompleteView> createState() => _RepairCompleteViewState();
}

class _RepairCompleteViewState extends ConsumerState<RepairCompleteView> {
  int _stars = 0;
  final Set<String> _picked = <String>{};
  final TextEditingController _review = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String text = <String>[
        if (_picked.isNotEmpty) '${_picked.join(', ')}.',
        _review.text.trim(),
      ].where((String e) => e.isNotEmpty).join(' ');
      await ref.read(repairApiProvider).rate(widget.request.id, _stars, text);
      ref.invalidate(repairRequestProvider(widget.request.id));
      ref.invalidate(repairMineProvider);
    } catch (e) {
      if (mounted) setState(() => _error = ServerError.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim() async {
    final String? reason = await askReason(
      context,
      title: 'Claim warranty',
      question: 'What is wrong now?',
      reasons: const <String>[
        'Same problem again',
        'The repair isn’t working',
        'A new problem after the repair',
        'Other reason',
      ],
      confirmLabel: 'Send warranty claim',
      danger: false,
    );
    if (reason == null || !mounted) return;
    try {
      await ref.read(repairApiProvider).reopen(widget.request.id, reason);
      ref.invalidate(repairRequestProvider(widget.request.id));
      ref.invalidate(repairMineProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ServerError.from(e).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final RepairRequest r = widget.request;
    final RepairTracking? t =
        ref.watch(repairTrackingProvider(r.id)).asData?.value;
    final TrackStep? last = t?.steps.where((TrackStep s) => s.done).lastOrNull;
    final String how = r.isStore
        ? 'Collected from ${r.serviceCenter ?? 'the shop'}'
        : 'Delivered to you';
    final String when = last?.at == null ? '' : ' · ${fmtDateTime(last!.at!)}';
    final DateTime? until =
        r.warrantyUntil == null ? null : DateTime.tryParse(r.warrantyUntil!);
    final bool inWarranty = until != null &&
        !until.isBefore(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        );
    final bool rated = r.ratingStars != null;

    return RepairShell(
      title: 'Repair completed',
      step: RepairStep.done,
      onBack: () => context.canPop() ? context.pop() : context.go('/repair'),
      bottom: rated
          ? null
          : RButton(
              label: 'Submit review',
              loading: _busy,
              onTap: _stars == 0 ? null : _submit,
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(RT.gutter, 22, RT.gutter, 24),
        children: <Widget>[
          const Center(
            child: RIconTile(
              PhosphorIconsBold.check,
              size: 62,
              iconSize: 28,
              circle: true,
              color: RT.green,
              bg: RT.greenTint,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Your phone is repaired',
            textAlign: TextAlign.center,
            style: rtHead(22),
          ),
          const SizedBox(height: 6),
          Text('$how$when', textAlign: TextAlign.center, style: rtBody(14)),
          const SizedBox(height: 20),
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    RDeviceThumb(r.device, size: 62),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(r.deviceName, style: rtHead(17)),
                          if ((r.device?.issuesLabel ?? '').isNotEmpty)
                            Text(
                              '${r.device!.issuesLabel} repaired',
                              style: rtBody(13.5),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    const RPill('Completed', kind: PillKind.green),
                    const Spacer(),
                    Text(r.code, style: rtBody(12.5, color: RT.muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Payment summary', style: rtHead(18)),
          const SizedBox(height: 12),
          _Payments(request: r),
          if (until != null) ...<Widget>[
            const SizedBox(height: 22),
            Text('Your repair warranty', style: rtHead(18)),
            const SizedBox(height: 12),
            RCard(
              child: Row(
                children: <Widget>[
                  PhosphorIcon(
                    PhosphorIconsRegular.shieldCheck,
                    size: 30,
                    color: inWarranty ? RT.green : RT.muted,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          inWarranty ? 'Repair warranty' : 'Warranty ended',
                          style: rtHead(15.5),
                        ),
                        Text(
                          '${inWarranty ? 'Valid until' : 'Ended on'} ${fmtDate(until)}',
                          style: rtBody(13.5),
                        ),
                      ],
                    ),
                  ),
                  if (inWarranty)
                    RButton(
                      label: 'Claim',
                      outline: true,
                      expand: false,
                      height: 44,
                      onTap: _claim,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text(
            rated ? 'Thanks for your review' : 'How was your repair?',
            style: rtHead(18),
          ),
          const SizedBox(height: 12),
          RCard(
            child: Column(
              children: <Widget>[
                Text(
                  'Rate ${r.serviceCenter ?? 'the shop'}',
                  textAlign: TextAlign.center,
                  style: rtHead(15.5),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (int i = 1; i <= 5; i++)
                      GestureDetector(
                        onTap: rated ? null : () => setState(() => _stars = i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: PhosphorIcon(
                            (rated ? r.ratingStars! : _stars) >= i
                                ? PhosphorIconsFill.star
                                : PhosphorIconsRegular.star,
                            size: 34,
                            color: RT.star,
                          ),
                        ),
                      ),
                  ],
                ),
                if (rated && (r.ratingReview ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    r.ratingReview!,
                    textAlign: TextAlign.center,
                    style: rtBody(14, h: 1.4),
                  ),
                ] else if (!rated) ...<Widget>[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      for (final String t in _tags)
                        RChip(
                          t,
                          height: 34,
                          selected: _picked.contains(t),
                          onTap: () => setState(
                            () => _picked.contains(t)
                                ? _picked.remove(t)
                                : _picked.add(t),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _review,
                    maxLength: 400,
                    maxLines: 3,
                    minLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Write a review (optional)',
                      counterText: '',
                      filled: true,
                      fillColor: RT.field,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  RBand(_error!, kind: BandKind.danger),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (r.invoiceId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RButton(
                label: 'View invoice',
                outline: true,
                height: 48,
                icon: PhosphorIconsBold.fileText,
                onTap: () => openRepairInvoice(context, ref, r),
              ),
            ),
          const SizedBox(height: 8),
          RLink(
            'Repair another phone',
            icon: PhosphorIconsRegular.wrench,
            onTap: () {
              ref.read(repairDraftProvider.notifier).reset();
              context.push('/repair/new');
            },
          ),
        ],
      ),
    );
  }
}

class _Payments extends StatelessWidget {
  const _Payments({required this.request});

  final RepairRequest request;

  static String _kind(String k) => switch (k) {
        'ADVANCE' => 'Advance paid',
        'BALANCE' => 'Balance paid',
        'DIAGNOSTIC' => 'Diagnostic fee',
        'REFUND' => 'Refunded',
        _ => 'Payment',
      };

  @override
  Widget build(BuildContext context) {
    final RepairMoney m = request.money;
    final List<RepairPayment> pays = request.payments
        .where((RepairPayment p) => p.kind != 'REFUND')
        .toList();
    final RepairPayment? lastPaid = pays.isEmpty ? null : pays.last;
    final String? method = lastPaid?.method;
    return RCard(
      child: Column(
        children: <Widget>[
          if (m.approvedTotal > 0)
            _row('Repair total', rupees(m.approvedTotal)),
          for (final RepairPayment p in pays)
            _row(_kind(p.kind), rupees(p.amount)),
          const Divider(height: 22, color: RT.border),
          Row(
            children: <Widget>[
              Expanded(child: Text('Total paid', style: rtHead(16))),
              Text(rupees(m.amountPaid), style: rtHead(21)),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              <String>[
                'Payment recorded by shop',
                if ((method ?? '').isNotEmpty) method!,
              ].join(' · '),
              style: rtBody(12.5),
            ),
          ),
          if (m.amountDue > 0) ...<Widget>[
            const SizedBox(height: 10),
            RBand(
              'Balance due ${rupees(m.amountDue)}. Pay the shop directly.',
              kind: BandKind.warn,
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(l, style: rtBody(14.5))),
            Text(v, style: rtHead(14.5)),
          ],
        ),
      );
}
