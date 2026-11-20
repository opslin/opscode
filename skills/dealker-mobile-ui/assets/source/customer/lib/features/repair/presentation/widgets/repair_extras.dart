import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/files/pdf_file.dart';
import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/core/utils/server_error.dart';
import 'package:dealker_app/features/repair/presentation/widgets/repair_ui.dart';
import 'package:dealker_app/features/repair/repair_models.dart';
import 'package:dealker_app/features/repair/repair_providers.dart';

/// "https://host/api/v1" → signed relative evidence links become absolute.
String repairAbsoluteUrl(String u) =>
    u.startsWith('http') ? u : '${Uri.parse(ApiConstants.baseUrl).origin}$u';

void _snack(BuildContext context, String m) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

Future<void> _call(BuildContext context, String phone) async {
  final bool ok =
      phone.isNotEmpty && await launchUrl(Uri(scheme: 'tel', path: phone));
  if (!ok && context.mounted) _snack(context, 'Could not open the phone app.');
}

/// Download the tax invoice with the customer's session and open it.
Future<void> openRepairInvoice(
    BuildContext context, WidgetRef ref, RepairRequest r) async {
  final String? id = r.invoiceId;
  if (id == null) {
    _snack(context, 'Your invoice is being prepared.');
    return;
  }
  try {
    final List<int> bytes = await ref.read(repairApiProvider).invoicePdf(id);
    if (bytes.isEmpty) throw StateError('empty');
    final safeCode = r.code.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final path = await savePdf(bytes, 'invoice-$safeCode.pdf');
    final opened = await openSavedPdf(path);
    if (!context.mounted) return;
    if (!opened) {
      _snack(context, 'Could not open the invoice.');
    } else if (kIsWeb) {
      _snack(context, 'Invoice download started.');
    }
  } catch (_) {
    if (context.mounted) _snack(context, 'Could not load the invoice.');
  }
}

/// Technician + chat + call, as in the Track screen of the mockups.
class RepairTechnicianCard extends StatelessWidget {
  const RepairTechnicianCard({required this.request, super.key});

  final RepairRequest request;

  @override
  Widget build(BuildContext context) {
    final RepairRequest r = request;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (r.technician != null)
            Row(
              children: <Widget>[
                const RIconTile(PhosphorIconsBold.userGear,
                    size: 46, iconSize: 22, circle: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(r.technician!, style: rtHead(16)),
                      Text('Repair technician', style: rtBody(13)),
                    ],
                  ),
                ),
                if ((r.technicianPhone ?? '').isNotEmpty)
                  GestureDetector(
                    onTap: () => _call(context, r.technicianPhone!),
                    child: const RIconTile(PhosphorIconsBold.phone,
                        size: 44,
                        iconSize: 20,
                        circle: true,
                        color: RT.green,
                        bg: RT.greenTint),
                  ),
              ],
            )
          else
            Text('Your shop will tell you who is repairing your phone.',
                style: rtBody(14)),
          const SizedBox(height: 12),
          RepairChatButton(request: r),
        ],
      ),
    );
  }
}

class RepairChatButton extends StatelessWidget {
  const RepairChatButton({required this.request, super.key});

  final RepairRequest request;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          RButton(
            label: 'Chat with ${request.serviceCenter ?? 'the shop'}',
            outline: true,
            height: 46,
            icon: PhosphorIconsBold.chatCircleText,
            onTap: () => context.push('/repair/${request.id}/chat'),
          ),
          if (request.unreadMessages > 0)
            Positioned(
              right: 10,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: RT.red, borderRadius: BorderRadius.circular(12)),
                child: Text('${request.unreadMessages} new',
                    style: rtHead(11, color: Colors.white)),
              ),
            ),
        ],
      );
}

/// "QC Mismatch Alert": the shop found a problem; approve the repair or ask to replace the device.
class RepairMismatchAlerts extends ConsumerStatefulWidget {
  const RepairMismatchAlerts(
      {required this.request, required this.onChanged, super.key});

  final RepairRequest request;
  final VoidCallback onChanged;

  @override
  ConsumerState<RepairMismatchAlerts> createState() =>
      _RepairMismatchAlertsState();
}

class _RepairMismatchAlertsState extends ConsumerState<RepairMismatchAlerts> {
  bool _busy = false;

  Future<void> _answer(RepairMismatch m, String choice) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(repairApiProvider)
          .answerMismatch(widget.request.id, m.id, choice);
      widget.onChanged();
    } catch (e) {
      if (mounted) _snack(context, ServerError.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<RepairMismatch> list = widget.request.mismatches;
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 22),
        Text('Quality check', style: rtHead(18)),
        const SizedBox(height: 12),
        for (final RepairMismatch m in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  RBand(
                    m.note == null || m.note!.isEmpty
                        ? 'The shop found something that does not match.'
                        : m.note!,
                    kind: m.open ? BandKind.danger : BandKind.success,
                    bold: m.title,
                    icon: m.open
                        ? PhosphorIconsBold.warning
                        : PhosphorIconsBold.check,
                  ),
                  const SizedBox(height: 12),
                  if (m.open) ...<Widget>[
                    Text('What would you like to do?',
                        style: rtHead(14.5, w: FontWeight.w700)),
                    const SizedBox(height: 10),
                    RButton(
                        label: 'Approve repair (no extra charge)',
                        height: 46,
                        loading: _busy,
                        onTap: () => _answer(m, 'APPROVE')),
                    const SizedBox(height: 8),
                    RButton(
                        label: 'Replace device (extra charge)',
                        outline: true,
                        height: 46,
                        onTap: _busy ? null : () => _answer(m, 'REPLACE')),
                  ] else
                    Text(
                      m.choice == 'APPROVE'
                          ? 'You approved the repair.'
                          : 'You asked the shop to replace the device.',
                      style: rtBody(14, color: RT.ink, w: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// "Pay now" strip shown whenever the shop is waiting for the advance or the balance.
class RepairPayNowCard extends ConsumerWidget {
  const RepairPayNowCard({required this.request, super.key});

  final RepairRequest request;

  static const Set<String> _payable = <String>{
    'ESTIMATE_APPROVED',
    'IN_REPAIR',
    'QC_PENDING',
    'REPAIRED',
    'READY_FOR_DELIVERY'
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RepairRequest r = request;
    if (!_payable.contains(r.status) || r.money.amountDue <= 0)
      return const SizedBox.shrink();
    final bool advance = r.status == 'ESTIMATE_APPROVED' &&
        r.money.advanceRequired > r.money.amountPaid;
    final double amount = advance
        ? r.money.advanceRequired - r.money.amountPaid
        : r.money.amountDue;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: RCard(
        child: Row(
          children: <Widget>[
            const RIconTile(PhosphorIconsBold.creditCard,
                size: 46, iconSize: 22, circle: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(advance ? 'Pay the advance' : 'Pay the balance',
                      style: rtHead(15.5)),
                  Text(rupees(amount), style: rtHead(20, color: RT.blue)),
                ],
              ),
            ),
            SizedBox(
                width: 120,
                child: RButton(
                    label: 'Pay now',
                    height: 44,
                    onTap: () => context.push('/repair/${r.id}/pay'))),
          ],
        ),
      ),
    );
  }
}

/// ₹ price with the shop's original price struck through and "X% off" when it gave a discount.
class RepairOfferPrice extends StatelessWidget {
  const RepairOfferPrice(this.offer, {this.size = 26, super.key});

  final RepairOffer offer;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!offer.hasDiscount)
      return Text(rupees(offer.total), style: rtHead(size));
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: <Widget>[
        Text(rupees(offer.total), style: rtHead(size)),
        Text(rupees(offer.mrpTotal!),
            style: rtBody(size * 0.55, color: RT.muted)
                .copyWith(decoration: TextDecoration.lineThrough)),
        RPill('${offer.discountPct}% off', kind: PillKind.green),
      ],
    );
  }
}

/// "Check & Diagnose" result as the customer sees it: every part Good / Low / Problem.
class RepairChecksCard extends StatelessWidget {
  const RepairChecksCard({required this.request, super.key});

  final RepairRequest request;

  @override
  Widget build(BuildContext context) {
    final List<RepairCheck> checks = request.latestChecks;
    if (checks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 22),
        Text('Device check', style: rtHead(18)),
        const SizedBox(height: 12),
        RCard(
          child: Column(
            children: <Widget>[
              for (final RepairCheck c in checks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: <Widget>[
                      PhosphorIcon(
                        c.pass
                            ? PhosphorIconsFill.checkCircle
                            : (c.result == 'LOW'
                                ? PhosphorIconsFill.warningCircle
                                : PhosphorIconsFill.xCircle),
                        size: 22,
                        color: c.pass
                            ? RT.green
                            : (c.result == 'LOW' ? RT.amber : RT.red),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(c.label,
                              style: rtHead(14.5, w: FontWeight.w600))),
                      Text(
                        c.pass ? 'Pass' : (c.result == 'LOW' ? 'Low' : 'Issue'),
                        style: rtHead(13.5,
                            color: c.pass
                                ? RT.green
                                : (c.result == 'LOW' ? RT.amber : RT.red)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
