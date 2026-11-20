import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/features/demand/application/demand_providers.dart';
import 'package:dealker_vendor/features/demand/data/demand_models.dart';
import 'package:dealker_vendor/features/demand/presentation/screens/select_sellers_screen.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/demand_common.dart';
import 'package:dealker_vendor/features/demand/presentation/widgets/requirement_blocks.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';

/// One requirement. The buyer who posted it sees the offers and picks sellers; every other
/// vendor sees what the buyer needs and their own offer.
class RequirementScreen extends ConsumerWidget {
  const RequirementScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(requirementDetailProvider(id));
    return detail.when(skipLoadingOnReload: true, skipError: true, 
      loading: () => Scaffold(
        backgroundColor: const Color(0xFFF6F8FE),
        appBar: const AuctionAppBar(title: 'Requirement'),
        body: ListView(padding: const EdgeInsets.all(16), children: const [
          CardSkeleton(height: 130),
          CardSkeleton(height: 200),
          CardSkeleton()
        ]),
      ),
      error: (e, _) => Scaffold(
        appBar: const AuctionAppBar(title: 'Requirement'),
        body: ErrorState(
            message: errorText(e, 'Could not load this requirement.'),
            onRetry: () => ref.invalidate(requirementDetailProvider(id))),
      ),
      data: (d) =>
          d.isBuyer ? SelectSellersScreen(detail: d) : _SellerView(detail: d),
    );
  }
}

class _SellerView extends ConsumerStatefulWidget {
  const _SellerView({required this.detail});
  final RequirementDetail detail;

  @override
  ConsumerState<_SellerView> createState() => _SellerViewState();
}

class _SellerViewState extends ConsumerState<_SellerView> {
  bool _busy = false;

  Requirement get r => widget.detail.requirement;
  Quote? get mine => widget.detail.myQuote;

  Future<void> _respond() async {
    await context.push(Routes.demandOffer(r.id));
    if (!mounted) return;
    refreshDemand(ref);
  }

  Future<void> _notInterested() async {
    final ok = await confirmAction(context,
        title: 'Not interested?',
        message:
            'This requirement will be hidden from your list. The buyer is not told.',
        confirmLabel: 'Hide it');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(demandRepositoryProvider).dismiss(r.id);
      refreshDemand(ref);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(Quote q) async {
    final ok = await confirmAction(context,
        title: 'Withdraw your offer?',
        message:
            'The buyer will no longer see your price. You can send a new offer while the requirement is open.',
        confirmLabel: 'Withdraw',
        danger: true,
        cancelLabel: 'Keep it');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(demandRepositoryProvider).withdrawOffer(q.id);
      refreshDemand(ref);
      if (mounted) showAppToast(context, 'Offer withdrawn.');
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = mine;
    final live = q != null &&
        !const ['WITHDRAWN', 'EXPIRED', 'NOT_SELECTED'].contains(q.status);
    final locked = q != null && q.quantityAwarded > 0;
    final closed = !r.isOpen && q == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: AuctionAppBar(title: 'Requirement Details', subtitle: r.number),
      bottomNavigationBar: closed || locked
          ? null
          : BottomActionBar(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AuctionButton(
                  label: live ? 'Update my offer' : 'View & Respond',
                  icon: live
                      ? PhosphorIconsBold.pencilSimple
                      : PhosphorIconsBold.paperPlaneTilt,
                  loading: _busy,
                  onPressed: r.isOpen ? _respond : null,
                ),
                if (!live) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _busy ? null : _notInterested,
                    child: const Text('Not interested',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            fontSize: 14)),
                  ),
                ],
              ]),
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(requirementDetailProvider(r.id));
          await ref
              .read(requirementDetailProvider(r.id).future)
              .catchError((_) => widget.detail);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (closed)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Notice(
                    icon: PhosphorIconsFill.lockSimple,
                    title: 'This requirement is closed',
                    text:
                        'The buyer has already chosen sellers, cancelled it, or the deadline passed.',
                    color: AppColors.textSecondary,
                    bg: kGreySoft),
              ),
            RequirementHeader(r),
            const SizedBox(height: 12),
            if (q != null) ...[
              _MyOffer(
                  q: q,
                  r: r,
                  orders: widget.detail.orders,
                  busy: _busy,
                  onWithdraw: () => _withdraw(q)),
              const SizedBox(height: 12),
            ],
            RequirementSpecs(r),
            const SizedBox(height: 12),
            if ((r.description ?? '').trim().isNotEmpty) ...[
              RequirementNotes(r),
              const SizedBox(height: 12)
            ],
            BuyerCard(r),
            const SizedBox(height: 12),
            const Notice(
              icon: PhosphorIconsFill.shieldCheck,
              title: 'Safe to sell',
              text:
                  'Buyers pay into Dealkr escrow before you dispatch. The money is released to your wallet when they confirm receipt.',
              color: AppColors.mint,
              bg: AppColors.mintSoft,
            ),
          ],
        ),
      ),
    );
  }
}

/// The seller's own offer: price, status, whether the buyer opened it, and any orders it produced.
class _MyOffer extends StatelessWidget {
  const _MyOffer(
      {required this.q,
      required this.r,
      required this.orders,
      required this.busy,
      required this.onWithdraw});
  final Quote q;
  final Requirement r;
  final List<DemandOrder> orders;
  final bool busy;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final state = q.offerState;
    final accepted =
        state == OfferState.accepted || state == OfferState.partial;
    final live = state == OfferState.pending || state == OfferState.viewed;
    final myOrders =
        orders.where((o) => o.status != OrderStatus.cancelled).toList();
    return Section(
      title: 'Your offer',
      trailing: OfferStatePill(state),
      color: accepted ? const Color(0xFFF4FCF7) : Colors.white,
      border: accepted ? const Color(0xFFBFE8CE) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(formatInr(q.unitPrice),
              style: heading(size: 24, color: kDemandBlue, w: FontWeight.w800)),
          const Text(' /pc',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const Spacer(),
          Text(
              '${pcs(q.quantityOffered)}  ·  ${formatInr(q.unitPrice * q.quantityOffered)}',
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy)),
        ]),
        const SizedBox(height: 8),
        Text(
          [
            conditionLabel(q.condition),
            if (q.deliveryDays != null)
              'Ready in ${q.deliveryDays} day${q.deliveryDays == 1 ? '' : 's'}',
          ].join('  ·  '),
          style:
              const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        if (state == OfferState.viewed)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Row(children: [
              Icon(PhosphorIconsFill.eye, size: 14, color: kDemandBlue),
              SizedBox(width: 5),
              Text('The buyer has opened your offer',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kDemandBlue)),
            ]),
          ),
        if (accepted) ...[
          const SizedBox(height: 10),
          Text(
            state == OfferState.partial
                ? 'The buyer accepted ${q.quantityAwarded} of your ${q.quantityOffered} pieces.'
                : 'The buyer accepted your offer. Dispatch once their payment is in escrow.',
            style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: AppColors.navy),
          ),
          const SizedBox(height: 10),
          for (final o in myOrders)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push(Routes.demandOrder(o.id)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder)),
                child: Row(children: [
                  const Icon(PhosphorIconsFill.package,
                      color: kDemandBlue, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.orderNumber, style: heading(size: 14)),
                          Text('${pcs(o.quantity)} · ${formatInr(o.subtotal)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ]),
                  ),
                  OrderStatusPill(o, buyer: false),
                  const SizedBox(width: 4),
                  const Icon(PhosphorIconsRegular.caretRight,
                      size: 16, color: AppColors.textMuted),
                ]),
              ),
            ),
        ],
        if (live) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: busy ? null : onWithdraw,
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              icon: const Icon(PhosphorIconsRegular.x,
                  size: 15, color: AppColors.rose),
              label: const Text('Withdraw offer',
                  style: TextStyle(
                      color: AppColors.rose, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ]),
    );
  }
}
