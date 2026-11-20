import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/demand/application/demand_providers.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/demand_common.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

const _conditions = [
  'NEW',
  'OPEN_BOX',
  'REFURBISHED',
  'USED_LIKE_NEW',
  'USED_GOOD',
  'USED_FAIR'
];
const _leadDays = [1, 2, 3, 5, 7];

/// "Matching Inventory" → "Send Offer": the seller sees which of their listings fit the requirement,
/// how many they can supply, and sends a price + quantity (partial supply is fine).
class OfferScreen extends ConsumerWidget {
  const OfferScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(requirementDetailProvider(id));
    final match = ref.watch(matchProvider(id));
    final err = detail.error ?? match.error;
    if (err != null) {
      return Scaffold(
        appBar: const AuctionAppBar(title: 'Send Offer'),
        body: ErrorState(
          message: errorText(err, 'Could not load your matching stock.'),
          onRetry: () {
            ref
              ..invalidate(requirementDetailProvider(id))
              ..invalidate(matchProvider(id));
          },
        ),
      );
    }
    if (!detail.hasValue || !match.hasValue) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F8FE),
        appBar: const AuctionAppBar(title: 'Send Offer'),
        body: ListView(padding: const EdgeInsets.all(16), children: const [
          CardSkeleton(height: 90),
          CardSkeleton(height: 120),
          CardSkeleton(height: 260)
        ]),
      );
    }
    return _OfferForm(
        r: detail.requireValue.requirement, match: match.requireValue);
  }
}

class _OfferForm extends ConsumerStatefulWidget {
  const _OfferForm({required this.r, required this.match});
  final Requirement r;
  final MatchResult match;

  @override
  ConsumerState<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends ConsumerState<_OfferForm> {
  late String _price;
  late int _qty;
  late String _condition;
  late int _days;
  late String _note;
  String? _listingId;
  bool _busy = false;

  Requirement get r => widget.r;
  MatchResult get m => widget.match;
  bool get _editing => m.myQuote != null && m.myQuote!.status != 'WITHDRAWN';

  @override
  void initState() {
    super.initState();
    final mine = _editing ? m.myQuote : null;
    final s = m.suggested;
    _price = mine != null
        ? _fmt(mine.unitPrice)
        : (s != null ? _fmt(s.unitPrice) : '');
    _qty = mine?.quantityOffered ?? s?.quantity ?? 1;
    _condition = mine?.condition ?? s?.condition ?? 'NEW';
    _days = mine?.deliveryDays ?? 2;
    _note = mine?.note ?? '';
    _listingId = s?.listingId;
    if (_qty > m.remaining && m.remaining > 0) _qty = m.remaining;
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);

  double? get _unit => double.tryParse(_price.replaceAll(',', ''));
  double get _total => (_unit ?? 0) * _qty;
  double get _commission => _total * m.commissionPercent / 100;

  void _pick(MatchListing l) {
    setState(() {
      _listingId = l.id;
      _price = _fmt(l.suggestedPrice);
      _condition = l.condition ?? _condition;
      final cap = l.stock < m.remaining ? l.stock : m.remaining;
      _qty = cap < 1 ? 1 : cap;
    });
  }

  String? _problem() {
    final u = _unit;
    if (u == null || u <= 0) return 'Enter your price per piece.';
    if (_qty < 1) return 'Offer at least 1 piece.';
    if (_qty > m.remaining) return 'The buyer only needs ${m.remaining} more.';
    return null;
  }

  Future<void> _send() async {
    final p = _problem();
    if (p != null) {
      showAppToast(context, p, error: true, bottom: 90);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(demandRepositoryProvider).sendOffer(r.id, {
        'quantity': _qty,
        'unitPrice': _unit,
        'condition': _condition,
        'deliveryDays': _days,
        if (_note.trim().isNotEmpty) 'note': _note.trim(),
        if (_listingId != null) 'listingId': _listingId,
      });
      if (!mounted) return;
      refreshDemand(ref);
      showAppToast(
          context,
          _editing
              ? 'Offer updated — the buyer will see the new price.'
              : 'Offer sent! Track the buyer’s response in My Offers.');
      context.go(Routes.demandTab('offers'));
    } catch (e) {
      if (mounted) {
        showAppToast(context, errorText(e, 'Could not send your offer.'),
            error: true, bottom: 90);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = priceRange(r);
    final unit = _unit;
    final aboveBudget =
        unit != null && r.targetPriceMax != null && unit > r.targetPriceMax!;
    final stock = m.totalStock;
    final selected = m.listings.where((l) => l.id == _listingId).firstOrNull;
    final heldStock = selected?.stock ?? stock;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: AuctionAppBar(
          title: _editing ? 'Update Offer' : 'Send Offer',
          subtitle: requirementTitle(r)),
      bottomNavigationBar: BottomActionBar(
        child: AuctionButton(
          label: _editing ? 'Update offer' : 'Send offer',
          icon: PhosphorIconsBold.paperPlaneTilt,
          loading: _busy,
          onPressed: _send,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _MatchBanner(match: m),
          const SizedBox(height: 12),
          if (m.listings.isNotEmpty) ...[
            for (final l in m.listings.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ListingTile(
                    l: l, selected: l.id == _listingId, onTap: () => _pick(l)),
              ),
            const SizedBox(height: 2),
          ],
          Section(
            child: Column(children: [
              KV('Requirement needed', pcs(r.remaining), bold: true),
              if (price != null) KV('Buyer’s target (per pc)', price),
              if (r.minBattery != null) KV('Battery', '${r.minBattery}%+'),
            ]),
          ),
          const SizedBox(height: 12),
          Section(
            title: 'Your offer',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('Your offer price (per pc)'),
              AuctionField(
                fieldKey: ValueKey('price-$_listingId'),
                initial: _price,
                prefix: '₹',
                hint: 'e.g. 29500',
                number: true,
                maxLength: 9,
                onChanged: (v) => setState(() => _price = v),
              ),
              if (aboveBudget)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Notice(
                      icon: PhosphorIconsFill.warning,
                      text:
                          'This is above the buyer’s maximum price — they may pick a cheaper seller.',
                      color: kAmberText,
                      bg: AppColors.amberSoft),
                ),
              const SizedBox(height: 16),
              const FieldLabel('Quantity you can supply'),
              Row(children: [
                QtyStepper(
                    value: _qty,
                    min: 1,
                    max: m.remaining < 1 ? 1 : m.remaining,
                    onChanged: (v) => setState(() => _qty = v)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('of ${r.remaining} needed',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                ),
              ]),
              const SizedBox(height: 8),
              if (stock > 0)
                Notice(
                  icon: PhosphorIconsFill.package,
                  text: _qty <= heldStock
                      ? 'You can supply ${pcs(_qty)} (out of ${r.remaining}) from your stock of ${pcs(heldStock)}.'
                      : 'You hold ${pcs(heldStock)} — the other ${_qty - heldStock} must come from elsewhere, so only promise what you can deliver.',
                  color: _qty <= heldStock ? kDemandBlue : kAmberText,
                  bg: _qty <= heldStock ? kDemandBlueSoft : AppColors.amberSoft,
                )
              else
                const Notice(
                    icon: PhosphorIconsFill.info,
                    text:
                        'This item is not in your stock. Offer only what you can source and deliver on time.',
                    color: kAmberText,
                    bg: AppColors.amberSoft),
              const SizedBox(height: 16),
              const FieldLabel('Condition of the pieces'),
              ChoiceChips<String>(
                  options: _conditions,
                  value: _condition,
                  label: conditionLabel,
                  onChanged: (v) => setState(() => _condition = v)),
              const SizedBox(height: 16),
              const FieldLabel('Ready to hand over in'),
              ChoiceChips<int>(
                  options: _leadDays,
                  value: _days,
                  label: (d) => d == 1 ? '1 day' : '$d days',
                  onChanged: (v) => setState(() => _days = v)),
              const SizedBox(height: 16),
              const FieldLabel('Note for the buyer', optional: true),
              AuctionField(
                  initial: _note,
                  maxLines: 3,
                  maxLength: 300,
                  hint: 'Box, bill, warranty, grading…',
                  onChanged: (v) => _note = v),
            ]),
          ),
          const SizedBox(height: 12),
          Section(
            title: 'What you earn',
            child: Column(children: [
              KV('Offer value (${pcs(_qty)})', formatInr(_total)),
              KV('Dealkr fee (${m.commissionPercent.toStringAsFixed(m.commissionPercent == m.commissionPercent.roundToDouble() ? 0 : 1)}%)',
                  '− ${formatInr(_commission)}'),
              const Divider(height: 18, color: AppColors.cardBorder),
              KV('You receive', formatInr(_total - _commission),
                  bold: true, valueColor: AppColors.mint),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                    'Paid into your wallet once the buyer confirms they received the order.',
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textMuted)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _MatchBanner extends StatelessWidget {
  const _MatchBanner({required this.match});
  final MatchResult match;

  @override
  Widget build(BuildContext context) {
    switch (match.level) {
      case MatchLevel.exact:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.mintSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFE8CE)),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: AppColors.mint, shape: BoxShape.circle),
              child: const Icon(PhosphorIconsBold.check,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Match found!',
                        style: heading(
                            size: 18,
                            color: const Color(0xFF0B6B33),
                            w: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                        'Your inventory matches this requirement — you have ${pcs(match.totalStock)} in stock.',
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: AppColors.textSecondary)),
                  ]),
            ),
          ]),
        );
      case MatchLevel.close:
        return const Notice(
          icon: PhosphorIconsFill.info,
          title: 'Similar stock found',
          text:
              'You hold this model, but the storage or battery differs from what the buyer asked for. You can still offer it — mention the difference in your note.',
          color: kAmberText,
          bg: AppColors.amberSoft,
        );
      case MatchLevel.none:
        return const Notice(
          icon: PhosphorIconsFill.magnifyingGlass,
          title: 'No matching stock',
          text:
              'This model is not in your catalogue. You can still send an offer if you can source it in time.',
        );
    }
  }
}

class _ListingTile extends StatelessWidget {
  const _ListingTile(
      {required this.l, required this.selected, required this.onTap});
  final MatchListing l;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? kDemandBlue : AppColors.cardBorder,
                width: selected ? 1.6 : 1),
          ),
          child: Row(children: [
            ProductThumb(l.thumbnail, size: 60, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: heading(size: 14.5)),
                    const SizedBox(height: 5),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      Pill(conditionLabel(l.condition),
                          fg: AppColors.textSecondary, bg: kGreySoft),
                      if (l.battery != null)
                        Pill('Battery ${l.battery}%',
                            fg: AppColors.textSecondary, bg: kGreySoft),
                      if (l.level == MatchLevel.close)
                        const Pill('Different spec',
                            fg: kAmberText, bg: AppColors.amberSoft),
                    ]),
                    const SizedBox(height: 5),
                    Text.rich(
                        TextSpan(children: [
                          const TextSpan(
                              text: 'You have: ',
                              style: TextStyle(color: AppColors.textSecondary)),
                          TextSpan(
                              text: pcs(l.stock),
                              style: heading(
                                  size: 14,
                                  color: kDemandBlue,
                                  w: FontWeight.w800)),
                          TextSpan(
                              text: '   ·   ${formatInr(l.suggestedPrice)}/pc',
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                        ]),
                        style: const TextStyle(fontSize: 13)),
                  ]),
            ),
            Icon(
                selected
                    ? PhosphorIconsFill.checkCircle
                    : PhosphorIconsRegular.circle,
                color: selected ? kDemandBlue : AppColors.borderStrong,
                size: 24),
          ]),
        ),
      );
}
