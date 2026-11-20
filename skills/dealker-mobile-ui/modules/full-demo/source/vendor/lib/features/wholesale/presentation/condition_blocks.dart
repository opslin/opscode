import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/features/wholesale/data/condition_report.dart';

// The customer app's product-page blocks (condition, Dealkr QC card + report, in the box, highlights, specs)
// brought to the vendor marketplace, on a pure white page.

const _blue = Color(0xFF1D4ED8);
const _ink = Color(0xFF0F1B3D);
const _muted = Color(0xFF6B7280);
const _line = Color(0xFFE6EAF2);
const _soft = Color(0xFFF6F7FB);
const _green = Color(0xFF15803D);
const _amber = Color(0xFFB45309);

const _font = 'PlusJakartaSans';
const _h = TextStyle(fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w800, color: _ink);

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line)),
        child: child,
      );
}

String _date(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// "Dealkr QC Certified / 100% Genuine" + warranty chips.
class TrustChips extends StatelessWidget {
  const TrustChips({super.key, required this.report});
  final ConditionReport report;

  @override
  Widget build(BuildContext context) {
    final chips = <(IconData, String, Color, Color)>[];
    if (report.isUsed && report.qc != null) {
      chips.add((Icons.verified_rounded, 'Dealkr QC Certified', _blue, const Color(0xFFEEF3FF)));
    } else if (!report.isUsed) {
      chips.add((Icons.verified_rounded, '100% Genuine', _blue, const Color(0xFFEEF3FF)));
    }
    if ((report.warranty ?? '').trim().isNotEmpty) {
      chips.add((
        Icons.shield_outlined,
        report.warranty!.trim(),
        report.isUsed ? _amber : _green,
        report.isUsed ? const Color(0xFFFFF3E0) : const Color(0xFFE7F8EE),
      ));
    }
    if (report.hasInvoice) {
      chips.add((Icons.receipt_long_outlined, 'GST invoice', _green, const Color(0xFFE7F8EE)));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final (i, t, fg, bg) in chips)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(i, size: 14, color: fg),
            const SizedBox(width: 4),
            Flexible(
                child: Text(t,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: _font, fontSize: 11.5, fontWeight: FontWeight.w700, color: fg))),
          ]),
        ),
    ]);
  }
}

/// Device condition: grade selector (read-only) + skin / battery / usage facts. Used, refurbished and open-box items.
class ConditionBlock extends StatelessWidget {
  const ConditionBlock({super.key, required this.report});
  final ConditionReport report;

  @override
  Widget build(BuildContext context) {
    if (!report.isUsed) return const SizedBox.shrink();
    final facts = <(String, String)>[
      for (final c in report.checklist.take(2)) (c.label, c.value),
      if (report.batteryHealth != null) ('Battery health', '${report.batteryHealth}%'),
      if ((report.usageDuration ?? '').isNotEmpty) ('Usage', report.usageDuration!),
    ];
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Device condition', style: _h),
        const SizedBox(height: 10),
        Row(children: [
          for (var i = 0; i < report.grades.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
                child: _Grade(
                    label: report.grades[i].label,
                    on: report.grades[i].key == report.condition)),
          ],
        ]),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 10),
          LayoutBuilder(
              builder: (context, bc) => Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final (l, v) in facts)
                      SizedBox(
                        width: ((bc.maxWidth - 8) / 2).floorToDouble(),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(12)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l, style: const TextStyle(fontFamily: _font, fontSize: 11.5, color: _muted)),
                            const SizedBox(height: 2),
                            Text(v,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: _font, fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
                          ]),
                        ),
                      ),
                  ])),
        ],
        if ((report.notes ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(report.notes!.trim(),
              style: const TextStyle(fontFamily: _font, fontSize: 12.5, height: 1.45, color: _muted)),
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
            style: TextStyle(fontFamily: _font, fontSize: 12.5, fontWeight: FontWeight.w800, color: on ? _blue : _muted)),
      );
}

class QcScoreRing extends StatelessWidget {
  const QcScoreRing({super.key, required this.score, this.size = 62});
  final int? score;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: ((score ?? 0) / 100).clamp(0, 1).toDouble(),
              strokeWidth: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
            ),
          ),
          Text(score == null ? '–' : '$score',
              style: TextStyle(fontFamily: _font, fontSize: size * 0.32, fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
      );
}

/// Dark QC score card → opens the full report.
class QcSummaryCard extends StatelessWidget {
  const QcSummaryCard({super.key, required this.report, required this.name});
  final ConditionReport report;
  final String name;

  @override
  Widget build(BuildContext context) {
    final qc = report.qc;
    if (!report.isUsed || qc == null) return const SizedBox.shrink();
    final date = qc.checkedAt == null ? '' : ' · ${_date(qc.checkedAt!)}';
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => WholesaleQcScreen(report: report, name: name))),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0F1B3D), Color(0xFF1D3A8A)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          qc.score == null
              ? Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.12)),
                  child: const Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 32))
              : QcScoreRing(score: qc.score),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Dealkr QC Report',
                  style: TextStyle(fontFamily: _font, fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 2),
              Text('${qc.checks.length > 1 ? '${qc.checks.length} checks passed' : 'Passed quality check'}$date',
                  style: TextStyle(fontFamily: _font, fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
            ]),
          ),
          const Text('View',
              style: TextStyle(fontFamily: _font, fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
        ]),
      ),
    );
  }
}

class InBoxBlock extends StatelessWidget {
  const InBoxBlock({super.key, required this.report});
  final ConditionReport report;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final items = <String>[...report.accessories, if (report.hasInvoice) 'GST invoice']
        .where((x) => seen.add(x.trim().toLowerCase()))
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("What's in the box", style: _h),
        const SizedBox(height: 10),
        Wrap(runSpacing: 10, children: [
          for (final s in items.map((x) => x.isEmpty ? x : x[0].toUpperCase() + x.substring(1)))
            FractionallySizedBox(
              widthFactor: 0.5,
              child: Row(children: [
                Icon(_iconFor(s), size: 20, color: _blue),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(s,
                        style: const TextStyle(fontFamily: _font, fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink))),
              ]),
            ),
        ]),
      ]),
    );
  }

  static IconData _iconFor(String s) {
    final l = s.toLowerCase();
    if (l.contains('box')) return Icons.inventory_2_outlined;
    if (l.contains('charger') || l.contains('adapter')) return Icons.power_outlined;
    if (l.contains('cable')) return Icons.cable_rounded;
    if (l.contains('invoice') || l.contains('bill')) return Icons.receipt_long_outlined;
    if (l.contains('manual') || l.contains('warranty')) return Icons.menu_book_outlined;
    if (l.contains('case') || l.contains('cover')) return Icons.phone_iphone_rounded;
    return Icons.check_circle_outline_rounded;
  }
}

class HighlightsBlock extends StatelessWidget {
  const HighlightsBlock({super.key, required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Highlights', style: _h),
        const SizedBox(height: 10),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.check_circle_rounded, size: 16, color: _blue)),
              const SizedBox(width: 8),
              Expanded(child: Text(l, style: const TextStyle(fontFamily: _font, fontSize: 13, height: 1.35, color: _ink))),
            ]),
          ),
      ]),
    );
  }
}

class SpecsBlock extends StatelessWidget {
  const SpecsBlock({super.key, required this.rows});
  final List<({String label, String value})> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Specifications', style: _h),
        const SizedBox(height: 6),
        for (var i = 0; i < rows.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
                border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: Color(0xFFEEF0F6)))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 4, child: Text(rows[i].label, style: const TextStyle(fontFamily: _font, fontSize: 13, color: _muted))),
              const SizedBox(width: 8),
              Expanded(
                  flex: 6,
                  child: Text(rows[i].value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontFamily: _font, fontSize: 13, fontWeight: FontWeight.w700, color: _ink))),
            ]),
          ),
      ]),
    );
  }
}

// ── Full QC report ────────────────────────────────────────────────────────

class WholesaleQcScreen extends ConsumerWidget {
  const WholesaleQcScreen({super.key, required this.report, required this.name});
  final ConditionReport report;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qc = report.qc!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded, color: _ink), onPressed: () => Navigator.of(context).maybePop()),
              const Text('QC report', style: TextStyle(fontFamily: _font, fontSize: 19, fontWeight: FontWeight.w800, color: _ink)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0F1B3D), Color(0xFF1D3A8A)]),
                    borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  if (qc.score != null)
                    QcScoreRing(score: qc.score, size: 78)
                  else
                    const Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 56),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(qc.score == null ? 'Quality checked' : qc.verdict,
                          style: const TextStyle(fontFamily: _font, fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 3),
                      Text('Checked by Dealkr QC team${qc.checkedAt == null ? '' : '\n${_date(qc.checkedAt!)}'}',
                          style: TextStyle(fontFamily: _font, fontSize: 12, height: 1.4, color: Colors.white.withValues(alpha: 0.85))),
                    ]),
                  ),
                ]),
              ),
              if (name.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(name, style: const TextStyle(fontFamily: _font, fontSize: 13, color: _muted)),
              ],
              if (report.batteryHealth != null && !qc.checks.any((k) => k.label.toLowerCase().contains('battery'))) ...[
                const SizedBox(height: 14),
                _Box(
                  title: 'Battery',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Health', style: TextStyle(fontFamily: _font, fontSize: 13, color: _ink)),
                      Text('${report.batteryHealth}%',
                          style: const TextStyle(fontFamily: _font, fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: report.batteryHealth! / 100,
                        minHeight: 8,
                        backgroundColor: _line,
                        valueColor: AlwaysStoppedAnimation<Color>(report.batteryHealth! >= 80 ? const Color(0xFF22C55E) : _amber),
                      ),
                    ),
                  ]),
                ),
              ],
              if (qc.checks.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Box(
                  title: 'Verified checks',
                  child: Column(children: [
                    for (var i = 0; i < qc.checks.length; i++)
                      _Row(
                          label: qc.checks[i].label,
                          value: qc.checks[i].ok ? 'Pass' : qc.checks[i].value,
                          ok: qc.checks[i].ok,
                          last: i == qc.checks.length - 1),
                  ]),
                ),
              ],
              if (report.checklist.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Box(
                  title: 'Condition & skin',
                  child: Column(children: [
                    for (var i = 0; i < report.checklist.length; i++)
                      _Row(label: report.checklist[i].label, value: report.checklist[i].value, ok: null, last: i == report.checklist.length - 1),
                  ]),
                ),
              ],
              if ((report.notes ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                _Box(
                  title: 'Inspector note',
                  child: Text(report.notes!.trim(),
                      style: const TextStyle(fontFamily: _font, fontSize: 13, height: 1.5, color: _muted)),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: _h),
          const SizedBox(height: 8),
          child,
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.ok, required this.last});
  final String label;
  final String value;
  final bool? ok;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final vc = ok == null ? _ink : (ok! ? _green : _amber);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFEEF0F6)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 5, child: Text(label, style: const TextStyle(fontFamily: _font, fontSize: 13, color: _ink))),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (ok != null) ...[
              Icon(ok! ? Icons.check_circle_rounded : Icons.error_outline_rounded, size: 15, color: vc),
              const SizedBox(width: 4),
            ],
            Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontFamily: _font, fontSize: 13, fontWeight: FontWeight.w700, color: vc))),
          ]),
        ),
      ]),
    );
  }
}
