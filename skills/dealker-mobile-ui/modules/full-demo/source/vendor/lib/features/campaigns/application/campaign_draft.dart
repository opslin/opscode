import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';

/// Steps of the create flow.
enum CampaignStep { type, details, products, bidding, review }

/// Everything the vendor has entered so far. Validation lives here (not in the
/// widgets) so the rules are testable and the screens only show the message.
class CampaignDraft {
  const CampaignDraft({
    this.step = CampaignStep.type,
    this.targeting = Targeting.auto,
    this.name = '',
    this.startsOn,
    this.endsOn,
    this.dailyBudget = '',
    this.totalBudget = '',
    this.products = const [],
    this.bid = '',
    this.keywords = const [],
  });

  final CampaignStep step;
  final Targeting targeting;
  final String name;
  final DateTime? startsOn;
  final DateTime? endsOn;
  final String dailyBudget;
  final String totalBudget;
  final List<AdProduct> products;
  final String bid;
  final List<KeywordDraft> keywords;

  num? _num(String s) => s.trim().isEmpty ? null : num.tryParse(s.trim());
  num? get dailyN => _num(dailyBudget);
  num? get totalN => _num(totalBudget);
  num? get bidN => _num(bid);
  bool get isManual => targeting == Targeting.manual;
  List<KeywordDraft> get positive =>
      keywords.where((k) => !k.negative).toList();

  /// Number of whole days the campaign runs, or null when it has no end date.
  int? get runDays => endsOn == null || startsOn == null
      ? null
      : endsOn!.difference(startsOn!).inDays + 1;

  CampaignDraft copyWith({
    CampaignStep? step,
    Targeting? targeting,
    String? name,
    DateTime? startsOn,
    Object? endsOn = _keep,
    String? dailyBudget,
    String? totalBudget,
    List<AdProduct>? products,
    String? bid,
    List<KeywordDraft>? keywords,
  }) =>
      CampaignDraft(
        step: step ?? this.step,
        targeting: targeting ?? this.targeting,
        name: name ?? this.name,
        startsOn: startsOn ?? this.startsOn,
        endsOn: identical(endsOn, _keep) ? this.endsOn : endsOn as DateTime?,
        dailyBudget: dailyBudget ?? this.dailyBudget,
        totalBudget: totalBudget ?? this.totalBudget,
        products: products ?? this.products,
        bid: bid ?? this.bid,
        keywords: keywords ?? this.keywords,
      );

  /// First problem with the "Details" step, or null.
  String? detailsError(AdRules r, {DateTime? today}) {
    final n = name.trim();
    if (n.length < 3) return 'Give the campaign a name (at least 3 letters).';
    if (n.length > 120) return 'The name can be at most 120 characters.';
    final t = today ?? _day(DateTime.now());
    final s = startsOn;
    if (s == null) return 'Pick a start date.';
    if (s.isBefore(t)) return 'The start date cannot be in the past.';
    if (endsOn != null && endsOn!.isBefore(s)) {
      return 'The end date must be on or after the start date.';
    }
    final d = dailyN;
    if (d == null || d <= 0) return 'Enter a daily budget.';
    if (d < r.minDailyBudget) {
      return 'Daily budget must be at least ₹${_fmt(r.minDailyBudget)}.';
    }
    if (totalBudget.trim().isNotEmpty) {
      final tb = totalN;
      if (tb == null || tb <= 0) {
        return 'Enter a valid total budget or leave it empty.';
      }
      if (tb < d) return 'Total budget cannot be lower than the daily budget.';
    }
    return null;
  }

  String? productsError(AdRules r) {
    if (products.isEmpty) return 'Choose at least one product to advertise.';
    if (products.length > r.maxProducts) {
      return 'A campaign can promote at most ${r.maxProducts} products.';
    }
    return null;
  }

  String? biddingError(AdRules r) {
    final b = bidN;
    if (b == null || b <= 0) return 'Enter how much you will pay per click.';
    if (b < r.minCpc || b > r.maxCpc) {
      return 'Your bid must be between ₹${_fmt(r.minCpc)} and ₹${_fmt(r.maxCpc)}.';
    }
    if (isManual && positive.isEmpty) {
      return 'Add at least one keyword shoppers will search for.';
    }
    if (keywords.length > r.maxKeywords) {
      return 'A campaign can have at most ${r.maxKeywords} keywords.';
    }
    for (final k in keywords) {
      if (k.bid != null && (k.bid! < r.minCpc || k.bid! > r.maxCpc)) {
        return 'The bid for "${k.keyword}" must be between ₹${_fmt(r.minCpc)} and ₹${_fmt(r.maxCpc)}.';
      }
    }
    return null;
  }

  /// Body for `POST /manage/ads`. [submit] sends it for review in one call.
  Map<String, dynamic> toRequest({required bool submit}) => {
        'name': name.trim(),
        'targeting': targeting.api,
        'defaultBid': bidN,
        'dailyBudget': dailyN,
        if (totalN != null) 'totalBudget': totalN,
        'startsOn': isoDay(startsOn!),
        if (endsOn != null) 'endsOn': isoDay(endsOn!),
        'productIds': [for (final p in products) p.id],
        if (keywords.isNotEmpty)
          'keywords': [for (final k in keywords) k.toJson()],
        'submit': submit,
      };
}

const _keep = Object();
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
String _fmt(num n) => n == n.roundToDouble() ? n.toInt().toString() : '$n';

class CampaignDraftNotifier extends Notifier<CampaignDraft> {
  @override
  CampaignDraft build() => const CampaignDraft();

  void go(CampaignStep s) => state = state.copyWith(step: s);
  void targeting(Targeting t) => state = state.copyWith(targeting: t);
  void name(String v) => state = state.copyWith(name: v);
  void starts(DateTime d) => state = state.copyWith(startsOn: d);
  void ends(DateTime? d) => state = state.copyWith(endsOn: d);
  void daily(String v) => state = state.copyWith(dailyBudget: v);
  void total(String v) => state = state.copyWith(totalBudget: v);
  void bid(String v) => state = state.copyWith(bid: v);

  void toggleProduct(AdProduct p) {
    final has = state.products.any((x) => x.id == p.id);
    state = state.copyWith(
        products: has
            ? state.products.where((x) => x.id != p.id).toList()
            : [...state.products, p]);
  }

  void addKeyword(KeywordDraft k) {
    final dupe = state.keywords.any((x) =>
        x.keyword == k.keyword &&
        x.matchType == k.matchType &&
        x.negative == k.negative);
    if (dupe) return;
    state = state.copyWith(keywords: [...state.keywords, k]);
  }

  void removeKeyword(KeywordDraft k) => state =
      state.copyWith(keywords: state.keywords.where((x) => x != k).toList());

  /// Pre-fills the start date the first time the Details step opens.
  void ensureStart() {
    if (state.startsOn == null) {
      state = state.copyWith(startsOn: _day(DateTime.now()));
    }
  }
}
