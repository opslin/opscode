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

/// "Hand Over & Payment": send the phone back (or let the customer collect it), take the balance by hand, finish.
class RepairHandoverScreen extends ConsumerStatefulWidget {
  const RepairHandoverScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<RepairHandoverScreen> createState() =>
      _RepairHandoverScreenState();
}

class _RepairHandoverScreenState extends ConsumerState<RepairHandoverScreen> {
  String _method = 'CASH';
  final _courier = TextEditingController();
  final _ref = TextEditingController();
  bool _busy = false;
  bool _completed = false;

  @override
  void dispose() {
    _courier.dispose();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _go(Future<Object?> Function() fn, {String? ok}) async {
    setState(() => _busy = true);
    try {
      await fn();
      refreshRepairs(ref, id: widget.id);
      if (mounted && ok != null) showAppToast(context, ok);
    } catch (e) {
      refreshRepairs(ref, id: widget.id);
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(jobProvider(widget.id));
    final repo = ref.read(repairsRepositoryProvider);
    final j = d.value;
    if (j != null && (j.status == 'COMPLETED' || _completed))
      return _Completed(j);
    return Scaffold(
      backgroundColor: RC.canvas,
      appBar: RepairAppBar(
          title: 'Hand Over & Payment',
          subtitle: j == null ? null : '#${j.code}',
          onBack: () => context.canPop()
              ? context.pop()
              : context.go(Routes.repairJob(widget.id))),
      body: d.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e),
            onRetry: () => ref.invalidate(jobProvider(widget.id))),
        data: (j) {
          final outDone = j.has('OUT_FOR_DELIVERY');
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                RepairSection(
                  title: 'Order total',
                  art: A3.cart('receipt'),
                  child: Column(children: [
                    KV(
                        'Repair price',
                        formatInr(j.agreedSubtotal > 0
                            ? j.agreedSubtotal
                            : j.approvedTotal)),
                    if (j.agreedTax > 0) KV('GST', formatInr(j.agreedTax)),
                    KV('Total', formatInr(j.approvedTotal), bold: true),
                    KV('Paid', formatInr(j.amountPaid), color: RC.green),
                    KV('Still to collect', formatInr(j.amountDue),
                        bold: true,
                        color: j.amountDue > 0 ? RC.amber : RC.green),
                  ]),
                ),
                if (j.isPickup)
                  RepairSection(
                    title: 'Send the phone back',
                    art: A3.cart('van'),
                    trailing: outDone
                        ? const StatusChip('Sent', kind: ChipKind.green)
                        : null,
                    child: outDone
                        ? const Text(
                            'The customer has been told their phone is on the way.',
                            style: TextStyle(
                                fontSize: 13.5, color: AppColors.textSecondary))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(j.address,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _courier,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Who delivers? (optional, e.g. our rider Ravi)',
                                    hintStyle: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textMuted),
                                    filled: true,
                                    fillColor: RC.canvas,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide:
                                            const BorderSide(color: RC.line)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide:
                                            const BorderSide(color: RC.line)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                AuctionButton(
                                    label: 'Phone is out for delivery',
                                    height: 46,
                                    icon: PhosphorIconsFill.truck,
                                    loading: _busy,
                                    onPressed: () => _go(
                                        () => repo.outForDelivery(j.id,
                                            courier: _courier.text),
                                        ok: 'Customer told it is on the way.')),
                              ]),
                  )
                else
                  RepairSection(
                    title: 'Customer collects',
                    art: A3.shop(3),
                    child: Text(
                        'The customer picks the phone up from your shop. Show them it works before you take payment.',
                        style: TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            color: AppColors.textSecondary)),
                  ),
                if (j.amountDue > 0)
                  RepairSection(
                    title: 'Take payment',
                    art: A3.exchange('money'),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final (m, label, icon) in const [
                              ('CASH', 'Cash in hand', PhosphorIconsFill.money),
                              ('UPI', 'UPI', PhosphorIconsFill.qrCode),
                              ('CARD', 'Card', PhosphorIconsFill.creditCard),
                            ])
                              ChoiceChip(
                                showCheckmark: false,
                                avatar: Icon(icon,
                                    size: 17,
                                    color: _method == m
                                        ? RC.blue
                                        : AppColors.textMuted),
                                label: Text(label),
                                selected: _method == m,
                                onSelected: (_) => setState(() => _method = m),
                                selectedColor: RC.tint,
                                labelStyle: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _method == m
                                        ? RC.blue
                                        : AppColors.navy),
                              ),
                          ]),
                          const SizedBox(height: 10),
                          if (_method != 'CASH')
                            TextField(
                              controller: _ref,
                              decoration: InputDecoration(
                                hintText: 'Payment reference (optional)',
                                hintStyle: const TextStyle(
                                    fontSize: 13, color: AppColors.textMuted),
                                filled: true,
                                fillColor: RC.canvas,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: RC.line)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: RC.line)),
                              ),
                            ),
                          if (_method == 'CASH')
                            const HintBox(
                                'Collect the cash from the customer, then tap the button to mark it as paid in the app.',
                                icon: PhosphorIconsFill.info),
                          const SizedBox(height: 10),
                          AuctionButton(
                              label:
                                  'Mark ${formatInr(j.amountDue)} as received',
                              icon: PhosphorIconsBold.check,
                              loading: _busy,
                              onPressed: () => _go(
                                  () => repo.recordPayment(j.id,
                                      kind: 'BALANCE',
                                      method: _method,
                                      amount: j.amountDue,
                                      reference: _ref.text,
                                      idempotencyKey:
                                          'bal-${j.id}-${DateTime.now().millisecondsSinceEpoch}'),
                                  ok: 'Payment saved.')),
                        ]),
                  ),
              ]);
        },
      ),
      bottomNavigationBar: j == null
          ? null
          : BottomActionBar(
              child: AuctionButton(
                  label: 'Complete order',
                  icon: PhosphorIconsFill.sealCheck,
                  loading: _busy,
                  onPressed: j.amountDue > 0 ||
                          (j.isPickup && !j.has('OUT_FOR_DELIVERY'))
                      ? null
                      : () => _go(() async {
                            await repo.step(j.id, 'deliver');
                            if (mounted) setState(() => _completed = true);
                            return null;
                          })),
            ),
    );
  }
}

/// "Order Completed!" — invoice, the customer's review, back to the inbox.
class _Completed extends ConsumerWidget {
  const _Completed(this.first);
  final RepairJob first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final j = ref.watch(jobProvider(first.id)).value ?? first;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 30),
          Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: const BoxDecoration(
                  color: RC.greenTint, shape: BoxShape.circle),
              child: const Icon(PhosphorIconsFill.sealCheck,
                  color: RC.green, size: 60),
            ),
          ),
          const SizedBox(height: 20),
          Center(child: Text('Order completed!', style: heading(size: 26))),
          const SizedBox(height: 6),
          const Center(
              child: Text('Payment received. The repair is finished.',
                  style: TextStyle(
                      fontSize: 14.5, color: AppColors.textSecondary))),
          const SizedBox(height: 22),
          HomeCard(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              for (final g in groupDevices(j.items))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    DeviceThumb(
                        brand: g.first.brand, model: g.first.model, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            g.qty > 1
                                ? '${g.first.name} × ${g.qty}'
                                : g.first.name,
                            style: heading(size: 15.5))),
                  ]),
                ),
              const Divider(height: 18, color: RC.line),
              KV('Order', '#${j.code}'),
              KV('Customer', j.customerName.isEmpty ? '—' : j.customerName),
              KV('Amount received', formatInr(j.amountPaid),
                  bold: true, color: RC.green),
              if (j.warrantyUntil != null)
                KV('Warranty until', isoDay(j.warrantyUntil!)),
            ]),
          ),
          const SizedBox(height: 18),
          AuctionButton(
              label: j.invoiceId == null
                  ? 'Invoice is being prepared'
                  : 'View invoice',
              outlined: true,
              icon: PhosphorIconsFill.fileText,
              onPressed: j.invoiceId == null
                  ? () => ref.invalidate(jobProvider(j.id))
                  : () => openPdf(
                      context,
                      () => ref
                          .read(repairsRepositoryProvider)
                          .invoicePdf(j.invoiceId!),
                      'invoice-${j.code}')),
          const SizedBox(height: 10),
          AuctionButton(
              label: j.ratingStars == null
                  ? 'Customer review (not yet)'
                  : 'Customer review — ${j.ratingStars}/5',
              outlined: true,
              icon: PhosphorIconsFill.star,
              onPressed: () => context.go(Routes.repairJob(j.id))),
          const SizedBox(height: 10),
          AuctionButton(
              label: 'Back to Repair Requests',
              icon: PhosphorIconsBold.arrowLeft,
              onPressed: () => context.go(Routes.repairs)),
        ]),
      ),
    );
  }
}
