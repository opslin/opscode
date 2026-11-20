import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/features/products/data/product_catalog.dart';
import 'package:dealker_vendor/features/products/data/unit_qc.dart';

enum AddStep { details, media, checklist, deviceQc, photoQc, videoQc, b2b, b2c, summary }

const _keep = Object();

/// 15-digit IMEI with the Luhn check the platform QC also applies.
bool isValidImei(String v) {
  final s = v.replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^\d{15}$').hasMatch(s)) return false;
  var sum = 0;
  for (var i = 0; i < 15; i++) {
    var d = int.parse(s[i]);
    if (i.isOdd) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 == 0;
}

/// Channel selection rules shared by Add Product and Bulk Add.
///
/// Choosing B2B on a product that is still B2C-only switches it to **B2B only** —
/// selling to customers as well is an explicit, optional extra the vendor turns on
/// afterwards. At least one channel always stays selected.
({bool b2b, bool b2c}) nextChannels({
  required bool b2b,
  required bool b2c,
  bool? tapB2b,
  bool? tapB2c,
}) {
  var nb2b = tapB2b ?? b2b;
  var nb2c = tapB2c ?? b2c;
  if (tapB2b == true && !b2b && b2c) nb2c = false; // B2B starts B2B-only
  if (!nb2b && !nb2c) return (b2b: b2b, b2c: b2c); // keep at least one
  return (b2b: nb2b, b2c: nb2c);
}

num? parseNum(String s) => s.trim().isEmpty ? null : num.tryParse(s.trim());

/// Everything the vendor enters while adding one product. Immutable; the
/// notifier replaces it on each edit.
class ProductDraft {
  const ProductDraft({
    this.step = AddStep.details,
    this.type = ProductType.mobile,
    this.brand = '',
    this.model = '',
    this.storage = '',
    this.condition = ProductCondition.newItem,
    this.conditionNotes = '',
    this.usage = '',
    this.battery = '',
    this.inBox = const [],
    this.quantity = '1',
    this.imei = '',
    this.description = '',
    this.sellB2b = false,
    this.sellB2c = true,
    this.images = const [],
    this.uploading = 0,
    this.angles = const {},
    this.scratchChoice,
    this.photoNote = '',
    this.videoUrl,
    this.videoUploading = false,
    this.videoChecks = const {},
    this.checklist = const {},
    this.checklistConfirmed = false,
    this.unitQc = const {},
    this.wholesale = '',
    this.moq = '1',
    this.discount = 0,
    this.b2bNotes = '',
    this.price = '',
    this.mrp = '',
    this.warranty = 'No warranty',
    this.returnDays = 7,
  });

  final AddStep step;
  final ProductType type;
  final String brand;
  final String model;
  final String storage;
  final ProductCondition condition;
  final String conditionNotes;

  /// How long the device has been used ("11 months") — shown on the customer product page.
  final String usage;

  /// Battery health % as typed; empty = not stated.
  final String battery;

  /// What the buyer gets in the box ("Charger", "GST invoice"…).
  final List<String> inBox;
  final String quantity;
  final String imei;
  final String description;
  final bool sellB2b;
  final bool sellB2c;

  final List<String> images;
  final int uploading;

  /// photo url → angle key (front/back/…).
  final Map<String, String> angles;

  /// null = not answered, true = no major scratches, false = has marks.
  final bool? scratchChoice;
  final String photoNote;
  final String? videoUrl;
  final bool videoUploading;
  final Map<String, bool> videoChecks;

  final Map<String, String> checklist;
  final bool checklistConfirmed;

  /// Device number (1-based) -> its QC. Only for used / refurbished / open-box; every unit needs one.
  final Map<int, UnitQc> unitQc;

  final String wholesale;
  final String moq;
  final int discount;
  final String b2bNotes;

  final String price;
  final String mrp;
  final String warranty;
  final int returnDays;

  // ── derived ──────────────────────────────────────────────────────────
  num? get priceN => parseNum(price);
  num? get mrpN => parseNum(mrp);
  num? get wholesaleN => parseNum(wholesale);
  int? get moqN => int.tryParse(moq.trim());
  int? get batteryN => int.tryParse(battery.trim());
  int? get quantityN => int.tryParse(quantity.trim());

  /// Every unit of a used / refurbished / open-box listing is its own device with its own QC report.
  bool get singleUnit => false;
  int get stock => quantityN ?? 0;

  /// Brand-new stock needs no per-device QC; everything else needs one report per unit.
  bool get needsDeviceQc => condition != ProductCondition.newItem;
  int get devicesDone => [for (var i = 1; i <= stock; i++) if (unitQc.containsKey(i)) i].length;

  String get title {
    final parts = [
      if (brand.isNotEmpty &&
          !model.toLowerCase().startsWith(brand.toLowerCase()))
        brand,
      model,
    ].where((p) => p.trim().isNotEmpty).join(' ');
    return storage.isEmpty ? parts : '$parts ($storage)';
  }

  /// Steps the vendor goes through, given the chosen channels.
  List<AddStep> get steps => [
        AddStep.details,
        // Refurbished / open box / used: the per-device QC list comes first, right after the details.
        if (needsDeviceQc) AddStep.deviceQc,
        AddStep.media,
        if (!needsDeviceQc) AddStep.checklist,
        AddStep.photoQc,
        AddStep.videoQc,
        if (sellB2b) AddStep.b2b,
        if (sellB2c) AddStep.b2c,
        AddStep.summary,
      ];

  int get stepIndex => steps.indexOf(step).clamp(0, steps.length - 1);

  int get discountPct => (mrpN != null && priceN != null && mrpN! > priceN!)
      ? (((mrpN! - priceN!) / mrpN!) * 100).round()
      : 0;

  bool get hasVideo => videoUrl != null;
  bool get frontBackTagged => kPhotoAngles
      .where((a) => a.required)
      .every((a) => angles.containsValue(a.key));
  int get taggedAngles => angles.values.toSet().length;

  // ── validation (null = OK) ───────────────────────────────────────────
  String? detailsError() {
    if (!sellB2b && !sellB2c) return 'Choose at least one: B2B or B2C.';
    if (brand.trim().isEmpty) return 'Select a brand.';
    if (model.trim().isEmpty) return 'Enter or select the model.';
    if (type.hasStorage && storage.isEmpty) return 'Select the storage.';
    final q = quantityN;
    if (!singleUnit && (q == null || q < 1)) {
      return 'Enter how many units you have.';
    }
    if (condition.isUsed && conditionNotes.trim().length < 10) {
      return 'Describe the condition (scratches, usage) — at least 10 characters.';
    }
    if (battery.trim().isNotEmpty &&
        (batteryN == null || batteryN! < 1 || batteryN! > 100)) {
      return 'Battery health must be a number from 1 to 100.';
    }
    if (imei.trim().isNotEmpty &&
        sellB2c &&
        type.hasImei &&
        !isValidImei(imei)) {
      return 'IMEI must be a valid 15-digit number.';
    }
    return null;
  }

  String? mediaError() {
    if (uploading > 0 || videoUploading) return 'Wait for uploads to finish.';
    if (images.length < 3) return 'Add at least 3 photos (${images.length}/3).';
    return null;
  }

  String? checklistError() => checklistConfirmed
      ? null
      : 'Confirm the details are accurate to continue.';

  String? deviceQcError() => devicesDone >= stock
      ? null
      : 'Complete the QC for every device ($devicesDone of $stock done).';

  String? photoQcError() {
    if (!frontBackTagged) {
      return 'Mark which photos show the Front and the Back.';
    }
    if (scratchChoice == null) return 'Tell us about scratches on the body.';
    if (scratchChoice == false && photoNote.trim().length < 5) {
      return 'Add a short note about the marks.';
    }
    return null;
  }

  String? b2bError() {
    final w = wholesaleN;
    if (w == null || w <= 0) return 'Enter the wholesale price.';
    final m = moqN;
    if (m == null || m < 1) return 'Minimum order quantity must be at least 1.';
    if (!singleUnit && stock > 0 && m > stock) {
      return 'MOQ ($m) cannot be more than your stock ($stock).';
    }
    return null;
  }

  String? b2cError() {
    final p = priceN;
    if (p == null || p <= 0) return 'Enter the selling price.';
    if (mrp.trim().isNotEmpty && (mrpN == null || mrpN! < p)) {
      return 'MRP cannot be lower than the selling price.';
    }
    if (sellB2b && wholesaleN != null && wholesaleN! > p) {
      return 'Wholesale price cannot be higher than the B2C price.';
    }
    return null;
  }

  String? errorFor(AddStep s) => switch (s) {
        AddStep.details => detailsError(),
        AddStep.media => mediaError(),
        AddStep.checklist => checklistError(),
        AddStep.deviceQc => deviceQcError(),
        AddStep.photoQc => photoQcError(),
        AddStep.videoQc => videoUploadingError(),
        AddStep.b2b => b2bError(),
        AddStep.b2c => b2cError(),
        AddStep.summary => null,
      };

  String? videoUploadingError() =>
      videoUploading ? 'The video is still uploading.' : null;

  ProductDraft copyWith({
    AddStep? step,
    ProductType? type,
    String? brand,
    String? model,
    String? storage,
    ProductCondition? condition,
    String? conditionNotes,
    String? usage,
    String? battery,
    List<String>? inBox,
    String? quantity,
    String? imei,
    String? description,
    bool? sellB2b,
    bool? sellB2c,
    List<String>? images,
    int? uploading,
    Map<String, String>? angles,
    Object? scratchChoice = _keep,
    String? photoNote,
    Object? videoUrl = _keep,
    bool? videoUploading,
    Map<String, bool>? videoChecks,
    Map<String, String>? checklist,
    bool? checklistConfirmed,
    Map<int, UnitQc>? unitQc,
    String? wholesale,
    String? moq,
    int? discount,
    String? b2bNotes,
    String? price,
    String? mrp,
    String? warranty,
    int? returnDays,
  }) =>
      ProductDraft(
        step: step ?? this.step,
        type: type ?? this.type,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        storage: storage ?? this.storage,
        condition: condition ?? this.condition,
        conditionNotes: conditionNotes ?? this.conditionNotes,
        usage: usage ?? this.usage,
        battery: battery ?? this.battery,
        inBox: inBox ?? this.inBox,
        quantity: quantity ?? this.quantity,
        imei: imei ?? this.imei,
        description: description ?? this.description,
        sellB2b: sellB2b ?? this.sellB2b,
        sellB2c: sellB2c ?? this.sellB2c,
        images: images ?? this.images,
        uploading: uploading ?? this.uploading,
        angles: angles ?? this.angles,
        scratchChoice: identical(scratchChoice, _keep)
            ? this.scratchChoice
            : scratchChoice as bool?,
        photoNote: photoNote ?? this.photoNote,
        videoUrl:
            identical(videoUrl, _keep) ? this.videoUrl : videoUrl as String?,
        videoUploading: videoUploading ?? this.videoUploading,
        videoChecks: videoChecks ?? this.videoChecks,
        checklist: checklist ?? this.checklist,
        checklistConfirmed: checklistConfirmed ?? this.checklistConfirmed,
        unitQc: unitQc ?? this.unitQc,
        wholesale: wholesale ?? this.wholesale,
        moq: moq ?? this.moq,
        discount: discount ?? this.discount,
        b2bNotes: b2bNotes ?? this.b2bNotes,
        price: price ?? this.price,
        mrp: mrp ?? this.mrp,
        warranty: warranty ?? this.warranty,
        returnDays: returnDays ?? this.returnDays,
      );

  /// Request body for `POST /vendor/listings`.
  ///
  /// [selfChecked] false (bulk add) leaves out the checklist / photo / video
  /// declarations — the vendor never made them, so none are claimed.
  Map<String, dynamic> toRequest(
      {required String categoryId, bool selfChecked = true}) {
    final cl = checklist.isEmpty
        ? {for (final i in checklistFor(type)) i.label: i.best}
        : checklist;
    final notes = [
      conditionNotes.trim(),
      if (scratchChoice == false) photoNote.trim(),
    ].where((e) => e.isNotEmpty).join(' · ');
    return {
      'name': title,
      'brand': brand.trim(),
      'categoryId': categoryId,
      if (description.trim().isNotEmpty) 'description': description.trim(),
      'condition': condition.api,
      if (notes.isNotEmpty) 'conditionNotes': notes,
      if (usage.trim().isNotEmpty && condition != ProductCondition.newItem)
        'usageDuration': usage.trim(),
      if (batteryN != null && condition != ProductCondition.newItem)
        'batteryHealth': batteryN,
      if (inBox.isNotEmpty) ...{
        'accessoriesIncluded': inBox.join(', '),
        'hasInvoice': inBox.contains('GST invoice'),
      },
      'images': images,
      if (videoUrl != null) 'videoUrl': videoUrl,
      'stock': stock,
      'sellB2c': sellB2c,
      'sellB2b': sellB2b,
      if (sellB2c) ...{
        'price': priceN,
        if (mrpN != null) 'mrp': mrpN,
        if (warranty != 'No warranty') 'warrantyInfo': warranty,
        'returnPolicyDays': returnDays,
        if (type.hasImei && imei.trim().isNotEmpty && stock == 1)
          'imei': imei.replaceAll(RegExp(r'[\s-]'), ''),
      },
      if (sellB2b) ...{
        'wholesalePrice': wholesaleN,
        'moq': moqN,
        'b2bDiscountPct': discount,
        if (b2bNotes.trim().isNotEmpty) 'b2bNotes': b2bNotes.trim(),
      },
      'specifications': {
        'product_type': type.key,
        'model': model.trim(),
        if (storage.isNotEmpty) 'storage': storage,
      },
      if (needsDeviceQc && selfChecked) ...{
        'unitQc': [for (var i = 1; i <= stock; i++) (unitQc[i] ?? UnitQc.allGood()).toJson()],
      },
      if (selfChecked)
        'vendorQc': {
          'version': 1,
          if (!needsDeviceQc) 'checklist': cl,
          'photoAngles': [
            for (final e in angles.entries) {'url': e.key, 'angle': e.value}
          ],
          'noMajorScratches': scratchChoice,
          if (photoNote.trim().isNotEmpty) 'photoNote': photoNote.trim(),
          if (videoUrl != null) 'videoChecks': videoChecks,
        },
    };
  }
}

class ProductDraftNotifier extends Notifier<ProductDraft> {
  @override
  ProductDraft build() => const ProductDraft();

  void set(ProductDraft Function(ProductDraft d) f) => state = f(state);

  void go(AddStep s) => state = state.copyWith(step: s);
  void reset() => state = const ProductDraft();

  /// Changing the type resets everything that depends on it.
  void setType(ProductType t) {
    if (t == state.type) return;
    state = ProductDraft(
      step: state.step,
      type: t,
      sellB2b: state.sellB2b,
      sellB2c: state.sellB2c,
      condition: state.condition,
      usage: state.usage,
      images: state.images,
      angles: state.angles,
      videoUrl: state.videoUrl,
    );
  }

  void setBrand(String b) => state = state.copyWith(brand: b, model: '');

  void setChannel({bool? b2b, bool? b2c}) {
    final next = nextChannels(
        b2b: state.sellB2b, b2c: state.sellB2c, tapB2b: b2b, tapB2c: b2c);
    state = state.copyWith(sellB2b: next.b2b, sellB2c: next.b2c);
  }

  // photos
  void addImage(String url) {
    if (state.images.length >= 8 || state.images.contains(url)) return;
    state = state.copyWith(images: [...state.images, url]);
  }

  void removeImage(String url) {
    state = state.copyWith(
      images: state.images.where((e) => e != url).toList(),
      angles: Map.of(state.angles)..remove(url),
    );
  }

  void setUploading(int delta) =>
      state = state.copyWith(uploading: (state.uploading + delta).clamp(0, 99));

  /// Gives [angle] to [url]; an angle belongs to one photo at a time and a
  /// photo carries one angle.
  void tagAngle(String url, String angle) {
    final next = Map.of(state.angles)
      ..removeWhere((k, v) => v == angle || k == url);
    if (state.angles[url] != angle) next[url] = angle;
    state = state.copyWith(angles: next);
  }

  /// Saves the QC of device [n]. Reports of devices beyond the quantity are dropped.
  void saveUnit(int n, UnitQc qc) =>
      state = state.copyWith(unitQc: {...state.unitQc, n: qc});

  void dropExtraUnits() {
    final stock = state.stock;
    if (state.unitQc.keys.any((k) => k > stock)) {
      state = state.copyWith(unitQc: {for (final e in state.unitQc.entries) if (e.key <= stock) e.key: e.value});
    }
  }

  // checklist
  void answer(String item, String value) => state = state.copyWith(
      checklist: {...state.checklist, item: value}, checklistConfirmed: false);

  void toggleVideoCheck(String item) => state = state.copyWith(videoChecks: {
        ...state.videoChecks,
        item: !(state.videoChecks[item] ?? false)
      });
}
