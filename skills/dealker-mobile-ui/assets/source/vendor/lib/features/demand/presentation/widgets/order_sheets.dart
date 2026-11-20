import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/demand_common.dart';

const _couriers = [
  'Shiprocket',
  'Porter',
  'Blue Dart',
  'Delhivery',
  'Own delivery'
];

/// "Delivery / Pickup": the seller chooses how the buyer gets the goods.
/// Returns the request body for `POST /orders/:id/status`, or null when dismissed.
Future<Map<String, dynamic>?> showDispatchSheet(BuildContext context,
        {required DemandOrder order, required Requirement requirement}) =>
    showDemandSheet<Map<String, dynamic>>(context,
        builder: (_) => _DispatchSheet(order: order, requirement: requirement));

class _DispatchSheet extends StatefulWidget {
  const _DispatchSheet({required this.order, required this.requirement});
  final DemandOrder order;
  final Requirement requirement;

  @override
  State<_DispatchSheet> createState() => _DispatchSheetState();
}

class _DispatchSheetState extends State<_DispatchSheet> {
  // Pickup is the recommended default; only a buyer who asked for delivery starts on the courier option.
  late bool _pickup = widget.requirement.fulfilmentPref != 'DELIVERY';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 14, minute: 0);
  String _courier = '';
  String _awb = '';
  String _link = '';
  String _note = '';
  String? _error;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  void _submit() {
    if (_pickup) {
      final at = DateTime(
          _date.year, _date.month, _date.day, _time.hour, _time.minute);
      if (at.isBefore(DateTime.now())) {
        setState(() => _error = 'Pick a pickup time in the future.');
        return;
      }
      Navigator.pop(context, {
        'status': 'DISPATCHED',
        'fulfilmentType': 'PICKUP',
        'pickupAt': at.toUtc().toIso8601String(),
        if (_note.trim().isNotEmpty) 'pickupNote': _note.trim(),
      });
    } else {
      if (_courier.trim().isEmpty || _awb.trim().isEmpty) {
        setState(() => _error = 'Enter the courier and the tracking ID.');
        return;
      }
      Navigator.pop(context, {
        'status': 'DISPATCHED',
        'fulfilmentType': 'DELIVERY',
        'courierName': _courier.trim(),
        'awb': _awb.trim(),
        if (_link.trim().isNotEmpty) 'trackingUrl': _link.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pref = widget.requirement.fulfilmentPref;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Delivery / Pickup', style: heading(size: 20)),
      const SizedBox(height: 4),
      Text(
        pref == 'ANY'
            ? 'How will ${widget.order.buyerName} get the order?'
            : 'The buyer prefers ${pref == 'PICKUP' ? 'to collect it' : 'delivery'}.',
        style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 14),
      _Option(
        selected: _pickup,
        icon: PhosphorIconsFill.storefront,
        title: 'Vendor pickup',
        subtitle: 'The buyer collects it from your shop',
        badge: pref == 'PICKUP' ? 'Buyer’s choice' : 'Recommended',
        onTap: () => setState(() {
          _pickup = true;
          _error = null;
        }),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: PickerField(
                    value: formatDay(_date, year: false),
                    icon: PhosphorIconsRegular.calendarBlank,
                    onTap: _pickDate)),
            const SizedBox(width: 10),
            Expanded(
                child: PickerField(
                    value: _time.format(context),
                    icon: PhosphorIconsRegular.clock,
                    onTap: _pickTime)),
          ]),
          const SizedBox(height: 10),
          AuctionField(
              initial: _note,
              hint: 'Who to ask for, landmark… (optional)',
              maxLength: 200,
              onChanged: (v) => _note = v),
        ]),
      ),
      const SizedBox(height: 10),
      _Option(
        selected: !_pickup,
        icon: PhosphorIconsFill.truck,
        title: 'Courier delivery',
        subtitle: 'Ship it and share the tracking ID',
        badge: pref == 'DELIVERY' ? 'Buyer’s choice' : null,
        onTap: () => setState(() {
          _pickup = false;
          _error = null;
        }),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 12),
          ChoiceChips<String>(
            options: _couriers,
            value: _couriers.contains(_courier) ? _courier : null,
            label: (c) => c,
            onChanged: (c) => setState(() => _courier = c),
          ),
          const SizedBox(height: 10),
          AuctionField(
            key: ValueKey('courier-$_courier'),
            initial: _courier,
            hint: 'Courier / delivery partner',
            maxLength: 60,
            onChanged: (v) => _courier = v,
          ),
          const SizedBox(height: 10),
          AuctionField(
              initial: _awb,
              hint: 'Tracking ID (AWB)',
              maxLength: 60,
              onChanged: (v) => _awb = v),
          const SizedBox(height: 10),
          AuctionField(
              initial: _link,
              hint: 'Tracking link (optional)',
              maxLength: 300,
              onChanged: (v) => _link = v),
        ]),
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.rose)),
      ],
      const SizedBox(height: 16),
      AuctionButton(
          label: _pickup ? 'Schedule pickup' : 'Confirm dispatch',
          icon: PhosphorIconsBold.check,
          onPressed: _submit),
      const SizedBox(height: 8),
      const Center(
        child: Text(
            'The buyer is notified immediately. Shipment status only — no live location.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ),
    ]);
  }
}

class _Option extends StatelessWidget {
  const _Option(
      {required this.selected,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap,
      required this.child,
      this.badge});
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF3F8FF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? kDemandBlue : AppColors.border,
                width: selected ? 1.6 : 1.2),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: selected ? kDemandBlueSoft : kGreySoft,
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(icon,
                    color: selected ? kDemandBlue : AppColors.textSecondary,
                    size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                            child: Text(title, style: heading(size: 15.5))),
                        if (badge != null) ...[
                          const SizedBox(width: 7),
                          Pill(badge!,
                              fg: AppColors.mint, bg: AppColors.mintSoft),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.textSecondary)),
                    ]),
              ),
              Icon(
                  selected
                      ? PhosphorIconsFill.radioButton
                      : PhosphorIconsRegular.circle,
                  color: selected ? kDemandBlue : AppColors.borderStrong,
                  size: 24),
            ]),
            if (selected) child,
          ]),
        ),
      );
}

typedef ReceiptResult = ({int quantity, bool ok, String? note});

/// Buyer confirms what arrived. Everything fine releases the payment; anything short or wrong raises an issue.
Future<ReceiptResult?> showReceiveSheet(BuildContext context,
        {required DemandOrder order}) =>
    showDemandSheet<ReceiptResult>(context,
        builder: (_) => _ReceiveSheet(order: order));

class _ReceiveSheet extends StatefulWidget {
  const _ReceiveSheet({required this.order});
  final DemandOrder order;

  @override
  State<_ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<_ReceiveSheet> {
  late int _qty = widget.order.quantity;
  bool _problem = false;
  String _note = '';
  String? _error;

  bool get _issue => _problem || _qty < widget.order.quantity;

  void _submit() {
    if (_issue && _note.trim().length < 3) {
      setState(() => _error = 'Tell us what is wrong so Dealkr can help.');
      return;
    }
    Navigator.pop(context, (
      quantity: _qty,
      ok: !_issue,
      note: _note.trim().isEmpty ? null : _note.trim()
    ));
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Confirm receipt', style: heading(size: 20)),
      const SizedBox(height: 4),
      Text('${o.productName} · ${pcs(o.quantity)} from ${o.sellerName}',
          style:
              const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
      const SizedBox(height: 16),
      const FieldLabel('How many pieces did you receive?'),
      Row(children: [
        QtyStepper(
            value: _qty,
            min: 0,
            max: o.quantity,
            onChanged: (v) => setState(() => _qty = v)),
        const SizedBox(width: 12),
        Text('of ${o.quantity} ordered',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
      ]),
      const SizedBox(height: 16),
      Segmented(
          labels: const ['All good', 'There is a problem'],
          index: _issue ? 1 : 0,
          onChanged: (i) => setState(() => _problem = i == 1)),
      const SizedBox(height: 14),
      if (_issue) ...[
        const FieldLabel('What is wrong?'),
        AuctionField(
            initial: _note,
            maxLines: 3,
            maxLength: 400,
            hint: 'Short quantity, damaged, not as described…',
            onChanged: (v) => _note = v),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_error!,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.rose))),
        const SizedBox(height: 10),
        const Notice(
          icon: PhosphorIconsFill.shieldCheck,
          text:
              'The payment stays in escrow. Dealkr reviews the issue with both of you and releases or refunds it.',
          color: kAmberText,
          bg: AppColors.amberSoft,
        ),
      ] else
        Notice(
          icon: PhosphorIconsFill.info,
          text:
              'Confirming releases ${formatInr(o.subtotal)} to ${o.sellerName}. Check the pieces first — this cannot be undone.',
        ),
      const SizedBox(height: 16),
      AuctionButton(
        label: _issue ? 'Report issue' : 'Confirm & release payment',
        icon: _issue ? PhosphorIconsBold.flag : PhosphorIconsBold.check,
        danger: _issue,
        onPressed: _submit,
      ),
    ]);
  }
}

/// Seller cannot fulfil a paid order — asks for the reason the buyer will see.
Future<String?> showCancelOrderSheet(BuildContext context,
        {required DemandOrder order}) =>
    showDemandSheet<String>(context,
        builder: (_) => _CancelSheet(order: order));

class _CancelSheet extends StatefulWidget {
  const _CancelSheet({required this.order});
  final DemandOrder order;

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  String _reason = '';
  String? _error;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Cancel this order?', style: heading(size: 20)),
        const SizedBox(height: 6),
        Text(
            '${widget.order.buyerName} is refunded ${formatInr(widget.order.subtotal)} in full and the pieces go back on their requirement.',
            style: const TextStyle(
                fontSize: 13.5, height: 1.4, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        const FieldLabel('Reason for the buyer'),
        AuctionField(
            initial: _reason,
            maxLines: 3,
            maxLength: 300,
            hint: 'e.g. Stock sold out',
            onChanged: (v) => _reason = v),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_error!,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.rose))),
        const SizedBox(height: 10),
        const Notice(
          icon: PhosphorIconsFill.warning,
          text:
              'The buyer is told straight away and can pick another seller. Cancel only when you truly cannot deliver.',
          color: kAmberText,
          bg: AppColors.amberSoft,
        ),
        const SizedBox(height: 16),
        AuctionButton(
          label: 'Cancel order & refund buyer',
          danger: true,
          onPressed: () {
            if (_reason.trim().length < 3) {
              setState(() => _error = 'Please give a short reason.');
              return;
            }
            Navigator.pop(context, _reason.trim());
          },
        ),
        const SizedBox(height: 6),
        Center(
            child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep the order',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)))),
      ]);
}
