import 'package:dio/dio.dart';

import 'package:dealker_vendor/features/auctions/data/auction_models.dart';
import 'package:dealker_vendor/features/auctions/data/auction_repository.dart';

/// DEMO ONLY — in-memory auctions so the create/manage/bid flow can be
/// reviewed without a vendor login. Active only when `.env` has
/// `DEMO_HOME=true`. Delete with the switch in `auction_providers.dart`.
class DemoAuctionRepository extends AuctionRepository {
  DemoAuctionRepository() : super(Dio());

  static int _seq = 3;
  final List<AuctionItem> _mine = [
    _item('d1', 'AU-261013-A1B2C3', 'iPhone 15 Pro Max 256GB | Titanium',
        'LIVE', AuctionAudience.b2c,
        start: 45000,
        current: 47500,
        bids: 5,
        ends: const Duration(hours: 1, minutes: 32, seconds: 12)),
    _item('d2', 'AU-261013-D4E5F6', 'Samsung S23 Ultra 12GB | 256GB',
        'SCHEDULED', AuctionAudience.b2b,
        start: 52000,
        qty: 10,
        starts: const Duration(days: 1),
        ends: const Duration(days: 1, hours: 2)),
    _item('d3', 'AU-261010-G7H8I9', 'MacBook Air M2 8GB | 256GB', 'SOLD',
        AuctionAudience.b2c,
        start: 78000,
        current: 86500,
        bids: 11,
        win: 86500,
        ends: const Duration(days: -3)),
  ];

  static AuctionItem _item(
    String id,
    String number,
    String title,
    String status,
    AuctionAudience audience, {
    required num start,
    num? current,
    int bids = 0,
    int qty = 1,
    num? win,
    Duration ends = const Duration(hours: 2),
    Duration starts = Duration.zero,
  }) =>
      AuctionItem(
        id: id,
        number: number,
        title: title,
        imageUrl: null,
        images: const [],
        status: status,
        audience: audience,
        quantity: qty,
        startPrice: start,
        currentPrice: current ?? start,
        reservePrice: start + 5000,
        bidIncrement: 500,
        buyNowPrice: null,
        registrationFee: 500,
        bidCount: bids,
        bidderCount: bids == 0 ? 0 : (bids / 2).ceil(),
        registrationCount: bids == 0 ? 0 : (bids / 2).ceil() + 1,
        startsAt: DateTime.now().add(starts),
        endsAt: DateTime.now().add(ends),
        winningBid: win,
        rejectedReason: null,
        serverOffset: Duration.zero,
      );

  @override
  Future<AuctionRules> rules() async => const AuctionRules(
        enabled: true,
        minFee: 100,
        maxFee: 5000,
        feeMaxPct: 10,
        minDurationMinutes: 30,
        maxDurationDays: 14,
        requiresApproval: true,
        antiSnipeWindowSec: 120,
        antiSnipeExtendSec: 120,
        paymentWindowHours: 24,
        loserRefundPct: 0,
        vendorSharePct: 50,
      );

  @override
  Future<List<ProductOption>> products({String q = ''}) async {
    const all = [
      ProductOption(
          id: 'p1',
          name: 'iPhone 15 Pro Max',
          brand: '256GB | Titanium',
          price: 134900,
          thumbnail: null,
          images: [],
          stock: 24),
      ProductOption(
          id: 'p2',
          name: 'MacBook Air M2',
          brand: '8GB | 256GB',
          price: 99900,
          thumbnail: null,
          images: [],
          stock: 9),
      ProductOption(
          id: 'p3',
          name: 'Samsung S23 Ultra',
          brand: '12GB | 256GB',
          price: 74999,
          thumbnail: null,
          images: [],
          stock: 40),
      ProductOption(
          id: 'p4',
          name: 'iPhone 14',
          brand: '128GB | Blue',
          price: 58900,
          thumbnail: null,
          images: [],
          stock: 15),
    ];
    final s = q.toLowerCase();
    return all.where((p) => p.name.toLowerCase().contains(s)).toList();
  }

  @override
  Future<String> uploadImage(String filePath) async => filePath;

  @override
  Future<String> uploadVideo(String filePath) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return filePath;
  }

  @override
  Future<AuctionItem> create(CreateAuctionRequest req) async {
    final starts = req.startsAt ?? DateTime.now();
    final item = AuctionItem(
      id: 'd${++_seq}',
      number: 'AU-261013-${_seq}ABCD',
      title: req.title,
      imageUrl: null,
      images: const [],
      status: req.saveAsDraft ? 'DRAFT' : 'PENDING_APPROVAL',
      audience: req.audience,
      quantity: req.quantity ?? 1,
      startPrice: req.startPrice,
      currentPrice: req.startPrice,
      reservePrice: req.reservePrice,
      bidIncrement: req.bidIncrement,
      buyNowPrice: req.buyNowPrice,
      registrationFee: req.registrationFee,
      bidCount: 0,
      bidderCount: 0,
      registrationCount: 0,
      startsAt: starts,
      endsAt: starts.add(Duration(hours: req.durationHours)),
      winningBid: null,
      rejectedReason: null,
      serverOffset: Duration.zero,
    );
    _mine.insert(0, item);
    return item;
  }

  @override
  Future<AuctionList> list({List<String>? statuses, int limit = 30}) async {
    final counts = <String, int>{};
    for (final a in _mine) {
      counts[a.status] = (counts[a.status] ?? 0) + 1;
    }
    final items = statuses == null || statuses.isEmpty
        ? _mine
        : _mine.where((a) => statuses.contains(a.status)).toList();
    return AuctionList(items: items, total: items.length, counts: counts);
  }

  @override
  Future<AuctionDetail> detail(String id) async {
    final a = _mine.firstWhere((x) => x.id == id);
    final names = [
      'Bidder #4',
      'Bidder #2',
      'Bidder #3',
      'Bidder #2',
      'Bidder #1'
    ];
    return AuctionDetail(
      auction: a,
      bids: [
        for (var i = 0; i < a.bidCount.clamp(0, 5); i++)
          BidEntry(
              seq: a.bidCount - i,
              alias: names[i],
              amount: a.currentPrice - i * 500,
              at: DateTime.now().subtract(Duration(minutes: 3 + i * 6)),
              isLeading: i == 0,
              isYou: false),
      ],
    );
  }

  @override
  Future<void> cancel(String id, {String? reason}) async {
    final i = _mine.indexWhere((a) => a.id == id);
    final a = _mine[i];
    _mine[i] = _copy(a, status: 'CANCELLED');
  }

  @override
  Future<AuctionItem> submit(String id) async {
    final i = _mine.indexWhere((a) => a.id == id);
    _mine[i] = _copy(_mine[i], status: 'PENDING_APPROVAL');
    return _mine[i];
  }

  AuctionItem _copy(AuctionItem a, {String? status}) => AuctionItem(
        id: a.id,
        number: a.number,
        title: a.title,
        imageUrl: a.imageUrl,
        images: a.images,
        status: status ?? a.status,
        audience: a.audience,
        quantity: a.quantity,
        startPrice: a.startPrice,
        currentPrice: a.currentPrice,
        reservePrice: a.reservePrice,
        bidIncrement: a.bidIncrement,
        buyNowPrice: a.buyNowPrice,
        registrationFee: a.registrationFee,
        bidCount: a.bidCount,
        bidderCount: a.bidderCount,
        registrationCount: a.registrationCount,
        startsAt: a.startsAt,
        endsAt: a.endsAt,
        winningBid: a.winningBid,
        rejectedReason: a.rejectedReason,
        serverOffset: a.serverOffset,
      );

  // ── bidding on other vendors' lots ──────────────────────────────────

  LotView _lot(String id, String title, num cur, int bids, int qty,
          {bool registered = false, bool leading = false}) =>
      LotView(
        id: id,
        number: 'AU-261013-$id',
        title: title,
        description: 'Brand-new sealed units, GST invoice, 1-year warranty.',
        imageUrl: null,
        images: const [],
        status: 'LIVE',
        quantity: qty,
        unitPrice: qty > 1 ? (cur / qty).roundToDouble() : null,
        sellerName: 'Apex Mobiles, Delhi',
        startPrice: cur - 4000,
        currentPrice: cur,
        minNextBid: cur + 500,
        increment: 500,
        reserveStatus: 'MET',
        registrationFee: 500,
        feePolicy:
            '₹500 registration fee, charged to your wallet when you join. If you win, it is deducted from the price you pay.',
        bidCount: bids,
        bidderCount: 3,
        startsAt: DateTime.now().subtract(const Duration(hours: 1)),
        endsAt: DateTime.now().add(const Duration(minutes: 47, seconds: 20)),
        finalPrice: null,
        leaderAlias: 'Bidder #2',
        my: MyBidStanding(
            registered: registered,
            isLeading: leading,
            myMax: leading ? cur : null,
            isWinner: false,
            feePaid: registered ? 500 : 0,
            amountDue: null),
        serverOffset: Duration.zero,
      );

  @override
  Future<LotList> lots(
      {LotQuery query = const LotQuery(), int limit = 30}) async {
    final items = [
      _lot('L1', 'iPhone 13 128GB — lot of 20', 612000, 7, 20),
      _lot('L2', 'Redmi Note 13 5G — lot of 50', 395000, 4, 50,
          registered: true, leading: true),
    ];
    return LotList(
        items: items,
        total: items.length,
        counts: const {'live': 2, 'upcoming': 0, 'ended': 0});
  }

  @override
  Future<LotList> myLots() async {
    final l = await lots();
    return LotList(
        items: l.items.where((x) => x.my.registered).toList(), total: 1);
  }

  @override
  Future<LotView> lot(String id) async =>
      (await lots()).items.firstWhere((l) => l.id == id);

  @override
  Future<List<BidEntry>> lotBids(String id) async => [
        BidEntry(
            seq: 7,
            alias: 'Bidder #2',
            amount: 612000,
            at: DateTime.now().subtract(const Duration(minutes: 4)),
            isLeading: true,
            isYou: false),
        BidEntry(
            seq: 6,
            alias: 'Bidder #1',
            amount: 606000,
            at: DateTime.now().subtract(const Duration(minutes: 9)),
            isLeading: false,
            isYou: false),
      ];

  @override
  Future<String> consentText() async =>
      'The registration fee is charged to your wallet. If you win it is deducted from your payable amount.';

  @override
  Future<void> register(String id) async {}

  @override
  Future<void> placeBid(String id, num maxAmount) async {}
}
