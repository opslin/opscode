import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/core/theme/product_card_tokens.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_state.dart';
import 'package:dealker_app/features/home/presentation/providers/manual_products_provider.dart';
import 'package:dealker_app/features/products/data/local/recently_viewed_datasource.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:dealker_app/shared/widgets/app_image.dart';
import 'package:dealker_app/shared/widgets/dealker_product_card.dart';
import 'package:dealker_app/shared/widgets/marketplace_product_box.dart';

/// Home-design blocks of `05-home-below-fold.jpg`: live auction, deal of the
/// day, recently viewed / recommended.
/// All wording and colours come from the section `config` set in the
/// dashboard theme builder (keys mirror `dashboard/.../dealerBlocks.ts`);
/// all numbers come from the API.

/// Defaults per block — identical to `DEALER_BLOCK_DEFAULTS` in the dashboard,
/// so a section saved without a value renders the same as its builder preview.
const Map<String, dynamic> kLiveAuctionDefaults = <String, dynamic>{
  'title': 'LIVE AUCTION',
  'subtitle': 'Real Bids · Genuine Buyers · Best Deals',
  'view_all_label': 'View All →',
  'button_label': 'Bid Now →',
  'header_bg_color': '#EEE9FB',
  'max_auctions': 4,
};
const Map<String, dynamic> kDealOfDayDefaults = <String, dynamic>{
  'title': 'DEAL OF THE DAY',
  'subtitle': '',
  'ends_label': 'Ends in',
  'view_all_label': 'View All →',
  'button_label': 'Grab Deal →',
  'bg_image_url': '',
  'header_bg_color': '#2B2FD6',
  'header_text_color': '#FFFFFF',
  'timer_bg_color': '#14146B',
  'timer_border_color': '#FFFFFF',
  'timer_text_color': '#FFFFFF',
  'view_all_bg_color': '#FFFFFF',
  'view_all_text_color': '#1F4FE0',
  'panel_color': '#FFFFFF',
  'grab_button_color': '#1B5BF2',
};
const Map<String, dynamic> kRecentRecommendedDefaults = <String, dynamic>{
  'left_title': 'Recently Viewed',
  'right_title': 'Recommended for You',
  'view_all_label': 'View All →',
};

String _s(Map<String, dynamic> c, String k, String d) {
  final v = c[k];
  return v is String ? v : d;
}

Color _c(Map<String, dynamic> c, String k, Color d) {
  final v = c[k];
  if (v is! String) return d;
  var h = v.replaceAll('#', '').trim();
  if (h.length == 3) h = h.split('').map((String e) => '$e$e').join();
  if (h.length == 6) h = 'FF$h';
  final int? n = int.tryParse(h, radix: 16);
  return n == null ? d : Color(n);
}

EdgeInsets get _outer => EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h);

String _two(int n) => n.toString().padLeft(2, '0');

/// Re-renders every second with the time left until [end].
class _Ticker extends StatefulWidget {
  const _Ticker({required this.end, required this.builder});

  final DateTime end;
  final Widget Function(BuildContext, Duration) builder;

  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Duration left = widget.end.difference(DateTime.now());
    return widget.builder(context, left.isNegative ? Duration.zero : left);
  }
}

// ── Live auction ────────────────────────────────────────────────────────

/// One live auction plus the offset between the server clock and this device,
/// so the countdown is right even when the phone's clock is off.
class LiveAuctionData {
  const LiveAuctionData(this.auction, this.clockOffset);

  final Map<String, dynamic> auction;
  final Duration clockOffset;

  DateTime get now => DateTime.now().add(clockOffset);
}

/// Default number of live auctions on Home; the section's `max_auctions` (dashboard theme builder) overrides it.
const int kLiveAuctionDefaultMax = 4;

/// Reads `max_auctions` from the section config, kept within 1..12.
int liveAuctionMax(Map<String, dynamic> config) {
  final dynamic v = config['max_auctions'];
  final int? n = v is num ? v.toInt() : int.tryParse('$v');
  return (n ?? kLiveAuctionDefaultMax).clamp(1, 12);
}

Future<List<LiveAuctionData>> _fetchAuctions(
  Ref ref,
  String tab,
  int limit,
) async {
  final dio = ref.watch(dioClientProvider);
  final response = await dio.get<dynamic>(
    '/auctions',
    queryParameters: <String, dynamic>{'tab': tab, 'limit': limit},
  );
  final body = response.data;
  if (body is! Map || body['data'] is! List) return const <LiveAuctionData>[];
  final DateTime? server = DateTime.tryParse('${body['server_time']}');
  final Duration offset =
      server == null ? Duration.zero : server.difference(DateTime.now());
  return <LiveAuctionData>[
    for (final dynamic row in body['data'] as List)
      if (row is Map) LiveAuctionData(Map<String, dynamic>.from(row), offset),
  ];
}

/// Live auctions for the Home strip (nearest-ending first, at most `limit`).
/// Open to guests; watching / bidding need a login.
final liveAuctionProvider =
    FutureProvider.autoDispose.family<List<LiveAuctionData>, int>(
  (Ref ref, int limit) => _fetchAuctions(ref, 'live', limit),
);

/// Every live auction, for the full Auctions screen.
final allLiveAuctionsProvider =
    FutureProvider.autoDispose<List<LiveAuctionData>>(
  (Ref ref) => _fetchAuctions(ref, 'live', 50),
);

class LiveAuctionSection extends ConsumerStatefulWidget {
  const LiveAuctionSection({required this.config, super.key});

  final Map<String, dynamic> config;

  @override
  ConsumerState<LiveAuctionSection> createState() => _LiveAuctionSectionState();
}

class _LiveAuctionSectionState extends ConsumerState<LiveAuctionSection> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Bids and anti-snipe extensions change the price/end time: refresh often.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) ref.invalidate(liveAuctionProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> config = widget.config;
    final List<LiveAuctionData> list =
        ref.watch(liveAuctionProvider(liveAuctionMax(config))).asData?.value ??
            const <LiveAuctionData>[];
    if (list.isEmpty) return const SizedBox.shrink();
    if (list.length == 1) {
      return Padding(
        padding: _outer,
        child: AuctionCard(config: config, data: list.first),
      );
    }
    // Several live auctions: swipe sideways (the next one peeks in) and a
    // "View All" tile at the end opens the Auctions screen.
    final double w = MediaQuery.sizeOf(context).width;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final LiveAuctionData d in list) ...<Widget>[
              SizedBox(
                width: w * 0.88,
                child: AuctionCard(config: config, data: d),
              ),
              SizedBox(width: 10.w),
            ],
            SizedBox(
              width: w * 0.34,
              child: _ViewAllTile(config: config),
            ),
          ],
        ),
      ),
    );
  }
}

/// Last tile of the Home strip: opens the full Auctions screen.
class _ViewAllTile extends StatelessWidget {
  const _ViewAllTile({required this.config});

  final Map<String, dynamic> config;

  @override
  Widget build(BuildContext context) {
    final Color text = _c(config, 'text_color', const Color(0xFF1B1B4B));
    final Color button = _c(config, 'button_color', const Color(0xFF4F3FE0));
    final String label = _s(
      config,
      'view_all_label',
      'View All →',
    ).replaceAll('→', '').trim();
    return GestureDetector(
      onTap: () => context.push('/auctions'),
      child: Container(
        decoration: BoxDecoration(
          color: _c(config, 'bg_color', Colors.white),
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(color: button, shape: BoxShape.circle),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 24.w,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              label.isEmpty ? 'View All' : label,
              style: TextStyle(
                color: text,
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Live auctions',
              style: TextStyle(
                color: text.withValues(alpha: 0.6),
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One live-auction card (Home strip and the Auctions screen).
class AuctionCard extends ConsumerStatefulWidget {
  const AuctionCard({
    required this.config,
    required this.data,
    this.showHeader = true,
    super.key,
  });

  final Map<String, dynamic> config;
  final LiveAuctionData data;

  /// The "LIVE AUCTION … View All" strip on top; hidden on the full Auctions screen.
  final bool showHeader;

  @override
  ConsumerState<AuctionCard> createState() => _AuctionCardState();
}

class _AuctionCardState extends ConsumerState<AuctionCard> {
  bool? _watchOverride;

  Future<void> _toggleWatch(String id, bool watching) async {
    if (ref.read(authStateProvider) is! AuthAuthenticated) {
      AppToast.show(context, 'Log in to watch auctions');
      return;
    }
    setState(() => _watchOverride = !watching);
    try {
      final dio = ref.read(dioClientProvider);
      if (watching) {
        await dio.delete<dynamic>('/auctions/$id/watch');
      } else {
        await dio.post<dynamic>('/auctions/$id/watch');
      }
    } catch (_) {
      if (mounted) setState(() => _watchOverride = watching);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> config = widget.config;
    final LiveAuctionData data = widget.data;
    final Map<String, dynamic> a = data.auction;

    final Color text = _c(config, 'text_color', const Color(0xFF1B1B4B));
    final Color live = _c(config, 'live_color', const Color(0xFFE0262F));
    final Color button = _c(config, 'button_color', const Color(0xFF4F3FE0));
    final Color winning = _c(config, 'winning_color', const Color(0xFF1FB454));
    final Color headerBg = _c(
      config,
      'header_bg_color',
      const Color(0xFFEEE9FB),
    );
    final num price = (a['current_price'] as num?) ?? 0;
    final num? increment = a['increment'] as num?;
    final int bids = (a['bid_count'] as num?)?.toInt() ?? 0;
    final DateTime? end = DateTime.tryParse('${a['ends_at']}');
    final DateTime? start = DateTime.tryParse('${a['starts_at']}');
    final bool leading = (a['my'] is Map) && a['my']['is_leading'] == true;
    final bool watching = _watchOverride ?? (a['watching'] == true);
    final String? image = a['image_url'] as String?;
    final String seller =
        (a['seller'] is Map) ? '${a['seller']['name'] ?? ''}' : '';
    final String reserve = '${a['reserve_status'] ?? 'NONE'}';
    void open() => context.push('/auctions/${a['id']}');

    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: _c(config, 'bg_color', Colors.white),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        children: <Widget>[
          // Header strip (Home only)
          if (widget.showHeader) ...<Widget>[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[headerBg, Colors.white],
                ),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: <Widget>[
                  PhosphorIcon(
                    PhosphorIcons.gavelFill,
                    size: 26.w,
                    color: button,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              _s(config, 'title', 'LIVE AUCTION'),
                              style: TextStyle(
                                color: text,
                                fontSize: 15.sp,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 1.5.h,
                              ),
                              decoration: BoxDecoration(
                                color: live,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  PhosphorIcon(
                                    PhosphorIcons.playFill,
                                    size: 7.w,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 2.w),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _s(config, 'subtitle', ''),
                          style: TextStyle(
                            color: text.withValues(alpha: 0.85),
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/auctions'),
                    child: Text(
                      _s(config, 'view_all_label', 'View All →'),
                      style: TextStyle(
                        color: button,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
          ],
          // Body
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 78.w,
                height: 82.w,
                decoration: BoxDecoration(
                  color: headerBg.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: headerBg),
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.all(6.w),
                        child: image == null
                            ? const SizedBox.shrink()
                            : AppImage(
                                imageUrl: ApiConstants.resolveMediaUrl(image) ??
                                    image,
                                memCacheWidth: 300,
                                memCacheHeight: 300,
                                fit: BoxFit.contain,
                                placeholder: const SizedBox.shrink(),
                                errorWidget: const SizedBox.shrink(),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 3.w,
                      right: 3.w,
                      child: GestureDetector(
                        onTap: () => _toggleWatch('${a['id']}', watching),
                        child: PhosphorIcon(
                          watching
                              ? PhosphorIcons.heartFill
                              : PhosphorIcons.heart,
                          size: 16.w,
                          color: watching ? live : text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 5.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: live,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        '◆ LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 7.5.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      '${a['title'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: text,
                        fontSize: 10.5.sp,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (seller.isNotEmpty)
                      Text(
                        seller,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: text.withValues(alpha: 0.6),
                          fontSize: 8.5.sp,
                        ),
                      ),
                    SizedBox(height: 4.h),
                    Text(
                      bids > 0 ? 'Highest Bid' : 'Starting Bid',
                      style: TextStyle(
                        color: text.withValues(alpha: 0.75),
                        fontSize: 9.sp,
                      ),
                    ),
                    Text(
                      MarketplaceProductBox.inr(price),
                      style: TextStyle(
                        color: text,
                        fontSize: 16.sp,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (leading)
                      Container(
                        margin: EdgeInsets.only(top: 4.h),
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: winning,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            PhosphorIcon(
                              PhosphorIcons.coinsFill,
                              size: 10.w,
                              color: const Color(0xFFFFE066),
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              'You are Winning',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                flex: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(height: 30.h),
                    if (increment != null) ...<Widget>[
                      Text(
                        'Bid Increment',
                        style: TextStyle(
                          color: text.withValues(alpha: 0.75),
                          fontSize: 8.5.sp,
                        ),
                      ),
                      Text(
                        MarketplaceProductBox.inr(increment),
                        style: TextStyle(
                          color: text,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (end != null)
                      _Ticker(
                        end: end.subtract(data.clockOffset),
                        builder: (BuildContext _, Duration left) {
                          if (left == Duration.zero) {
                            // Auction ended: drop it on the next poll.
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) ref.invalidate(liveAuctionProvider);
                            });
                          }
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              PhosphorIcon(
                                PhosphorIcons.clockFill,
                                size: 12.w,
                                color: live,
                              ),
                              SizedBox(width: 3.w),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _left(left),
                                    style: TextStyle(
                                      color: live,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    SizedBox(height: 10.h),
                    GestureDetector(
                      onTap: open,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 9.h),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              button,
                              Color.lerp(
                                button,
                                const Color(0xFF3B82F6),
                                0.55,
                              )!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(11.r),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _s(config, 'button_label', 'Bid Now →'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          // Footer: bids, time progress, reserve status
          Row(
            children: <Widget>[
              PhosphorIcon(PhosphorIcons.usersFill, size: 12.w, color: text),
              SizedBox(width: 4.w),
              Text(
                '$bids ${bids == 1 ? 'bid' : 'bids'}',
                style: TextStyle(
                  color: text,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _TimeBar(
                  start: start,
                  end: end,
                  now: () => data.now,
                  color: button,
                ),
              ),
              if (reserve != 'NONE') ...<Widget>[
                SizedBox(width: 10.w),
                Text(
                  reserve == 'MET' ? 'Reserve met' : 'Reserve not met',
                  style: TextStyle(
                    color: reserve == 'MET'
                        ? winning
                        : text.withValues(alpha: 0.65),
                    fontSize: 8.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String _left(Duration d) {
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h left';
  if (d.inHours >= 1) return '${d.inHours}h ${_two(d.inMinutes % 60)}m left';
  return '${d.inMinutes}m ${_two(d.inSeconds % 60)}s left';
}

/// Elapsed share of the auction's scheduled window (not the reserve — the API
/// never exposes the reserve price).
class _TimeBar extends StatelessWidget {
  const _TimeBar({
    required this.start,
    required this.end,
    required this.now,
    required this.color,
  });

  final DateTime? start;
  final DateTime? end;
  final DateTime Function() now;
  final Color color;

  @override
  Widget build(BuildContext context) {
    double value = 0;
    if (start != null && end != null) {
      final int total = end!.difference(start!).inMilliseconds;
      if (total > 0) {
        value = (now().difference(start!).inMilliseconds / total).clamp(
          0.0,
          1.0,
        );
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 5.h,
        backgroundColor: color.withValues(alpha: 0.12),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

// ── Deal of the day ─────────────────────────────────────────────────────

/// Festive deals block (`docs/design/06-diwali-deals-reference.jpg`): the
/// dashboard-uploaded background art carries the title, the app draws the
/// bordered "Ends in" timer + View All over it, and the deals sit in a white
/// panel as Dealkr product cards. Every size is a share of the section width
/// measured from the 1448 px reference, so it looks the same on any phone.
class DealOfDaySection extends StatelessWidget {
  const DealOfDaySection({
    required this.config,
    required this.products,
    super.key,
  });

  final Map<String, dynamic> config;
  final List<ProductEntity> products;

  /// Reference width in design px (the background art is 1448 x 1086).
  static const double _refW = 1448;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final String bgUrl = _s(config, 'bg_image_url', '').trim();
    final Color headerBg = _c(
      config,
      'header_bg_color',
      const Color(0xFF2B2FD6),
    );
    final Color headerText = _c(config, 'header_text_color', Colors.white);
    final Color timerBg = _c(config, 'timer_bg_color', const Color(0xFF14146B));
    final Color timerBorder = _c(config, 'timer_border_color', Colors.white);
    final Color timerText = _c(config, 'timer_text_color', Colors.white);
    final Color viewBg = _c(config, 'view_all_bg_color', Colors.white);
    final Color viewText = _c(
      config,
      'view_all_text_color',
      const Color(0xFF1F4FE0),
    );
    final Color panel = _c(config, 'panel_color', Colors.white);
    final Color button = _c(
      config,
      'grab_button_color',
      ProductCardTokens.blue,
    );
    final DateTime now = DateTime.now();
    final DateTime end =
        DateTime.tryParse(_s(config, 'ends_at', ''))?.toLocal() ??
            DateTime(now.year, now.month, now.day + 1);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double w = box.maxWidth;
        final double s = w / _refW; // one reference pixel
        final double headerH = 285 * s;
        final double side = 45 * s;
        final double pad = math.max(20 * s, 8);
        const double gap = 12;
        // Same size as the product-carousel cards: the next card peeks in.
        final double cardW = (MediaQuery.sizeOf(context).width * 0.6)
            .clamp(220.0, 280.0)
            .toDouble();
        final DealkerCardSlots slots = DealkerCardSlots.forProducts(
          products,
          cardW,
        );
        final double cardH = slots.heightFor(cardW);
        final double panelH = cardH + 2 * pad;
        final double totalH = headerH + panelH + 26 * s;
        final ProductEntity first = products.first;

        void viewAll() {
          final String? cat = first.categoryId;
          if (cat != null && cat.isNotEmpty) {
            context.push('/categories/$cat/products');
          } else {
            AppToast.show(context, 'Coming soon');
          }
        }

        return SizedBox(
          width: w,
          height: totalH,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        headerBg,
                        Color.lerp(
                          headerBg,
                          Colors.black,
                          bgUrl.isEmpty ? 0.35 : 0.1,
                        )!,
                      ],
                    ),
                  ),
                ),
              ),
              // The art keeps its own proportions (1448 x 1086) from the top;
              // its lower edge fades into the header colour behind the panel.
              if (bgUrl.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: math.min(w * 1086 / _refW, totalH),
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (Rect r) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: <double>[0, 0.72, 1],
                    ).createShader(r),
                    child: AppImage(
                      imageUrl: ApiConstants.resolveMediaUrl(bgUrl) ?? bgUrl,
                      memCacheWidth: 1200,
                      memCacheHeight: 900,
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      placeholder: const SizedBox.shrink(),
                      errorWidget: const SizedBox.shrink(),
                    ),
                  ),
                ),
              // Title text only when there is no artwork (the art carries it).
              if (bgUrl.isEmpty)
                Positioned(
                  left: 60 * s,
                  top: 70 * s,
                  width: w * 0.5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _s(config, 'title', 'DEAL OF THE DAY'),
                          maxLines: 1,
                          style: TextStyle(
                            color: headerText,
                            fontSize: math.max(88 * s, 18),
                            height: 1.0,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (_s(config, 'subtitle', '').isNotEmpty)
                        Text(
                          _s(config, 'subtitle', ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: headerText.withValues(alpha: 0.85),
                            fontSize: math.max(40 * s, 10),
                          ),
                        ),
                    ],
                  ),
                ),
              // Timer + View All capsule (top right of the art).
              Positioned(
                right: 28 * s,
                top: 128 * s,
                height: 112 * s,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10 * s),
                  decoration: BoxDecoration(
                    color: timerBg.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: timerBorder.withValues(alpha: 0.25),
                      width: math.max(1.5 * s, 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _EndsInPill(
                        end: end,
                        s: s,
                        label: _s(config, 'ends_label', 'Ends in'),
                        bg: timerBg,
                        border: timerBorder,
                        text: timerText,
                      ),
                      Container(
                        width: math.max(2 * s, 0.7),
                        height: 62 * s,
                        margin: EdgeInsets.symmetric(horizontal: 14 * s),
                        color: timerBorder.withValues(alpha: 0.3),
                      ),
                      GestureDetector(
                        onTap: viewAll,
                        child: Container(
                          height: 82 * s,
                          padding: EdgeInsets.symmetric(horizontal: 22 * s),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: viewBg,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 14 * s,
                                offset: Offset(0, 6 * s),
                              ),
                            ],
                          ),
                          child: Text(
                            _s(config, 'view_all_label', 'View All →'),
                            style: TextStyle(
                              color: viewText,
                              fontSize: math.max(36 * s, 10),
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // White panel with the deal cards.
              Positioned(
                left: side,
                right: side,
                top: headerH,
                height: panelH,
                child: Container(
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(46 * s),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 30 * s,
                        offset: Offset(0, 10 * s),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(46 * s),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.all(pad),
                      itemCount: products.length,
                      separatorBuilder: (_, __) => SizedBox(width: gap),
                      itemBuilder: (BuildContext _, int i) =>
                          DealkerProductCard(
                        product: products[i],
                        width: cardW,
                        nameLines: slots.nameLines,
                        showSoldRow: slots.showSold,
                        showRatingRow: slots.showRating,
                        buttonLabel: _s(
                          config,
                          'button_label',
                          'Grab Deal →',
                        ),
                        buttonColor: button,
                        onTap: () => context.push('/product/${products[i].id}'),
                        onOptionsTap: products[i].hasMultipleOptions
                            ? () => showProductOptionsSheet(
                                  context,
                                  products[i],
                                )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Stopwatch icon + "Ends in" over HH:MM:SS inside a bordered capsule.
class _EndsInPill extends StatelessWidget {
  const _EndsInPill({
    required this.end,
    required this.s,
    required this.label,
    required this.bg,
    required this.border,
    required this.text,
  });

  final DateTime end;
  final double s;
  final String label;
  final Color bg;
  final Color border;
  final Color text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 98 * s,
      padding: EdgeInsets.symmetric(horizontal: 24 * s),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border, width: math.max(3 * s, 1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PhosphorIcon(
            PhosphorIcons.timer,
            size: math.max(54 * s, 14),
            color: text,
          ),
          SizedBox(width: 16 * s),
          _Ticker(
            end: end,
            builder: (BuildContext _, Duration left) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    color: text.withValues(alpha: 0.85),
                    fontSize: math.max(25 * s, 7.5),
                    height: 1,
                  ),
                ),
                Text(
                  '${_two(left.inHours)}:${_two(left.inMinutes % 60)}:${_two(left.inSeconds % 60)}',
                  style: TextStyle(
                    color: text,
                    fontSize: math.max(40 * s, 11),
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recently viewed & recommended ───────────────────────────────────────

class RecentRecommendedSection extends ConsumerWidget {
  const RecentRecommendedSection({
    required this.config,
    required this.products,
    super.key,
  });

  final Map<String, dynamic> config;
  final List<ProductEntity> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> ids =
        const RecentlyViewedDataSource().getAll().take(3).toList();
    final List<ProductEntity> recent = ids.isEmpty
        ? const <ProductEntity>[]
        : (ref
                .watch(manualProductsByIdsProvider(ids.join(',')))
                .asData
                ?.value ??
            const <ProductEntity>[]);
    final List<ProductEntity> recommended = products.take(3).toList();
    if (recent.isEmpty && recommended.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: _outer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (recent.isNotEmpty)
            Expanded(
              child: _MiniList(
                title: _s(config, 'left_title', 'Recently Viewed'),
                config: config,
                items: recent,
              ),
            ),
          if (recent.isNotEmpty && recommended.isNotEmpty) SizedBox(width: 8.w),
          if (recommended.isNotEmpty)
            Expanded(
              child: _MiniList(
                title: _s(config, 'right_title', 'Recommended for You'),
                config: config,
                items: recommended,
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniList extends StatelessWidget {
  const _MiniList({
    required this.title,
    required this.config,
    required this.items,
  });

  final String title;
  final Map<String, dynamic> config;
  final List<ProductEntity> items;

  @override
  Widget build(BuildContext context) {
    final Color text = _c(config, 'text_color', const Color(0xFF111111));
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: _c(config, 'bg_color', Colors.white),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _s(config, 'view_all_label', 'View All →'),
                style: TextStyle(
                  color: text.withValues(alpha: 0.7),
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: <Widget>[
              for (final ProductEntity p in items)
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/product/${p.id}'),
                    child: Column(
                      children: <Widget>[
                        SizedBox(
                          height: 38.h,
                          child: Builder(
                            builder: (BuildContext _) {
                              final OptimizedMediaAsset m =
                                  ApiConstants.optimizedMedia(
                                p.thumbnailUrl ??
                                    (p.images.isNotEmpty
                                        ? p.images.first
                                        : null),
                                profile: CustomerImageProfile.listProduct,
                              );
                              return m.url == null
                                  ? const SizedBox.shrink()
                                  : AppImage(
                                      imageUrl: m.url!,
                                      memCacheWidth: m.memCacheWidth,
                                      memCacheHeight: m.memCacheHeight,
                                      fit: BoxFit.contain,
                                      placeholder: const SizedBox.shrink(),
                                      errorWidget: const SizedBox.shrink(),
                                    );
                            },
                          ),
                        ),
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: text,
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          MarketplaceProductBox.inr(p.effectivePrice),
                          style: TextStyle(
                            color: text,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
