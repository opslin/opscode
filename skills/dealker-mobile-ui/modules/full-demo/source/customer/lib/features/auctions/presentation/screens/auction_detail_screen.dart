import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:dealker_app/shared/widgets/loading/dealker_page_loader.dart';
import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/core/utils/server_error.dart';
import 'package:dealker_app/core/utils/extensions/double_extensions.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:dealker_app/features/auctions/presentation/widgets/auction_checkout_sheet.dart';
import 'package:dealker_app/features/auctions/presentation/widgets/auction_media_gallery.dart';
import 'package:dealker_app/features/home/presentation/widgets/dealer_blocks.dart';
import 'package:dealker_app/features/payments/presentation/providers/payment_provider.dart';
import 'package:dealker_app/features/payments/presentation/service/razorpay_service.dart';
import 'package:dealker_app/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:dealker_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:dealker_app/routing/app_router.dart' show currentUserProvider;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:dealker_app/routing/route_names.dart';
import 'package:dealker_app/shared/widgets/web_service_frame.dart';

const Color _ink = Color(0xFF001F5F);
const Color _accent = Color(0xFF1558E8);
const Color _live = Color(0xFFE0262F);
const Color _good = Color(0xFF1FB454);
const Color _bg = Color(0xFFF3F6FF);

typedef AuctionApiError = ServerError;

/// One auction, fetched fresh and refreshed every few seconds while it is live.
final auctionDetailProvider = FutureProvider.autoDispose
    .family<LiveAuctionData, String>((Ref ref, String id) async {
  final dio = ref.watch(dioClientProvider);
  final response = await dio.get<dynamic>('/auctions/$id');
  final dynamic body = response.data;
  final dynamic data = body is Map ? body['data'] : null;
  if (data is! Map) throw StateError('Auction not found');
  final DateTime? server = DateTime.tryParse('${data['server_time']}');
  return LiveAuctionData(
    Map<String, dynamic>.from(data),
    server == null ? Duration.zero : server.difference(DateTime.now()),
  );
});

final auctionBidsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((Ref ref, String id) async {
  final dio = ref.watch(dioClientProvider);
  final response = await dio.get<dynamic>('/auctions/$id/bids',
      queryParameters: <String, dynamic>{'limit': 20});
  final dynamic data =
      response.data is Map ? (response.data as Map)['data'] : null;
  return <Map<String, dynamic>>[
    if (data is List)
      for (final dynamic r in data)
        if (r is Map) Map<String, dynamic>.from(r),
  ];
});

class AuctionDetailScreen extends ConsumerStatefulWidget {
  const AuctionDetailScreen({required this.auctionId, super.key});

  final String auctionId;

  @override
  ConsumerState<AuctionDetailScreen> createState() =>
      _AuctionDetailScreenState();
}

class _AuctionDetailScreenState extends ConsumerState<AuctionDetailScreen> {
  Timer? _poll;
  Timer? _tick;
  bool _busy = false;
  bool? _watchOverride;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _busy) return;
      ref.invalidate(auctionDetailProvider(widget.auctionId));
      ref.invalidate(auctionBidsProvider(widget.auctionId));
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(auctionDetailProvider(widget.auctionId));
    ref.invalidate(auctionBidsProvider(widget.auctionId));
  }

  Future<bool> _needLogin(String what) {
    return ref.read(authGateControllerProvider).protectRoute(
          context,
          route: '/auctions/${widget.auctionId}',
          title: 'Log in to $what',
          message: 'Please log in to take part in auctions.',
        );
  }

  Future<void> _toggleWatch(bool watching) async {
    if (!await _needLogin('watch auctions') || !mounted) return;
    setState(() => _watchOverride = !watching);
    try {
      final dio = ref.read(dioClientProvider);
      if (watching) {
        await dio.delete<dynamic>('/auctions/${widget.auctionId}/watch');
      } else {
        await dio.post<dynamic>('/auctions/${widget.auctionId}/watch');
      }
    } catch (_) {
      if (mounted) setState(() => _watchOverride = watching);
    }
  }

  Future<double> _walletBalance() async {
    try {
      final r = await ref.read(dioClientProvider).get<dynamic>('/wallet');
      final d = r.data is Map ? (r.data as Map)['data'] : null;
      return d is Map ? ((d['balance'] as num?) ?? 0).toDouble() : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Pays [amount] through Razorpay into the wallet (existing top-up flow). True when the money landed.
  Future<bool> _topUpOnline(double amount) async {
    final service = ref.read(razorpayServiceProvider);
    final result =
        await ref.read(walletProvider.notifier).createTopupOrder(amount);
    if (!mounted) return false;
    if (!result.isSuccess || result.order == null) {
      AppToast.show(context, result.failure?.message ?? 'Payment could not start');
      return false;
    }
    final order = result.order!;
    final user = ref.read(currentUserProvider);
    final done = Completer<bool>();
    service
      ..onSuccess = (PaymentSuccessResponse r) async {
        final ok = r.paymentId != null && r.signature != null
            ? await ref.read(walletProvider.notifier).verifyTopup(
                  WalletTopupVerifyParams(
                      paymentId: r.paymentId!,
                      orderId: order.razorpayOrderId,
                      signature: r.signature!),
                )
            : null;
        if (!done.isCompleted) done.complete(ok?.isSuccess == true);
        if (ok != null && !ok.isSuccess && mounted) {
          AppToast.show(context, ok.failure!.message);
        }
      }
      ..onFailure = (PaymentFailureResponse r) {
        final m = r.message?.trim();
        if (mounted) {
          AppToast.show(context,
              m == null || m.isEmpty ? 'Payment cancelled or failed.' : m);
        }
        if (!done.isCompleted) done.complete(false);
      }
      ..onExternalWallet = (_) {};
    try {
      service.open(RazorpayOptions(
        key: order.key,
        amount: order.amount,
        razorpayOrderId: order.razorpayOrderId,
        name: 'Dealkr',
        description: 'Auction registration fee',
        contact: user?.phone,
        email: user?.email,
        prefillName: user?.name,
        themeColorHex: '#4F3FE0',
      ));
    } catch (_) {
      if (mounted) AppToast.show(context, 'Unable to open Razorpay right now.');
      return false;
    }
    final ok = await done.future;
    service
      ..onSuccess = null
      ..onFailure = null
      ..onExternalWallet = null;
    return ok;
  }

  Future<void> _join(Map<String, dynamic> a) async {
    if (!await _needLogin('join this auction') || !mounted) return;
    final num fee = (a['registration_fee'] as num?) ?? 0;
    final double balance = fee > 0 ? await _walletBalance() : 0;
    if (!mounted) return;
    final String? method = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (BuildContext c) => _JoinSheet(
        fee: fee,
        balance: balance,
        policy: '${a['fee_policy'] ?? ''}',
      ),
    );
    if (method == null || !mounted) return;
    await _run(() async {
      if (fee > 0 && method == 'RAZORPAY') {
        // Pay only what the wallet is short of (Razorpay needs at least ₹10); the fee is then taken from the wallet.
        final double need = (fee.toDouble() - balance);
        if (need > 0) {
          final double amount = need < 10 ? 10 : need.ceilToDouble();
          if (!await _topUpOnline(amount)) return;
        }
      }
      await ref.read(dioClientProvider).post<dynamic>(
        '/auctions/${widget.auctionId}/register',
        data: <String, dynamic>{'consent': true},
      );
      if (mounted) AppToast.show(context, 'You have joined this auction', type: ToastType.success);
    }, walletHint: true);
  }

  Future<void> _bid(Map<String, dynamic> a) async {
    final num minNext = (a['min_next_bid'] as num?) ?? 0;
    final num inc = (a['increment'] as num?) ?? 1;
    final num? myMax = (a['my'] is Map) ? a['my']['my_max'] as num? : null;
    final double? amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (BuildContext c) => _BidSheet(
        minNext: minNext.toDouble(),
        increment: inc.toDouble(),
        myMax: myMax?.toDouble(),
      ),
    );
    if (amount == null || !mounted) return;
    await _run(() async {
      final Response<dynamic> r =
          await ref.read(dioClientProvider).post<dynamic>(
        '/auctions/${widget.auctionId}/bids',
        data: <String, dynamic>{'maxAmount': amount},
      );
      final dynamic d = r.data is Map ? (r.data as Map)['data'] : null;
      final bool leading = d is Map && d['you_are_leading'] == true;
      if (mounted) {
        AppToast.show(
          context,
          leading
              ? 'You are the highest bidder'
              : 'Bid placed, but someone has a higher maximum. Bid higher to lead.',
        );
      }
    });
  }

  Future<void> _buyNow(Map<String, dynamic> a) async {
    final num price = (a['buy_now_price'] as num?) ?? 0;
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext c) => AlertDialog(
            title: const Text('Buy now?'),
            content: Text(
              'You will win this auction immediately at ${price.toInrCurrency}. You can then pay for it.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Buy now'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    await _run(() async {
      await ref
          .read(dioClientProvider)
          .post<dynamic>('/auctions/${widget.auctionId}/buy-now');
      if (mounted)
        AppToast.show(context, 'You won this auction. Complete your payment.');
    });
  }

  Future<void> _pay(Map<String, dynamic> a) async {
    final bool done = await showAuctionCheckoutSheet(
      context,
      ref,
      auctionId: widget.auctionId,
      amountDue: ((a['my'] as Map)['amount_due'] as num?)?.toDouble() ?? 0,
    );
    if (done) _refresh();
  }

  Future<void> _run(Future<void> Function() action,
      {bool walletHint = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
    } catch (e) {
      final AuctionApiError err = AuctionApiError.from(e);
      if (!mounted) return;
      if (err.code == 'INSUFFICIENT_WALLET' && walletHint) {
        final bool add = await showDialog<bool>(
              context: context,
              builder: (BuildContext c) => AlertDialog(
                title: const Text('Add money to your wallet'),
                content: Text(
                  '${err.message}${err.shortfall != null ? '\n\nYou need ${err.shortfall!.toInrCurrency} more.' : ''}',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Not now'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Add money'),
                  ),
                ],
              ),
            ) ??
            false;
        if (add && mounted) context.push(RouteNames.topup);
      } else {
        AppToast.show(context, err.message);
      }
      _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _left(Duration d) {
    if (d.isNegative) return 'Ended';
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h left';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m left';
    return '${d.inMinutes}m ${(d.inSeconds % 60).toString().padLeft(2, '0')}s left';
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<LiveAuctionData> async =
        ref.watch(auctionDetailProvider(widget.auctionId));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(RouteNames.auctions),
        ),
        title: Text(
          'Auction',
          style: TextStyle(
            color: _ink,
            fontSize: 22.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: <Widget>[
          if (async.asData?.value case final LiveAuctionData d?)
            _livePill(d),
          SizedBox(width: 12.w),
        ],
      ),
      body: async.when(
        loading: () => const DealkerPageLoader(),
        error: (Object e, StackTrace _) => Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('This auction could not be loaded.'),
                SizedBox(height: 12.h),
                OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          ),
        ),
        data: (LiveAuctionData data) =>
            WebServiceFrame(panelColor: _bg, child: _body(data)),
      ),
    );
  }

  Widget _livePill(LiveAuctionData data) {
    final Map<String, dynamic> a = data.auction;
    final String status = '${a['status']}';
    final bool isLive = status == 'LIVE';
    final bool upcoming = status == 'SCHEDULED';
    final DateTime? target =
        DateTime.tryParse('${isLive ? a['ends_at'] : a['starts_at']}');
    final Duration t = (isLive || upcoming) && target != null
        ? target.difference(data.now)
        : Duration.zero;
    final Duration d = t.isNegative ? Duration.zero : t;
    String two(int n) => n.toString().padLeft(2, '0');
    final String clock = d.inDays > 0
        ? '${d.inDays}d ${two(d.inHours % 24)}h'
        : '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    final String label = isLive
        ? 'Live'
        : upcoming
            ? 'Starts in'
            : status.replaceAll('_', ' ');
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE3EAF7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isLive)
            Container(
              width: 9.w,
              height: 9.w,
              decoration:
                  const BoxDecoration(color: _live, shape: BoxShape.circle),
            ),
          if (isLive) SizedBox(width: 6.w),
          Text(label,
              style: TextStyle(
                  color: isLive ? _live : _ink,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800)),
          if (isLive || upcoming) ...<Widget>[
            SizedBox(width: 8.w),
            Icon(Icons.schedule_rounded, color: _ink, size: 15.sp),
            SizedBox(width: 4.w),
            Text(clock,
                style: TextStyle(
                    color: _ink,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures()
                    ])),
          ],
        ],
      ),
    );
  }

  Widget _body(LiveAuctionData data) {
    final Map<String, dynamic> a = data.auction;
    final String status = '${a['status']}';
    final Map<String, dynamic> my = a['my'] is Map
        ? Map<String, dynamic>.from(a['my'] as Map)
        : <String, dynamic>{};
    final bool registered = my['registered'] == true;
    final bool leading = my['is_leading'] == true;
    final bool winner = my['is_winner'] == true;
    final bool watching = _watchOverride ?? (a['watching'] == true);
    final bool isLive = status == 'LIVE';
    final bool upcoming = status == 'SCHEDULED';
    final num current = (a['current_price'] as num?) ?? 0;
    final num minNext = (a['min_next_bid'] as num?) ?? 0;
    final num? buyNow = a['buy_now_price'] as num?;
    final int bids = (a['bid_count'] as num?)?.toInt() ?? 0;
    final DateTime? ends = DateTime.tryParse('${a['ends_at']}');
    final DateTime? starts = DateTime.tryParse('${a['starts_at']}');
    final Duration left = isLive && ends != null
        ? ends.difference(data.now)
        : upcoming && starts != null
            ? starts.difference(data.now)
            : Duration.zero;
    final List<String> images = <String>[
      for (final dynamic i in (a['images'] as List? ?? const <dynamic>[])) '$i',
    ];
    if (images.isEmpty && a['image_url'] != null)
      images.add('${a['image_url']}');
    final String seller =
        a['seller'] is Map ? '${a['seller']['name'] ?? ''}' : '';

    return Stack(
      children: <Widget>[
        RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 130.h),
            children: <Widget>[
              AuctionMediaGallery(
                images: images,
                videoUrl: '${a['video_url'] ?? ''}'.isEmpty
                    ? null
                    : '${a['video_url']}',
                qc: AuctionQc.from(a['qc_report']),
                overlay: GestureDetector(
                  onTap: () => _toggleWatch(watching),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(
                      watching ? Icons.favorite : Icons.favorite_border,
                      color: watching ? _live : _ink,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Row(
                children: <Widget>[
                  _chip(
                    isLive
                        ? 'LIVE'
                        : upcoming
                            ? 'STARTS SOON'
                            : status.replaceAll('_', ' '),
                    isLive ? _live : _accent,
                  ),
                  const Spacer(),
                  if (isLive || upcoming)
                    Text(
                      upcoming
                          ? 'Starts in ${_left(left).replaceAll(' left', '')}'
                          : _left(left),
                      style: TextStyle(
                        color: _live,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                '${a['title']}',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (seller.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Text(
                    'Sold by $seller',
                    style: TextStyle(color: Colors.black54, fontSize: 13.sp),
                  ),
                ),
              SizedBox(height: 14.h),
              _priceHero(
                a: a,
                bids: bids,
                current: current,
                isLive: isLive,
                upcoming: upcoming,
                left: left,
                minNext: minNext,
              ),
              if (registered)
                _statusCard(
                  winner: winner,
                  leading: leading,
                  isLive: isLive,
                  bids: bids,
                  status: status,
                  my: my,
                ),
              if (winner &&
                  (status == 'AWAITING_PAYMENT' || status == 'SOLD'))
                _chatCard('${a['title']}'),
              SizedBox(height: 14.h),
              if ('${a['description'] ?? ''}'.trim().isNotEmpty)
                _infoCard('About this item', '${a['description']}',
                    'assets/cart/notepad.png'),
              if ('${a['fee_policy'] ?? ''}'.isNotEmpty)
                _infoCard('Registration fee', '${a['fee_policy']}',
                    'assets/auction/fee.png'),
              _BidHistory(auctionId: widget.auctionId),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _actionBar(
            a: a,
            status: status,
            registered: registered,
            winner: winner,
            buyNow: buyNow,
            my: my,
          ),
        ),
      ],
    );
  }

  Widget _priceHero({
    required Map<String, dynamic> a,
    required int bids,
    required num current,
    required bool isLive,
    required bool upcoming,
    required Duration left,
    required num minNext,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF00205F), Color(0xFF0B3BA8), _accent],
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _accent.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -30.w,
            top: -40.h,
            child: Container(
              width: 190.w,
              height: 190.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 16.h, 14.w, 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            bids > 0 ? 'Current bid' : 'Starting bid',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    current.toInrCurrency,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 38.sp,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                              if (bids > 0) ...<Widget>[
                                SizedBox(width: 8.w),
                                Container(
                                  width: 28.w,
                                  height: 28.w,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFB800),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.arrow_upward_rounded,
                                      color: _ink, size: 18.sp),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Image.asset('assets/auction/keep_bidding.png',
                        width: 104.w,
                        height: 104.w,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ],
                ),
                SizedBox(height: 10.h),
                Divider(
                    height: 1, color: Colors.white.withValues(alpha: 0.25)),
                SizedBox(height: 12.h),
                IntrinsicHeight(
                  child: Row(
                    children: <Widget>[
                      _heroStat(Icons.gavel_rounded, 'Bids', '$bids'),
                      _statDivider(),
                      _heroStat(Icons.groups_rounded, 'Bidders',
                          '${a['bidder_count'] ?? 0}'),
                      _statDivider(),
                      _heroStat(
                          Icons.trending_up_rounded,
                          'Increment',
                          ((a['increment'] as num?) ?? 0).toInrCurrency,
                          iconColor: const Color(0xFF3DDC84)),
                    ],
                  ),
                ),
                if (isLive) ...<Widget>[
                  SizedBox(height: 12.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.trending_up_rounded,
                            color: const Color(0xFFFFC400), size: 18.sp),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            'Next minimum bid: ${minNext.toInrCurrency}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if ('${a['reserve_status']}' == 'NOT_MET')
                  Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: Text(
                      'Reserve price not met yet',
                      style: TextStyle(
                          color: const Color(0xFFFFC400), fontSize: 12.sp),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(
        width: 1,
        margin: EdgeInsets.symmetric(horizontal: 10.w),
        color: Colors.white.withValues(alpha: 0.25),
      );

  Widget _heroStat(IconData icon, String l, String v, {Color? iconColor}) =>
      Expanded(
        child: Row(
          children: <Widget>[
            Icon(icon, color: iconColor ?? Colors.white, size: 22.sp),
            SizedBox(width: 6.w),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.sp)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      v,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _statusCard({
    required bool winner,
    required bool leading,
    required bool isLive,
    required int bids,
    required String status,
    required Map<String, dynamic> my,
  }) {
    final bool outbid = !winner && !leading && my['my_max'] != null && isLive;
    final Color c = winner || leading
        ? _good
        : outbid
            ? _live
            : _accent;
    final String title = winner
        ? 'You won this auction!'
        : leading
            ? 'You are the highest bidder'
            : outbid
                ? 'You have been outbid'
                : 'You are registered';
    final String sub = winner
        ? (status == 'AWAITING_PAYMENT'
            ? 'Pay ${((my['amount_due'] as num?) ?? 0).toInrCurrency} to complete your purchase.'
            : 'Congratulations. Your purchase is complete.')
        : leading
            ? 'Your max bid is ${((my['my_max'] as num?) ?? 0).toInrCurrency}.'
            : outbid
                ? 'Your max was ${((my['my_max'] as num).toInrCurrency)}. Bid again to lead.'
                : 'You are bidder #${my['bidder_no']}.';
    return Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.withValues(alpha: 0.10), Colors.white),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Image.asset(
            winner
                ? 'assets/auction/trophy.png'
                : leading
                ? 'assets/profile/crown.png'
                : 'assets/sell/timer.png',
            width: 52.w,
            height: 52.w,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: TextStyle(
                        color: _ink,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 2.h),
                Text(sub,
                    style: TextStyle(
                        color: Colors.black87, fontSize: 12.5.sp, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatCard(String title) => GestureDetector(
        onTap: () => context.push('/auctions/${widget.auctionId}/chat',
            extra: title),
        child: Container(
          margin: EdgeInsets.only(top: 12.h),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF3B82F6), _accent, Color(0xFF0B3AA8)],
            ),
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _accent.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Image.asset('assets/profile/chat.png',
                  width: 52.w, height: 52.w),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Chat with the seller',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.5.sp,
                            fontWeight: FontWeight.w800)),
                    Text('Ask about payment, packing and delivery',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12.sp)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
      );

  Widget _infoCard(String title, String body, String art) => Padding(
        padding: EdgeInsets.only(top: 12.h),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          child: InkWell(
            borderRadius: BorderRadius.circular(20.r),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              builder: (BuildContext c) => SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(c).size.height * 0.75),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title,
                            style: TextStyle(
                                color: _ink,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 10.h),
                        Text(body,
                            style: TextStyle(
                                color: Colors.black87,
                                fontSize: 14.sp,
                                height: 1.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child: Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: const Color(0xFFE3EAF7)),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 52.w,
                    height: 52.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    padding: EdgeInsets.all(7.w),
                    child: Image.asset(art,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.article_outlined,
                            color: _accent)),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title,
                            style: TextStyle(
                                color: _ink,
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 3.h),
                        Text(body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.black87,
                                fontSize: 13.5.sp,
                                height: 1.35)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: _accent, size: 28.sp),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _actionBar({
    required Map<String, dynamic> a,
    required String status,
    required bool registered,
    required bool winner,
    required num? buyNow,
    required Map<String, dynamic> my,
  }) {
    Widget? primary;
    Widget? secondary;
    String? note;

    if (winner && status == 'AWAITING_PAYMENT' && my['order_id'] == null) {
      primary = _btn('Pay ${((my['amount_due'] as num?) ?? 0).toInrCurrency}',
          () => _pay(a));
    } else if (winner && my['order_id'] != null) {
      primary = _btn('View my order',
          () => context.go('${RouteNames.orders}/${my['order_id']}'));
    } else if (status == 'LIVE' || status == 'SCHEDULED') {
      if (!registered) {
        final num fee = (a['registration_fee'] as num?) ?? 0;
        primary = _btn(
          fee > 0 ? 'Join auction · ${fee.toInrCurrency} fee' : 'Join auction',
          () => _join(a),
        );
      } else if (status == 'LIVE') {
        primary = _btn('Place bid', () => _bid(a));
        if (buyNow != null) {
          secondary = _btn('Buy now ${buyNow.toInrCurrency}', () => _buyNow(a),
              outlined: true);
        }
      } else {
        note = 'Bidding opens when the auction starts.';
      }
    } else {
      note = 'This auction has ended.';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 22.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(color: Color(0x14000000), blurRadius: 12)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (note != null)
            Text(note,
                style: TextStyle(color: Colors.black54, fontSize: 13.sp)),
          if (primary != null) primary,
          if (secondary != null) ...<Widget>[SizedBox(height: 8.h), secondary],
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap, {bool outlined = false}) {
    final Widget child = _busy
        ? SizedBox(
            width: 20.w,
            height: 20.w,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: outlined ? _accent : Colors.white,
            ),
          )
        : Text(
            label,
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800),
          );
    final ButtonStyle shape = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size.fromHeight(50.h)),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      ),
    );
    return outlined
        ? OutlinedButton(
            onPressed: _busy ? null : onTap,
            style: shape,
            child: child,
          )
        : FilledButton(
            onPressed: _busy ? null : onTap,
            style: shape.merge(
              FilledButton.styleFrom(backgroundColor: _accent),
            ),
            child: child,
          );
  }

  Widget _chip(String t, Color c) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(8.r)),
        child: Text(
          t,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _BidHistory extends ConsumerWidget {
  const _BidHistory({required this.auctionId});

  final String auctionId;

  static const List<Color> _avatar = <Color>[
    Color(0xFF1558E8),
    Color(0xFF0E7C86),
    Color(0xFF6B4EE6),
    Color(0xFFD9480F),
    Color(0xFF2B8A3E),
  ];

  static String _ago(dynamic at) {
    final DateTime? t = DateTime.tryParse('$at')?.toLocal();
    if (t == null) return '';
    final Duration d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} hr ago';
    return '${d.inDays} d ago';
  }

  static String _name(Map<String, dynamic> b) => b['is_you'] == true
      ? 'You'
      : '${b['username'] ?? b['alias'] ?? 'Bidder'}';

  // Rank 1 gold, 2 silver-blue, 3 bronze, the rest grey.
  static (Color, Color, Color) _rankColors(int rank) => switch (rank) {
        1 => (const Color(0xFFFFF0B8), const Color(0xFFE29A00), const Color(0xFF7A4B00)),
        2 => (const Color(0xFFE4ECF8), const Color(0xFF7C93B8), const Color(0xFF34476B)),
        3 => (const Color(0xFFF6DDD0), const Color(0xFFB8672E), const Color(0xFF6B3410)),
        _ => (const Color(0xFFECEFF4), const Color(0xFF8A94A6), const Color(0xFF4B5568)),
      };

  Widget _row(Map<String, dynamic> b, int rank, {bool first = false}) {
    final String name = _name(b);
    final String initial =
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final (Color bg, Color icon, Color fg) = _rankColors(rank);
    final String ago = _ago(b['at']);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      color: rank.isEven ? const Color(0xFFF7F9FE) : Colors.white,
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 22.r,
            backgroundColor: _avatar[(rank - 1) % _avatar.length],
            child: Text(initial,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: _ink,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 4.h),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                      color: bg, borderRadius: BorderRadius.circular(8.r)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                          rank <= 3
                              ? Icons.workspace_premium_rounded
                              : Icons.military_tech_rounded,
                          color: icon,
                          size: 15.sp),
                      SizedBox(width: 4.w),
                      Text('Rank #$rank',
                          style: TextStyle(
                              color: fg,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE8FF),
                  borderRadius: BorderRadius.circular(12.r),
                  border: first
                      ? Border.all(color: _accent.withValues(alpha: 0.5))
                      : null,
                ),
                child: Text(
                  ((b['amount'] as num?) ?? 0).toInrCurrency,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (ago.isNotEmpty) ...<Widget>[
                SizedBox(height: 3.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.schedule_rounded,
                        color: Colors.black45, size: 12.sp),
                    SizedBox(width: 3.w),
                    Text(ago,
                        style: TextStyle(
                            color: Colors.black54, fontSize: 11.5.sp)),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _all(BuildContext context, List<Map<String, dynamic>> bids) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (BuildContext c) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 10.h),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('All bids (${bids.length})',
                      style: TextStyle(
                          color: _ink,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: bids.length,
                  itemBuilder: (_, int i) => _row(bids[i], i + 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Map<String, dynamic>> bids =
        ref.watch(auctionBidsProvider(auctionId)).asData?.value ??
            const <Map<String, dynamic>>[];
    if (bids.isEmpty) return const SizedBox.shrink();
    final List<Map<String, dynamic>> top = bids.take(5).toList();
    return Padding(
      padding: EdgeInsets.only(top: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22.r),
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE3EAF7)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[Color(0xFF0B3BA8), _accent],
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.bar_chart_rounded,
                          color: const Color(0xFFFFB800), size: 24.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text('Recent Bids',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w800)),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDE8FF),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                            'Last ${top.length} ${top.length == 1 ? 'Bid' : 'Bids'}',
                            style: TextStyle(
                                color: _accent,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                for (int i = 0; i < top.length; i++)
                  _row(top[i], i + 1, first: i == 0),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          OutlinedButton(
            onPressed: () => _all(context, bids),
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(50.h),
              foregroundColor: _accent,
              side: const BorderSide(color: _accent, width: 1.6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26.r)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('View All Bids',
                    style: TextStyle(
                        fontSize: 16.sp, fontWeight: FontWeight.w800)),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinSheet extends StatefulWidget {
  const _JoinSheet(
      {required this.fee, required this.balance, required this.policy});

  final num fee;
  final double balance;
  final String policy;

  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  bool _agree = false;
  late String _method =
      widget.balance >= widget.fee ? 'WALLET' : 'RAZORPAY';

  Widget _option(String value, IconData icon, String title, String sub,
      {bool enabled = true}) {
    final bool on = _method == value;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? () => setState(() => _method = value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: on ? const Color(0xFFEFECFF) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
                color: on ? _accent : const Color(0xFFE3E0F5),
                width: on ? 1.8 : 1.2),
          ),
          child: Row(children: <Widget>[
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                  color: on ? _accent : const Color(0xFFF1EFFC),
                  borderRadius: BorderRadius.circular(12.r)),
              child: Icon(icon, color: on ? Colors.white : _accent, size: 22.r),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title,
                        style: TextStyle(
                            color: _ink,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800)),
                    Text(sub,
                        style: TextStyle(
                            color: Colors.black54, fontSize: 12.sp)),
                  ]),
            ),
            Icon(on ? Icons.check_circle : Icons.circle_outlined,
                color: on ? _accent : Colors.black26),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool paid = widget.fee > 0;
    final bool walletOk = widget.balance >= widget.fee;
    final double short = widget.fee.toDouble() - widget.balance;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20.w, 20.h, 20.w, 20.h + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Join this auction',
            style: TextStyle(
              color: _ink,
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            paid
                ? 'Registration fee ${widget.fee.toInrCurrency}'
                : 'There is no registration fee for this auction.',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
          ),
          if (widget.policy.isNotEmpty) ...<Widget>[
            SizedBox(height: 6.h),
            Text(
              widget.policy,
              style: TextStyle(
                  color: Colors.black54, fontSize: 12.sp, height: 1.4),
            ),
          ],
          if (paid) ...<Widget>[
            SizedBox(height: 14.h),
            Text('Pay with',
                style:
                    TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800)),
            SizedBox(height: 8.h),
            _option(
                'WALLET',
                Icons.account_balance_wallet_rounded,
                'Dealkr wallet',
                walletOk
                    ? 'Balance ${widget.balance.toInrCurrency}'
                    : 'Balance ${widget.balance.toInrCurrency} · not enough',
                enabled: walletOk),
            _option(
                'RAZORPAY',
                Icons.bolt_rounded,
                'UPI / Card / Net banking',
                walletOk
                    ? 'Pay securely with Razorpay'
                    : 'Pay ${short.ceil().toDouble().toInrCurrency} more with Razorpay'),
          ],
          CheckboxListTile(
            activeColor: _accent,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _agree,
            onChanged: (bool? v) => setState(() => _agree = v ?? false),
            title: Text(
              'I understand and agree to the registration terms.',
              style: TextStyle(fontSize: 13.sp),
            ),
          ),
          SizedBox(height: 6.h),
          FilledButton(
            onPressed: _agree ? () => Navigator.pop(context, _method) : null,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              minimumSize: Size.fromHeight(50.h),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r)),
            ),
            child: Text(
              paid ? 'Pay ${widget.fee.toInrCurrency} & join' : 'Join',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _BidSheet extends StatefulWidget {
  const _BidSheet({
    required this.minNext,
    required this.increment,
    required this.myMax,
  });

  final double minNext;
  final double increment;
  final double? myMax;

  @override
  State<_BidSheet> createState() => _BidSheetState();
}

class _BidSheetState extends State<_BidSheet> {
  late final TextEditingController _c = TextEditingController(
    text: widget.minNext.toStringAsFixed(0),
  );
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _set(double v) => setState(() {
        _c.text = v.toStringAsFixed(0);
        _error = null;
      });

  void _submit() {
    final double? v = double.tryParse(_c.text.trim());
    if (v == null || v < widget.minNext) {
      setState(() => _error = 'Enter at least ${widget.minNext.toInrCurrency}');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20.w, 20.h, 20.w, 20.h + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Place your bid',
            style: TextStyle(
              color: _ink,
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Enter the most you are willing to pay. We bid for you only as much as needed to keep you in front.',
            style:
                TextStyle(color: Colors.black54, fontSize: 12.sp, height: 1.4),
          ),
          if (widget.myMax != null)
            Padding(
              padding: EdgeInsets.only(top: 6.h),
              child: Text(
                'Your current maximum: ${widget.myMax!.toInrCurrency}',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
              ),
            ),
          SizedBox(height: 12.h),
          TextField(
            controller: _c,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly
            ],
            style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              prefixText: '₹ ',
              errorText: _error,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            children: <Widget>[
              for (final int n in <int>[0, 1, 2, 5])
                ActionChip(
                  label: Text(
                    n == 0
                        ? 'Min ${widget.minNext.toInrCurrency}'
                        : '+${(widget.increment * n).toInrCurrency}',
                  ),
                  onPressed: () => _set(widget.minNext + widget.increment * n),
                ),
            ],
          ),
          SizedBox(height: 14.h),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              minimumSize: Size.fromHeight(50.h),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r)),
            ),
            child: Text(
              'Confirm bid',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
