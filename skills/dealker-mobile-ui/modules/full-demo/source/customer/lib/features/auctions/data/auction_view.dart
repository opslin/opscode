import 'package:dealker_app/features/home/presentation/widgets/dealer_blocks.dart'
    show LiveAuctionData;
import 'package:dealker_app/shared/widgets/marketplace_product_box.dart';

num? _n(Object? v) => v is num ? v : num.tryParse('$v');
String? _s(Object? v) {
  final String t = '${v ?? ''}'.trim();
  return t.isEmpty || t == 'null' ? null : t;
}

/// What the Auctions screens need from one auction, read from the server's JSON (nothing invented:
/// a missing value stays null and the row that would show it is hidden).
class AuctionView {
  AuctionView(this.raw, this.clockOffset);

  factory AuctionView.fromJson(
          Map<String, dynamic> json, Duration clockOffset) =>
      AuctionView(json, clockOffset);

  final Map<String, dynamic> raw;

  /// Server clock minus this phone's clock, so countdowns are right even when the phone's clock is off.
  final Duration clockOffset;

  DateTime get now => DateTime.now().add(clockOffset);

  String get id => '${raw['id']}';
  String get title => _s(raw['title']) ?? 'Auction';
  String get status => '${raw['status']}';
  String? get imageUrl {
    final String? one = _s(raw['image_url']);
    if (one != null) return one;
    final Object? imgs = raw['images'];
    if (imgs is List && imgs.isNotEmpty) return _s(imgs.first);
    return null;
  }

  /// The seller attached a video / a QC report (shown as tiny badges on cards, in full on the detail page).
  bool get hasVideo => _s(raw['video_url']) != null;
  bool get hasQc =>
      raw['qc_report'] is Map && (raw['qc_report'] as Map).isNotEmpty;

  /// People who opened this lot, and the tag the server earned it (TOP_BID / HOT / TRENDING).
  int get viewCount => _n(raw['view_count'])?.toInt() ?? 0;
  String? get badge => _s(raw['badge']);
  String? get categoryName => _s(raw['category_name']);

  num get currentPrice =>
      _n(raw['current_price']) ?? _n(raw['start_price']) ?? 0;
  num get startPrice => _n(raw['start_price']) ?? currentPrice;
  num? get minNextBid => _n(raw['min_next_bid']);
  num? get increment => _n(raw['increment']);
  int get bidCount => _n(raw['bid_count'])?.toInt() ?? 0;
  int get bidderCount => _n(raw['bidder_count'])?.toInt() ?? 0;
  num? get registrationFee => _n(raw['registration_fee']);
  String? get feePolicy => _s(raw['fee_policy']);
  DateTime? get startsAt => DateTime.tryParse('${raw['starts_at']}')?.toLocal();
  DateTime? get endsAt => DateTime.tryParse('${raw['ends_at']}')?.toLocal();
  DateTime? get endedAt => DateTime.tryParse('${raw['ended_at']}')?.toLocal();
  String? get sellerName =>
      _s((raw['seller'] is Map) ? (raw['seller'] as Map)['name'] : null);
  bool get watching => raw['watching'] == true;
  Map<String, dynamic> get my => raw['my'] is Map
      ? Map<String, dynamic>.from(raw['my'] as Map)
      : const <String, dynamic>{};
  bool get registered => my['registered'] == true;
  bool get isLeading => my['is_leading'] == true;
  num? get myMax => _n(my['my_max']);
  String? get winnerAlias => _s(raw['winner_alias']);
  num? get finalPrice => _n(raw['final_price']);

  bool get isLive => status == 'LIVE' || status == 'PAUSED';
  bool get isUpcoming => status == 'SCHEDULED';
  bool get isEnded => !isLive && !isUpcoming;
  bool get isSold => status == 'SOLD' || status == 'AWAITING_PAYMENT';

  /// Live auction whose time ran out on the server clock (the card flips to "Ended" without a reload).
  bool get isOverByClock => isLive && endsAt != null && !endsAt!.isAfter(now);

  /// You have bid and someone is now ahead of you.
  bool get isOutbid => isLive && registered && myMax != null && !isLeading;

  Duration? get timeLeft => endsAt?.difference(now);
  Duration? get startsIn => startsAt?.difference(now);

  /// "Apple iPhone 12 64GB" — the one-line title of My Bids rows.
  String get shortTitle {
    final ({String name, String? variant}) p = nameParts;
    return p.variant == null ? p.name : '${p.name} ${p.variant}';
  }

  /// "Apple iPhone 14 (128GB, Starlight)" → ("Apple iPhone 14", "128GB").
  ({String name, String? variant}) get nameParts {
    final RegExpMatch? m =
        RegExp(r'^(.*?)\s*\(([^()]{1,60})\)\s*$').firstMatch(title);
    if (m == null) return (name: title, variant: null);
    final List<String> parts = m
        .group(2)!
        .split(RegExp(r'[,/|]'))
        .map((String x) => x.trim())
        .where((String x) => x.isNotEmpty)
        .toList();
    if (m.group(1)!.isEmpty || parts.isEmpty)
      return (name: title, variant: null);
    final bool allMemory = parts.every((String p) =>
        RegExp(r'^\d+\s?(GB|TB)$', caseSensitive: false).hasMatch(p));
    // Only the first part ("128GB", "8GB + 256GB") — the colour is on the detail page.
    final List<String> memory = parts
        .where((String p) =>
            RegExp(r'^\d+\s?(GB|TB)$', caseSensitive: false).hasMatch(p))
        .toList();
    final String? variant = memory.isNotEmpty
        ? memory.join(' + ')
        : (allMemory ? null : parts.first);
    return (name: m.group(1)!.trim(), variant: variant);
  }
}

String inr(num v) => MarketplaceProductBox.inr(v);

String two(int n) => n.toString().padLeft(2, '0');

/// 02h 14m 08s (cards, My Bids).
String clockHms(Duration d) {
  final int s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${two(s ~/ 3600)}h ${two((s % 3600) ~/ 60)}m ${two(s % 60)}s';
}

/// Short form for the Ending-soon strip: "1h 12m" / "28m 14s".
String clockShort(Duration d) {
  final int s = d.inSeconds < 0 ? 0 : d.inSeconds;
  if (s >= 3600) return '${s ~/ 3600}h ${two((s % 3600) ~/ 60)}m';
  return '${s ~/ 60}m ${two(s % 60)}s';
}

/// "STARTS IN 2h" / "STARTS IN 42m" / "STARTS IN 3d".
String startsInLabel(Duration d) {
  final int m = d.inMinutes < 0 ? 0 : d.inMinutes;
  if (m >= 1440) return 'STARTS IN ${m ~/ 1440}d';
  if (m >= 60) return 'STARTS IN ${m ~/ 60}h';
  return 'STARTS IN ${m <= 0 ? 1 : m}m';
}

const List<String> _mon = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

String time12(DateTime t) {
  final int h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${two(t.minute)} ${t.hour >= 12 ? 'PM' : 'AM'}';
}

/// "Starts at 12:00 PM" today, otherwise "Starts 16 Oct, 12:00 PM".
String startsAtLabel(DateTime t, DateTime now) {
  final bool today =
      t.year == now.year && t.month == now.month && t.day == now.day;
  return today
      ? 'Starts at ${time12(t)}'
      : 'Starts ${t.day} ${_mon[t.month - 1]}, ${time12(t)}';
}

/// "Starts 12:00 PM, 16 Oct 2026" (My Bids rows).
String startsFullLabel(DateTime t) =>
    'Starts ${time12(t)}, ${t.day} ${_mon[t.month - 1]} ${t.year}';

/// One page of the browse list plus the numbers the page header needs.
class AuctionPage {
  const AuctionPage({
    required this.items,
    required this.total,
    required this.counts,
    required this.brands,
    this.categories = const <({String id, String name, int count})>[],
  });
  final List<AuctionView> items;
  final int total;
  final AuctionCounts counts;
  final List<({String name, int count})> brands;
  final List<({String id, String name, int count})> categories;
}

class AuctionCounts {
  const AuctionCounts(
      {this.live = 0, this.upcoming = 0, this.ended = 0, this.watching = 0});
  factory AuctionCounts.fromJson(Object? j) {
    final Map<String, dynamic> m =
        j is Map ? Map<String, dynamic>.from(j) : const <String, dynamic>{};
    return AuctionCounts(
      live: _n(m['live'])?.toInt() ?? 0,
      upcoming: _n(m['upcoming'])?.toInt() ?? 0,
      ended: _n(m['ended'])?.toInt() ?? 0,
      watching: _n(m['watching'])?.toInt() ?? 0,
    );
  }
  final int live;
  final int upcoming;
  final int ended;
  final int watching;

  AuctionCounts copyWith({int? watching}) => AuctionCounts(
      live: live,
      upcoming: upcoming,
      ended: ended,
      watching: watching ?? this.watching);
}

LiveAuctionData asLive(AuctionView v) => LiveAuctionData(v.raw, v.clockOffset);
