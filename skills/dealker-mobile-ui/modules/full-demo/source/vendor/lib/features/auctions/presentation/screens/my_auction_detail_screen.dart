import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/core/theme/app_colors.dart';
import 'package:dealker_vendor/routing/route_names.dart';
import 'package:dealker_vendor/features/auctions/application/auction_providers.dart';
import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/auctions/presentation/screens/auctions_hub_screen.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_media_view.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/sale_card.dart';
import 'package:dealker_vendor/core/utils/polling.dart';

/// Seller view of one of the vendor's own auctions: live price, countdown,
/// masked bid feed and the actions allowed in the current state.
class MyAuctionDetailScreen extends ConsumerStatefulWidget {
  const MyAuctionDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<MyAuctionDetailScreen> createState() =>
      _MyAuctionDetailScreenState();
}

class _MyAuctionDetailScreenState extends ConsumerState<MyAuctionDetailScreen> {
  Timer? _poll;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Bids arrive from other users, so refresh while the screen is open.
    _poll = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !screenActive(context)) return;
      final live = ref.read(auctionDetailProvider(widget.id)).value?.auction;
      if (live != null && (live.isLive || live.status == 'SCHEDULED')) {
        ref.invalidate(auctionDetailProvider(widget.id));
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _act(AuctionItem a, String action) async {
    setState(() => _busy = true);
    await runAuctionAction(context, ref, a, action);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(auctionDetailProvider(widget.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      appBar: AuctionAppBar(
        title: 'Auction Details',
        onBack: () =>
            context.canPop() ? context.pop() : context.go('/auctions'),
      ),
      body: detail.when(skipLoadingOnReload: true, skipError: true, 
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: errorText(e, 'Could not load this auction.'),
            onRetry: () => ref.invalidate(auctionDetailProvider(widget.id))),
        data: (d) => _Body(detail: d, busy: _busy, onAction: _act),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(
      {required this.detail, required this.busy, required this.onAction});
  final AuctionDetail detail;
  final bool busy;
  final void Function(AuctionItem, String) onAction;

  AuctionItem get a => detail.auction;

  bool get _hasActions =>
      a.canSubmit || a.canRelist || a.canCancel || a.canEndNow;

  @override
  Widget build(BuildContext context) {
    final sold = a.status == 'SOLD' || a.status == 'AWAITING_PAYMENT';
    final leader = detail.bids.isEmpty ? null : detail.bids.first;

    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            HomeCard(
              padding: const EdgeInsets.all(14),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ProductThumb(a.cover, size: 74),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                color: AppColors.navy)),
                        const SizedBox(height: 7),
                        Wrap(spacing: 7, runSpacing: 5, children: [
                          AudienceChip(a.audience),
                          StatusPill(a.status),
                        ]),
                        const SizedBox(height: 6),
                        Text('#${a.number}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            HomeCard(
              padding: const EdgeInsets.all(12),
              child: AuctionMediaView(
                  images: a.images.isNotEmpty
                      ? a.images
                      : [if (a.cover != null) a.cover!],
                  videoUrl: a.videoUrl,
                  qc: a.qc),
            ),
            const SizedBox(height: 12),
            _Hero(a: a, sold: sold, leader: leader),
            if (a.status == 'REJECTED' &&
                (a.rejectedReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              _Note(
                  icon: PhosphorIconsFill.warning,
                  color: AppColors.rose,
                  bg: AppColors.roseSoft,
                  text: 'Rejected: ${a.rejectedReason}'),
            ],
            if (a.status == 'PENDING_APPROVAL') ...[
              const SizedBox(height: 12),
              const _Note(
                  icon: PhosphorIconsFill.hourglassMedium,
                  color: Color(0xFFB45309),
                  bg: AppColors.amberSoft,
                  text:
                      'Waiting for Dealkr to approve this auction. It will go live automatically.'),
            ],
            if (a.status == 'AWAITING_PAYMENT' || a.status == 'SOLD') ...[
              const SizedBox(height: 12),
              SaleCard(auction: a),
              const SizedBox(height: 12),
              _ChatCard(auctionId: a.id, title: a.title),
            ],
            const SizedBox(height: 12),
            HomeCard(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Column(children: [
                SummaryRow('Starting price', formatInr(a.startPrice)),
                if (a.reservePrice != null)
                  SummaryRow('Reserve price', formatInr(a.reservePrice!)),
                if (a.buyNowPrice != null)
                  SummaryRow('Buy-now price', formatInr(a.buyNowPrice!)),
                SummaryRow(
                    'Bid increment',
                    a.bidIncrement == null
                        ? 'Automatic'
                        : formatInr(a.bidIncrement!)),
                SummaryRow('Registration fee', formatInr(a.registrationFee)),
                if (a.audience == AuctionAudience.b2b)
                  SummaryRow('Lot size', unitsLabel(a.quantity)),
                SummaryRow('Registered bidders', '${a.registrationCount}'),
                SummaryRow('Starts', formatDateTime(a.startsAt)),
                SummaryRow('Ends', formatDateTime(a.endsAt)),
              ]),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Text('Bids', style: heading(size: 17)),
              const SizedBox(width: 8),
              Text('(${a.bidCount})',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 10),
            if (detail.bids.isEmpty)
              const HomeCard(
                  child: Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(
                    child: Text('No bids yet.',
                        style: TextStyle(color: AppColors.textMuted))),
              ))
            else
              HomeCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(children: [
                  for (final (i, b) in detail.bids.take(15).indexed) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppColors.cardBorder),
                    _BidRow(b),
                  ],
                ]),
              ),
            const SizedBox(height: 8),
            const Text(
                'Bidders are shown as anonymous numbers to keep bidding fair.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
      if (_hasActions)
        BottomActionBar(
          child: Row(children: [
            if (a.canEndNow)
              Expanded(
                child: AuctionButton(
                    label: 'End now & sell to top bidder',
                    onPressed: busy ? null : () => onAction(a, 'endnow')),
              ),
            if (a.canCancel)
              Expanded(
                child: AuctionButton(
                    label: 'Cancel Auction',
                    outlined: true,
                    danger: true,
                    onPressed: busy ? null : () => onAction(a, 'cancel')),
              ),
            if (a.canCancel && (a.canSubmit || a.canRelist))
              const SizedBox(width: 10),
            if (a.canSubmit)
              Expanded(
                  child: AuctionButton(
                      label: 'Submit',
                      onPressed: busy ? null : () => onAction(a, 'submit'))),
            if (a.canRelist && !a.canSubmit)
              Expanded(
                  child: AuctionButton(
                      label: 'Relist',
                      onPressed: busy ? null : () => onAction(a, 'relist'))),
          ]),
        ),
    ]);
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.a, required this.sold, required this.leader});
  final AuctionItem a;
  final bool sold;
  final BidEntry? leader;

  @override
  Widget build(BuildContext context) {
    final upcoming = a.status == 'SCHEDULED';
    final running = a.isLive || a.status == 'PAUSED';
    final ended = !running &&
        !upcoming &&
        const ['SOLD', 'AWAITING_PAYMENT', 'UNSOLD', 'DEFAULTED', 'CANCELLED']
            .contains(a.status);

    if (!running && !upcoming && !ended) return const SizedBox.shrink();

    final label = running
        ? 'Auction Ends In'
        : upcoming
            ? 'Auction Starts In'
            : switch (a.status) {
                'SOLD' || 'AWAITING_PAYMENT' => 'Auction Completed',
                'CANCELLED' => 'Auction Cancelled',
                _ => 'Auction Ended Unsold',
              };

    final art = running
        ? 'assets/3d/auction/live.png'
        : upcoming
            ? 'assets/3d/cart/calendar.png'
            : sold
                ? 'assets/3d/auction/trophy.png'
                : 'assets/3d/sell/wait.png';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: ended && !sold
                ? const [Color(0xFF3B4663), Color(0xFF59627E)]
                : const [Color(0xFF001F5F), Color(0xFF123F9E), kAuctionBlue]),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
              color: kAuctionBlue.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 10),
              Text(sold ? 'Final price' : 'Current highest bid',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                    formatInr(sold && a.winningBid != null
                        ? a.winningBid!
                        : a.highest),
                    style: heading(size: 34, color: Colors.white, w: FontWeight.w900)),
              ),
            ]),
          ),
          Image.asset(art, width: 86, height: 86, fit: BoxFit.contain),
        ]),
        if (running || upcoming) ...[
          const SizedBox(height: 12),
          CountdownBoxes(
              endsAt: upcoming ? a.startsAt : a.endsAt, offset: a.serverOffset),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Expanded(child: _Figure('Total bids', '${a.bidCount}', onDark: true)),
            if (sold && leader != null)
              Expanded(child: _Figure('Winner', leader!.displayName, onDark: true)),
            if (!sold)
              Expanded(
                  child: _Figure('Bidders', '${a.registrationCount}', onDark: true)),
          ]),
        ),
        if (a.audience == AuctionAudience.b2b &&
            a.quantity > 1 &&
            a.hasBids) ...[
          const SizedBox(height: 10),
          Text('≈ ${formatInr((a.highest / a.quantity).round())} per unit',
              style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
        ],
      ]),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, {this.big = false, this.onDark = false});
  final String label;
  final String value;
  final bool big;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: onDark ? Colors.white70 : AppColors.textMuted)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: heading(
                  size: big ? 22 : 17,
                  color: onDark
                      ? Colors.white
                      : big
                          ? kAuctionBlue
                          : AppColors.navy,
                  w: FontWeight.w800)),
        ),
      ]);
}

class _Note extends StatelessWidget {
  const _Note(
      {required this.icon,
      required this.color,
      required this.bg,
      required this.text});
  final IconData icon;
  final Color color;
  final Color bg;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 13, height: 1.4, color: color))),
        ]),
      );
}

class _BidRow extends StatelessWidget {
  const _BidRow(this.b);
  final BidEntry b;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color:
                    b.isLeading ? AppColors.mintSoft : const Color(0xFFF1F4FB),
                shape: BoxShape.circle),
            child: Icon(
                b.isLeading
                    ? PhosphorIconsFill.crown
                    : PhosphorIconsRegular.user,
                size: 17,
                color: b.isLeading ? AppColors.mint : AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.displayName,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              Text(timeAgo(b.at),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted)),
            ]),
          ),
          Text(formatInr(b.amount),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: b.isLeading ? AppColors.mint : AppColors.navy)),
        ]),
      );
}


/// Entry to the chat with the winning buyer, with an unread badge.
class _ChatCard extends ConsumerWidget {
  const _ChatCard({required this.auctionId, required this.title});
  final String auctionId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(_chatUnreadProvider(auctionId)).value ?? 0;
    return GestureDetector(
      onTap: () async {
        await context.push(Routes.auctionChat(auctionId), extra: title);
        ref.invalidate(_chatUnreadProvider(auctionId));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B82F6), Color(0xFF1F6FEB), Color(0xFF1553C7)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF1F6FEB).withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 8))
          ],
        ),
        child: Row(children: [
          Image.asset('assets/3d/profile/chat.png', width: 54, height: 54),
          const SizedBox(width: 12),
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Chat with the buyer',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Talk about payment, packing and delivery',
                    style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 12.5)),
              ])),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFC400),
                  borderRadius: BorderRadius.circular(14)),
              child: Text('$unread new',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12)),
            )
          else
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 18),
        ]),
      ),
    );
  }
}

final _chatUnreadProvider = FutureProvider.autoDispose.family<int, String>(
    (ref, id) => ref.watch(auctionRepositoryProvider).chatUnread(id));
