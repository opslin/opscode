import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/sell_leads/application/sell_lead_providers.dart';
import 'package:dealker_vendor/features/sell_leads/data/sell_lead_models.dart';
import 'package:dealker_vendor/features/sell_leads/data/sell_lead_repository.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// Everything that happens after the seller accepts this buyer's offer:
/// pay Dealkr (Razorpay) → collect the phone → inspect → final price → seller is paid.
class SellDealPanel extends ConsumerStatefulWidget {
  const SellDealPanel({required this.lead, super.key});
  final SellLead lead;

  @override
  ConsumerState<SellDealPanel> createState() => _SellDealPanelState();
}

class _SellDealPanelState extends ConsumerState<SellDealPanel> {
  Razorpay? _rzp;
  RazorpayOrder? _order;
  bool _busy = false;

  // pickup form
  String _provider = 'PORTER';
  final _awb = TextEditingController();
  final _courier = TextEditingController();
  final _tracking = TextEditingController();

  // inspection form
  final List<XFile> _photos = [];
  String _physical = 'GOOD';
  String _screen = 'FLAWLESS';
  bool _imeiOk = true;
  final _imeiSeen = TextEditingController();
  final _battery = TextEditingController();
  final _remarks = TextEditingController();
  final _finalPrice = TextEditingController();

  SellDeal get _deal => widget.lead.deal!;
  String get _id => widget.lead.id;
  SellLeadRepository get _repo => ref.read(sellLeadRepositoryProvider);

  @override
  void dispose() {
    _rzp?.clear();
    for (final c in [
      _awb,
      _courier,
      _tracking,
      _imeiSeen,
      _battery,
      _remarks,
      _finalPrice
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    ref
      ..invalidate(sellLeadProvider(_id))
      ..invalidate(sellLeadsProvider('progress'));
  }

  Future<void> _run(Future<Object?> Function() job, {String? ok}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
      _refresh();
      if (mounted && ok != null) showAppToast(context, ok);
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Razorpay Checkout ──────────────────────────────────────────────────

  Future<void> _pay() async {
    setState(() => _busy = true);
    try {
      final order = await _repo.razorpayOrder(_id);
      _order = order;
      _rzp?.clear();
      final r = Razorpay();
      r.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaid);
      r.on(Razorpay.EVENT_PAYMENT_ERROR, _onPayError);
      r.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
      _rzp = r;
      r.open({
        'key': order.keyId,
        'order_id': order.orderId,
        'amount': order.amount,
        'currency': 'INR',
        'name': 'Dealkr',
        'description': order.description,
        'theme': {'color': '#5B4BEA'},
        'retry': {'enabled': true, 'max_count': 2},
      });
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onPaid(PaymentSuccessResponse r) async {
    try {
      await _repo.razorpayVerify(_id,
          orderId: r.orderId ?? _order?.orderId ?? '',
          paymentId: r.paymentId ?? '',
          signature: r.signature ?? '');
      _refresh();
      if (mounted) {
        showAppToast(
            context, 'Payment received. Dealkr is holding it for the seller.');
      }
    } catch (e) {
      // The money may have left the account even though verification failed: ask the server to look it up.
      try {
        await _repo.razorpaySync(_id);
        _refresh();
      } catch (_) {}
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onPayError(PaymentFailureResponse r) async {
    if (mounted) setState(() => _busy = false);
    // Closing Checkout is not a failure; a payment that went through but lost its callback is recovered here.
    try {
      final l = await _repo.razorpaySync(_id);
      if (l.deal?.funded == true) {
        _refresh();
        return;
      }
    } catch (_) {}
    if (mounted && r.code != Razorpay.PAYMENT_CANCELLED) {
      showAppToast(
          context,
          r.message?.isNotEmpty == true
              ? r.message!
              : 'Payment did not complete.',
          error: true);
    }
  }

  // ── Photos + inspection ───────────────────────────────────────────────

  Future<void> _addPhoto(ImageSource source) async {
    final f = await ImagePicker()
        .pickImage(source: source, imageQuality: 85, maxWidth: 2000);
    if (f != null && mounted) setState(() => _photos.add(f));
  }

  Future<void> _submitInspection() async {
    final battery = _battery.text.trim().isEmpty
        ? null
        : int.tryParse(_battery.text.trim());
    if (_battery.text.trim().isNotEmpty &&
        (battery == null || battery < 0 || battery > 100)) {
      showAppToast(context, 'Battery health must be 0 to 100.', error: true);
      return;
    }
    if (!_imeiOk && _imeiSeen.text.trim().length < 14) {
      showAppToast(context, 'Enter the IMEI you saw on the phone.',
          error: true);
      return;
    }
    await _run(() async {
      if (_photos.isNotEmpty) {
        final ids = <String>[];
        for (final p in _photos) {
          ids.add(await _repo.uploadEvidence(p.path));
        }
        await _repo.attachEvidence(_id, ids);
        _photos.clear();
      }
      final st = _deal.inspectionStatus;
      if (st == null ||
          st == 'NOT_STARTED' ||
          st == 'AWAITING_EVIDENCE' ||
          st == 'EVIDENCE_UPLOADED' ||
          st == 'RECHECK') {
        await _repo.startInspection(_id);
      }
      await _repo.submitInspection(_id, {
        'physicalCondition': _physical,
        'screenCondition': _screen,
        'imeiVerified': _imeiOk,
        if (!_imeiOk) 'imeiObserved': _imeiSeen.text.trim(),
        if (battery != null) 'batteryHealth': battery,
        if (_remarks.text.trim().isNotEmpty) 'remarks': _remarks.text.trim(),
      });
      return null;
    }, ok: 'Inspection saved.');
  }

  Future<void> _decide(String result) async {
    final price =
        num.tryParse(_finalPrice.text.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (result == 'PASSED' &&
        price != null &&
        _deal.agreedPrice != null &&
        price > _deal.agreedPrice!) {
      showAppToast(context,
          'The final price cannot be higher than the offer of ${formatInr(_deal.agreedPrice!)}.',
          error: true);
      return;
    }
    String? note;
    if (result != 'PASSED') {
      note = await _askReason(result == 'FAILED'
          ? 'Why does the phone fail?'
          : 'What needs another look?');
      if (note == null) return;
    }
    await _run(
        () => _repo.decideInspection(_id,
            result: result,
            note: note,
            finalValuation: result == 'PASSED' ? price : null),
        ok: result == 'PASSED'
            ? (price != null && price < (_deal.agreedPrice ?? price)
                ? 'Sent to the seller to accept the new price.'
                : 'Approved. The seller will be paid.')
            : 'Saved.');
  }

  Future<String?> _askReason(String title) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: c,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => c.text.trim().isEmpty
                  ? null
                  : Navigator.pop(ctx, c.text.trim()),
              child: const Text('Continue')),
        ],
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = _deal;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _card(
        color: const Color(0xFFE7F7EC),
        child: Row(children: [
          const Icon(Icons.check_circle, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  d.ended
                      ? 'This sale has ended.'
                      : 'Your offer of ${formatInr(d.agreedPrice ?? 0)} was accepted',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14.5))),
        ]),
      ),
      const SizedBox(height: 12),
      _steps(d),
      const SizedBox(height: 12),
      if (!d.ended) _action(d),
      const SizedBox(height: 12),
      _seller(d),
    ]);
  }

  Widget _card({required Widget child, Color? color}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color ?? Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: color == null
                ? Border.all(color: const Color(0xFFE6E8F0))
                : null),
        child: child,
      );

  Widget _steps(SellDeal d) => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Progress', style: heading(size: 15)),
          const SizedBox(height: 8),
          for (final s in d.steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Icon(
                    s.done
                        ? Icons.check_circle
                        : (s.current
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                    size: 18,
                    color: s.done
                        ? AppColors.success
                        : (s.current ? AppColors.violet : AppColors.textMuted)),
                const SizedBox(width: 8),
                Text(s.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            s.current ? FontWeight.w800 : FontWeight.w500,
                        color: s.done || s.current
                            ? AppColors.navy
                            : AppColors.textMuted)),
              ]),
            ),
        ]),
      );

  Widget _seller(SellDeal d) => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Seller', style: heading(size: 15)),
          const SizedBox(height: 6),
          Text(d.sellerName.isEmpty ? '—' : d.sellerName,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (d.sellerPhone.isNotEmpty)
            Text(d.sellerPhone,
                style: const TextStyle(color: AppColors.textSecondary)),
          if (d.imei != null && d.imei!.isNotEmpty)
            Text('IMEI ${d.imei}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]),
      );

  Widget _btn(String label, VoidCallback? onTap,
          {bool outlined = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: outlined
            ? OutlinedButton(
                onPressed: _busy ? null : onTap,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: color ?? AppColors.violet),
                child: Text(label))
            : FilledButton(
                onPressed: _busy ? null : onTap,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: color ?? AppColors.violet),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(label)),
      );

  Widget _note(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13, color: AppColors.textSecondary, height: 1.4));

  Widget _info(String title, String body) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: heading(size: 16)),
        const SizedBox(height: 4),
        _note(body)
      ]);

  Widget _action(SellDeal d) {
    // 1 · pay first — everything else waits for the money to be held.
    if (d.needsPayment) {
      return _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pay ${formatInr(d.agreedPrice ?? 0)} to Dealkr',
              style: heading(size: 16)),
          const SizedBox(height: 6),
          _note(
              'Dealkr holds the money safely. The seller is paid only after you inspect and approve the phone. Pay with UPI, card or net banking.'),
          _btn('Pay ${formatInr(d.agreedPrice ?? 0)}', _pay),
          if (d.paymentStatus == 'SUBMITTED')
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _note(
                    'A manual payment reference is waiting for finance to confirm. You can also pay online.')),
        ]),
      );
    }
    switch (d.stage) {
      case 'OFFER_ACCEPTED':
        return _card(
            child: _info('Payment received',
                'Waiting for the seller to choose pickup or drop-off.'));
      case 'PICKUP_REQUESTED':
      case 'PICKUP_SCHEDULED':
      case 'PICKED_UP':
      case 'IN_TRANSIT':
        return _collect(d);
      case 'RECEIVED':
      case 'INSPECTING':
        return _inspect(d);
      case 'FINAL_PRICE':
        return _card(
            child: _info('Waiting for the seller',
                'You offered a lower price of ${formatInr(d.finalValuation ?? 0)}. The seller is deciding whether to accept it.'));
      case 'PAYOUT_PENDING':
        return _card(
            child: _info('Approved',
                'The seller is choosing where to receive ${formatInr(d.payoutAmount ?? d.agreedPrice ?? 0)}.'));
      case 'PAID':
        return _card(
            child: _info('Completed', 'The seller has been paid. Thank you!'));
      case 'RETURNING':
        return _card(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _info('Return the phone',
              'The sale ended after pickup. Send the phone back to the seller; your payment is being refunded.'),
          _btn(
              'I have returned the phone',
              () => _run(() => _repo.markReturned(_id),
                  ok: 'Marked as returned.')),
        ]));
      default:
        return _card(child: _info('In progress', 'Nothing to do right now.'));
    }
  }

  // 2 · collect the phone
  Widget _collect(SellDeal d) {
    final f = d.fulfilment;
    if (f == null) {
      return _card(
          child: _info('Payment received',
              'Waiting for the seller to choose pickup or drop-off.'));
    }
    final children = <Widget>[];
    if (f.pickup) {
      children.addAll([
        Text('Collect the phone', style: heading(size: 16)),
        const SizedBox(height: 6),
        Text(f.address ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        _note(
            '${f.date ?? ''} · ${f.window ?? ''}${(f.note ?? '').isEmpty ? '' : '\n“${f.note}”'}'),
      ]);
    } else {
      children.addAll([
        Text('Drop-off at your store', style: heading(size: 16)),
        const SizedBox(height: 6),
        _note(
            'The seller will bring the phone to your shop. Mark it received when it arrives.'),
      ]);
    }
    final p = d.pickup;
    if (f.pickup && p == null) {
      children.addAll([
        const SizedBox(height: 12),
        const Text(
            'Dealkr could not book the pickup automatically. Book a courier yourself:',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _provider,
          decoration: const InputDecoration(
              labelText: 'Courier', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'PORTER', child: Text('Porter')),
            DropdownMenuItem(value: 'SHIPROCKET', child: Text('Shiprocket')),
            DropdownMenuItem(value: 'BLUEDART', child: Text('Blue Dart')),
            DropdownMenuItem(value: 'SELF', child: Text('My own team')),
          ],
          onChanged: (v) => setState(() => _provider = v ?? 'PORTER'),
        ),
        const SizedBox(height: 8),
        TextField(
            controller: _awb,
            decoration: const InputDecoration(
                labelText: 'Tracking / AWB number (optional)',
                border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(
            controller: _courier,
            decoration: const InputDecoration(
                labelText: 'Courier or rider name (optional)',
                border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(
            controller: _tracking,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
                labelText: 'Tracking link (optional)',
                border: OutlineInputBorder())),
        _btn(
            'Confirm pickup booking',
            () => _run(
                () => _repo.arrangePickup(_id,
                    provider: _provider,
                    awb: _awb.text,
                    courierName: _courier.text,
                    trackingUrl: _tracking.text),
                ok: 'Pickup booked. The seller is notified.')),
      ]);
    } else if (f.pickup && p != null && p.auto) {
      final onTheWay = p.status == 'PICKED_UP' || p.status == 'IN_TRANSIT';
      children.addAll([
        const SizedBox(height: 10),
        _note(
            'Dealkr booked the pickup for you${p.simulated ? ' (demo)' : ''}. A delivery partner collects the phone from the seller and brings it to your store.\n${p.courier ?? ''}${(p.awb ?? '').isEmpty ? '' : ' · AWB ${p.awb}'}\nStatus: ${p.status.replaceAll('_', ' ').toLowerCase()}'),
        if (onTheWay)
          _btn('Store is closed - retry delivery', () async {
            final why = await _askReason('Why can you not take the phone now?');
            if (why != null) {
              await _run(() => _repo.storeClosed(_id, note: why),
                  ok: 'Noted. The delivery will be retried.');
            }
          }, outlined: true, color: AppColors.textMuted),
        if (p.simulated && p.status != 'IN_TRANSIT')
          _btn('Demo: move the courier forward',
              () => _run(() => _repo.simulatePickup(_id)),
              outlined: true),
        _btn(
            'Phone received at my store',
            () => _run(() => _repo.markReceived(_id),
                ok: 'Marked received. Now inspect the phone.')),
      ]);
    } else if (f.pickup && p != null) {
      children.addAll([
        const SizedBox(height: 10),
        _note(
            '${p.provider ?? ''}${(p.courier ?? '').isEmpty ? '' : ' · ${p.courier}'}${(p.awb ?? '').isEmpty ? '' : ' · AWB ${p.awb}'}\nStatus: ${p.status.replaceAll('_', ' ').toLowerCase()}'),
        if (p.status == 'PICKUP_SCHEDULED')
          _btn(
              'Phone picked up',
              () => _run(() => _repo.pickupStatus(_id, 'PICKED_UP'),
                  ok: 'Marked picked up.'),
              outlined: true),
        if (p.status == 'PICKED_UP')
          _btn('Phone is in transit',
              () => _run(() => _repo.pickupStatus(_id, 'IN_TRANSIT')),
              outlined: true),
        _btn(
            'Phone received',
            () => _run(() => _repo.markReceived(_id),
                ok: 'Marked received. Now inspect the phone.')),
        _btn('Pickup failed', () async {
          final why = await _askReason('What went wrong?');
          if (why != null) {
            await _run(() => _repo.pickupStatus(_id, 'FAILED', note: why));
          }
        }, outlined: true, color: AppColors.textMuted),
      ]);
    } else {
      children.add(_btn(
          'Phone received',
          () => _run(() => _repo.markReceived(_id),
              ok: 'Marked received. Now inspect the phone.')));
    }
    return _card(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children));
  }

  // 3 · inspect → final price
  Widget _inspect(SellDeal d) {
    final st = d.inspectionStatus ?? 'NOT_STARTED';
    if (st == 'INSPECTION_COMPLETE') {
      return _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Final price', style: heading(size: 16)),
          const SizedBox(height: 6),
          _note(
              'Inspection saved. Approve at the agreed ${formatInr(d.agreedPrice ?? 0)} or enter a lower price if the phone is not as described. The seller must accept any reduction.'),
          const SizedBox(height: 10),
          TextField(
              controller: _finalPrice,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText:
                      'Final price (leave blank for ${formatInr(d.agreedPrice ?? 0)})',
                  prefixText: '₹ ',
                  border: const OutlineInputBorder())),
          _btn('Approve', () => _decide('PASSED')),
          _btn('Needs another look', () => _decide('RECHECK'), outlined: true),
          _btn('Reject the phone', () => _decide('FAILED'),
              outlined: true, color: Colors.red),
        ]),
      );
    }
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Inspect the phone', style: heading(size: 16)),
        const SizedBox(height: 4),
        _note(
            'Check the phone against the seller’s description. Photos are kept as evidence.'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < _photos.length; i++)
            Chip(
                label: Text('Photo ${i + 1}'),
                onDeleted: () => setState(() => _photos.removeAt(i))),
          ActionChip(
              avatar: const Icon(Icons.photo_camera, size: 18),
              label: const Text('Camera'),
              onPressed: () => _addPhoto(ImageSource.camera)),
          ActionChip(
              avatar: const Icon(Icons.photo_library, size: 18),
              label: const Text('Gallery'),
              onPressed: () => _addPhoto(ImageSource.gallery)),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _physical,
          decoration: const InputDecoration(
              labelText: 'Body condition', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'EXCELLENT', child: Text('Excellent')),
            DropdownMenuItem(value: 'GOOD', child: Text('Good')),
            DropdownMenuItem(value: 'FAIR', child: Text('Fair')),
            DropdownMenuItem(value: 'POOR', child: Text('Poor')),
          ],
          onChanged: (v) => setState(() => _physical = v ?? 'GOOD'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _screen,
          decoration: const InputDecoration(
              labelText: 'Screen', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'FLAWLESS', child: Text('Flawless')),
            DropdownMenuItem(
                value: 'MINOR_SCRATCHES', child: Text('Minor scratches')),
            DropdownMenuItem(
                value: 'MAJOR_SCRATCHES', child: Text('Major scratches')),
            DropdownMenuItem(value: 'CRACKED', child: Text('Cracked')),
            DropdownMenuItem(value: 'DEAD_PIXELS', child: Text('Dead pixels')),
          ],
          onChanged: (v) => setState(() => _screen = v ?? 'FLAWLESS'),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    'IMEI on the phone matches${d.imei == null ? '' : ' (${d.imei})'}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Text('Dial *#06# on the phone to check',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ])),
          Switch(value: _imeiOk, onChanged: (v) => setState(() => _imeiOk = v)),
        ]),
        if (!_imeiOk)
          TextField(
              controller: _imeiSeen,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'IMEI you saw', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(
            controller: _battery,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Battery health % (optional)',
                border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(
            controller: _remarks,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Remarks (optional)', border: OutlineInputBorder())),
        _btn('Save inspection', _submitInspection),
      ]),
    );
  }
}
