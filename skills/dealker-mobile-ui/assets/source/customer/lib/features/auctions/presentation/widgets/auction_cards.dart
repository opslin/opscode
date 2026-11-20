import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/features/auctions/data/auction_view.dart';
import 'package:dealker_app/features/auctions/presentation/widgets/auction_ui.dart';

/// What a card's button does. The screen supplies these so cards stay dumb.
class AuctionActions {
  const AuctionActions({
    required this.open,
    required this.watch,
    required this.register,
    required this.bid,
    required this.expired,
  });
  final void Function(AuctionView a) open;
  final void Function(AuctionView a) watch;
  final void Function(AuctionView a) register;
  final void Function(AuctionView a) bid;

  /// A live card's countdown hit zero — refresh so it flips to Ended.
  final VoidCallback expired;
}

Widget _photo(AuctionView a, double size) {
  final String? url = ApiConstants.resolveMediaUrl(a.imageUrl);
  return SizedBox(
    width: size,
    height: size,
    child: url == null
        ? Icon(PhosphorIconsRegular.image,
            size: size * .35, color: AU.chipBorder)
        : CachedNetworkImage(
            imageUrl: webImageSource(url),
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => Icon(PhosphorIconsRegular.image,
                size: size * .35, color: AU.chipBorder),
          ),
  );
}

/// Short names show "iPhone 13" with the variant on a second bold line (like the design);
/// longer names simply wrap over two lines.
class _Title extends StatelessWidget {
  const _Title(this.a);
  final AuctionView a;
  static const double size = 14;

  /// Height of two title lines, so cards in a row line up.
  static double get height => size.sp * 1.25 * 2 + 2;

  @override
  Widget build(BuildContext context) {
    final ({String name, String? variant}) p = a.nameParts;
    final bool split = p.variant != null && p.name.length <= 17;
    return SizedBox(
      height: height,
      child: split
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: jakarta(size.sp, h: 1.25)),
                  Text(p.variant!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: jakarta(size.sp, h: 1.25)),
                ])
          : Text(p.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: jakarta(size.sp, h: 1.25)),
    );
  }
}

class _SoldBy extends StatelessWidget {
  const _SoldBy(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => Row(children: <Widget>[
        Flexible(
            child: Text('Sold by $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: dm(11.5.sp))),
        SizedBox(width: 4.w),
        const VerifiedCheck(size: 13),
      ]);
}

String _left(Duration d) {
  final int s = d.inSeconds < 0 ? 0 : d.inSeconds;
  if (s >= 86400) return '${s ~/ 86400}d ${(s % 86400) ~/ 3600}h left';
  if (s >= 3600) return '${s ~/ 3600}h ${two((s % 3600) ~/ 60)}m left';
  return '${s ~/ 60}m ${two(s % 60)}s left';
}

/// Tag(s) on a card's photo: the earned badge, then the category chip.
class _Tags extends StatelessWidget {
  const _Tags(this.a);
  final AuctionView a;

  @override
  Widget build(BuildContext context) {
    final ({String label, IconData icon, Color bg})? b = switch (a.badge) {
      'TOP_BID' => (
          label: 'Top Bid',
          icon: PhosphorIconsFill.crown,
          bg: AU.indigo
        ),
      'HOT' => (
          label: 'Hot Auction',
          icon: PhosphorIconsFill.fire,
          bg: const Color(0xFF16A34A)
        ),
      'TRENDING' => (
          label: 'Trending',
          icon: PhosphorIconsFill.trendUp,
          bg: const Color(0xFF2563EB)
        ),
      _ => null,
    };
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (b != null)
            Container(
              margin: EdgeInsets.only(bottom: 4.h),
              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
              decoration: BoxDecoration(
                  color: b.bg, borderRadius: BorderRadius.circular(8.r)),
              child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Icon(b.icon, size: 11.sp, color: Colors.white),
                SizedBox(width: 3.w),
                Text(b.label, style: jakarta(10.sp, color: Colors.white)),
              ]),
            ),
          if (a.categoryName != null)
            Container(
              constraints: BoxConstraints(maxWidth: 78.w),
              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
              decoration: BoxDecoration(
                  color: AU.ink, borderRadius: BorderRadius.circular(8.r)),
              child: Text(a.categoryName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(10.sp, color: Colors.white)),
            ),
        ]);
  }
}

class _Views extends StatelessWidget {
  const _Views(this.n);
  final int n;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
        decoration: BoxDecoration(
            color: const Color(0xFF6B7390).withValues(alpha: .85),
            borderRadius: BorderRadius.circular(10.r)),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Icon(PhosphorIconsFill.eye, size: 12.sp, color: Colors.white),
          SizedBox(width: 3.w),
          Text(n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n',
              style: jakarta(10.5.sp, color: Colors.white)),
        ]),
      );
}

/// Tiny "video / QC report available" chips on a card's photo.
class _MediaBadges extends StatelessWidget {
  const _MediaBadges(this.a);
  final AuctionView a;

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon) => Container(
          margin: EdgeInsets.only(left: 4.w),
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
              color: AU.indigoSoft, borderRadius: BorderRadius.circular(8.r)),
          child: Icon(icon, size: 13.sp, color: AU.indigo),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
      if (a.hasVideo) chip(PhosphorIconsFill.playCircle),
      if (a.hasQc) chip(PhosphorIconsFill.sealCheck),
    ]);
  }
}

/// "You're winning" / "You're outbid  Bid ₹52,500 to lead".
class _StateLine extends StatelessWidget {
  const _StateLine(this.a);
  final AuctionView a;
  @override
  Widget build(BuildContext context) {
    if (!a.isLive) return const SizedBox.shrink();
    if (a.registered && a.isLeading) {
      return Padding(
        padding: EdgeInsets.only(top: 8.h),
        child: Align(
            alignment: Alignment.centerLeft,
            child: Pill(
                text: "You're winning",
                bg: AU.greenSoft,
                fg: AU.greenText,
                size: 11.5,
                weight: FontWeight.w700,
                vertical: 5)),
      );
    }
    if (a.isOutbid) {
      final num? next = a.minNextBid;
      return Padding(
        padding: EdgeInsets.only(top: 8.h),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
          decoration: BoxDecoration(
              color: AU.amberSoft, borderRadius: BorderRadius.circular(8.r)),
          child: Text.rich(
            TextSpan(children: <InlineSpan>[
              TextSpan(
                  text: "You're ",
                  style: dm(11.sp, color: AU.amberText, w: FontWeight.w600)),
              TextSpan(text: 'outbid', style: jakarta(11.sp, color: AU.live)),
              if (next != null)
                TextSpan(
                    text: '  Bid ${inr(next)} to lead',
                    style: dm(11.sp, color: AU.amberText, w: FontWeight.w600)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// The indigo two-line / outline button at the foot of a card.
class AuctionCta extends StatelessWidget {
  const AuctionCta(
      {required this.a, required this.actions, this.height = 48, super.key});
  final AuctionView a;
  final AuctionActions actions;
  final double height;

  Widget _filled(String top, String? sub, VoidCallback onTap,
          {IconData? icon}) =>
      SizedBox(
        width: double.infinity,
        height: height.h,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AU.indigo,
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r)),
          ),
          child: icon != null
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                      Icon(icon, size: 19.sp, color: Colors.white),
                      SizedBox(width: 7.w),
                      Flexible(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(top,
                                  style:
                                      jakarta(14.5.sp, color: Colors.white)))),
                    ])
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                      FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(top,
                              style: jakarta(14.sp, color: Colors.white))),
                      if (sub != null)
                        FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(sub,
                                style: dm(11.5.sp,
                                    color: Colors.white.withValues(alpha: .92),
                                    w: FontWeight.w600))),
                    ]),
        ),
      );

  Widget _outline(String label, VoidCallback onTap, {IconData? icon}) =>
      SizedBox(
        width: double.infinity,
        height: 44.h,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AU.indigo, width: 1.4),
            foregroundColor: AU.indigo,
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r)),
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 18.sp),
                  SizedBox(width: 6.w)
                ],
                Flexible(
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label,
                            style: jakarta(14.sp, color: AU.indigo)))),
              ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (a.isUpcoming) {
      return a.watching
          ? _outline('Reminder set', () => actions.watch(a),
              icon: PhosphorIconsFill.bellRinging)
          : _outline('Remind me', () => actions.watch(a),
              icon: PhosphorIconsRegular.bell);
    }
    if (a.isEnded || a.isOverByClock)
      return _outline('View details', () => actions.open(a));
    // One button for everyone: it opens the lot, where joining (fee + consent) and bidding happen.
    return _filled('Place Bid', null, () => actions.open(a),
        icon: PhosphorIconsFill.gavel);
  }
}

/// The 2-column grid card (all seven states of the design come from [a]'s data).
class AuctionCard extends StatelessWidget {
  const AuctionCard({required this.a, required this.actions, super.key});
  final AuctionView a;
  final AuctionActions actions;

  @override
  Widget build(BuildContext context) {
    final bool live = a.isLive && !a.isOverByClock;
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () => actions.open(a),
      child: Container(
        padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AU.border),
          boxShadow: <BoxShadow>[
            BoxShadow(
                color: const Color(0xFF1B2540).withValues(alpha: .05),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Flexible(
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: StatusBadge(a))),
                    SizedBox(width: 4.w),
                    WatchHeart(on: a.watching, onTap: () => actions.watch(a)),
                  ]),
              SizedBox(
                height: 124.h,
                child: Stack(alignment: Alignment.center, children: <Widget>[
                  Center(child: _photo(a, 104.h)),
                  Positioned(left: 0, bottom: 0, child: _Tags(a)),
                  if (a.viewCount > 0)
                    Positioned(right: 0, bottom: 0, child: _Views(a.viewCount)),
                  if (a.hasVideo || a.hasQc)
                    Positioned(right: 0, top: 0, child: _MediaBadges(a)),
                ]),
              ),
              SizedBox(height: 8.h),
              _Title(a),
              if (a.sellerName != null) ...<Widget>[
                SizedBox(height: 4.h),
                _SoldBy(a.sellerName!)
              ],
              SizedBox(height: 10.h),
              ..._priceBlock(),
              _StateLine(a),
              // In the grid both cards of a row are stretched to the same height, so the buttons line up.
              Flexible(child: SizedBox(height: 10.h)),
              AuctionCta(a: a, actions: actions),
            ]),
      ),
    );
  }

  List<Widget> _priceBlock() {
    if (a.isUpcoming) {
      final DateTime? s = a.startsAt;
      return <Widget>[
        if (s != null) Text(startsAtLabel(s, a.now), style: dm(12.sp)),
        if (s != null) SizedBox(height: 8.h),
        Text('Start price', style: dm(12.sp)),
        Text(inr(a.startPrice), style: jakarta(21.sp)),
      ];
    }
    if (a.isEnded || a.isOverByClock) {
      final num? price = a.isSold ? (a.finalPrice ?? a.currentPrice) : null;
      return <Widget>[
        Text(price != null ? 'Sold for' : 'Not sold', style: dm(12.sp)),
        if (price != null) Text(inr(price), style: jakarta(21.sp)),
        if (price != null && a.winnerAlias != null)
          Text('Won by ${a.winnerAlias}', style: dm(12.sp)),
        if (price == null) Text('Ended with no winner', style: dm(12.sp)),
      ];
    }
    return <Widget>[
      FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(inr(a.currentPrice), style: jakarta(22.sp))),
      SizedBox(height: 4.h),
      Row(children: <Widget>[
        Icon(PhosphorIconsFill.gavel, size: 14.sp, color: AU.indigo),
        SizedBox(width: 4.w),
        Expanded(
            child: Text(
                a.bidCount == 0
                    ? 'No bids'
                    : '${a.bidCount} bid${a.bidCount == 1 ? '' : 's'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: dm(11.5.sp))),
        Flexible(
            flex: 2,
            child: Ticking(builder: (_) {
              final Duration d = a.timeLeft ?? Duration.zero;
              if (d.inSeconds <= 0)
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => actions.expired());
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Icon(PhosphorIconsRegular.clock, size: 13.sp, color: AU.live),
                  SizedBox(width: 3.w),
                  Text(_left(d),
                      style: dm(11.5.sp, color: AU.live, w: FontWeight.w700)),
                ]),
              );
            })),
      ]),
    ];
  }
}

/// Grey placeholder with the same silhouette as [AuctionCard].
class AuctionCardSkeleton extends StatelessWidget {
  const AuctionCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AU.border),
        ),
        child: LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
          final double w = c.maxWidth;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(children: <Widget>[
                  Bone(width: w * .26, height: 22.h, radius: 8),
                  const Spacer(),
                  Icon(PhosphorIconsRegular.heart,
                      size: 22.sp, color: AU.chipBorder),
                ]),
                SizedBox(height: 8.h),
                Center(
                    child: Bone(width: w * .55, height: w * .55, radius: 14)),
                SizedBox(height: 12.h),
                Bone(width: w * .4, height: 11.h),
                SizedBox(height: 8.h),
                Bone(height: 12.h),
                SizedBox(height: 7.h),
                Bone(width: w * .6, height: 12.h),
                SizedBox(height: 7.h),
                Bone(width: w * .35, height: 10.h),
                SizedBox(height: 14.h),
                Bone(height: 44.h, radius: 10),
              ]);
        }),
      );
}

/// One tile of the "Ending soon" strip.
class EndingSoonCard extends StatelessWidget {
  const EndingSoonCard({required this.a, required this.actions, super.key});
  final AuctionView a;
  final AuctionActions actions;

  @override
  Widget build(BuildContext context) {
    final ({String name, String? variant}) p = a.nameParts;
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () => actions.open(a),
      child: Container(
        width: 140.w,
        padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
        decoration: BoxDecoration(
          color: AU.band,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AU.border),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: 96.h,
                child: Stack(alignment: Alignment.center, children: <Widget>[
                  Center(child: _photo(a, 92.h)),
                  Positioned(
                      left: 0,
                      bottom: 0,
                      child: CountdownPill(a,
                          solid: true, short: true, onDone: actions.expired)),
                ]),
              ),
              SizedBox(height: 8.h),
              SizedBox(
                height: 13.5.sp * 1.25 * 2,
                child: (p.variant != null && p.name.length <= 15)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                            Text(p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: jakarta(13.5.sp, h: 1.25)),
                            Text(p.variant!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: dm(13.5.sp,
                                    color: const Color(0xFF3F4663), h: 1.25)),
                          ])
                    : Text(p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: jakarta(13.5.sp, h: 1.25)),
              ),
              SizedBox(height: 8.h),
              Text(inr(a.currentPrice), style: jakarta(17.sp)),
              Text(
                  a.bidCount == 0
                      ? 'No bids yet'
                      : '${a.bidCount} bid${a.bidCount == 1 ? '' : 's'}',
                  style: dm(12.sp)),
            ]),
      ),
    );
  }
}

/// Horizontal row card — My Bids, and the list view of the browse page.
class AuctionRowCard extends StatelessWidget {
  const AuctionRowCard(
      {required this.a, required this.actions, this.showCta = true, super.key});
  final AuctionView a;
  final AuctionActions actions;
  final bool showCta;

  @override
  Widget build(BuildContext context) {
    final bool live = a.isLive && !a.isOverByClock;
    final bool ended = a.isEnded || a.isOverByClock;
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () => actions.open(a),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AU.border),
          boxShadow: <BoxShadow>[
            BoxShadow(
                color: const Color(0xFF1B2540).withValues(alpha: .04),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 100.w,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (!live) StatusBadge(a),
                      SizedBox(height: live ? 6.h : 4.h),
                      Center(child: _photo(a, 80.w)),
                      if (live && a.registered && a.isLeading) ...<Widget>[
                        SizedBox(height: 6.h),
                        Pill(
                            text: "You're winning",
                            bg: AU.greenSoft,
                            fg: AU.greenText,
                            size: 10.5,
                            horizontal: 6,
                            weight: FontWeight.w700)
                      ],
                      if (live && a.isOutbid) ...<Widget>[
                        SizedBox(height: 6.h),
                        Pill(
                            text: "You're outbid",
                            bg: AU.amberSoft,
                            fg: AU.amberText,
                            size: 10.5,
                            horizontal: 6,
                            weight: FontWeight.w700)
                      ],
                    ]),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (live) ...<Widget>[
                        const LiveBadge(),
                        SizedBox(height: 6.h)
                      ],
                      Text(a.shortTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: jakarta(14.5.sp, h: 1.25)),
                      SizedBox(height: 6.h),
                      ..._body(live, ended),
                      if (showCta && !live) ...<Widget>[
                        SizedBox(height: 10.h),
                        AuctionCta(a: a, actions: actions)
                      ],
                    ]),
              ),
              if (live)
                Padding(
                    padding: EdgeInsets.only(top: 34.h),
                    child: Icon(PhosphorIconsRegular.caretRight,
                        size: 20.sp, color: AU.ink)),
            ]),
      ),
    );
  }

  List<Widget> _body(bool live, bool ended) {
    if (live) {
      return <Widget>[
        Text('Current bid', style: dm(12.5.sp)),
        Text(inr(a.currentPrice), style: jakarta(21.sp)),
        Text(
            '${a.bidCount} bid${a.bidCount == 1 ? '' : 's'} · ${a.bidderCount} bidder${a.bidderCount == 1 ? '' : 's'}',
            style: dm(12.sp)),
        SizedBox(height: 6.h),
        Align(
            alignment: Alignment.centerLeft,
            child: CountdownPill(a, onDone: actions.expired)),
      ];
    }
    if (ended) {
      final num? price = a.isSold ? (a.finalPrice ?? a.currentPrice) : null;
      return <Widget>[
        Text(price != null ? 'Sold for' : 'Not sold', style: dm(12.5.sp)),
        if (price != null) Text(inr(price), style: jakarta(21.sp)),
        if (price != null && a.winnerAlias != null)
          Text('Won by ${a.winnerAlias}', style: dm(12.5.sp)),
      ];
    }
    return <Widget>[
      Text('Start price', style: dm(12.5.sp)),
      Text(inr(a.startPrice), style: jakarta(21.sp)),
      if (a.startsAt != null)
        Text(startsFullLabel(a.startsAt!), style: dm(12.sp)),
    ];
  }
}
