import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show AuctionButton, BottomActionBar, ErrorState, errorText;
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart'
    show formatInr;
import 'package:dealker_vendor/features/repairs/application/repairs_providers.dart';
import 'package:dealker_vendor/features/repairs/data/offer_draft.dart'
    show groupDevices;
import 'package:dealker_vendor/features/repairs/data/repair_models.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/shared/widgets/premium_ui.dart' show A3;

/// "Set your price": the shop quotes this repair itself. Each problem starts at the price in the shop's own price list
/// (green) or is empty (amber) — either way the shop can type any custom amount, then sends it to the customer.
class JobQuoteScreen extends ConsumerStatefulWidget {
  const JobQuoteScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<JobQuoteScreen> createState() => _JobQuoteScreenState();
}

class _Row {
  _Row(this.item, this.issue, this.listPrice, int qty)
      : qty = qty,
        ctrl = TextEditingController(
            text: listPrice == null ? '' : _plain(listPrice));
  final RepairItem item;
  final String issue;
  final num? listPrice; // from the shop's price list, per phone
  final int qty;
  final TextEditingController ctrl;

  num? get price => num.tryParse(ctrl.text.trim());
  bool get fromList => listPrice != null && price == listPrice;
  static String _plain(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
}

class _Extra {
  final desc = TextEditingController();
  final amount = TextEditingController();
}

class _JobQuoteScreenState extends ConsumerState<JobQuoteScreen> {
  List<_Row>? _rows;
  num _taxPct = 18;
  final _extras = <_Extra>[];
  final _note = TextEditingController();
  bool _busy = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final r in _rows ?? const <_Row>[]) {
      r.ctrl.dispose();
    }
    for (final e in _extras) {
      e.desc.dispose();
      e.amount.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(repairsRepositoryProvider);
      final job = await repo.job(widget.id);
      final sq = await repo.jobSuggestedQuote(widget.id);
      final rows = <_Row>[];
      for (final g in groupDevices(job.items)) {
        final issues = g.first.issues.isEmpty ? ['OTHER'] : g.first.issues;
        for (final issue in issues) {
          final mine = sq.lines
              .where((l) => l.itemId == g.first.id && l.issue == issue)
              .fold<num>(0, (a, l) => a + l.amount);
          rows.add(_Row(g.first, issue, mine > 0 ? mine : null, g.qty));
        }
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _taxPct = sq.taxPct ?? 18;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  num get _subtotal {
    var t = 0.0;
    for (final r in _rows ?? const <_Row>[]) {
      t += (r.price ?? 0) * r.qty;
    }
    for (final e in _extras) {
      t += num.tryParse(e.amount.text.trim()) ?? 0;
    }
    return t;
  }

  bool get _ready =>
      (_rows ?? const <_Row>[]).isNotEmpty &&
      _rows!.every((r) => (r.price ?? 0) > 0) &&
      _extras.every((e) =>
          e.amount.text.trim().isEmpty ||
          ((num.tryParse(e.amount.text.trim()) ?? 0) > 0 &&
              e.desc.text.trim().length >= 2));

  Future<void> _send(RepairJob job) async {
    setState(() => _busy = true);
    try {
      final lines = <QuoteLine>[];
      for (final g in groupDevices(job.items)) {
        for (final r in _rows!.where((r) => r.item.id == g.first.id)) {
          for (final it in g.items) {
            lines.add(QuoteLine(
                kind: 'LABOUR',
                description: '${it.name} — ${issueMeta(r.issue).label}',
                qty: 1,
                unitPrice: r.price!,
                itemId: it.id,
                issue: r.issue));
          }
        }
      }
      for (final e in _extras) {
        final a = num.tryParse(e.amount.text.trim());
        if (a != null && a > 0) {
          lines.add(QuoteLine(
              kind: 'OTHER',
              description: e.desc.text.trim(),
              qty: 1,
              unitPrice: a));
        }
      }
      await ref
          .read(repairsRepositoryProvider)
          .sendEstimate(job.id, lines: lines, note: _note.text);
      refreshRepairs(ref, id: job.id);
      if (!mounted) return;
      showAppToast(context, 'Price sent. The customer will approve it.');
      context.go(Routes.repairJob(job.id));
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(jobProvider(widget.id));
    final tax = _subtotal * _taxPct / 100;
    return Scaffold(
      backgroundColor: RC.canvas,
      appBar: RepairAppBar(
          title: 'Set your price',
          subtitle: 'Your own price for each problem',
          art: A3.cart('coupon'),
          onBack: () => context.canPop()
              ? context.pop()
              : context.go(Routes.repairJob(widget.id))),
      body: _loadError != null
          ? ErrorState(
              message: errorText(_loadError!),
              onRetry: () {
                setState(() => _loadError = null);
                _load();
              })
          : _rows == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    const HintBox(
                        'Green prices come from your own price list. Change any price, or type your own when a problem has none. The customer approves the final price.',
                        icon: PhosphorIconsFill.tag),
                    const SizedBox(height: 14),
                    for (final r in _rows!) _priceCard(r),
                    RepairSection(
                      title: 'Other charges',
                      art: A3.cart('receipt'),
                      child: Column(children: [
                        for (var i = 0; i < _extras.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              Expanded(
                                  flex: 5,
                                  child: _field(_extras[i].desc, 'e.g. Screen guard')),
                              const SizedBox(width: 8),
                              Expanded(
                                  flex: 3,
                                  child: _field(_extras[i].amount, '₹',
                                      number: true)),
                              IconButton(
                                  onPressed: () => setState(() {
                                        final e = _extras.removeAt(i);
                                        e.desc.dispose();
                                        e.amount.dispose();
                                      }),
                                  icon: const Icon(PhosphorIconsBold.trash,
                                      size: 19, color: RC.red)),
                            ]),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => _extras.add(_Extra())),
                              icon: const Icon(PhosphorIconsBold.plus, size: 17),
                              label: const Text('Add another charge')),
                        ),
                      ]),
                    ),
                    RepairSection(
                      title: 'Message for the customer',
                      art: A3.profile('chat'),
                      child: TextField(
                        controller: _note,
                        maxLines: 2,
                        maxLength: 300,
                        decoration: InputDecoration(
                          hintText: 'Optional — e.g. Original part, 90 days warranty',
                          hintStyle: const TextStyle(
                              fontSize: 13, color: AppColors.textMuted),
                          counterText: '',
                          filled: true,
                          fillColor: RC.canvas,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: RC.line)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: RC.line)),
                        ),
                      ),
                    ),
                    RepairSection(
                      title: 'Price summary',
                      art: A3.exchange('money'),
                      child: Column(children: [
                        KV('Repairs', formatInr(_subtotal)),
                        KV('GST ${_taxPct.toStringAsFixed(_taxPct % 1 == 0 ? 0 : 1)}%',
                            formatInr(tax)),
                        const Divider(height: 18),
                        KV('Customer pays', formatInr(_subtotal + tax),
                            bold: true, color: RC.blue),
                      ]),
                    ),
                  ],
                ),
      bottomNavigationBar: job.maybeWhen(
        data: (j) => BottomActionBar(
            child: AuctionButton(
                label: 'Send price to customer',
                icon: PhosphorIconsBold.paperPlaneRight,
                loading: _busy,
                onPressed: _ready && _rows != null ? () => _send(j) : null)),
        orElse: () => null,
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {bool number = false}) =>
      TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: number
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: RC.line)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: RC.line)),
        ),
      );

  Widget _priceCard(_Row r) {
    final m = issueMeta(r.issue);
    final listed = r.listPrice != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: (listed ? RC.green : RC.amber).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: RC.blue.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IssueBadge(r.issue, size: 46),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(m.label,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w800)),
                Text(r.qty > 1 ? '${r.item.name} × ${r.qty}' : r.item.name,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
              ])),
          StatusChip(listed ? 'Your price list' : 'Type your price',
              kind: listed ? ChipKind.green : ChipKind.amber),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _field(r.ctrl, listed ? 'Price per phone' : 'Your price per phone ₹',
                number: true),
          ),
          if (listed && !r.fromList) ...[
            const SizedBox(width: 8),
            TextButton(
                onPressed: () => setState(
                    () => r.ctrl.text = _Row._plain(r.listPrice!)),
                child: Text('Use ${formatInr(r.listPrice!)}')),
          ],
        ]),
      ]),
    );
  }
}
