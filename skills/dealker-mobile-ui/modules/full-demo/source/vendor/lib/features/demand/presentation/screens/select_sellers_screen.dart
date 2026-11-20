import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/demand/application/demand_providers.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/demand_common.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/requirement_blocks.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

enum _Sort {
  price('Price (low to high)'),
  rating('Seller rating'),
  speed('Fastest delivery');

  const _Sort(this.label);
  final String label;
}

/// The buyer's view of their own requirement: every seller's offer, pick one or several (split the
/// quantity between them), then pay. Once sellers are chosen it also tracks the resulting orders.
class SelectSellersScreen extends ConsumerStatefulWidget {
  const SelectSellersScreen({super.key, required this.detail});
  final RequirementDetail detail;

  @override
  ConsumerState<SelectSellersScreen> createState() =>
      _SelectSellersScreenState();
}

class _SelectSellersScreenState extends ConsumerState<SelectSellersScreen> {
  final _picked = <String, int>{};
  _Sort _sort = _Sort.price;
  bool _busy = false;

  Requirement get r => widget.detail.requirement;
  List<DemandOrder> get _orders => widget.detail.orders
      .where((o) => o.status != OrderStatus.cancelled)
      .toList();

  int get _selectedQty => _picked.values.fold(0, (s, v) => s + v);
  double get _selectedTotal {
    var t = 0.0;
    for (final q in widget.detail.quotes) {
      t += (_picked[q.id] ?? 0) * q.unitPrice;
    }
    return t;
  }

  List<Quote> get _quotes {
    final list =
        widget.detail.quotes.where((q) => q.status != 'WITHDRAWN').toList();
    switch (_sort) {
      case _Sort.price:
        list.sort((a, b) => a.unitPrice.compareTo(b.unitPrice));
      case _Sort.rating:
        list.sort(
            (a, b) => (b.sellerRating ?? 0).compareTo(a.sellerRating ?? 0));
      case _Sort.speed:
        list.sort(
            (a, b) => (a.deliveryDays ?? 99).compareTo(b.deliveryDays ?? 99));
    }
    // Offers that are already ordered sit at the bottom — they cannot be picked again.
    return [
      ...list.where((q) => q.selectable),
      ...list.where((q) => !q.selectable)
    ];
  }

  void _toggle(Quote q) {
    setState(() {
      if (_picked.containsKey(q.id)) {
        _picked.remove(q.id);
      } else {
        final room = r.remaining - _selectedQty;
        if (room <= 0) {
          showAppToast(context,
              'You have already picked all ${r.remaining} pieces. Lower another seller’s quantity first.',
              bottom: 100);
          return;
        }
        _picked[q.id] = q.available < room ? q.available : room;
      }
    });
  }

  int _maxFor(Quote q) {
    final others = _selectedQty - (_picked[q.id] ?? 0);
    final room = r.remaining - others;
    return room < q.available ? room : q.available;
  }

  Future<void> _proceed() async {
    setState(() => _busy = true);
    try {
      await ref.read(demandRepositoryProvider).award(
          r.id, [for (final e in _picked.entries) Selection(e.key, e.value)]);
      if (!mounted) return;
      refreshDemand(ref);
      _picked.clear();
      await context.push(Routes.demandPay(r.id));
      if (mounted) refreshDemand(ref);
    } catch (e) {
      if (mounted) {
        showAppToast(context, errorText(e, 'Could not confirm your sellers.'),
            error: true, bottom: 100);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await confirmAction(context,
        title: 'Cancel this requirement?',
        message:
            'Sellers will stop receiving it and their offers close. Orders that are already paid cannot be cancelled here.',
        confirmLabel: 'Cancel requirement',
        danger: true,
        cancelLabel: 'Keep it');
    if (!ok || !mounted) return;
    try {
      await ref.read(demandRepositoryProvider).cancelRequirement(r.id);
      if (!mounted) return;
      refreshDemand(ref);
      showAppToast(context, 'Requirement cancelled.');
      context.pop();
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unpaid = widget.detail.unpaidOrders;
    final unpaidTotal = unpaid.fold<double>(0, (s, o) => s + o.subtotal);
    final quotes = _quotes;
    final selectable = r.isOpen;
    final showBar = selectable && _picked.isNotEmpty;
    final offers =
        widget.detail.quotes.where((q) => q.status != 'WITHDRAWN').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: AuctionAppBar(
        title: 'Select Sellers',
        subtitle: r.number,
        actions: [
          if (r.status == ReqStatus.open || r.status == ReqStatus.awarded)
            PopupMenuButton<String>(
              icon: const Icon(PhosphorIconsRegular.dotsThreeVertical,
                  color: AppColors.navy),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onSelected: (_) => _cancel(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'cancel', child: Text('Cancel requirement'))
              ],
            ),
        ],
      ),
      bottomNavigationBar: showBar
          ? BottomActionBar(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(
                    child: Text('Selected $_selectedQty of ${r.remaining} pcs',
                        style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text(formatInr(_selectedTotal),
                      style: heading(size: 19, w: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                AuctionButton(
                  label: 'Select & Proceed (${_picked.length})',
                  trailing: PhosphorIconsBold.arrowRight,
                  loading: _busy,
                  onPressed: _proceed,
                ),
              ]),
            )
          : (unpaid.isNotEmpty
              ? BottomActionBar(
                  child: AuctionButton(
                      label: 'Pay ${formatInr(unpaidTotal)}',
                      icon: PhosphorIconsBold.lockKey,
                      onPressed: () async {
                        await context.push(Routes.demandPay(r.id));
                        if (mounted) refreshDemand(ref);
                      }),
                )
              : null),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(requirementDetailProvider(r.id));
          await ref
              .read(requirementDetailProvider(r.id).future)
              .catchError((_) => widget.detail);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, showBar ? 24 : 32),
          children: [
            RequirementHeader(r, showStatus: true),
            const SizedBox(height: 12),
            if (unpaid.isNotEmpty) ...[
              Notice(
                icon: PhosphorIconsFill.hourglassMedium,
                title: 'Payment pending',
                text:
                    'You picked ${unpaid.length} seller${unpaid.length == 1 ? '' : 's'}. Pay ${formatInr(unpaidTotal)} to confirm — the money is held safely until you receive the order.',
                color: kAmberText,
                bg: AppColors.amberSoft,
              ),
              const SizedBox(height: 12),
            ],
            if (_orders.isNotEmpty) ...[
              _OrdersBlock(orders: _orders),
              const SizedBox(height: 12),
            ],
            if (selectable) ...[
              Row(children: [
                Expanded(
                  child: Text(
                      offers == 0
                          ? 'No offers yet'
                          : '$offers seller${offers == 1 ? ' has' : 's have'} responded',
                      style: heading(size: 16.5)),
                ),
                if (offers > 1)
                  _SortMenu(
                      sort: _sort, onChanged: (s) => setState(() => _sort = s)),
              ]),
              const SizedBox(height: 4),
              Text(
                  offers == 0
                      ? '${closesIn(r.responseDeadline)}. Matching sellers have been alerted — offers appear here as they arrive.'
                      : 'Pick one seller, or split the ${r.remaining} pieces between several. ${closesIn(r.responseDeadline)}.',
                  style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: AppColors.textMuted)),
              const SizedBox(height: 12),
              if (quotes.isEmpty)
                const EmptyState(
                  icon: PhosphorIconsRegular.hourglassMedium,
                  title: 'Waiting for offers',
                  message:
                      'Sellers who hold this model have been notified. Pull down to check for new offers.',
                ),
              for (final q in quotes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _QuoteCard(
                    q: q,
                    picked: _picked[q.id],
                    max: _maxFor(q),
                    bestPrice: quotes.isEmpty
                        ? null
                        : quotes
                            .map((x) => x.unitPrice)
                            .reduce((a, b) => a < b ? a : b),
                    onToggle: q.selectable ? () => _toggle(q) : null,
                    onQty: (v) => setState(() => _picked[q.id] = v),
                  ),
                ),
              if (r.quantityAwarded > 0)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                      'Offers already used for your earlier picks are not shown again.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
            ],
            if (!selectable && _orders.isEmpty)
              const EmptyState(
                icon: PhosphorIconsRegular.lockSimple,
                title: 'This requirement is closed',
                message:
                    'It was cancelled or expired before any seller was picked.',
              ),
          ],
        ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort, required this.onChanged});
  final _Sort sort;
  final ValueChanged<_Sort> onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_Sort>(
        initialValue: sort,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: onChanged,
        itemBuilder: (_) => [
          for (final s in _Sort.values)
            PopupMenuItem(value: s, child: Text(s.label))
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(PhosphorIconsRegular.sortAscending,
                size: 16, color: kDemandBlue),
            const SizedBox(width: 5),
            Text(
                sort == _Sort.price
                    ? 'Price'
                    : (sort == _Sort.rating ? 'Rating' : 'Speed'),
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
            const Icon(PhosphorIconsRegular.caretDown,
                size: 13, color: AppColors.textSecondary),
          ]),
        ),
      );
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard(
      {required this.q,
      required this.picked,
      required this.max,
      required this.bestPrice,
      required this.onToggle,
      required this.onQty});
  final Quote q;
  final int? picked;
  final int max;
  final double? bestPrice;
  final VoidCallback? onToggle;
  final ValueChanged<int> onQty;

  @override
  Widget build(BuildContext context) {
    final on = picked != null;
    final best = bestPrice != null && q.unitPrice == bestPrice;
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? const Color(0xFFF3F8FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: on ? kDemandBlue : AppColors.cardBorder,
              width: on ? 1.6 : 1),
        ),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Initials(q.sellerName, size: 46),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                          child: Text(q.sellerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: heading(size: 15.5))),
                      if (best) ...[
                        const SizedBox(width: 6),
                        const Pill('Best price',
                            fg: AppColors.mint, bg: AppColors.mintSoft),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      StarRating(q.sellerRating),
                      if (q.sellerCity != null)
                        Text('  ·  ${q.sellerCity}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      if (q.sellerCompleted > 0)
                        Text('  ·  ${q.sellerCompleted} orders',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                    ]),
                  ]),
            ),
            if (onToggle != null)
              Icon(
                  on
                      ? PhosphorIconsFill.checkSquare
                      : PhosphorIconsRegular.square,
                  color: on ? kDemandBlue : AppColors.borderStrong,
                  size: 26)
            else if (q.quantityAwarded > 0)
              const Pill('Ordered',
                  fg: AppColors.mint,
                  bg: AppColors.mintSoft,
                  icon: PhosphorIconsFill.checkCircle),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: pcs(
                          q.available > 0 ? q.available : q.quantityAwarded),
                      style: heading(size: 14.5, w: FontWeight.w800)),
                  TextSpan(
                      text: q.available > 0 ? ' available' : ' ordered',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ]),
                style: const TextStyle(fontSize: 13)),
            const Spacer(),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: formatInr(q.unitPrice),
                  style: heading(
                      size: 18.5, color: kDemandBlue, w: FontWeight.w800)),
              const TextSpan(
                  text: ' /pc',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ])),
          ]),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(spacing: 6, runSpacing: 5, children: [
              Pill(conditionLabel(q.condition),
                  fg: AppColors.textSecondary, bg: kGreySoft),
              if (q.deliveryDays != null)
                Pill('Ready in ${q.deliveryDays}d',
                    fg: AppColors.textSecondary,
                    bg: kGreySoft,
                    icon: PhosphorIconsRegular.truck),
            ]),
          ),
          if ((q.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('“${q.note}”',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary))),
          ],
          if (on) ...[
            const Divider(height: 22, color: AppColors.cardBorder),
            Row(children: [
              const Text('Take',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              const SizedBox(width: 10),
              QtyStepper(
                  value: picked!,
                  min: 1,
                  max: max < 1 ? 1 : max,
                  compact: true,
                  onChanged: onQty),
              const Spacer(),
              Text(formatInr(picked! * q.unitPrice),
                  style: heading(size: 16, w: FontWeight.w800)),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Orders already created from this requirement (paid or awaiting payment).
class _OrdersBlock extends StatelessWidget {
  const _OrdersBlock({required this.orders});
  final List<DemandOrder> orders;

  @override
  Widget build(BuildContext context) => Section(
        title: 'Your orders',
        child: Column(children: [
          for (final o in orders)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push(Routes.demandOrder(o.id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Initials(o.sellerName, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.sellerName, style: heading(size: 14.5)),
                          Text(
                              '${pcs(o.quantity)} × ${formatInr(o.unitPrice)}  ·  ${o.orderNumber}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(formatInr(o.subtotal),
                        style: heading(size: 14.5, w: FontWeight.w800)),
                    const SizedBox(height: 3),
                    OrderStatusPill(o, buyer: true),
                  ]),
                ]),
              ),
            ),
        ]),
      );
}
