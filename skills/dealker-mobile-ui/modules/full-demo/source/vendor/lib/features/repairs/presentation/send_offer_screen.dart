import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/shared/widgets/premium_ui.dart' show A3;
import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show AuctionButton, BottomActionBar, errorText;
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/features/repairs/application/repairs_providers.dart';
import 'package:dealker_vendor/features/repairs/data/offer_draft.dart';
import 'package:dealker_vendor/features/repairs/data/repair_models.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// "Send Offer to Customer": the price breakdown plus time, warranty and how the phone reaches you.
class SendOfferScreen extends ConsumerStatefulWidget {
  const SendOfferScreen({super.key, required this.draft});
  final OfferDraft draft;

  @override
  ConsumerState<SendOfferScreen> createState() => _SendOfferScreenState();
}

class _SendOfferScreenState extends ConsumerState<SendOfferScreen> {
  bool _busy = false;
  MyOffer? _sent;
  late final _note = TextEditingController(text: widget.draft.note);
  late final _offer = TextEditingController(
      text: widget.draft.subtotal
          .toStringAsFixed(widget.draft.subtotal % 1 == 0 ? 0 : 2));

  /// The price the shop actually offers; anything below the list total is a discount.
  num get _offerPrice => num.tryParse(_offer.text) ?? d.subtotal;
  num get _discount => _offerPrice >= d.subtotal ? 0 : d.subtotal - _offerPrice;
  num get _discountPct => d.subtotal == 0 ? 0 : (_discount * 100 / d.subtotal);

  OfferDraft get d => widget.draft;

  @override
  void dispose() {
    _note.dispose();
    _offer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!d.pickupDelivery && !d.shopVisit) {
      showAppToast(
          context, 'Choose at least one way the customer can reach you.',
          error: true);
      return;
    }
    if (_offerPrice <= 0 || _offerPrice > d.subtotal) {
      showAppToast(context,
          'Your offer must be above ₹0 and not more than the total price.',
          error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final offer = await ref.read(repairsRepositoryProvider).sendOffer(
            d.requestId,
            lines: d.toLines((i) => issueMeta(i).label),
            estDaysMin: d.estMin,
            estDaysMax: d.estMax,
            warrantyDays: d.warrantyDays,
            pickupDelivery: d.pickupDelivery,
            shopVisit: d.shopVisit,
            discount: _discount,
            note: _note.text,
          );
      refreshRepairs(ref, id: d.requestId);
      if (mounted) setState(() => _sent = offer);
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent != null) return _Sent(_sent!, d);
    return Scaffold(
      backgroundColor: RC.canvas,
      appBar: RepairAppBar(
          title: 'Send Offer to Customer', onBack: () => context.pop()),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _PriceCard(d),
            RepairSection(
              title: 'Customer offer',
              art: A3.cart('coupon'),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'Offer price — what the customer pays (before GST)',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _offer,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(7)
                      ],
                      onChanged: (_) => setState(() {}),
                      style: heading(size: 24, color: RC.blue),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: heading(size: 22, color: RC.blue),
                        filled: true,
                        fillColor: RC.canvas,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: RC.line)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: RC.blue, width: 1.6)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final pct in const [0, 5, 10, 15])
                        ChoiceChip(
                          showCheckmark: false,
                          label: Text(pct == 0 ? 'No discount' : '$pct% off'),
                          selected: (_discountPct - pct).abs() < 0.5,
                          onSelected: (_) => setState(() => _offer.text =
                              (d.subtotal * (100 - pct) / 100)
                                  .round()
                                  .toString()),
                          selectedColor: RC.tint,
                          labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: (_discountPct - pct).abs() < 0.5
                                  ? RC.blue
                                  : AppColors.navy),
                        ),
                    ]),
                    if (_discount > 0) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Text(formatInr(d.subtotal),
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                                decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 10),
                        StatusChip(
                            '${_discountPct.toStringAsFixed(_discountPct % 1 == 0 ? 0 : 1)}% off • −${formatInr(_discount)}',
                            kind: ChipKind.green),
                      ]),
                    ],
                  ]),
            ),
            RepairSection(
              title: 'How long will it take?',
              art: A3.cart('clock'),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: _Stepper(
                          'From',
                          d.estMin,
                          0,
                          60,
                          (v) => setState(() {
                                d.estMin = v;
                                if (d.estMax < v) d.estMax = v;
                              }))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _Stepper('To', d.estMax, d.estMin, 60,
                          (v) => setState(() => d.estMax = v))),
                ]),
                const SizedBox(height: 4),
                Text(
                    d.estMax == 0
                        ? 'Same day'
                        : '${daysLabel(d.estMin, d.estMax)} after the phone reaches you',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
              ]),
            ),
            RepairSection(
              title: 'Warranty on this repair',
              art: A3.sell('shield'),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (days, label) in const [
                  (0, 'None'),
                  (30, '1 month'),
                  (90, '3 months'),
                  (180, '6 months'),
                  (365, '1 year')
                ])
                  ChoiceChip(
                    showCheckmark: false,
                    label: Text(label),
                    selected: d.warrantyDays == days,
                    onSelected: (_) => setState(() => d.warrantyDays = days),
                    selectedColor: RC.tint,
                    labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color:
                            d.warrantyDays == days ? RC.blue : AppColors.navy),
                  ),
              ]),
            ),
            RepairSection(
              title: 'How can the customer reach you?',
              art: A3.cart('van'),
              child: Column(children: [
                _Toggle(
                    'Pickup & delivery',
                    'You collect the phone and bring it back',
                    PhosphorIconsFill.truck,
                    d.pickupDelivery,
                    (v) => setState(() => d.pickupDelivery = v)),
                const SizedBox(height: 8),
                _Toggle(
                    'Visit my shop',
                    'Customer brings the phone to you',
                    PhosphorIconsFill.storefront,
                    d.shopVisit,
                    (v) => setState(() => d.shopVisit = v)),
              ]),
            ),
            RepairSection(
              title: 'Message for the customer',
              art: A3.profile('chat'),
              child: TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Optional — e.g. original parts, same-day service',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  filled: true,
                  fillColor: RC.canvas,
                  counterText: '',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: RC.line)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: RC.line)),
                ),
              ),
            ),
          ]),
      bottomNavigationBar: BottomActionBar(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Text('Your offer',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const Spacer(),
            Text(formatInr(_offerPrice),
                style: heading(size: 22, color: RC.blue)),
          ]),
          if (d.taxPct != null && d.taxPct! > 0)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                  '+ ${d.taxPct!.toStringAsFixed(d.taxPct! % 1 == 0 ? 0 : 1)}% GST added by Dealkr',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted)),
            ),
          const SizedBox(height: 10),
          AuctionButton(
              label: 'Send Offer',
              icon: PhosphorIconsFill.paperPlaneTilt,
              loading: _busy,
              onPressed: _send),
        ]),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard(this.d);
  final OfferDraft d;

  @override
  Widget build(BuildContext context) => RepairSection(
        title: 'Price details',
        art: A3.cart('receipt'),
        child: Column(children: [
          for (final (n, g) in groupDevices(d.devices).indexed) ...[
            if (n > 0) const Divider(height: 22, color: RC.line),
            Row(children: [
              DeviceThumb(brand: g.first.brand, model: g.first.model, size: 44),
              const SizedBox(width: 10),
              Expanded(child: Text(g.first.name, style: heading(size: 15))),
              if (g.qty > 1)
                StatusChip('× ${g.qty}', icon: PhosphorIconsFill.stack),
            ]),
            const SizedBox(height: 8),
            for (final r in d.chosen.where((r) => r.itemId == g.first.id))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  IssueBadge(r.issue, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(issueMeta(r.issue).label,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600))),
                  Text(
                      g.qty > 1
                          ? '${formatInr(r.price)} × ${g.qty}'
                          : formatInr(r.price),
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy)),
                ]),
              ),
          ],
          const Divider(height: 22, color: RC.line),
          Row(children: [
            Text('Total price', style: heading(size: 15)),
            const Spacer(),
            Text(formatInr(d.subtotal),
                style: heading(size: 18, color: RC.blue)),
          ]),
        ]),
      );
}

class _Stepper extends StatelessWidget {
  const _Stepper(this.label, this.value, this.min, this.max, this.onChanged);
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
              color: RC.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RC.line)),
          child: Row(children: [
            IconButton(
                onPressed: value > min ? () => onChanged(value - 1) : null,
                icon: const Icon(PhosphorIconsBold.minus,
                    size: 18, color: RC.blue)),
            Expanded(
                child: Text('$value day${value == 1 ? '' : 's'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800))),
            IconButton(
                onPressed: value < max ? () => onChanged(value + 1) : null,
                icon: const Icon(PhosphorIconsBold.plus,
                    size: 18, color: RC.blue)),
          ]),
        ),
      ]);
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.title, this.sub, this.icon, this.on, this.onChanged);
  final String title;
  final String sub;
  final IconData icon;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged(!on),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: on ? RC.tint : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: on ? RC.blue : RC.line, width: on ? 1.4 : 1),
          ),
          child: Row(children: [
            Icon(icon, color: on ? RC.blue : AppColors.textMuted, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: heading(size: 14.5)),
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ]),
            ),
            Icon(
                on
                    ? PhosphorIconsFill.checkCircle
                    : PhosphorIconsRegular.circle,
                color: on ? RC.blue : AppColors.borderStrong,
                size: 24),
          ]),
        ),
      );
}

/// After sending: plain confirmation, nothing else to do until the customer picks a shop.
class _Sent extends StatelessWidget {
  const _Sent(this.offer, this.d);
  final MyOffer offer;
  final OfferDraft d;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              Container(
                width: 108,
                height: 108,
                decoration: const BoxDecoration(
                    color: RC.greenTint, shape: BoxShape.circle),
                child: const Icon(PhosphorIconsFill.paperPlaneTilt,
                    color: RC.green, size: 52),
              ),
              const SizedBox(height: 22),
              Text('Offer sent!', style: heading(size: 26)),
              const SizedBox(height: 8),
              const Text(
                  'The customer can now see your price.\nWe will tell you when they choose your shop.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14.5,
                      height: 1.4,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 22),
              HomeCard(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  KV('Your price (with GST)', formatInr(offer.total),
                      bold: true, color: RC.blue),
                  KV('Time', daysLabel(offer.estDaysMin, offer.estDaysMax)),
                  KV(
                      'Warranty',
                      offer.warrantyDays == 0
                          ? 'None'
                          : '${offer.warrantyDays} days'),
                ]),
              ),
              const Spacer(),
              AuctionButton(
                  label: 'Back to Repair Requests',
                  icon: PhosphorIconsBold.arrowLeft,
                  onPressed: () => context.go(Routes.repairs)),
              const SizedBox(height: 4),
            ]),
          ),
        ),
      );
}
