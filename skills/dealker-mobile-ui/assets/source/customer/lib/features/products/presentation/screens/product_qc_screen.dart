import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/features/products/data/condition/product_condition.dart';
import 'package:dealker_app/features/products/presentation/widgets/product_condition_blocks.dart';

const Color _blue = Color(0xFF1D4ED8);
const Color _ink = Color(0xFF0F1B3D);
const Color _muted = Color(0xFF6B7280);
const Color _line = Color(0xFFE6EAF2);
const Color _green = Color(0xFF15803D);
const Color _amber = Color(0xFFB45309);

const TextStyle _h = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 15.5,
    fontWeight: FontWeight.w800,
    color: _ink);

/// Full customer-facing QC report (opened from the QC card on a used product).
class ProductQcScreen extends ConsumerWidget {
  const ProductQcScreen({required this.productId, this.name, super.key});
  final String productId;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProductCondition?> async =
        ref.watch(productConditionProvider(productId));
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
            child: Row(children: <Widget>[
              IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home')),
              const Text('QC report',
                  style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: _ink)),
            ]),
          ),
          Expanded(
            child: async.when(
              loading: () => const DealkerPageLoader(),
              error: (_, __) =>
                  const Center(child: Text('Could not load the report')),
              data: (ProductCondition? c) => (c == null || c.qc == null)
                  ? const Center(
                      child: Text('No QC report for this item',
                          style: TextStyle(
                              fontFamily: 'PlusJakartaSans', color: _muted)))
                  : _Body(c: c, name: name),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.c, this.name});
  final ProductCondition c;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final ProductQc qc = c.qc!;
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF0F1B3D), Color(0xFF1D3A8A)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: <Widget>[
              if (qc.score != null)
                QcScoreRing(score: qc.score, size: 78)
              else
                const Icon(Icons.verified_rounded,
                    color: Color(0xFF34D399), size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(qc.score == null ? 'Quality checked' : qc.verdict,
                          style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 3),
                      Text(
                          'Checked by Dealkr QC team'
                          '${qc.checkedAt == null ? '' : '\n${_d(qc.checkedAt!)}'}',
                          style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              height: 1.4,
                              color: Colors.white.withValues(alpha: 0.85))),
                    ]),
              ),
            ]),
          ),
          if (c.batteryHealth != null &&
              !qc.checks.any((ConditionCheck k) =>
                  k.label.toLowerCase().contains('battery'))) ...<Widget>[
            const SizedBox(height: 14),
            _Box(
              title: 'Battery',
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text('Health',
                              style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  color: _ink)),
                          Text('${c.batteryHealth}%',
                              style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _ink)),
                        ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: c.batteryHealth! / 100,
                        minHeight: 8,
                        backgroundColor: _line,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            c.batteryHealth! >= 80
                                ? const Color(0xFF22C55E)
                                : _amber),
                      ),
                    ),
                  ]),
            ),
          ],
          if (qc.checks.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _Box(
              title: 'Verified checks',
              child: Column(children: <Widget>[
                for (int i = 0; i < qc.checks.length; i++)
                  _Row(
                    label: qc.checks[i].label,
                    value: qc.checks[i].ok ? 'Pass' : qc.checks[i].value,
                    ok: qc.checks[i].ok,
                    last: i == qc.checks.length - 1,
                  ),
              ]),
            ),
          ],
          if (c.checklist.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _Box(
              title: 'Condition & skin',
              child: Column(children: <Widget>[
                for (int i = 0; i < c.checklist.length; i++)
                  _Row(
                    label: c.checklist[i].label,
                    value: c.checklist[i].value,
                    ok: null,
                    last: i == c.checklist.length - 1,
                  ),
              ]),
            ),
          ],
          if ((c.notes ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _Box(
              title: 'Inspector note',
              child: Text(c.notes!.trim(),
                  style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      height: 1.5,
                      color: _muted)),
            ),
          ],
        ]);
  }

  static String _d(DateTime d) {
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
}

class _Box extends StatelessWidget {
  const _Box({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: _h),
              const SizedBox(height: 8),
              child,
            ]),
      );
}

class _Row extends StatelessWidget {
  const _Row(
      {required this.label,
      required this.value,
      required this.ok,
      required this.last});
  final String label;
  final String value;
  final bool? ok;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final Color vc = ok == null ? _ink : (ok! ? _green : _amber);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFEEF0F6)))),
      child:
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Expanded(
            flex: 5,
            child: Text(label,
                style: const TextStyle(
                    fontFamily: 'PlusJakartaSans', fontSize: 13, color: _ink))),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child:
              Row(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
            if (ok != null) ...<Widget>[
              Icon(
                  ok!
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  size: 15,
                  color: vc),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: vc)),
            ),
          ]),
        ),
      ]),
    );
  }
}
