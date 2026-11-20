import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/products/application/product_draft.dart';
import 'package:dealker_vendor/features/products/application/product_providers.dart';
import 'package:dealker_vendor/features/products/data/product_catalog.dart';
import 'package:dealker_vendor/features/products/data/product_models.dart';
import 'package:dealker_vendor/features/products/presentation/widgets/product_common.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

enum EditKind { price, stock, b2b, b2c }

/// Opens one of the quick editors; returns true when something was saved.
Future<bool> showEditSheet(
    BuildContext context, ListingDetail p, EditKind kind) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (c) => _EditSheet(p: p, kind: kind),
  );
  return saved ?? false;
}

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.p, required this.kind});
  final ListingDetail p;
  final EditKind kind;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late String price =
      widget.p.sellB2c && widget.p.price > 0 ? '${widget.p.price.round()}' : '';
  late String mrp = widget.p.mrp == null ? '' : '${widget.p.mrp!.round()}';
  late String wholesale = widget.p.wholesalePrice == null
      ? ''
      : '${widget.p.wholesalePrice!.round()}';
  late String moq = '${widget.p.moq}';
  late String stock = '${widget.p.stock}';
  late int discount = (widget.p.discountPct ?? 0).round();
  late String notes = widget.p.b2bNotes;
  late bool b2b = widget.p.sellB2b;
  late bool b2c = widget.p.sellB2c;
  late int returnDays = widget.p.returnDays;
  bool _saving = false;

  ListingDetail get p => widget.p;

  String get _title => switch (widget.kind) {
        EditKind.price => 'Update Price',
        EditKind.stock => 'Update Stock',
        EditKind.b2b => 'Update B2B Details',
        EditKind.b2c => 'Update B2C Details',
      };

  /// Request body + the first validation problem.
  (Map<String, dynamic>, String?) _build() {
    final body = <String, dynamic>{};
    String? err;
    switch (widget.kind) {
      case EditKind.price:
        if (p.sellB2c) {
          final v = parseNum(price);
          if (v == null || v <= 0) err = 'Enter the selling price.';
          body['price'] = v;
          if (mrp.trim().isNotEmpty) {
            final m = parseNum(mrp);
            if (m == null || (v != null && m < v)) {
              err ??= 'MRP cannot be lower than the selling price.';
            }
            body['mrp'] = m;
          } else {
            body['mrp'] = null;
          }
        }
        if (p.sellB2b) {
          final w = parseNum(wholesale);
          if (w == null || w <= 0) err ??= 'Enter the wholesale price.';
          if (p.sellB2c &&
              w != null &&
              parseNum(price) != null &&
              w > parseNum(price)!) {
            err ??= 'Wholesale price cannot be higher than the B2C price.';
          }
          body['wholesalePrice'] = w;
        }
      case EditKind.stock:
        final q = int.tryParse(stock.trim());
        if (q == null || q < 0) err = 'Enter the number of units.';
        if (p.condition.isUsed && p.sellB2c && (q ?? 0) > 1) {
          err ??= 'Used items sold to customers are single units (quantity 1).';
        }
        if (p.sellB2b && q != null && q > 0 && p.moq > q) {
          err ??= 'Stock is below your MOQ (${p.moq}). Lower the MOQ first.';
        }
        body['stock'] = q;
      case EditKind.b2b:
        body['sellB2b'] = b2b;
        if (b2b) {
          final w = parseNum(wholesale);
          if (w == null || w <= 0) err = 'Enter the wholesale price.';
          final m = int.tryParse(moq.trim());
          if (m == null || m < 1) err ??= 'MOQ must be at least 1.';
          if (m != null && p.stock > 0 && m > p.stock) {
            err ??= 'MOQ can’t be more than stock (${p.stock}).';
          }
          if (p.sellB2c && w != null && w > p.price) {
            err ??= 'Wholesale price cannot be higher than the B2C price.';
          }
          body
            ..['wholesalePrice'] = w
            ..['moq'] = m
            ..['b2bDiscountPct'] = discount
            ..['b2bNotes'] = notes.trim();
        } else if (!b2c) {
          err = 'Keep at least one channel on.';
        }
      case EditKind.b2c:
        body['sellB2c'] = b2c;
        if (b2c) {
          final v = parseNum(price);
          if (v == null || v <= 0) err = 'Enter the selling price.';
          if (mrp.trim().isNotEmpty) {
            final m = parseNum(mrp);
            if (m == null || (v != null && m < v)) {
              err ??= 'MRP cannot be lower than the selling price.';
            }
            body['mrp'] = m;
          }
          body
            ..['price'] = v
            ..['returnPolicyDays'] = returnDays;
        } else if (!b2b) {
          err = 'Keep at least one channel on.';
        }
    }
    return (body, err);
  }

  Future<void> _save() async {
    final (body, err) = _build();
    if (err != null) {
      showAppToast(context, err, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(productRepositoryProvider).update(p.id, body);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showAppToast(context, explainFailure(e).message, error: true);
        setState(() => _saving = false);
      }
    }
  }

  Widget _switch(String label, String sub, bool v, ValueChanged<bool> on) =>
      Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: const Color(0xFFF7F9FE),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder)),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              Text(sub,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textMuted)),
            ]),
          ),
          Switch(
              value: v,
              activeThumbColor: Colors.white,
              activeTrackColor: kBlue,
              onChanged: on),
        ]),
      );

  Widget _money(String label, String value, ValueChanged<String> on,
          {bool optional = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FieldLabel(label, optional: optional),
          AuctionField(
              initial: value,
              number: true,
              maxLength: 9,
              prefix: '₹',
              hint: '0',
              onChanged: on),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final fields = <Widget>[
      switch (widget.kind) {
        EditKind.price =>
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p.sellB2c) ...[
              _money('Selling price (B2C)', price, (v) => price = v),
              _money('MRP', mrp, (v) => mrp = v, optional: true),
            ],
            if (p.sellB2b)
              _money('Wholesale price (B2B, per unit)', wholesale,
                  (v) => wholesale = v),
          ]),
        EditKind.stock =>
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('Units in stock'),
            AuctionField(
                initial: stock,
                number: true,
                maxLength: 6,
                hint: '0',
                onChanged: (v) => stock = v),
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 14),
              child: Text(
                  'Set to 0 when you run out — the product shows as out of stock automatically.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ),
          ]),
        EditKind.b2b =>
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _switch(
                'Sell to vendors (B2B)',
                'Wholesale buyers can order in bulk',
                b2b,
                (v) => setState(() => b2b = v)),
            if (b2b) ...[
              _money('Wholesale price (per unit)', wholesale,
                  (v) => wholesale = v),
              const FieldLabel('Minimum order quantity (MOQ)'),
              AuctionField(
                  initial: moq,
                  number: true,
                  maxLength: 5,
                  hint: '1',
                  onChanged: (v) => moq = v),
              const SizedBox(height: 14),
              const FieldLabel('Business discount'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final d in kDiscountChoices)
                  _Pill(
                      label: d == 0 ? 'None' : '$d%',
                      selected: discount == d,
                      onTap: () => setState(() => discount = d)),
              ]),
              const SizedBox(height: 14),
              const FieldLabel('B2B notes', optional: true),
              AuctionField(
                  initial: notes,
                  maxLines: 3,
                  maxLength: 500,
                  hint: 'Notes for wholesale buyers',
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (v) => notes = v),
              const SizedBox(height: 6),
            ],
          ]),
        EditKind.b2c =>
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _switch(
                'Sell to customers (B2C)',
                'Visible in the Dealkr customer app',
                b2c,
                (v) => setState(() => b2c = v)),
            if (b2c) ...[
              _money('Selling price', price, (v) => price = v),
              _money('MRP', mrp, (v) => mrp = v, optional: true),
              const FieldLabel('Return window'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in kReturnDayChoices)
                  _Pill(
                      label: r == 0 ? 'No returns' : '$r days',
                      selected: returnDays == r,
                      onTap: () => setState(() => returnDays = r)),
              ]),
              const SizedBox(height: 6),
            ],
          ]),
      },
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4))),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: Text(_title, style: heading(size: 19))),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(PhosphorIconsRegular.x, size: 22)),
                ]),
                const SizedBox(height: 4),
                Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 16),
                ...fields,
                const SizedBox(height: 8),
                AuctionButton(
                    label: 'Save Changes', loading: _saving, onPressed: _save),
              ]),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? kBlueSoft : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? kBlue : AppColors.border,
                width: selected ? 1.8 : 1.2),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? kBlue : AppColors.textSecondary)),
          ),
        ),
      );
}
