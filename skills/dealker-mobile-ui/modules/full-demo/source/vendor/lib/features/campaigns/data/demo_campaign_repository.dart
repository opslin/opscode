import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_repository.dart';

const _img = 'https://api.dealker.agnixstudio.in/uploads/products';

/// DEMO ONLY — in-memory campaigns + ad wallet so the whole create / manage /
/// wallet flow can be reviewed without a vendor login. Active only when `.env`
/// has `DEMO_HOME=true`. Delete with the switch in `campaign_providers.dart`.
class DemoCampaignRepository extends CampaignRepository {
  DemoCampaignRepository() : super(Dio());

  static int _seq = 1004;
  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static const _catalogue = <AdProduct>[
    AdProduct(
        id: 'a1',
        name: 'Apple iPhone 15 Pro (256GB)',
        brand: 'Apple',
        thumbnail: '$_img/apple-iphone-15-pro-256gb-natural-titanium.jpg',
        price: 119900,
        stock: 24,
        rating: 4.6),
    AdProduct(
        id: 'a2',
        name: 'Samsung Galaxy S24 Ultra 5G (12GB, 256GB)',
        brand: 'Samsung',
        thumbnail:
            '$_img/samsung-galaxy-s24-ultra-5g-12gb-256gb-titanium-gray.jpg',
        price: 109999,
        stock: 12,
        rating: 4.5),
    AdProduct(
        id: 'a3',
        name: 'Apple iPhone 15 (128GB)',
        brand: 'Apple',
        thumbnail: '$_img/apple-iphone-15-128gb-blue.jpg',
        price: 69900,
        stock: 40,
        rating: 4.7),
    AdProduct(
        id: 'a4',
        name: 'Apple iPhone 16 (128GB)',
        brand: 'Apple',
        thumbnail: '$_img/apple-iphone-16-128gb-black.jpg',
        price: 79900,
        stock: 18,
        rating: 4.8),
  ];

  AdWallet _wallet = const AdWallet(
    balance: 4820,
    lifetimeTopup: 12000,
    lifetimeSpend: 7180,
    settlementBalance: 38400,
    withdrawable: 3000,
    activeCampaigns: 1,
    dailyCommitment: 1500,
  );

  final List<WalletEntry> _ledger = [
    WalletEntry(
        id: 'l4',
        type: 'CLICK_CHARGE',
        amount: -354,
        tax: 54,
        balanceAfter: 4820,
        campaignName: 'iPhone 15 Series',
        at: DateTime.now().subtract(const Duration(hours: 2))),
    WalletEntry(
        id: 'l3',
        type: 'TOPUP_SETTLEMENT',
        amount: 5000,
        balanceAfter: 5174,
        reason: 'Top-up from settlement balance',
        at: DateTime.now().subtract(const Duration(days: 1))),
    WalletEntry(
        id: 'l2',
        type: 'PROMO_CREDIT',
        amount: 1000,
        balanceAfter: 174,
        reason: 'Welcome credit',
        at: DateTime.now().subtract(const Duration(days: 4))),
  ];

  final List<CampaignDetail> _all = [
    _detail('c1', 'AD-1001', 'iPhone 15 Series', CampaignStatus.active,
        Targeting.auto,
        bid: 14,
        daily: 1500,
        total: 30000,
        start: -6,
        end: 24,
        spentToday: 612,
        products: [0, 2],
        imp: 18420,
        clk: 612,
        spend: 8568),
    _detail('c2', 'AD-1002', 'Samsung Ultra push', CampaignStatus.pending,
        Targeting.manual,
        bid: 18,
        daily: 1000,
        start: 0,
        products: [
          1
        ],
        keywords: const [
          KeywordDraft('samsung s24 ultra', matchType: 'PHRASE'),
          KeywordDraft('galaxy s24', matchType: 'BROAD'),
        ]),
    _detail(
        'c3', 'AD-1003', 'Diwali Special', CampaignStatus.ended, Targeting.auto,
        bid: 12,
        daily: 800,
        start: -40,
        end: -12,
        products: [3],
        imp: 9100,
        clk: 240,
        spend: 2880),
  ];

  static CampaignDetail _detail(
    String id,
    String number,
    String name,
    String status,
    Targeting t, {
    required num bid,
    required num daily,
    num? total,
    required int start,
    int? end,
    num spentToday = 0,
    List<int> products = const [],
    List<KeywordDraft> keywords = const [],
    int imp = 0,
    int clk = 0,
    num spend = 0,
  }) {
    final prods = [
      for (final i in products)
        CampaignProduct(
            productId: _catalogue[i].id,
            name: _catalogue[i].name,
            brand: _catalogue[i].brand,
            status: 'ACTIVE',
            thumbnail: _catalogue[i].thumbnail,
            price: _catalogue[i].price,
            stock: _catalogue[i].stock,
            impressions: imp ~/ products.length,
            clicks: clk ~/ products.length,
            spend: spend / products.length),
    ];
    final kws = [
      for (final (i, k) in keywords.indexed)
        CampaignKeyword(
            id: '$id-k$i',
            keyword: k.keyword,
            matchType: k.matchType,
            negative: k.negative,
            status: 'ACTIVE',
            bid: k.bid),
    ];
    final item = CampaignItem(
      id: id,
      number: number,
      name: name,
      status: status,
      targeting: t,
      defaultBid: bid,
      dailyBudget: daily,
      totalBudget: total,
      startsOn: _today.add(Duration(days: start)),
      endsOn: end == null ? null : _today.add(Duration(days: end)),
      productCount: prods.length,
      keywordCount: kws.length,
      spentToday: spentToday,
      impressions: imp,
      clicks: clk,
      spend: spend,
    );
    return CampaignDetail(
      item: item,
      products: prods,
      keywords: kws,
      events: [
        CampaignEvent(
            event: 'CREATED',
            actor: 'VENDOR',
            at: DateTime.now().subtract(Duration(days: -start + 1))),
      ],
      totals: CampaignTotals(
          impressions: imp,
          clicks: clk,
          spend: spend,
          ctr: imp == 0 ? 0 : clk / imp,
          avgCpc: clk == 0 ? 0 : spend / clk),
    );
  }

  Future<void> _lag([int ms = 350]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  CampaignDetail _find(String id) => _all.firstWhere((c) => c.item.id == id);

  void _set(String id, CampaignDetail Function(CampaignDetail) f) {
    final i = _all.indexWhere((c) => c.item.id == id);
    _all[i] = f(_all[i]);
  }

  CampaignDetail _withItem(CampaignDetail d, CampaignItem item) =>
      CampaignDetail(
          item: item,
          products: d.products,
          keywords: d.keywords,
          events: d.events,
          totals: d.totals);

  CampaignItem _copy(CampaignItem c,
          {String? status,
          String? name,
          num? bid,
          num? daily,
          num? total,
          DateTime? starts,
          DateTime? ends,
          int? products,
          int? keywords,
          String? pausedReason}) =>
      CampaignItem(
        id: c.id,
        number: c.number,
        name: name ?? c.name,
        status: status ?? c.status,
        targeting: c.targeting,
        defaultBid: bid ?? c.defaultBid,
        dailyBudget: daily ?? c.dailyBudget,
        totalBudget: total ?? c.totalBudget,
        startsOn: starts ?? c.startsOn,
        endsOn: ends ?? c.endsOn,
        productCount: products ?? c.productCount,
        keywordCount: keywords ?? c.keywordCount,
        spentToday: c.spentToday,
        impressions: c.impressions,
        clicks: c.clicks,
        spend: c.spend,
        pausedReason: pausedReason,
      );

  // ── create flow ─────────────────────────────────────────────────────

  @override
  Future<AdRules> rules() async => const AdRules();

  @override
  Future<List<AdProduct>> products({String q = ''}) async {
    await _lag(200);
    final s = q.toLowerCase();
    return _catalogue
        .where((p) => s.isEmpty || p.name.toLowerCase().contains(s))
        .toList();
  }

  @override
  Future<BidEstimate> estimate(String keyword,
      {String matchType = 'BROAD'}) async {
    await _lag(250);
    final big = keyword.contains('iphone') || keyword.contains('samsung');
    return BidEstimate(
        keyword: keyword,
        competition: big ? 'HIGH' : 'LOW',
        suggested: big ? 22 : 6,
        competing: big ? 7 : 1,
        highest: big ? 26 : 5,
        avgCpc: big ? 17.4 : 4.2,
        note:
            'You pay the lowest price that keeps your position — usually less than your bid — plus GST.');
  }

  @override
  Future<CampaignDetail> create(Map<String, dynamic> body) async {
    await _lag(700);
    final ids = ((body['productIds'] as List?) ?? const []).cast<String>();
    final kws = ((body['keywords'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((k) => KeywordDraft('${k['keyword']}',
            matchType: '${k['matchType'] ?? 'BROAD'}',
            negative: k['negative'] == true,
            bid: k['bid'] as num?))
        .toList();
    final submit = body['submit'] == true;
    final d = _detail(
      'c$_seq',
      'AD-${_seq++}',
      '${body['name']}',
      submit ? CampaignStatus.pending : CampaignStatus.draft,
      Targeting.of('${body['targeting']}'),
      bid: body['defaultBid'] as num,
      daily: body['dailyBudget'] as num,
      total: body['totalBudget'] as num?,
      start: 0,
      products: [
        for (final id in ids) _catalogue.indexWhere((p) => p.id == id)
      ],
      keywords: kws,
    );
    final item = _copy(d.item,
        starts: DateTime.tryParse('${body['startsOn']}') ?? _today,
        ends: DateTime.tryParse('${body['endsOn']}'));
    final made = _withItem(d, item);
    _all.insert(0, made);
    return made;
  }

  // ── manage ──────────────────────────────────────────────────────────

  @override
  Future<CampaignList> list({List<String>? statuses, int limit = 50}) async {
    await _lag();
    final rows = _all
        .map((d) => d.item)
        .where((c) =>
            statuses == null || statuses.isEmpty || statuses.contains(c.status))
        .toList();
    final counts = <String, int>{};
    for (final d in _all) {
      counts[d.item.status] = (counts[d.item.status] ?? 0) + 1;
    }
    return CampaignList(items: rows, total: rows.length, counts: counts);
  }

  @override
  Future<CampaignDetail> detail(String id) async {
    await _lag(250);
    return _find(id);
  }

  @override
  Future<CampaignReport> report(String id, {int days = 30}) async {
    await _lag();
    final d = _find(id);
    final t = d.totals;
    final daily = [
      for (var i = days - 1; i >= 0; i--)
        DayStat(
            _today.subtract(Duration(days: i)),
            t.impressions == 0 ? 0 : 420 + (i * 37) % 260,
            t.impressions == 0 ? 0 : 12 + (i * 7) % 17,
            t.impressions == 0 ? 0 : 150 + (i * 23) % 210),
    ];
    final orders = t.clicks == 0 ? 0 : t.clicks ~/ 14;
    final sales = orders * 71000;
    return CampaignReport(
      days: days,
      attributionDays: 7,
      totals: CampaignTotals(
          impressions: t.impressions,
          clicks: t.clicks,
          spend: t.spend,
          orders: orders,
          sales: sales,
          ctr: t.ctr,
          avgCpc: t.avgCpc,
          acos: sales == 0 ? null : t.spend / sales,
          roas: t.spend == 0 ? null : sales / t.spend),
      daily: daily,
      products: [
        for (final p in d.products)
          ReportProduct(
              name: p.name,
              impressions: p.impressions,
              clicks: p.clicks,
              spend: p.spend,
              orders: orders ~/ (d.products.isEmpty ? 1 : d.products.length),
              sales: sales / (d.products.isEmpty ? 1 : d.products.length)),
      ],
      keywords: const [],
    );
  }

  @override
  Future<AdsOverview> overview({int days = 30}) async {
    await _lag();
    final w = await wallet();
    return AdsOverview(
      days: days,
      totals: const CampaignTotals(
          impressions: 27520,
          clicks: 852,
          spend: 11448,
          orders: 61,
          sales: 4331000,
          ctr: 0.031,
          avgCpc: 13.4,
          acos: 0.0026,
          roas: 378),
      counts: {
        for (final d in _all) d.item.status: 0,
      }..updateAll((k, _) => _all.where((d) => d.item.status == k).length),
      wallet: w,
    );
  }

  @override
  Future<CampaignDetail> update(String id, Map<String, dynamic> body) async {
    await _lag();
    _set(
        id,
        (d) => _withItem(
            d,
            _copy(d.item,
                name: body['name'] as String?,
                bid: body['defaultBid'] as num?,
                daily: body['dailyBudget'] as num?,
                total: body['totalBudget'] as num?,
                starts: DateTime.tryParse('${body['startsOn']}'),
                ends: DateTime.tryParse('${body['endsOn']}'))));
    return _find(id);
  }

  CampaignDetail _status(String id, String status) {
    _set(id, (d) => _withItem(d, _copy(d.item, status: status)));
    return _find(id);
  }

  @override
  Future<CampaignDetail> submit(String id) async {
    await _lag();
    return _status(id, CampaignStatus.pending);
  }

  @override
  Future<CampaignDetail> pause(String id) async {
    await _lag();
    return _status(id, CampaignStatus.paused);
  }

  @override
  Future<CampaignDetail> resume(String id) async {
    await _lag();
    return _status(id, CampaignStatus.active);
  }

  @override
  Future<CampaignDetail> end(String id) async {
    await _lag();
    return _status(id, CampaignStatus.ended);
  }

  @override
  Future<CampaignDetail> addProducts(String id, List<String> productIds) async {
    await _lag();
    _set(id, (d) {
      final add = [
        for (final pid in productIds)
          if (!d.products.any((p) => p.productId == pid))
            () {
              final p = _catalogue.firstWhere((c) => c.id == pid);
              return CampaignProduct(
                  productId: p.id,
                  name: p.name,
                  brand: p.brand,
                  status: 'ACTIVE',
                  thumbnail: p.thumbnail,
                  price: p.price,
                  stock: p.stock);
            }(),
      ];
      final products = [...d.products, ...add];
      return CampaignDetail(
          item: _copy(d.item, products: products.length),
          products: products,
          keywords: d.keywords,
          events: d.events,
          totals: d.totals);
    });
    return _find(id);
  }

  @override
  Future<CampaignDetail> setProductPaused(
      String id, String productId, bool paused) async {
    await _lag(200);
    _set(
        id,
        (d) => CampaignDetail(
            item: d.item,
            products: [
              for (final p in d.products)
                p.productId == productId
                    ? CampaignProduct(
                        productId: p.productId,
                        name: p.name,
                        brand: p.brand,
                        status: paused ? 'PAUSED' : 'ACTIVE',
                        thumbnail: p.thumbnail,
                        price: p.price,
                        stock: p.stock,
                        bidOverride: p.bidOverride,
                        impressions: p.impressions,
                        clicks: p.clicks,
                        spend: p.spend)
                    : p
            ],
            keywords: d.keywords,
            events: d.events,
            totals: d.totals));
    return _find(id);
  }

  @override
  Future<CampaignDetail> removeProduct(String id, String productId) async {
    await _lag(200);
    _set(id, (d) {
      final products =
          d.products.where((p) => p.productId != productId).toList();
      return CampaignDetail(
          item: _copy(d.item, products: products.length),
          products: products,
          keywords: d.keywords,
          events: d.events,
          totals: d.totals);
    });
    return _find(id);
  }

  @override
  Future<CampaignDetail> addKeywords(
      String id, List<KeywordDraft> keywords) async {
    await _lag(200);
    _set(id, (d) {
      final all = [
        ...d.keywords,
        for (final (i, k) in keywords.indexed)
          CampaignKeyword(
              id: '$id-n${d.keywords.length + i}',
              keyword: k.keyword,
              matchType: k.matchType,
              negative: k.negative,
              status: 'ACTIVE',
              bid: k.bid),
      ];
      return CampaignDetail(
          item: _copy(d.item, keywords: all.where((k) => !k.negative).length),
          products: d.products,
          keywords: all,
          events: d.events,
          totals: d.totals);
    });
    return _find(id);
  }

  @override
  Future<CampaignDetail> removeKeyword(String id, String keywordId) async {
    await _lag(200);
    _set(id, (d) {
      final all = d.keywords.where((k) => k.id != keywordId).toList();
      return CampaignDetail(
          item: _copy(d.item, keywords: all.where((k) => !k.negative).length),
          products: d.products,
          keywords: all,
          events: d.events,
          totals: d.totals);
    });
    return _find(id);
  }

  // ── ad wallet ───────────────────────────────────────────────────────

  @override
  Future<AdWallet> wallet() async {
    await _lag(200);
    return _wallet;
  }

  @override
  Future<WalletStatement> statement({int limit = 40}) async {
    await _lag(200);
    return WalletStatement(items: _ledger, total: _ledger.length);
  }

  void _move(num by, String type, String reason) {
    final w = _wallet;
    _wallet = AdWallet(
      balance: w.balance + by,
      lifetimeTopup: w.lifetimeTopup + (by > 0 ? by : 0),
      lifetimeSpend: w.lifetimeSpend,
      settlementBalance: w.settlementBalance - by,
      withdrawable: (w.withdrawable + by).clamp(0, double.infinity),
      activeCampaigns: w.activeCampaigns,
      dailyCommitment: w.dailyCommitment,
      gstPct: w.gstPct,
    );
    _ledger.insert(
        0,
        WalletEntry(
            id: 'l${_ledger.length + 10}',
            type: type,
            amount: by,
            balanceAfter: _wallet.balance,
            reason: reason,
            at: DateTime.now()));
  }

  @override
  Future<void> topUp(num amount, {required String idempotencyKey}) async {
    await _lag(600);
    if (amount > _wallet.settlementBalance) {
      throw const ValidationFailure(
          message: 'Not enough settlement balance to move this amount');
    }
    _move(amount, 'TOPUP_SETTLEMENT', 'Top-up from settlement balance');
  }

  @override
  Future<void> withdraw(num amount) async {
    await _lag(600);
    _move(-amount, 'WITHDRAW_SETTLEMENT', 'Moved back to settlement');
  }
}
