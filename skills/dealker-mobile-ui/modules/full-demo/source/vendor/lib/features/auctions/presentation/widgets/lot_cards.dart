import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/auctions/presentation/widgets/auction_common.dart';

// Same skin as the customer app's Auctions page, so a vendor bidding on a B2B
// lot sees exactly what a customer sees on a B2C one.
const kLotIndigo = Color(0xFF4F3FE0);
const kLotIndigoSoft = Color(0xFFEEEBFF);
const kLotInk = Color(0xFF0B1033);
const kLotMuted = Color(0xFF6B7390);
const kLotLive = Color(0xFFE5232E);
const kLotLiveSoft = Color(0xFFFDECEE);
const kLotBorder = Color(0xFFE6E9F2);

TextStyle jakarta(double size,
        {Color color = kLotInk, FontWeight w = FontWeight.w800, double? h}) =>
    TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: size,
        fontWeight: w,
        color: color,
        height: h);

TextStyle dm(double size,
        {Color color = kLotMuted, FontWeight w = FontWeight.w500, double? h}) =>
    TextStyle(
        fontFamily: 'DMSans',
        fontSize: size,
        fontWeight: w,
        color: color,
        height: h);

String _two(int n) => n.toString().padLeft(2, '0');

String timeLeftLabel(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  if (s >= 86400) return '${s ~/ 86400}d ${(s % 86400) ~/ 3600}h left';
  if (s >= 3600) return '${s ~/ 3600}h ${_two((s % 3600) ~/ 60)}m left';
  return '${s ~/ 60}m ${_two(s % 60)}s left';
}

String startsInLabel(Duration d) {
  final m = d.inMinutes < 0 ? 0 : d.inMinutes;
  if (m >= 1440) return 'STARTS IN ${m ~/ 1440}d';
  if (m >= 60) return 'STARTS IN ${m ~/ 60}h';
  return 'STARTS IN ${m <= 0 ? 1 : m}m';
}

/// Rebuilds every second (countdowns).
class Ticking extends StatefulWidget {
  const Ticking(this.builder, {super.key});
  final WidgetBuilder builder;

  @override
  State<Ticking> createState() => _TickingState();
}

class _TickingState extends State<Ticking> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

extension LotClock on LotView {
  DateTime get _now => DateTime.now().add(serverOffset);
  Duration? get timeLeft => endsAt?.difference(_now);
  Duration? get startsIn => startsAt?.difference(_now);
  bool get overByClock => isLive && endsAt != null && !endsAt!.isAfter(_now);
}

class _Pill extends StatelessWidget {
  const _Pill(this.text,
      {required this.bg, required this.fg, this.icon, this.dot = false});
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot) ...[
            Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(10.5, color: fg))),
        ]),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.l);
  final LotView l;

  @override
  Widget build(BuildContext context) {
    if (l.isLive && !l.overByClock) {
      return const _Pill('LIVE', bg: kLotLive, fg: Colors.white, dot: true);
    }
    if (l.isUpcoming) {
      return Ticking((_) => _Pill(startsInLabel(l.startsIn ?? Duration.zero),
          bg: const Color(0xFFEEF0F7), fg: kLotInk));
    }
    return const _Pill('ENDED', bg: Color(0xFF6E7487), fg: Colors.white);
  }
}

class _Tags extends StatelessWidget {
  const _Tags(this.l);
  final LotView l;

  @override
  Widget build(BuildContext context) {
    final b = switch (l.badge) {
      'TOP_BID' => ('Top Bid', PhosphorIconsFill.crown, kLotIndigo),
      'HOT' => ('Hot Auction', PhosphorIconsFill.fire, const Color(0xFF16A34A)),
      'TRENDING' => (
          'Trending',
          PhosphorIconsFill.trendUp,
          const Color(0xFF2563EB)
        ),
      _ => null,
    };
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (b != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _Pill(b.$1, bg: b.$3, fg: Colors.white, icon: b.$2)),
          if (l.categoryName != null)
            Container(
              constraints: const BoxConstraints(maxWidth: 80),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: kLotInk, borderRadius: BorderRadius.circular(8)),
              child: Text(l.categoryName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(10, color: Colors.white)),
            ),
        ]);
  }
}

class _Views extends StatelessWidget {
  const _Views(this.n);
  final int n;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: kLotMuted.withValues(alpha: .85),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(PhosphorIconsFill.eye, size: 12, color: Colors.white),
          const SizedBox(width: 3),
          Text(n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n',
              style: jakarta(10.5, color: Colors.white)),
        ]),
      );
}

class _MediaBadges extends StatelessWidget {
  const _MediaBadges(this.l);
  final LotView l;

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData i) => Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: kLotIndigoSoft, borderRadius: BorderRadius.circular(8)),
          child: Icon(i, size: 13, color: kLotIndigo),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (l.videoUrl != null) chip(PhosphorIconsFill.playCircle),
      if (l.qc != null) chip(PhosphorIconsFill.sealCheck),
    ]);
  }
}

/// 2-column grid card — same layout as the customer app's.
class LotGridCard extends StatelessWidget {
  const LotGridCard({
    super.key,
    required this.l,
    required this.onOpen,
    required this.onWatch,
    this.onExpired,
  });
  final LotView l;
  final VoidCallback onOpen;
  final VoidCallback onWatch;
  final VoidCallback? onExpired;

  @override
  Widget build(BuildContext context) {
    final live = l.isLive && !l.overByClock;
    final ended = !l.isLive && !l.isUpcoming || l.overByClock;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kLotBorder),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF1B2540).withValues(alpha: .05),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: _StatusBadge(l)),
            const Spacer(),
            GestureDetector(
              onTap: onWatch,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                    l.watching
                        ? PhosphorIconsFill.heart
                        : PhosphorIconsRegular.heart,
                    size: 22,
                    color: l.watching ? kLotIndigo : kLotInk),
              ),
            ),
          ]),
          SizedBox(
            height: 124,
            child: Stack(alignment: Alignment.center, children: [
              Center(child: ProductThumb(l.cover, size: 104, radius: 12)),
              Positioned(left: 0, bottom: 0, child: _Tags(l)),
              if (l.viewCount > 0)
                Positioned(right: 0, bottom: 0, child: _Views(l.viewCount)),
              if (l.videoUrl != null || l.qc != null)
                Positioned(right: 0, top: 0, child: _MediaBadges(l)),
            ]),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 14 * 1.25 * 2,
            child: Text(l.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: jakarta(14, h: 1.25)),
          ),
          const SizedBox(height: 4),
          Text('${unitsLabel(l.quantity)} · ${l.sellerName}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: dm(11.5)),
          const SizedBox(height: 10),
          ..._price(live, ended),
          const SizedBox(height: 10),
          _cta(live, ended),
        ]),
      ),
    );
  }

  List<Widget> _price(bool live, bool ended) {
    if (l.isUpcoming) {
      return [
        Text('Start price', style: dm(12)),
        Text(formatInr(l.startPrice), style: jakarta(21)),
      ];
    }
    if (ended) {
      final p = l.finalPrice;
      return [
        Text(p != null ? 'Sold for' : 'Not sold', style: dm(12)),
        Text(p != null ? formatInr(p) : 'No winner', style: jakarta(21)),
      ];
    }
    return [
      FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(formatInr(l.currentPrice), style: jakarta(22))),
      const SizedBox(height: 4),
      Row(children: [
        const Icon(PhosphorIconsFill.gavel, size: 14, color: kLotIndigo),
        const SizedBox(width: 4),
        Expanded(
            child: Text(
                l.bidCount == 0
                    ? 'No bids'
                    : '${l.bidCount} bid${l.bidCount == 1 ? '' : 's'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: dm(11.5))),
        Flexible(
          flex: 2,
          child: Ticking((_) {
            final d = l.timeLeft ?? Duration.zero;
            if (d.inSeconds <= 0 && onExpired != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => onExpired!());
            }
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(PhosphorIconsRegular.clock,
                    size: 13, color: kLotLive),
                const SizedBox(width: 3),
                Text(timeLeftLabel(d),
                    style: dm(11.5, color: kLotLive, w: FontWeight.w700)),
              ]),
            );
          }),
        ),
      ]),
      if (l.my.registered && l.my.isLeading) ...[
        const SizedBox(height: 6),
        const _Pill("You're winning",
            bg: Color(0xFFDDF5E4), fg: Color(0xFF15803D)),
      ],
    ];
  }

  Widget _cta(bool live, bool ended) {
    if (live) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(PhosphorIconsFill.gavel, size: 19),
          label: Text('Place Bid', style: jakarta(14.5, color: Colors.white)),
          style: FilledButton.styleFrom(
              backgroundColor: kLotIndigo,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: onOpen,
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: kLotIndigo, width: 1.4),
            foregroundColor: kLotIndigo,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
        child: Text(l.isUpcoming ? 'View lot' : 'View details',
            style: jakarta(14, color: kLotIndigo)),
      ),
    );
  }
}
