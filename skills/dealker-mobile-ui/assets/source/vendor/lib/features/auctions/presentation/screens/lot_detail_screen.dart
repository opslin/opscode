import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_media_view.dart';
import 'package:dealker_vendor/shared/widgets/app_toast.dart';
import 'package:dealker_vendor/core/utils/polling.dart';

/// Bidder view of another vendor's B2B lot: register (pay the fee), then bid.
/// Bidding is proxy-style — the amount entered is the MAXIMUM; the server only
/// raises the price as far as needed to keep the bidder in the lead.
class LotDetailScreen extends ConsumerStatefulWidget {
  const LotDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<LotDetailScreen> createState() => _LotDetailScreenState();
}

class _LotDetailScreenState extends ConsumerState<LotDetailScreen> {
  Timer? _poll;
  final _bid = TextEditingController();
  bool _busy = false;
  num? _seededFor; // min-next-bid the field was last seeded from

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !screenActive(context)) return;
      if (ref.read(lotProvider(widget.id)).value?.isLive == true) _refresh();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _bid.dispose();
    super.dispose();
  }

  void _refresh() {
    ref
      ..invalidate(lotProvider(widget.id))
      ..invalidate(lotBidsProvider(widget.id));
  }

  /// Keeps the field at the current minimum unless the user typed something higher.
  void _seed(LotView l) {
    final min = l.minNextBid;
    if (min == null || _seededFor == min) return;
    final typed = num.tryParse(_bid.text) ?? 0;
    if (typed < min) _bid.text = '${min.toInt()}';
    _seededFor = min;
  }

  Future<void> _register(LotView l) async {
    final consent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => _ConsentSheet(lot: l),
    );
    if (consent != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(auctionRepositoryProvider).register(l.id);
      _refresh();
      if (mounted) showAppToast(context, 'You are registered. Place your bid!');
    } catch (e) {
      if (!mounted) return;
      if (errorText(e).toLowerCase().contains('wallet')) {
        // Short of wallet money: offer the transfer instead of a dead-end error.
        final go = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Add money to your wallet'),
            content: Text(
                '${errorText(e)}\n\nYou can move money from your sales earnings into your Dealkr wallet instantly.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Not now')),
              TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Open wallet')),
            ],
          ),
        );
        if (go == true && mounted) context.push(Routes.wallet);
      } else {
        showAppToast(context, errorText(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Winners pay in the Cart (same checkout as wholesale): the lot is already waiting there.
  Future<void> _pay(LotView l) async {
    ref.read(dismissedWinsProvider.notifier).restore(l.id); // pay = back in the cart
    await context.push(Routes.wholesaleCart);
    if (mounted) _refresh();
  }

  Future<void> _placeBid(LotView l) async {
    final amount = num.tryParse(_bid.text.trim());
    final min = l.minNextBid;
    if (amount == null || (min != null && amount < min)) {
      showAppToast(
          context, 'Enter at least ${formatInr(min ?? l.startPrice)} to bid.',
          error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ref.read(auctionRepositoryProvider).placeBid(l.id, amount);
      _seededFor = null;
      _refresh();
      if (mounted) showAppToast(context, 'Bid placed.');
    } catch (e) {
      if (mounted) showAppToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lot = ref.watch(lotProvider(widget.id));
    final bids = ref.watch(lotBidsProvider(widget.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: AuctionAppBar(
        title: 'Lot Details',
        onBack: () =>
            context.canPop() ? context.pop() : context.go('/auctions'),
      ),
      body: lot.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e, 'Could not load this lot.'),
            onRetry: _refresh),
        data: (l) {
          _seed(l);
          return Column(children: [
            Expanded(
              child: RefreshIndicator(
                color: kAuctionBlue,
                onRefresh: () async {
                  _refresh();
                  await ref.read(lotProvider(widget.id).future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _Header(l),
                    const SizedBox(height: 12),
                    HomeCard(
                      padding: const EdgeInsets.all(12),
                      child: AuctionMediaView(
                          images: l.images.isNotEmpty
                              ? l.images
                              : [if (l.cover != null) l.cover!],
                          videoUrl: l.videoUrl,
                          qc: l.qc),
                    ),
                    const SizedBox(height: 12),
                    _PriceCard(l),
                    const SizedBox(height: 12),
                    if (l.my.registered) _Standing(l),
                    if (l.my.registered) const SizedBox(height: 12),
                    if (l.description.isNotEmpty) ...[
                      HomeCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('About this lot', style: heading(size: 15)),
                              const SizedBox(height: 6),
                              Text(l.description,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      height: 1.45,
                                      color: AppColors.textSecondary)),
                            ]),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text('Bids', style: heading(size: 17)),
                    const SizedBox(height: 10),
                    bids.when(skipLoadingOnReload: true, skipError: true, 
                      loading: () => const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator())),
                      error: (e, _) => Text(errorText(e),
                          style: const TextStyle(color: AppColors.rose)),
                      data: (list) => list.isEmpty
                          ? const HomeCard(
                              child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                  child: Text('No bids yet — be the first.',
                                      style: TextStyle(
                                          color: AppColors.textMuted))),
                            ))
                          : HomeCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              child: Column(children: [
                                for (final (i, b) in list.take(20).indexed) ...[
                                  if (i > 0)
                                    const Divider(
                                        height: 1, color: AppColors.cardBorder),
                                  _BidRow(b, leading: i == 0 && l.isLive),
                                ],
                              ]),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            _BottomBar(
              lot: l,
              busy: _busy,
              controller: _bid,
              onRegister: () => _register(l),
              onBid: () => _placeBid(l),
              onPay: () => _pay(l),
              onChanged: () => setState(() {}),
            ),
          ]);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.l);
  final LotView l;

  @override
  Widget build(BuildContext context) => HomeCard(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ProductThumb(l.cover, size: 74),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: AppColors.navy)),
              const SizedBox(height: 7),
              Wrap(spacing: 7, runSpacing: 5, children: [
                const AudienceChip(AuctionAudience.b2b),
                StatusPill(l.status),
              ]),
              const SizedBox(height: 7),
              Text('${unitsLabel(l.quantity)} · Sold by ${l.sellerName}',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textMuted)),
            ]),
          ),
        ]),
      );
}

class _PriceCard extends StatelessWidget {
  const _PriceCard(this.l);
  final LotView l;

  @override
  Widget build(BuildContext context) {
    final ended = !l.isLive && !l.isUpcoming;
    return HomeCard(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        if (!ended) ...[
          Text(l.isLive ? 'Auction Ends In' : 'Auction Starts In',
              style: heading(size: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          CountdownBoxes(
              endsAt: l.isLive ? l.endsAt : l.startsAt, offset: l.serverOffset),
          const SizedBox(height: 16),
        ],
        Row(children: [
          Expanded(
            child: Column(children: [
              Text(
                  ended && l.finalPrice != null
                      ? 'Final price'
                      : 'Current highest bid',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 3),
              Text(formatInr(l.finalPrice ?? l.currentPrice),
                  style: heading(
                      size: 24, color: kAuctionBlue, w: FontWeight.w800)),
              if (l.unitPrice != null)
                Text('≈ ${formatInr(l.unitPrice!)} / unit',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
          Container(width: 1, height: 52, color: AppColors.cardBorder),
          Expanded(
            child: Column(children: [
              const Text('Bids',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 3),
              Text('${l.bidCount}', style: heading(size: 22)),
              Text('${l.bidderCount} bidders',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
        ]),
        if (l.reserveStatus != 'NONE') ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: l.reserveStatus == 'MET'
                    ? AppColors.mintSoft
                    : AppColors.amberSoft,
                borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  l.reserveStatus == 'MET'
                      ? PhosphorIconsFill.checkCircle
                      : PhosphorIconsFill.info,
                  size: 16,
                  color: l.reserveStatus == 'MET'
                      ? AppColors.mint
                      : const Color(0xFFB45309)),
              const SizedBox(width: 7),
              Text(
                  l.reserveStatus == 'MET'
                      ? 'Reserve met'
                      : 'Reserve not met yet',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: l.reserveStatus == 'MET'
                          ? AppColors.mint
                          : const Color(0xFFB45309))),
            ]),
          ),
        ],
      ]),
    );
  }
}

String _orderLabel(String? s) => switch (s) {
      'ORDER_PLACED' => 'paid, waiting for the seller to confirm',
      'CONFIRMED' => 'confirmed by the seller',
      'PACKED' || 'READY_TO_SHIP' => 'packed, ready to ship',
      'SHIPPED' || 'OUT_FOR_DELIVERY' => 'on its way',
      'DELIVERED' => 'delivered',
      'CANCELLED' => 'cancelled',
      _ => 'processing',
    };

class _Standing extends StatelessWidget {
  const _Standing(this.l);
  final LotView l;

  @override
  Widget build(BuildContext context) {
    final my = l.my;
    if (my.isWinner && my.orderId == null && l.status == 'AWAITING_PAYMENT') {
      final due = my.amountDue ?? l.finalPrice ?? l.currentPrice;
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF001F5F), Color(0xFF1F6FEB), Color(0xFF5B4BEA)]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('YOU WON THIS LOT',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70)),
              const SizedBox(height: 4),
              Text('Pay ${formatInr(due)} to claim it',
                  style: heading(size: 19, color: Colors.white, w: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                  my.paymentDeadline == null
                      ? 'Complete payment in your cart.'
                      : 'Pay before ${formatDateTime(my.paymentDeadline)}.',
                  style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
            ]),
          ),
          Image.asset('assets/3d/auction/trophy.png', height: 78),
        ]),
      );
    }
    final (icon, color, bg, text) = my.isWinner
        ? (
            PhosphorIconsFill.trophy,
            AppColors.mint,
            AppColors.mintSoft,
            my.orderId != null
                ? 'You won this lot. Order ${my.orderNumber ?? ''} · ${_orderLabel(my.orderStatus)}.'
                : 'You won this lot${my.amountDue != null ? ' — pay ${formatInr(my.amountDue!)}' : ''}.'
          )
        : my.isLeading
            ? (
                PhosphorIconsFill.crown,
                AppColors.mint,
                AppColors.mintSoft,
                'You are leading${my.myMax != null ? ' · your max ${formatInr(my.myMax!)}' : ''}.'
              )
            : (
                PhosphorIconsFill.checkCircle,
                kAuctionBlue,
                kAuctionBlueSoft,
                l.bidCount > 0 && (my.myMax ?? 0) > 0
                    ? 'You have been outbid. Raise your bid to get back in the lead.'
                    : 'You are registered. Place your bid below.'
              );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: color))),
      ]),
    );
  }
}

class _BidRow extends StatelessWidget {
  const _BidRow(this.b, {required this.leading});
  final BidEntry b;
  final bool leading;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: leading ? AppColors.mintSoft : const Color(0xFFF1F4FB),
                shape: BoxShape.circle),
            child: Icon(
                leading ? PhosphorIconsFill.crown : PhosphorIconsRegular.user,
                size: 17,
                color: leading ? AppColors.mint : AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(b.isYou ? 'You' : b.displayName,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: b.isYou ? kAuctionBlue : AppColors.navy)),
                if (b.isYou)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: kAuctionBlueSoft,
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(b.alias,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: kAuctionBlue)),
                  ),
              ]),
              Text(timeAgo(b.at),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted)),
            ]),
          ),
          Text(formatInr(b.amount),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: leading ? AppColors.mint : AppColors.navy)),
        ]),
      );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.lot,
    required this.busy,
    required this.controller,
    required this.onRegister,
    required this.onBid,
    required this.onPay,
    required this.onChanged,
  });
  final LotView lot;
  final bool busy;
  final TextEditingController controller;
  final VoidCallback onRegister;
  final VoidCallback onBid;
  final VoidCallback onPay;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = lot;
    // The winner of a finished lot pays from here (wallet) and then follows the order.
    if (l.my.isWinner &&
        l.status == 'AWAITING_PAYMENT' &&
        l.my.orderId == null) {
      return BottomActionBar(
        child: AuctionButton(
            label: 'Pay ${formatInr(l.my.amountDue ?? l.finalPrice ?? 0)} · Go to cart',
            icon: PhosphorIconsFill.shoppingCart,
            loading: busy,
            onPressed: onPay),
      );
    }
    if (!l.isLive && !l.isUpcoming) return const SizedBox.shrink();

    if (!l.my.registered) {
      return BottomActionBar(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (l.feePolicy.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(l.feePolicy,
                  style: const TextStyle(
                      fontSize: 12, height: 1.4, color: AppColors.textMuted)),
            ),
          AuctionButton(
              label: l.registrationFee > 0
                  ? 'Register · ${formatInr(l.registrationFee)} fee'
                  : 'Register for free',
              loading: busy,
              onPressed: onRegister),
        ]),
      );
    }

    if (l.isUpcoming) {
      return BottomActionBar(
          child: const Text('Bidding opens when the lot goes live.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)));
    }

    final min = l.minNextBid ?? l.startPrice;
    return BottomActionBar(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Expanded(
              child: Text('Your maximum bid',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy))),
          Text('Min ${formatInr(min)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy),
              decoration: InputDecoration(
                prefixText: '₹ ',
                isDense: true,
                filled: true,
                fillColor: kAuctionBlueSoft,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
              width: 130,
              child: AuctionButton(
                  label: 'Place Bid', loading: busy, onPressed: onBid)),
        ]),
        const SizedBox(height: 8),
        const Text(
            'We bid for you only as much as needed to keep you in the lead, up to your maximum.',
            style: TextStyle(
                fontSize: 11.5, height: 1.35, color: AppColors.textMuted)),
      ]),
    );
  }
}

class _ConsentSheet extends ConsumerStatefulWidget {
  const _ConsentSheet({required this.lot});
  final LotView lot;

  @override
  ConsumerState<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends ConsumerState<_ConsentSheet> {
  bool _agree = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.lot;
    final consent = ref.watch(consentTextProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 14),
          Align(
              alignment: Alignment.centerLeft,
              child: Text('Join this lot', style: heading(size: 19))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: kAuctionBlueSoft,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Expanded(
                  child: Text('Registration fee',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: AppColors.navy))),
              Text(formatInr(l.registrationFee),
                  style: heading(
                      size: 18, color: kAuctionBlue, w: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 12),
          Text(l.feePolicy.isNotEmpty ? l.feePolicy : (consent.value ?? ''),
              style: const TextStyle(
                  fontSize: 13, height: 1.45, color: AppColors.textSecondary)),
          if (l.feePolicy.isNotEmpty && (consent.value ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(consent.value!,
                style: const TextStyle(
                    fontSize: 12, height: 1.4, color: AppColors.textMuted)),
          ],
          const SizedBox(height: 10),
          InkWell(
            onTap: () => setState(() => _agree = !_agree),
            child: Row(children: [
              Checkbox(
                  value: _agree,
                  activeColor: kAuctionBlue,
                  onChanged: (v) => setState(() => _agree = v ?? false)),
              const Expanded(
                  child: Text('I agree to the registration terms.',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 8),
          AuctionButton(
              label: 'Pay ${formatInr(l.registrationFee)} & Register',
              onPressed: _agree ? () => Navigator.pop(context, true) : null),
        ]),
      ),
    );
  }
}
