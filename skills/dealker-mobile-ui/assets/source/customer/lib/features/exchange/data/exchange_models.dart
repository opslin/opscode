/// A trade-in device model from `GET /exchange-requests/catalog` (admin-managed catalogue).
class ExchangeModel {
  const ExchangeModel({
    required this.id,
    required this.name,
    required this.category,
    required this.variants,
    required this.colors,
    required this.basePrice,
    this.brand,
    this.brandLogoUrl,
    this.imageUrl,
    this.series,
  });

  factory ExchangeModel.fromJson(Map<String, dynamic> j) => ExchangeModel(
        id: '${j['id']}',
        name: '${j['name']}',
        category: '${j['category']}',
        variants: _strings(j['variants']),
        colors: _strings(j['colors']),
        basePrice: (j['basePrice'] as num?)?.toDouble() ?? 0,
        brand: (j['brand'] as String?)?.trim().isEmpty ?? true
            ? null
            : (j['brand'] as String).trim(),
        brandLogoUrl: j['brandLogoUrl'] as String?,
        imageUrl: j['imageUrl'] as String?,
        series: (j['series'] as String?)?.trim().isEmpty ?? true
            ? null
            : (j['series'] as String).trim(),
      );

  final String id;
  final String name;
  final String category;
  final List<String> variants; // lowest → highest storage
  final List<String> colors;
  final double basePrice;
  final String? brand;
  final String? brandLogoUrl;
  final String? imageUrl;
  final String? series;

  /// False for models imported without a catalogue price — the seller then types the price he expects.
  bool get hasPrice => basePrice > 0;

  static List<String> _strings(Object? v) =>
      v is List ? v.map((Object? e) => '$e').toList() : <String>[];
}

/// A kind of old device Dealkr accepts (Smartphone, Headphones …) and the questions it needs.
class ExchangeType {
  const ExchangeType({
    required this.key,
    required this.label,
    required this.icon,
    required this.needsImei,
    required this.hasScreen,
    required this.hasBattery,
    required this.hasCamera,
    this.upTo = 0,
    this.typical = 0,
    this.models = 0,
  });

  factory ExchangeType.fromJson(Map<String, dynamic> j) => ExchangeType(
        key: '${j['key']}',
        label: '${j['label']}',
        icon: '${j['icon'] ?? 'other'}',
        needsImei: j['needsImei'] == true,
        hasScreen: j['hasScreen'] != false,
        hasBattery: j['hasBattery'] != false,
        hasCamera: j['hasCamera'] == true,
        upTo: (j['upTo'] as num?)?.toDouble() ?? 0,
        typical: (j['typical'] as num?)?.toDouble() ?? 0,
        models: (j['models'] as num?)?.toInt() ?? 0,
      );

  final String key;
  final String label;
  final String icon;
  final bool needsImei;
  final bool hasScreen;
  final bool hasBattery;
  final bool hasCamera;

  /// Highest / middle credit this kind of device fetches on the product (₹, already capped to the product price).
  final double upTo;
  final double typical;
  final int models;
}

/// Answer of `GET /exchange-requests/for-product/:id` — is exchange offered on this product, and for what.
class ExchangeOffer {
  const ExchangeOffer({
    required this.eligible,
    required this.types,
    required this.maxValue,
  });

  factory ExchangeOffer.fromJson(Map<String, dynamic> j) => ExchangeOffer(
        eligible: j['eligible'] == true,
        maxValue: (j['maxValue'] as num?)?.toDouble() ?? 0,
        types: (j['types'] as List? ?? <Object?>[])
            .whereType<Map>()
            .map((Map e) => ExchangeType.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  static const ExchangeOffer none =
      ExchangeOffer(eligible: false, types: <ExchangeType>[], maxValue: 0);

  final bool eligible;
  final List<ExchangeType> types;
  final double maxValue;
}

/// Everything the exchange flow needs for one product: accepted types and their models.
class ExchangeOptions {
  const ExchangeOptions({
    required this.types,
    required this.models,
    required this.maxValue,
  });
  final List<ExchangeType> types;
  final List<ExchangeModel> models;
  final double maxValue;
}

/// One brand tile: the brand name + logo shared by its models.
class ExchangeBrand {
  const ExchangeBrand({required this.name, this.logoUrl});
  final String name;
  final String? logoUrl;
}

/// The customer's answers → the server's `qa` object (the server is the only authority on the price).
class ExchangeQa {
  const ExchangeQa({
    required this.ageMonths,
    required this.screenScratches,
    required this.bodyDents,
    required this.screenReplaced,
    required this.billAvailable,
    required this.boxAvailable,
    required this.chargerAvailable,
    required this.batteryHealth,
    required this.faceIdIssue,
    required this.cameraIssue,
    this.powersOn = true,
  });

  final int ageMonths;
  final String screenScratches; // NONE | MINOR | MAJOR
  final bool bodyDents;
  final bool screenReplaced;
  final bool billAvailable;
  final bool boxAvailable;
  final bool chargerAvailable;
  final int batteryHealth;
  final bool faceIdIssue;
  final bool cameraIssue;
  final bool powersOn;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ageMonths': ageMonths,
        'screenScratches': screenScratches,
        'bodyDents': bodyDents,
        'screenReplaced': screenReplaced,
        'skinReplaced': false,
        'billAvailable': billAvailable,
        'boxAvailable': boxAvailable,
        'chargerAvailable': chargerAvailable,
        'batteryHealth': batteryHealth,
        'powersOn': powersOn,
        'faceIdIssue': faceIdIssue,
        'cameraIssue': cameraIssue,
      };
}

class ExchangeQuote {
  const ExchangeQuote({
    required this.value,
    required this.credit,
    required this.condition,
    required this.base,
    required this.deductions,
  });

  factory ExchangeQuote.fromJson(Map<String, dynamic> j) => ExchangeQuote(
        value: (j['quote'] as num?)?.toDouble() ?? 0,
        credit: (j['credit'] as num?)?.toDouble() ??
            (j['quote'] as num?)?.toDouble() ??
            0,
        condition: '${j['condition']}',
        base: (j['base'] as num?)?.toDouble() ?? 0,
        deductions: (j['deductions'] as List? ?? <Object?>[])
            .whereType<Map>()
            .map((Map e) => '${e['label']}')
            .toList(),
      );

  final double value;

  /// What is taken off the new product (the value, capped to the programme's share of its price).
  final double credit;
  final String condition; // EXCELLENT | GOOD | FAIR | POOR
  final double base;
  final List<String> deductions;

  String get conditionLabel => switch (condition) {
        'EXCELLENT' => 'Like New',
        'GOOD' => 'Good',
        'FAIR' => 'Fair',
        _ => 'Poor',
      };
}

/// What the customer is buying (passed from the product page).
class ExchangeTarget {
  const ExchangeTarget({
    required this.productId,
    required this.name,
    required this.price,
  });
  final String productId;
  final String name;
  final double price;
}

class ExchangeSummary {
  const ExchangeSummary({required this.enabled, required this.maxValue});
  final bool enabled;
  final double maxValue;
}
