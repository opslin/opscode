import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/sell_phone/data/sell_models.dart';
import 'package:dealker_app/features/sell_phone/data/sell_repository.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_providers.dart';
import 'package:dealker_app/core/theme/repair_tokens.dart';
import 'package:dealker_app/features/sell_phone/presentation/sell_ui.dart';

/// Offers from nearby buyers: compare, refresh, accept one.
class SellOffersScreen extends ConsumerStatefulWidget {
  const SellOffersScreen({required this.requestId, super.key});
  final String requestId;

  @override
  ConsumerState<SellOffersScreen> createState() => _SellOffersScreenState();
}

class _SellOffersScreenState extends ConsumerState<SellOffersScreen> {
  Timer? _tick;
  Timer? _poll;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // New offers arrive while the customer watches this screen.
    _poll = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      ref.invalidate(sellOffersProvider(widget.requestId));
      ref.invalidate(sellThreadsProvider(widget.requestId));
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      await ref.read(sellRepositoryProvider).refreshOffers(widget.requestId);
      ref.invalidate(sellOffersProvider(widget.requestId));
    } catch (e) {
      if (mounted) AppToast.show(context, sellErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(SellOffer o) async {
    final bool? yes = await showModalBottomSheet<bool>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (BuildContext ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20.w,
          20.h,
          20.w,
          20.h + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Accept ${inr(o.amount)} from ${o.vendorName}?',
              style: TextStyle(
                fontSize: 18.sp,
                fontFamily: RT.head,
                fontWeight: FontWeight.w800,
                color: ReturnColors.ink,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'The other offers will be closed. The buyer pays Dealkr first, then your pickup is arranged. You are paid after they inspect your phone, and the price only changes if they find something different from what you described.',
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.4,
                color: ReturnColors.muted,
              ),
            ),
            SizedBox(height: 18.h),
            SellButton(
              'Accept offer',
              onPressed: () => Navigator.pop(ctx, true),
            ),
            SizedBox(height: 8.h),
            SellButton(
              'Not now',
              outlined: true,
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(sellRepositoryProvider)
          .acceptOffer(widget.requestId, o.id);
      ref.invalidate(sellJourneyProvider(widget.requestId));
      ref.invalidate(mySalesProvider);
      if (mounted) context.go('/sell/${widget.requestId}/book');
    } catch (e) {
      if (mounted) {
        AppToast.show(context, sellErrorMessage(e));
        ref.invalidate(sellOffersProvider(widget.requestId));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SellOffers> q =
        ref.watch(sellOffersProvider(widget.requestId));
    return SellScaffold(
      title: 'Offers for your phone',
      onBack: () => context.go('/sell'),
      child: q.when(
        loading: () => const DealkerPageLoader(),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                sellErrorMessage(e, 'Could not load offers.'),
                style: TextStyle(fontSize: 14.sp),
              ),
              TextButton(
                onPressed: () =>
                    ref.invalidate(sellOffersProvider(widget.requestId)),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (SellOffers d) => RefreshIndicator(
          color: ReturnColors.indigo,
          onRefresh: () async =>
              ref.refresh(sellOffersProvider(widget.requestId).future),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
            children: <Widget>[
              const SellStagesBar(current: 1),
              SizedBox(height: 16.h),
              SellGuideCard(
                guide: d.offers.isEmpty && !d.open
                    ? const SellGuide(
                        art: SellArt.wait,
                        title: 'No offers came in yet',
                        now: 'The waiting time is over and no buyer made an offer. This happens sometimes.',
                        next: 'Tap "Ask buyers again" below. Buyers will look at your phone once more.',
                        tone: SellTone.warn,
                        needsAction: true,
                      )
                    : sellGuide(stage: 'LISTED', offers: d.offers.length),
                child: d.open && d.offers.isEmpty
                    ? _WaitingStrip(left: _leftWords(d.closesAt))
                    : null,
              ),
              SizedBox(height: 12.h),
              _priceCard(d),
              SizedBox(height: 14.h),
              _conversations(),
              if (d.offers.isEmpty && d.open)
                _whileYouWait()
              else if (d.offers.isNotEmpty) ...<Widget>[
                Text(
                  d.offers.length == 1 ? 'Your offer' : 'Your ${d.offers.length} offers',
                  style: sellHead(18),
                ),
                SizedBox(height: 4.h),
                Text('Tap "Accept" on the one you like. You can also chat with the buyer first.', style: sellBody(13)),
                SizedBox(height: 10.h),
                ...d.offers.map(
                  (SellOffer o) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _offerCard(o, d),
                  ),
                ),
              ],
              SizedBox(height: 8.h),
              SellButton(
                d.refreshesLeft > 0
                    ? (d.open ? 'Check for new offers' : 'Ask buyers again')
                    : 'No more tries left',
                icon: Icons.refresh_rounded,
                outlined: true,
                busy: _busy,
                onPressed: d.refreshesLeft > 0 ? _refresh : null,
              ),
              SizedBox(height: 10.h),
              Center(
                child: TextButton(
                  onPressed: () => _cancel(),
                  child: Text(
                    'Cancel this sale',
                    style: TextStyle(
                      color: ReturnColors.red,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Every buyer who offered or wrote, newest first - so a message from a buyer who has not offered yet is never hidden.
  Widget _conversations() {
    final List<SellThreadSummary> list =
        ref.watch(sellThreadsProvider(widget.requestId)).asData?.value ??
            <SellThreadSummary>[];
    if (list.isEmpty) return const SizedBox.shrink();
    final int unread = list.fold(0, (int a, SellThreadSummary t) => a + t.unread);
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.forum_rounded, size: 20.sp, color: ReturnColors.indigo),
              SizedBox(width: 8.w),
              Text('Messages', style: sellHead(18)),
              if (unread > 0) ...<Widget>[
                SizedBox(width: 8.w),
                _badge(unread),
              ],
            ],
          ),
          SizedBox(height: 4.h),
          Text('Buyers who wrote to you or made an offer.', style: sellBody(12.5)),
          SizedBox(height: 10.h),
          ...list.map(_threadTile),
        ],
      ),
    );
  }

  Widget _badge(int n) => Container(
        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
        decoration: BoxDecoration(
            color: ReturnColors.red, borderRadius: BorderRadius.circular(10.r)),
        child: Text('$n',
            style: sellBody(11, color: Colors.white, w: FontWeight.w800)),
      );

  Widget _threadTile(SellThreadSummary t) {
    final bool fresh = t.unread > 0;
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () => context
            .push('/sell/${widget.requestId}/chat/${t.vendorId}')
            .then((_) {
          ref.invalidate(sellThreadsProvider(widget.requestId));
          ref.invalidate(sellOffersProvider(widget.requestId));
        }),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: fresh ? ReturnColors.indigoSoft : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
                color: fresh ? ReturnColors.indigo : ReturnColors.line,
                width: fresh ? 1.6 : 1),
          ),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 21.r,
                backgroundColor: ReturnColors.indigo,
                child: Text(
                  t.vendorName.isEmpty ? '?' : t.vendorName[0].toUpperCase(),
                  style: sellHead(16, color: Colors.white),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(t.vendorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: sellHead(14.5)),
                        ),
                        if (t.offerAmount != null)
                          Text(inr(t.offerAmount!),
                              style: sellHead(13.5, color: ReturnColors.green)),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      t.lastMessage == null
                          ? 'Made an offer - tap to talk'
                          : '${t.lastFromMe ? 'You: ' : ''}${t.lastMessage}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sellBody(12.5,
                          color: fresh ? ReturnColors.ink : ReturnColors.muted,
                          w: fresh ? FontWeight.w700 : FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (fresh) ...<Widget>[SizedBox(width: 8.w), _badge(t.unread)],
            ],
          ),
        ),
      ),
    );
  }

  String _leftWords(DateTime? at) {
    if (at == null) return '';
    final Duration d = at.difference(DateTime.now());
    if (d.isNegative) return '';
    final int h = d.inHours;
    final int m = d.inMinutes % 60;
    if (h > 0) return '$h hour${h == 1 ? '' : 's'} $m min left';
    return '${d.inMinutes.clamp(1, 59)} min left';
  }

  Widget _priceCard(SellOffers d) => SellCard(
        child: Row(
          children: <Widget>[
            SellImage(SellArt.hero, size: 52.w),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(d.askingPrice != null ? 'The price you asked for' : 'Your phone is worth about', style: sellBody(12.5)),
                  Text(
                    d.askingPrice != null ? inr(d.askingPrice!) : inrRange(d.estimateMin, d.estimateMax),
                    style: sellHead(21),
                  ),
                ],
              ),
            ),
            Text('No. ${d.code}', style: sellBody(11)),
          ],
        ),
      );

  Widget _whileYouWait() => SellCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('You can close this page', style: sellHead(16)),
            SizedBox(height: 4.h),
            Text('Nothing is lost. Offers will wait for you here.', style: sellBody(13)),
            SizedBox(height: 12.h),
            _tip(SellArt.bell, 'We send a notification when a buyer makes an offer.'),
            _tip(SellArt.timer, 'Most offers come within the waiting time shown above.'),
            _tip(SellArt.shield, 'You are never forced to sell. You only accept the price you like.'),
          ],
        ),
      );

  Widget _tip(String art, String text) => Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: Row(
          children: <Widget>[
            Container(
              width: 44.w,
              height: 44.w,
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(color: ReturnColors.indigoSoft, borderRadius: BorderRadius.circular(14.r)),
              child: Image.asset(art, fit: BoxFit.contain),
            ),
            SizedBox(width: 12.w),
            Expanded(child: Text(text, style: sellBody(13.5, color: ReturnColors.ink, w: FontWeight.w600))),
          ],
        ),
      );

  Future<void> _cancel() async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Cancel this sale?'),
        content: const Text('Your listing and all offers will be closed.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel sale'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ref
          .read(sellRepositoryProvider)
          .cancel(widget.requestId, 'Cancelled by customer');
      ref.invalidate(mySalesProvider);
      if (mounted) context.go('/sell');
    } catch (e) {
      if (mounted) AppToast.show(context, sellErrorMessage(e));
    }
  }

  Widget _offerCard(SellOffer o, SellOffers d) {
    return SellCard(
      border: o.best ? ReturnColors.green.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 20.r,
                backgroundColor: ReturnColors.indigoSoft,
                child: Icon(
                  Icons.storefront_rounded,
                  color: ReturnColors.indigo,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            o.vendorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontFamily: RT.head,
                              fontWeight: FontWeight.w800,
                              color: ReturnColors.ink,
                            ),
                          ),
                        ),
                        if (o.best) ...<Widget>[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 7.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: ReturnColors.greenSoft,
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              'Best offer',
                              style: TextStyle(
                                fontSize: 10.5.sp,
                                fontFamily: RT.head,
                                fontWeight: FontWeight.w800,
                                color: ReturnColors.green,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: <Widget>[
                        if (o.rating > 0) ...<Widget>[
                          Icon(
                            Icons.star_rounded,
                            size: 14.sp,
                            color: ReturnColors.amber,
                          ),
                          Text(
                            ' ${o.rating.toStringAsFixed(1)}  ',
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              color: ReturnColors.muted,
                            ),
                          ),
                        ],
                        if (o.distanceKm != null)
                          Text(
                            '${o.distanceKm!.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              color: ReturnColors.muted,
                            ),
                          ),
                        if (o.city != null && o.distanceKm == null)
                          Text(
                            o.city!,
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              color: ReturnColors.muted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                inr(o.amount),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontFamily: RT.head,
                  fontWeight: FontWeight.w900,
                  color: ReturnColors.ink,
                ),
              ),
            ],
          ),
          if (o.note != null && o.note!.isNotEmpty) ...<Widget>[
            SizedBox(height: 8.h),
            Text(
              o.note!,
              style: TextStyle(
                fontSize: 12.sp,
                fontStyle: FontStyle.italic,
                color: ReturnColors.muted,
              ),
            ),
          ],
          if (d.askingPrice != null && d.askingPrice! > 0) ...<Widget>[
            SizedBox(height: 8.h),
            _vsAsk(o.amount, d.askingPrice!),
          ],
          SizedBox(height: 12.h),
          Row(
            children: <Widget>[
              Expanded(
                child: _chatButton(o, d),
              ),
              SizedBox(width: 10.w),
              Expanded(
                flex: 2,
                child: SellButton(
                  'Accept ${inr(o.amount)}',
                  busy: _busy,
                  onPressed: d.open ? () => _accept(o) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// How this offer compares with the customer's own price.
  Widget _vsAsk(double offer, double ask) {
    final double diff = offer - ask;
    final bool meets = diff >= 0;
    final String text = diff == 0
        ? 'Matches your price'
        : meets
            ? '${inr(diff)} above your price'
            : '${inr(-diff)} below your price';
    return Row(
      children: <Widget>[
        Icon(
          meets ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          size: 14.sp,
          color: meets ? ReturnColors.green : ReturnColors.amber,
        ),
        SizedBox(width: 6.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: meets ? ReturnColors.green : ReturnColors.muted,
          ),
        ),
      ],
    );
  }

  Widget _chatButton(SellOffer o, SellOffers d) {
    final Widget button = SellButton(
      'Chat',
      icon: Icons.chat_bubble_outline_rounded,
      outlined: true,
      onPressed: () => context
          .push('/sell/${d.requestId}/chat/${o.vendorId}')
          .then((_) => ref.invalidate(sellOffersProvider(widget.requestId))),
    );
    if (o.unread == 0) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        button,
        Positioned(
          right: -4.w,
          top: -6.h,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: ReturnColors.red,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Text(
              '${o.unread}',
              style: TextStyle(
                fontSize: 10.5.sp,
                fontFamily: RT.head,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}


/// Animated "looking for buyers" strip: gently pulsing dots, plus how long the offers stay open.
class _WaitingStrip extends StatefulWidget {
  const _WaitingStrip({required this.left});
  final String left;

  @override
  State<_WaitingStrip> createState() => _WaitingStripState();
}

class _WaitingStripState extends State<_WaitingStrip> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: <Widget>[
            AnimatedBuilder(
              animation: _c,
              builder: (BuildContext context, Widget? _) => Row(
                children: <Widget>[
                  for (int i = 0; i < 3; i++)
                    Container(
                      margin: EdgeInsets.only(right: 5.w),
                      width: 9.w,
                      height: 9.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kSellGold.withValues(alpha: 0.3 + 0.7 * ((((_c.value * 3 - i) % 3) < 1) ? 1 - (((_c.value * 3 - i) % 3)) : 0)),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 6.w),
            Expanded(child: Text('Looking for buyers', style: sellBody(13.5, color: Colors.white, w: FontWeight.w700))),
            if (widget.left.isNotEmpty)
              Text(widget.left, style: sellBody(12.5, color: kSellGold, w: FontWeight.w800)),
          ],
        ),
      );
}
