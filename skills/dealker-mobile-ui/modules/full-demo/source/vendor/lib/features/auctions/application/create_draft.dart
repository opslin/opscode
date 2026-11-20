import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/features/auctions/data/auction_models.dart';

/// Steps of the create flow (mockup screens 1–6).
enum CreateStep { type, product, details, settings, media, review }

/// Durations offered in Settings, filtered by the platform's min/max rules.
const durationChoices = [1, 2, 6, 12, 24, 48, 72, 168];

String durationLabel(int h) => h < 24
    ? '$h ${h == 1 ? 'Hour' : 'Hours'}'
    : '${h ~/ 24} ${h == 24 ? 'Day' : 'Days'}';

/// Fixed bid steps offered next to "Automatic" (platform tiers).
const incrementChoices = <num>[100, 500, 1000, 2000, 5000];

/// Tick-list the seller confirms for the QC report (what bidders see).
const qcCheckItems = [
  'Boots properly',
  'Touch works',
  'Display OK',
  'Camera works',
  'Sound works',
  'Battery healthy',
  'No physical damage',
  'Original / box & accessories',
];

class CreateDraft {
  const CreateDraft({
    this.step = CreateStep.type,
    this.audience = AuctionAudience.b2b,
    this.product,
    this.title = '',
    this.startPrice = '',
    this.reservePrice = '',
    this.buyNowPrice = '',
    this.quantity = '1',
    this.startNow = true,
    this.startsAt,
    this.bidIncrement,
    this.durationHours = 24,
    this.registrationFee = '',
    this.images = const [],
    this.uploading = 0,
    this.videoUrl,
    this.videoUploading = false,
    this.qcChecklist = const {},
    this.qcChecks = const {},
    this.qcPhotos = const [],
    this.qcUploading = 0,
    this.qcNotes = '',
  });

  final CreateStep step;
  final AuctionAudience audience;
  final ProductOption? product;
  final String title;
  final String startPrice;
  final String reservePrice;
  final String buyNowPrice;
  final String quantity;
  final bool startNow;
  final DateTime? startsAt;
  final num? bidIncrement; // null = automatic platform tiers
  final int durationHours;
  final String registrationFee;
  final List<String> images;
  final int uploading;
  final String? videoUrl;
  final bool videoUploading;
  final Map<String, String> qcChecklist; // carried over from the product
  final Map<String, bool> qcChecks;
  final List<String> qcPhotos;
  final int qcUploading;
  final String qcNotes;

  bool get hasQc =>
      qcChecks.values.any((v) => v) ||
      qcChecklist.isNotEmpty ||
      qcPhotos.isNotEmpty ||
      qcNotes.trim().isNotEmpty;
  bool get mediaBusy => uploading > 0 || videoUploading || qcUploading > 0;

  QcReport? get qcReport => !hasQc
      ? null
      : QcReport(
          checklist: qcChecklist,
          checks: {
            for (final e in qcChecks.entries)
              if (e.value) e.key: true
          },
          photos: qcPhotos,
          notes: qcNotes.trim(),
        );

  num? _num(String s) => s.trim().isEmpty ? null : num.tryParse(s.trim());
  num? get startPriceN => _num(startPrice);
  num? get reserveN => _num(reservePrice);
  num? get buyNowN => _num(buyNowPrice);
  num? get feeN => _num(registrationFee);
  int? get quantityN => int.tryParse(quantity.trim());
  bool get isB2b => audience == AuctionAudience.b2b;

  CreateDraft copyWith({
    CreateStep? step,
    AuctionAudience? audience,
    ProductOption? product,
    String? title,
    String? startPrice,
    String? reservePrice,
    String? buyNowPrice,
    String? quantity,
    bool? startNow,
    DateTime? startsAt,
    Object? bidIncrement = _keep,
    int? durationHours,
    String? registrationFee,
    List<String>? images,
    int? uploading,
    Object? videoUrl = _keep,
    bool? videoUploading,
    Map<String, String>? qcChecklist,
    Map<String, bool>? qcChecks,
    List<String>? qcPhotos,
    int? qcUploading,
    String? qcNotes,
  }) =>
      CreateDraft(
        step: step ?? this.step,
        audience: audience ?? this.audience,
        product: product ?? this.product,
        title: title ?? this.title,
        startPrice: startPrice ?? this.startPrice,
        reservePrice: reservePrice ?? this.reservePrice,
        buyNowPrice: buyNowPrice ?? this.buyNowPrice,
        quantity: quantity ?? this.quantity,
        startNow: startNow ?? this.startNow,
        startsAt: startsAt ?? this.startsAt,
        bidIncrement: identical(bidIncrement, _keep)
            ? this.bidIncrement
            : bidIncrement as num?,
        durationHours: durationHours ?? this.durationHours,
        registrationFee: registrationFee ?? this.registrationFee,
        images: images ?? this.images,
        uploading: uploading ?? this.uploading,
        videoUrl:
            identical(videoUrl, _keep) ? this.videoUrl : videoUrl as String?,
        videoUploading: videoUploading ?? this.videoUploading,
        qcChecklist: qcChecklist ?? this.qcChecklist,
        qcChecks: qcChecks ?? this.qcChecks,
        qcPhotos: qcPhotos ?? this.qcPhotos,
        qcUploading: qcUploading ?? this.qcUploading,
        qcNotes: qcNotes ?? this.qcNotes,
      );

  // ── per-step validation: null means the step is complete ────────────

  String? detailsError() {
    if (title.trim().length < 3) return 'Enter an auction title.';
    final sp = startPriceN;
    if (sp == null || sp <= 0) return 'Enter a starting price.';
    final r = reserveN;
    if (reservePrice.trim().isNotEmpty && (r == null || r < sp)) {
      return 'Reserve price cannot be below the starting price.';
    }
    if (isB2b) {
      final q = quantityN;
      if (q == null || q < 1) return 'Enter how many units are in this lot.';
      final stock = product?.stock;
      if (stock != null && q > stock) {
        return 'Only $stock in stock — a lot of $q needs more.';
      }
    }
    if (!startNow) {
      final s = startsAt;
      if (s == null) return 'Pick a start date and time.';
      if (s.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
        return 'Start time must be at least 5 minutes from now.';
      }
    }
    return null;
  }

  String? settingsError(AuctionRules rules) {
    final sp = startPriceN ?? 0;
    final fee = feeN;
    final max = rules.maxFeeFor(sp);
    if (fee == null) return 'Enter a registration fee.';
    if (fee < rules.minFee) {
      return 'Registration fee must be at least ₹${rules.minFee.toInt()}.';
    }
    if (fee > max) {
      return 'Registration fee can be at most ₹${max.toInt()} '
          '(${rules.feeMaxPct.toInt()}% of the starting price).';
    }
    final b = buyNowN;
    if (buyNowPrice.trim().isNotEmpty && (b == null || b <= (reserveN ?? sp))) {
      return 'Buy-now price must be above the start and reserve prices.';
    }
    return null;
  }

  CreateAuctionRequest toRequest({bool draft = false}) => CreateAuctionRequest(
        audience: audience,
        productId: product!.id,
        title: title.trim(),
        startPrice: startPriceN!,
        registrationFee: feeN!,
        durationHours: durationHours,
        images: images,
        reservePrice: reserveN,
        buyNowPrice: buyNowN,
        bidIncrement: bidIncrement,
        quantity: isB2b ? quantityN : null,
        startsAt: startNow ? null : startsAt,
        saveAsDraft: draft,
        videoUrl: videoUrl,
        qc: qcReport,
      );
}

const _keep = Object();

class CreateDraftNotifier extends Notifier<CreateDraft> {
  @override
  CreateDraft build() => const CreateDraft();

  void go(CreateStep s) => state = state.copyWith(step: s);

  void setAudience(AuctionAudience a) {
    if (a == state.audience) return;
    state = state.copyWith(audience: a);
  }

  /// Picking a product pre-fills title, price hint and its own photos.
  void pickProduct(ProductOption p) => state = CreateDraft(
        step: state.step,
        audience: state.audience,
        product: p,
        title: p.name,
        images: p.images.isNotEmpty
            ? p.images.take(10).toList()
            : (p.thumbnail != null ? [p.thumbnail!] : const []),
        videoUrl: p.videoUrl,
        qcChecklist: p.qc?.checklist ?? const {},
        qcChecks: p.qc?.checks ?? const {},
        qcPhotos: p.qc?.photos ?? const [],
        qcNotes: p.qc?.notes ?? '',
      );

  void set({
    String? title,
    String? startPrice,
    String? reservePrice,
    String? buyNowPrice,
    String? quantity,
    String? registrationFee,
  }) =>
      state = state.copyWith(
        title: title,
        startPrice: startPrice,
        reservePrice: reservePrice,
        buyNowPrice: buyNowPrice,
        quantity: quantity,
        registrationFee: registrationFee,
      );

  void setStart({required bool now, DateTime? at}) =>
      state = state.copyWith(startNow: now, startsAt: at);
  void setIncrement(num? v) => state = state.copyWith(bidIncrement: v);
  void setDuration(int h) => state = state.copyWith(durationHours: h);

  void addImage(String url) {
    if (state.images.length >= 10) return;
    state = state.copyWith(images: [...state.images, url]);
  }

  void removeImage(String url) => state =
      state.copyWith(images: state.images.where((u) => u != url).toList());
  void setUploading(int delta) =>
      state = state.copyWith(uploading: (state.uploading + delta).clamp(0, 99));

  /// Pre-fills the registration fee with the platform minimum.
  void defaultFee(AuctionRules rules) {
    if (state.registrationFee.isNotEmpty) return;
    state = state.copyWith(registrationFee: '${rules.minFee.toInt()}');
  }

  void setVideo(String? url) => state = state.copyWith(videoUrl: url);
  void setVideoUploading(bool b) => state = state.copyWith(videoUploading: b);

  void toggleQc(String item) => state = state.copyWith(
      qcChecks: {...state.qcChecks, item: !(state.qcChecks[item] ?? false)});
  void addQcPhoto(String url) {
    if (state.qcPhotos.length >= 6) return;
    state = state.copyWith(qcPhotos: [...state.qcPhotos, url]);
  }

  void removeQcPhoto(String url) => state =
      state.copyWith(qcPhotos: state.qcPhotos.where((u) => u != url).toList());
  void setQcUploading(int delta) => state =
      state.copyWith(qcUploading: (state.qcUploading + delta).clamp(0, 99));
  void setQcNotes(String v) => state = state.copyWith(qcNotes: v);

  void reset() => state = const CreateDraft();
}
