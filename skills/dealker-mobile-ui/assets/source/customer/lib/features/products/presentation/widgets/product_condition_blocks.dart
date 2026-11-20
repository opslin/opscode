import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/features/products/data/condition/product_condition.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/shops/data/shop_summary.dart';
import 'package:dealker_app/features/shops/presentation/providers/shops_provider.dart';
import 'package:dealker_app/features/shops/presentation/widgets/shop_widgets.dart';

const Color _blue = Color(0xFF1D4ED8);
const Color _ink = Color(0xFF0F1B3D);
const Color _muted = Color(0xFF6B7280);
const Color _line = Color(0xFFE6EAF2);
const Color _soft = Color(0xFFF6F7FB);
const Color _green = Color(0xFF15803D);
const Color _amber = Color(0xFFB45309);

const TextStyle _h = TextStyle(
  fontFamily: 'PlusJakartaSans',
  fontSize: 16,
  fontWeight: FontWeight.w800,
  color: _ink,
);

class _Card extends StatelessWidget {
  const _Card({required this.child, this.color, this.border = true});
  final Widget child;
  final Color? color;
  final bool border;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: border ? Border.all(color: _line) : null,
        ),
        child: child,
      );
}

/// Corner tag on the gallery + trust chips under it.
class ConditionTag extends StatelessWidget {
  const ConditionTag({required this.condition, super.key});
  final ProductCondition condition;

  @override
  Widget build(BuildContext context) {
    final bool used = condition.condition != 'NEW';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: used ? const Color(0xFFFFF3E0) : const Color(0xFFE7F8EE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        used ? condition.tag : 'BRAND NEW · Sealed',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: used ? _amber : _green,
        ),
      ),
    );
  }
}

class TrustChips extends StatelessWidget {
  const TrustChips({required this.condition, super.key});
  final ProductCondition condition;

  @override
  Widget build(BuildContext context) {
    final List<(IconData, String, Color, Color)> chips =
        <(IconData, String, Color, Color)>[];
    if (condition.isUsed && condition.qc != null) {
      chips.add((
        Icons.verified_rounded,
        'Dealkr QC Certified',
        _blue,
        const Color(0xFFEEF3FF)
      ));
    } else if (!condition.isUsed) {
      chips.add((
        Icons.verified_rounded,
        '100% Genuine',
        _blue,
        const Color(0xFFEEF3FF)
      ));
    }
    if ((condition.warranty ?? '').trim().isNotEmpty) {
      chips.add((
        Icons.shield_outlined,
        condition.warranty!.trim(),
        condition.isUsed ? _amber : _green,
        condition.isUsed ? const Color(0xFFFFF3E0) : const Color(0xFFE7F8EE),
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final (IconData i, String t, Color fg, Color bg) in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
              Icon(i, size: 14, color: fg),
              const SizedBox(width: 4),
              Flexible(
                child: Text(t,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: fg)),
              ),
            ]),
          ),
      ],
    );
  }
}

/// "Device condition": grade selector (read-only) + skin / battery / usage facts. Used items only.
class ConditionBlock extends StatelessWidget {
  const ConditionBlock({required this.condition, super.key});
  final ProductCondition condition;

  @override
  Widget build(BuildContext context) {
    if (!condition.isUsed) return const SizedBox.shrink();
    final List<(String, String)> facts = <(String, String)>[
      for (final c in condition.checklist.take(2)) (c.label, c.value),
      if (condition.batteryHealth != null)
        ('Battery health', '${condition.batteryHealth}%'),
      if ((condition.usageDuration ?? '').isNotEmpty)
        ('Usage', condition.usageDuration!),
    ];
    return _Card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Device condition', style: _h),
            const SizedBox(height: 10),
            Row(children: <Widget>[
              for (int i = 0; i < condition.grades.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                    child: _Grade(
                        label: condition.grades[i].label,
                        on: condition.grades[i].key == condition.condition)),
              ],
            ]),
            if (facts.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints bc) =>
                      Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                        for (final (String l, String v) in facts)
                          SizedBox(
                            width: ((bc.maxWidth - 8) / 2).floorToDouble(),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: _soft,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(l,
                                        style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 11.5,
                                            color: _muted)),
                                    const SizedBox(height: 2),
                                    Text(v,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: _ink)),
                                  ]),
                            ),
                          ),
                      ])),
            ],
            if ((condition.notes ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(condition.notes!.trim(),
                  style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12.5,
                      height: 1.45,
                      color: _muted)),
            ],
          ]),
    );
  }
}

class _Grade extends StatelessWidget {
  const _Grade({required this.label, required this.on});
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? const Color(0xFFEEF3FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? _blue : _line, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: on ? _blue : _muted)),
      );
}

/// Dark QC score card → opens the full report.
class QcSummaryCard extends StatelessWidget {
  const QcSummaryCard(
      {required this.condition,
      required this.productId,
      required this.name,
      super.key});
  final ProductCondition condition;
  final String productId;
  final String name;

  @override
  Widget build(BuildContext context) {
    final ProductQc? qc = condition.qc;
    if (!condition.isUsed || qc == null) return const SizedBox.shrink();
    final String date =
        qc.checkedAt == null ? '' : ' · ${_date(qc.checkedAt!)}';
    return GestureDetector(
      onTap: () => context.push('/product/$productId/qc', extra: name),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: <Color>[Color(0xFF0F1B3D), Color(0xFF1D3A8A)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: <Widget>[
          qc.score == null
              ? Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12)),
                  child: const Icon(Icons.verified_rounded,
                      color: Color(0xFF34D399), size: 32))
              : QcScoreRing(score: qc.score, size: 62),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Dealkr QC Report',
                      style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                      '${qc.checks.length > 1 ? '${qc.checks.length} checks passed' : 'Passed quality check'}$date',
                      style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85))),
                ]),
          ),
          const Text('View',
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const Icon(Icons.chevron_right_rounded,
              color: Colors.white, size: 20),
        ]),
      ),
    );
  }
}

String _date(DateTime d) {
  const List<String> m = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

class QcScoreRing extends StatelessWidget {
  const QcScoreRing({required this.score, this.size = 62, super.key});
  final int? score;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: <Widget>[
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: ((score ?? 0) / 100).clamp(0, 1).toDouble(),
              strokeWidth: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
            ),
          ),
          Text(score == null ? '–' : '$score',
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ]),
      );
}

class InBoxBlock extends StatelessWidget {
  const InBoxBlock({required this.condition, super.key});
  final ProductCondition condition;

  @override
  Widget build(BuildContext context) {
    final List<String> items = <String>[
      ...condition.accessories,
      if (condition.hasInvoice) 'GST invoice',
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return _Card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text("What's in the box", style: _h),
            const SizedBox(height: 10),
            Wrap(runSpacing: 10, children: <Widget>[
              for (final String s in items.map((String x) =>
                  x.isEmpty ? x : x[0].toUpperCase() + x.substring(1)))
                FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Row(children: <Widget>[
                    Icon(_iconFor(s), size: 20, color: _blue),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(s,
                            style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _ink))),
                  ]),
                ),
            ]),
          ]),
    );
  }

  static IconData _iconFor(String s) {
    final String l = s.toLowerCase();
    if (l.contains('box')) return Icons.inventory_2_outlined;
    if (l.contains('charger') || l.contains('adapter'))
      return Icons.power_outlined;
    if (l.contains('cable')) return Icons.cable_rounded;
    if (l.contains('invoice') || l.contains('bill'))
      return Icons.receipt_long_outlined;
    if (l.contains('manual') || l.contains('warranty'))
      return Icons.menu_book_outlined;
    if (l.contains('case') || l.contains('cover'))
      return Icons.phone_iphone_rounded;
    return Icons.check_circle_outline_rounded;
  }
}

class HighlightsBlock extends StatelessWidget {
  const HighlightsBlock({required this.lines, super.key});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return _Card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Highlights', style: _h),
            const SizedBox(height: 10),
            for (final String l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.check_circle_rounded,
                              size: 16, color: _blue)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(l,
                              style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  height: 1.35,
                                  color: _ink))),
                    ]),
              ),
          ]),
    );
  }
}

class SpecsBlock extends StatelessWidget {
  const SpecsBlock({required this.rows, super.key});
  final List<({String label, String value})> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Specifications', style: _h),
            const SizedBox(height: 6),
            for (int i = 0; i < rows.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                    border: i == rows.length - 1
                        ? null
                        : const Border(
                            bottom: BorderSide(color: Color(0xFFEEF0F6)))),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                          flex: 4,
                          child: Text(rows[i].label,
                              style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  color: _muted))),
                      Expanded(
                          flex: 6,
                          child: Text(rows[i].value,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _ink))),
                    ]),
              ),
          ]),
    );
  }
}

class DescriptionBlock extends StatefulWidget {
  const DescriptionBlock({required this.text, super.key});
  final String text;

  @override
  State<DescriptionBlock> createState() => _DescriptionBlockState();
}

class _DescriptionBlockState extends State<DescriptionBlock> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final String t = widget.text.trim();
    if (t.isEmpty) return const SizedBox.shrink();
    return _Card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('About this item', style: _h),
            const SizedBox(height: 8),
            Text(t,
                maxLines: _open ? null : 4,
                overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    height: 1.5,
                    color: _muted)),
            if (t.length > 160)
              GestureDetector(
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_open ? 'Show less' : 'Read more',
                      style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _blue)),
                ),
              ),
          ]),
    );
  }
}

class VendorBlock extends ConsumerWidget {
  const VendorBlock({required this.product, this.fallbackShopId, super.key});
  final ProductEntity product;
  final String? fallbackShopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? shopId =
        (product.shopId ?? '').isNotEmpty ? product.shopId : fallbackShopId;
    final String name = (product.soldBy ?? product.vendorName ?? '').trim();
    if (name.isEmpty) return const SizedBox.shrink();
    final ShopSummary? shop = (shopId == null || shopId.isEmpty)
        ? null
        : ref.watch(shopProfileProvider(shopId)).asData?.value.summary;
    return _Card(
      child: Row(children: <Widget>[
        shop != null
            ? ShopAvatar(shop: shop, size: 44)
            : Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: Color(0xFFEEF3FF), shape: BoxShape.circle),
                child: const Icon(Icons.storefront_outlined, color: _blue)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(children: <Widget>[
                  Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: _ink))),
                  if (shop?.isVerified ?? false) ...<Widget>[
                    const SizedBox(width: 4),
                    const VerifiedTick(size: 15)
                  ],
                ]),
                if (shop != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                        [
                          if (shop.rating > 0)
                            '★ ${shop.rating.toStringAsFixed(1)} (${shop.ratingCount})',
                          if ((shop.city ?? '').isNotEmpty) shop.city!,
                        ].join(' · '),
                        style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: _muted)),
                  ),
              ]),
        ),
        if (shopId != null && shopId.isNotEmpty)
          GestureDetector(
            onTap: () => context.push('/shop/$shopId'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFFEEF3FF),
                  borderRadius: BorderRadius.circular(999)),
              child: const Text('View shop',
                  style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _blue)),
            ),
          ),
      ]),
    );
  }
}
