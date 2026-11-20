// Models for the Campaigns (sponsored ads) module. Field names follow the real
// API: /manage/ads* returns snake_case rows; money is already a plain number.
// Parsing is defensive so a missing field never crashes a screen.

num? _n(dynamic v) => v == null ? null : (v is num ? v : num.tryParse('$v'));
int _i(dynamic v) => _n(v)?.toInt() ?? 0;
String _s(dynamic v) => v == null ? '' : '$v';
Map<String, dynamic> _m(dynamic v) =>
    (v as Map?)?.cast<String, dynamic>() ?? const {};
List<Map<String, dynamic>> _l(dynamic v) =>
    ((v as List?) ?? const []).whereType<Map<String, dynamic>>().toList();

/// A `DATE` column. The server serialises it as an ISO instant at local
/// midnight, so converting to the device zone gives back the calendar day.
DateTime? _date(dynamic v) {
  final d = DateTime.tryParse(_s(v));
  if (d == null) return null;
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

DateTime? _ts(dynamic v) => DateTime.tryParse(_s(v))?.toLocal();

String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class CampaignStatus {
  CampaignStatus._();
  static const draft = 'DRAFT';
  static const pending = 'PENDING_REVIEW';
  static const active = 'ACTIVE';
  static const paused = 'PAUSED';
  static const rejected = 'REJECTED';
  static const suspended = 'SUSPENDED';
  static const ended = 'ENDED';
}

enum Targeting {
  auto('AUTO', 'Automatic'),
  manual('MANUAL', 'Keywords');

  const Targeting(this.api, this.label);
  final String api;
  final String label;
  static Targeting of(String s) => s == 'MANUAL' ? manual : auto;
}

/// Platform limits from `GET /manage/ads/rules`.
class AdRules {
  const AdRules({
    this.enabled = true,
    this.requiresApproval = true,
    this.minCpc = 2,
    this.maxCpc = 500,
    this.minDailyBudget = 100,
    this.minTopup = 500,
    this.maxTopup = 200000,
    this.gstPct = 18,
    this.maxProducts = 100,
    this.maxKeywords = 200,
    this.maxCampaigns = 20,
    this.attributionDays = 7,
  });

  final bool enabled;
  final bool requiresApproval;
  final num minCpc;
  final num maxCpc;
  final num minDailyBudget;
  final num minTopup;
  final num maxTopup;
  final num gstPct;
  final int maxProducts;
  final int maxKeywords;
  final int maxCampaigns;
  final int attributionDays;

  factory AdRules.fromJson(Map<String, dynamic> j) => AdRules(
        enabled: j['enabled'] != false,
        requiresApproval: j['campaigns_require_approval'] != false,
        minCpc: _n(j['min_cpc']) ?? 2,
        maxCpc: _n(j['max_cpc']) ?? 500,
        minDailyBudget: _n(j['min_daily_budget']) ?? 100,
        minTopup: _n(j['min_topup']) ?? 500,
        maxTopup: _n(j['max_topup']) ?? 200000,
        gstPct: _n(j['gst_pct']) ?? 18,
        maxProducts: _i(j['max_products_per_campaign']).clamp(1, 1000),
        maxKeywords: _i(j['max_keywords_per_campaign']).clamp(1, 1000),
        maxCampaigns: _i(j['max_campaigns_per_vendor']).clamp(1, 1000),
        attributionDays: _i(j['attribution_window_days']).clamp(1, 30),
      );
}

/// One of the vendor's own products that can be advertised.
class AdProduct {
  const AdProduct({
    required this.id,
    required this.name,
    this.brand = '',
    this.thumbnail,
    this.price,
    this.stock = 0,
    this.rating,
  });
  final String id;
  final String name;
  final String brand;
  final String? thumbnail;
  final num? price;
  final int stock;
  final num? rating;

  factory AdProduct.fromJson(Map<String, dynamic> j) => AdProduct(
        id: _s(j['id']),
        name: _s(j['name']),
        brand: _s(j['brand']),
        thumbnail: j['thumbnail'] as String?,
        price: _n(j['price']),
        stock: _i(j['stock_quantity']),
        rating: _n(j['rating_avg']),
      );
}

/// Row of `GET /manage/ads` (list).
class CampaignItem {
  const CampaignItem({
    required this.id,
    required this.number,
    required this.name,
    required this.status,
    required this.targeting,
    required this.defaultBid,
    required this.dailyBudget,
    this.totalBudget,
    this.startsOn,
    this.endsOn,
    this.productCount = 0,
    this.keywordCount = 0,
    this.spentToday = 0,
    this.impressions = 0,
    this.clicks = 0,
    this.spend = 0,
    this.pausedReason,
    this.rejectedReason,
    this.suspendedReason,
  });

  final String id;
  final String number;
  final String name;
  final String status;
  final Targeting targeting;
  final num defaultBid;
  final num dailyBudget;
  final num? totalBudget;
  final DateTime? startsOn;
  final DateTime? endsOn;
  final int productCount;
  final int keywordCount;
  final num spentToday;
  final int impressions; // last 30 days
  final int clicks; // last 30 days
  final num spend; // last 30 days, before GST
  final String? pausedReason;
  final String? rejectedReason;
  final String? suspendedReason;

  double get ctr => impressions == 0 ? 0 : clicks / impressions;
  double get todayUsed =>
      dailyBudget <= 0 ? 0 : (spentToday / dailyBudget).clamp(0, 1).toDouble();

  factory CampaignItem.fromJson(Map<String, dynamic> j) => CampaignItem(
        id: _s(j['id']),
        number: _s(j['campaign_number']),
        name: _s(j['name']),
        status: _s(j['status']),
        targeting: Targeting.of(_s(j['targeting'])),
        defaultBid: _n(j['default_bid']) ?? 0,
        dailyBudget: _n(j['daily_budget']) ?? 0,
        totalBudget: _n(j['total_budget']),
        startsOn: _date(j['starts_on']),
        endsOn: _date(j['ends_on']),
        productCount: _i(j['product_count']),
        keywordCount: _i(j['keyword_count']),
        spentToday: _n(j['spent_today']) ?? 0,
        impressions: _i(j['impressions_30d']),
        clicks: _i(j['clicks_30d']),
        spend: _n(j['spend_30d']) ?? 0,
        pausedReason: j['paused_reason'] as String?,
        rejectedReason: j['rejected_reason'] as String?,
        suspendedReason: j['suspended_reason'] as String?,
      );
}

class CampaignList {
  const CampaignList(
      {required this.items, required this.total, required this.counts});
  final List<CampaignItem> items;
  final int total;
  final Map<String, int> counts;

  int count(String status) => counts[status] ?? 0;
  int get all => counts.values.fold(0, (a, b) => a + b);
}

class CampaignProduct {
  const CampaignProduct({
    required this.productId,
    required this.name,
    required this.status,
    this.brand = '',
    this.thumbnail,
    this.price,
    this.stock = 0,
    this.bidOverride,
    this.impressions = 0,
    this.clicks = 0,
    this.spend = 0,
  });
  final String productId;
  final String name;
  final String brand;
  final String status; // ACTIVE | PAUSED
  final String? thumbnail;
  final num? price;
  final int stock;
  final num? bidOverride;
  final int impressions;
  final int clicks;
  final num spend;

  bool get paused => status == 'PAUSED';

  factory CampaignProduct.fromJson(Map<String, dynamic> j) => CampaignProduct(
        productId: _s(j['product_id']),
        name: _s(j['name']),
        brand: _s(j['brand']),
        status: _s(j['status']),
        thumbnail: j['thumbnail'] as String?,
        price: _n(j['price']),
        stock: _i(j['stock']),
        bidOverride: _n(j['bid_override']),
        impressions: _i(j['impressions']),
        clicks: _i(j['clicks']),
        spend: _n(j['spend']) ?? 0,
      );
}

class CampaignKeyword {
  const CampaignKeyword({
    required this.id,
    required this.keyword,
    required this.matchType,
    required this.negative,
    required this.status,
    this.bid,
    this.clicks = 0,
    this.spend = 0,
  });
  final String id;
  final String keyword;
  final String matchType; // EXACT | PHRASE | BROAD
  final bool negative;
  final String status;
  final num? bid;
  final int clicks;
  final num spend;

  factory CampaignKeyword.fromJson(Map<String, dynamic> j) => CampaignKeyword(
        id: _s(j['id']),
        keyword: _s(j['keyword']),
        matchType: _s(j['match_type']),
        negative: j['is_negative'] == true,
        status: _s(j['status']),
        bid: _n(j['bid']),
        clicks: _i(j['clicks']),
        spend: _n(j['spend']) ?? 0,
      );
}

class CampaignEvent {
  const CampaignEvent(
      {required this.event, required this.actor, required this.at});
  final String event;
  final String actor;
  final DateTime? at;

  factory CampaignEvent.fromJson(Map<String, dynamic> j) => CampaignEvent(
      event: _s(j['event']),
      actor: _s(j['actor_kind']),
      at: _ts(j['created_at']));
}

class CampaignTotals {
  const CampaignTotals(
      {this.impressions = 0,
      this.clicks = 0,
      this.spend = 0,
      this.orders = 0,
      this.sales = 0,
      this.ctr = 0,
      this.avgCpc = 0,
      this.acos,
      this.roas});
  final int impressions;
  final int clicks;
  final num spend;
  final int orders;
  final num sales;
  final double ctr;
  final num avgCpc;
  final double? acos;
  final double? roas;

  factory CampaignTotals.fromJson(Map<String, dynamic> j) => CampaignTotals(
        impressions: _i(j['impressions']),
        clicks: _i(j['clicks']),
        spend: _n(j['spend']) ?? 0,
        orders: _i(j['orders']),
        sales: _n(j['sales']) ?? 0,
        ctr: _n(j['ctr'])?.toDouble() ?? 0,
        avgCpc: _n(j['avg_cpc']) ?? 0,
        acos: _n(j['acos'])?.toDouble(),
        roas: _n(j['roas'])?.toDouble(),
      );
}

/// `GET /manage/ads/:id` — the campaign with its products, keywords and audit trail.
class CampaignDetail {
  const CampaignDetail({
    required this.item,
    required this.products,
    required this.keywords,
    required this.events,
    required this.totals,
  });
  final CampaignItem item;
  final List<CampaignProduct> products;
  final List<CampaignKeyword> keywords;
  final List<CampaignEvent> events;
  final CampaignTotals totals;

  factory CampaignDetail.fromJson(Map<String, dynamic> j) {
    final t = _m(j['totals_30d']);
    final item = CampaignItem.fromJson({
      ...j,
      'impressions_30d': t['impressions'],
      'clicks_30d': t['clicks'],
      'spend_30d': t['spend'],
      'product_count': _l(j['products']).length,
      'keyword_count':
          _l(j['keywords']).where((k) => k['is_negative'] != true).length,
    });
    return CampaignDetail(
      item: item,
      products: _l(j['products']).map(CampaignProduct.fromJson).toList(),
      keywords: _l(j['keywords']).map(CampaignKeyword.fromJson).toList(),
      events: _l(j['events']).map(CampaignEvent.fromJson).toList(),
      totals: CampaignTotals.fromJson(t),
    );
  }
}

class DayStat {
  const DayStat(this.day, this.impressions, this.clicks, this.spend);
  final DateTime day;
  final int impressions;
  final int clicks;
  final num spend;

  factory DayStat.fromJson(Map<String, dynamic> j) => DayStat(
      _date(j['day']) ?? DateTime.now(),
      _i(j['impressions']),
      _i(j['clicks']),
      _n(j['spend']) ?? 0);
}

class ReportProduct {
  const ReportProduct(
      {required this.name,
      this.impressions = 0,
      this.clicks = 0,
      this.spend = 0,
      this.orders = 0,
      this.sales = 0});
  final String name;
  final int impressions;
  final int clicks;
  final num spend;
  final int orders;
  final num sales;

  factory ReportProduct.fromJson(Map<String, dynamic> j) => ReportProduct(
      name: _s(j['name']),
      impressions: _i(j['impressions']),
      clicks: _i(j['clicks']),
      spend: _n(j['spend']) ?? 0,
      orders: _i(j['orders']),
      sales: _n(j['sales']) ?? 0);
}

class ReportKeyword {
  const ReportKeyword(
      {required this.keyword,
      this.matchType = '',
      this.clicks = 0,
      this.spend = 0,
      this.orders = 0,
      this.sales = 0});
  final String keyword;
  final String matchType;
  final int clicks;
  final num spend;
  final int orders;
  final num sales;

  factory ReportKeyword.fromJson(Map<String, dynamic> j) => ReportKeyword(
      keyword: _s(j['keyword']),
      matchType: _s(j['match_type']),
      clicks: _i(j['clicks']),
      spend: _n(j['spend']) ?? 0,
      orders: _i(j['orders']),
      sales: _n(j['sales']) ?? 0);
}

/// `GET /manage/ads/:id/report` — performance plus orders attributed to ad clicks.
class CampaignReport {
  const CampaignReport({
    required this.days,
    required this.attributionDays,
    required this.totals,
    required this.daily,
    required this.products,
    required this.keywords,
  });
  final int days;
  final int attributionDays;
  final CampaignTotals totals;
  final List<DayStat> daily;
  final List<ReportProduct> products;
  final List<ReportKeyword> keywords;

  factory CampaignReport.fromJson(Map<String, dynamic> j) => CampaignReport(
        days: _i(j['range_days']),
        attributionDays: _i(j['attribution_window_days']),
        totals: CampaignTotals.fromJson(_m(j['totals'])),
        daily: _l(j['daily']).map(DayStat.fromJson).toList(),
        products: _l(j['products']).map(ReportProduct.fromJson).toList(),
        keywords: _l(j['keywords']).map(ReportKeyword.fromJson).toList(),
      );
}

/// `GET /manage/ads/overview` — vendor-wide totals for the hub header.
class AdsOverview {
  const AdsOverview(
      {required this.days,
      required this.totals,
      required this.counts,
      required this.wallet});
  final int days;
  final CampaignTotals totals;
  final Map<String, int> counts;
  final AdWallet wallet;

  factory AdsOverview.fromJson(Map<String, dynamic> j) => AdsOverview(
        days: _i(j['range_days']),
        totals: CampaignTotals.fromJson(_m(j['totals'])),
        counts: _m(j['campaign_counts']).map((k, v) => MapEntry(k, _i(v))),
        wallet: AdWallet.fromJson(_m(j['wallet'])),
      );
}

class AdWallet {
  const AdWallet({
    this.balance = 0,
    this.lifetimeTopup = 0,
    this.lifetimeSpend = 0,
    this.settlementBalance = 0,
    this.withdrawable = 0,
    this.activeCampaigns = 0,
    this.dailyCommitment = 0,
    this.lowBalance = false,
    this.gstPct = 18,
    this.minTopup = 500,
    this.maxTopup = 200000,
  });
  final num balance;
  final num lifetimeTopup;
  final num lifetimeSpend;
  final num settlementBalance;
  final num withdrawable;
  final int activeCampaigns;
  final num dailyCommitment;
  final bool lowBalance;
  final num gstPct;
  final num minTopup;
  final num maxTopup;

  factory AdWallet.fromJson(Map<String, dynamic> j) => AdWallet(
        balance: _n(j['balance']) ?? 0,
        lifetimeTopup: _n(j['lifetime_topup']) ?? 0,
        lifetimeSpend: _n(j['lifetime_spend']) ?? 0,
        settlementBalance: _n(j['settlement_balance']) ?? 0,
        withdrawable: _n(j['withdrawable']) ?? 0,
        activeCampaigns: _i(j['active_campaigns']),
        dailyCommitment: _n(j['daily_commitment']) ?? 0,
        lowBalance: j['low_balance'] == true,
        gstPct: _n(j['gst_pct']) ?? 18,
        minTopup: _n(j['min_topup']) ?? 500,
        maxTopup: _n(j['max_topup']) ?? 200000,
      );
}

class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.tax = 0,
    this.reason,
    this.campaignName,
    this.at,
  });
  final String id;
  final String type;
  final num amount; // signed, gross of GST
  final num balanceAfter;
  final num tax;
  final String? reason;
  final String? campaignName;
  final DateTime? at;

  bool get credit => amount > 0;

  factory WalletEntry.fromJson(Map<String, dynamic> j) => WalletEntry(
        id: _s(j['id']),
        type: _s(j['entry_type']),
        amount: _n(j['amount']) ?? 0,
        balanceAfter: _n(j['balance_after']) ?? 0,
        tax: _n(j['tax_amount']) ?? 0,
        reason: j['reason'] as String?,
        campaignName: j['campaign_name'] as String?,
        at: _ts(j['created_at']),
      );
}

class WalletStatement {
  const WalletStatement({required this.items, required this.total});
  final List<WalletEntry> items;
  final int total;
}

/// `GET /manage/ads/estimate?keyword=` — what a keyword is likely to cost.
class BidEstimate {
  const BidEstimate({
    required this.keyword,
    required this.competition,
    required this.suggested,
    this.competing = 0,
    this.highest,
    this.avgCpc,
    this.note = '',
  });
  final String keyword;
  final String competition; // LOW | MEDIUM | HIGH
  final num suggested;
  final int competing;
  final num? highest;
  final num? avgCpc;
  final String note;

  factory BidEstimate.fromJson(Map<String, dynamic> j) => BidEstimate(
        keyword: _s(j['keyword']),
        competition: _s(j['competition']),
        suggested: _n(j['suggested_bid']) ?? 0,
        competing: _i(j['competing_campaigns']),
        highest: _n(j['highest_bid']),
        avgCpc: _n(j['avg_cpc_30d']),
        note: _s(j['note']),
      );
}

/// A keyword the vendor is adding in the create flow.
class KeywordDraft {
  const KeywordDraft(this.keyword,
      {this.matchType = 'BROAD', this.negative = false, this.bid});
  final String keyword;
  final String matchType;
  final bool negative;
  final num? bid;

  Map<String, dynamic> toJson() => {
        'keyword': keyword,
        'matchType': matchType,
        if (negative) 'negative': true,
        if (bid != null) 'bid': bid,
      };
}
