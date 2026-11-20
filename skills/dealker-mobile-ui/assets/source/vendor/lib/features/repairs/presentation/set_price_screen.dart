import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart'
    show AuctionButton, BottomActionBar, ErrorState, errorText;
import 'package:dealker_vendor/features/home/presentation/widgets/home_common.dart';
import 'package:dealker_vendor/features/repairs/application/repairs_providers.dart';
import 'package:dealker_vendor/features/repairs/data/offer_draft.dart';
import 'package:dealker_vendor/features/repairs/data/repair_models.dart';
import 'package:dealker_vendor/features/repairs/presentation/repair_ui.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// "Set Repair Price — device-wise price": tick the repairs you will do and set each price.
/// Pre-filled from the vendor's own price list (or the quote already sent).
class SetPriceScreen extends ConsumerStatefulWidget {
  const SetPriceScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<SetPriceScreen> createState() => _SetPriceScreenState();
}

class _SetPriceScreenState extends ConsumerState<SetPriceScreen> {
  OfferDraft? _draft;
  final int _rev = 0;

  OfferDraft _build(IncomingRequest r, SuggestedQuote? sq) {
    final mine = r.quoted ? r.offer : null;
    final rows = <DraftRow>[];
    for (final it in r.items) {
      for (final issue in it.issues) {
        final fromOffer = mine?.lines
                .where((l) => l.itemId == it.id && l.issue == issue)
                .toList() ??
            const [];
        final fromList = sq?.lines
                .where((l) => l.itemId == it.id && l.issue == issue)
                .toList() ??
            const [];
        final src = fromOffer.isNotEmpty ? fromOffer : fromList;
        final row = DraftRow(
          itemId: it.id,
          deviceName: it.name,
          issue: issue,
          fromPriceList: fromOffer.isEmpty && fromList.isNotEmpty,
          // a quote already sent: an issue it left out stays unticked
          selected: mine == null || fromOffer.isNotEmpty,
        );
        for (final l in src) {
          if (l.kind == 'LABOUR') {
            row.labour += l.amount;
          } else {
            row.parts += l.amount;
          }
        }
        rows.add(row);
      }
    }
    return OfferDraft(
      requestId: r.id,
      rows: rows,
      devices: r.items,
      estMin:
          mine?.estDaysMin ?? ((sq?.estDaysMin ?? 0) > 0 ? sq!.estDaysMin : 1),
      estMax:
          mine?.estDaysMax ?? ((sq?.estDaysMax ?? 0) > 0 ? sq!.estDaysMax : 2),
      warrantyDays: mine?.warrantyDays ?? sq?.warrantyDays ?? 90,
      pickupDelivery: mine?.pickupDelivery ?? true,
      shopVisit: mine?.shopVisit ?? true,
      note: mine?.note ?? '',
      taxPct: mine?.taxPct ?? sq?.taxPct,
    );
  }

  void _next(OfferDraft d) {
    if (d.chosen.isEmpty) {
      showAppToast(context, 'Tick at least one repair and set its price.',
          error: true);
      return;
    }
    if (!d.everyDevicePriced) {
      showAppToast(context, 'Every device needs at least one priced repair.',
          error: true);
      return;
    }
    context.push(Routes.repairOffer(widget.id), extra: d);
  }

  @override
  Widget build(BuildContext context) {
    final req = ref.watch(incomingDetailProvider(widget.id));
    final sq = ref.watch(suggestedQuoteProvider(widget.id));
    return Scaffold(
      backgroundColor: RC.canvas,
      appBar: RepairAppBar(
        title: 'Set Repair Price',
        subtitle: 'Price each repair separately',
        onBack: () =>
            context.canPop() ? context.pop() : context.go(Routes.repairs),
      ),
      body: req.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e, 'This request is no longer open.'),
            onRetry: () => ref.invalidate(incomingDetailProvider(widget.id))),
        data: (r) {
          if (sq.isLoading && _draft == null) {
            return const Center(child: CircularProgressIndicator());
          }
          _draft ??= _build(r, sq.value);
          return _body(r, _draft!, sq.value);
        },
      ),
      bottomNavigationBar: _draft == null
          ? null
          : BottomActionBar(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const Text('Total price',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                  const Spacer(),
                  Text(formatInr(_draft!.subtotal),
                      style: heading(size: 22, color: RC.blue)),
                ]),
                const SizedBox(height: 10),
                AuctionButton(
                    label: 'Save & Continue',
                    icon: PhosphorIconsBold.arrowRight,
                    onPressed: () => _next(_draft!)),
              ]),
            ),
    );
  }

  Widget _body(IncomingRequest r, OfferDraft d, SuggestedQuote? sq) {
    final missing = sq?.missing ?? const [];
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          for (final g in groupDevices(r.items)) ...[
            HomeCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      DeviceThumb(
                          brand: g.first.brand, model: g.first.model, size: 54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.first.name, style: heading(size: 16)),
                              Text(
                                  g.qty > 1
                                      ? 'Price for one phone — applies to all ${g.qty}'
                                      : 'Issues the customer reported',
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textMuted)),
                            ]),
                      ),
                      if (g.qty > 1)
                        StatusChip('× ${g.qty}', icon: PhosphorIconsFill.stack),
                    ]),
                    const Divider(height: 22, color: RC.line),
                    for (final issue in g.first.issues)
                      _PriceRow(
                        key: ValueKey('${g.first.id}-$issue-$_rev'),
                        peers: [
                          for (final it in g.items)
                            d.rows.firstWhere(
                                (x) => x.itemId == it.id && x.issue == issue)
                        ],
                        unlisted: missing.any((m) =>
                                m.itemId == g.first.id && m.issue == issue) &&
                            d.rows
                                    .firstWhere((x) =>
                                        x.itemId == g.first.id &&
                                        x.issue == issue)
                                    .price ==
                                0,
                        onChanged: () => setState(() {}),
                      ),
                  ]),
            ),
            const SizedBox(height: 12),
          ],
          if (d.rows.any((x) => x.fromPriceList))
            const HintBox(
                'Prices marked "from your price list" are filled in for you. You can change any of them.',
                icon: PhosphorIconsFill.tag),
          if (!d.everyDevicePriced && d.rows.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: HintBox(
                  'Every device needs at least one repair with a price.',
                  icon: PhosphorIconsFill.warning,
                  kind: ChipKind.amber),
            ),
        ]);
  }
}

class _PriceRow extends StatefulWidget {
  const _PriceRow(
      {super.key,
      required this.peers,
      required this.unlisted,
      required this.onChanged});
  final List<DraftRow> peers;
  final bool unlisted;
  final VoidCallback onChanged;

  @override
  State<_PriceRow> createState() => _PriceRowState();
}

class _PriceRowState extends State<_PriceRow> {
  DraftRow get row => widget.peers.first;

  void _spread() {
    for (final p in widget.peers.skip(1)) {
      p
        ..selected = row.selected
        ..parts = row.parts
        ..labour = row.labour;
    }
  }

  late final _ctl = TextEditingController(
      text: widget.peers.first.price > 0
          ? widget.peers.first.price
              .toStringAsFixed(widget.peers.first.price % 1 == 0 ? 0 : 2)
          : '');

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = issueMeta(row.issue);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            setState(() => row.selected = !row.selected);
            _spread();
            widget.onChanged();
          },
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: row.selected ? RC.blue : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: row.selected ? RC.blue : AppColors.borderStrong,
                  width: 1.6),
            ),
            child: row.selected
                ? const Icon(PhosphorIconsBold.check,
                    size: 16, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        IssueBadge(row.issue, size: 38),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.label,
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color:
                        row.selected ? AppColors.navy : AppColors.textMuted)),
            if (row.fromPriceList)
              const Text('from your price list',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: RC.green,
                      fontWeight: FontWeight.w600))
            else if (widget.unlisted)
              const Text('type your price',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: RC.amber,
                      fontWeight: FontWeight.w600)),
          ]),
        ),
        SizedBox(
          width: 104,
          child: TextField(
            controller: _ctl,
            enabled: row.selected,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(7)
            ],
            textAlign: TextAlign.end,
            onChanged: (v) {
              row.setPrice(num.tryParse(v) ?? 0);
              _spread();
              widget.onChanged();
            },
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.navy),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary),
              hintText: '0',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              filled: true,
              fillColor: row.selected ? Colors.white : const Color(0xFFF1F3F8),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: RC.line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: RC.blue, width: 1.6)),
              disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: RC.line)),
            ),
          ),
        ),
      ]),
    );
  }
}
