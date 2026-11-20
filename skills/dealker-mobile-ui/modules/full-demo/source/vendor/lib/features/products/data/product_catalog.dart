import 'package:flutter/widgets.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// A product type. The four built-ins keep their specific forms and
/// checklists; every other type is an existing platform category (managed by
/// admins — vendors only pick) and uses the generic
/// form — no storage / IMEI, free-typed brand and model.
///
/// The pick-lists below (brands, models, checklists) are suggestions only —
/// every picker also accepts a typed value.
@immutable
class ProductType {
  const ProductType._(
    this.key,
    this.label, {
    this.icon = PhosphorIconsRegular.headphones,
    this.builtIn = false,
    this.imageUrl,
    this.categoryId,
  });

  /// A platform category shown as a product type.
  const ProductType.custom({
    required String key,
    required String label,
    String? imageUrl,
    String? categoryId,
  }) : this._(key, label,
            imageUrl: imageUrl, categoryId: categoryId);

  static const mobile = ProductType._('mobile', 'Mobile',
      icon: PhosphorIconsRegular.deviceMobile, builtIn: true);
  static const laptop = ProductType._('laptop', 'Laptop',
      icon: PhosphorIconsRegular.laptop, builtIn: true);
  static const tablet = ProductType._('tablet', 'Tablet',
      icon: PhosphorIconsRegular.deviceTablet, builtIn: true);
  static const accessories = ProductType._('accessories', 'Accessories',
      icon: PhosphorIconsRegular.headphones, builtIn: true);

  /// The four built-in types, in picker order.
  static const values = [mobile, laptop, tablet, accessories];

  /// Stored in the listing specs as `product_type`.
  final String key;
  final String label;
  final IconData icon;
  final bool builtIn;
  final String? imageUrl;

  /// Platform category this type files listings under (custom types only).
  final String? categoryId;

  /// Same as [key]; kept so older call sites reading `.name` keep working.
  String get name => key;

  bool get hasStorage => !builtIn ? false : this != accessories;
  bool get hasImei => this == mobile || this == tablet;

  /// Old listings may carry a key we do not know (a custom type): keep it
  /// readable instead of falling back to Mobile.
  static ProductType fromKey(String? k) {
    if (k == null || k.isEmpty) return mobile;
    for (final t in values) {
      if (t.key == k) return t;
    }
    final label = k
        .split(RegExp(r'[-_\s]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
    return ProductType.custom(key: k, label: label);
  }

  @override
  bool operator ==(Object other) => other is ProductType && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Server condition enum ↔ vendor-facing label.
enum ProductCondition {
  newItem('NEW', 'New', 'Sealed / unused'),
  openBox('OPEN_BOX', 'Open Box', 'Opened, unused'),
  refurbished('REFURBISHED', 'Refurbished', 'Restored & tested'),
  likeNew('USED_LIKE_NEW', 'Like New', 'Barely used'),
  good('USED_GOOD', 'Good', 'Light signs of use'),
  fair('USED_FAIR', 'Fair', 'Visible wear');

  const ProductCondition(this.api, this.label, this.hint);
  final String api;
  final String label;
  final String hint;

  /// Used phones need a written condition description.
  bool get isUsed => api.startsWith('USED_');

  static ProductCondition fromApi(String? v) => ProductCondition.values
      .firstWhere((c) => c.api == v, orElse: () => ProductCondition.newItem);
}

const kStorageOptions = ['64GB', '128GB', '256GB', '512GB', '1TB', '2TB'];

const kWarrantyOptions = [
  'No warranty',
  '3 Months',
  '6 Months',
  '1 Year',
  '2 Years',
];

const kUsageOptions = [
  'Less than 1 month',
  '3 months',
  '6 months',
  '9 months',
  '1 year',
  '18 months',
  '2 years',
  '3+ years',
];

/// "What's in the box" choices, by product type. Shown to customers as-is.
List<String> inBoxFor(ProductType t) => switch (t.key) {
      'mobile' || 'tablet' => const [
          'Charger',
          'Cable',
          'Original box',
          'Earphones',
          'SIM ejector',
          'Back cover',
          'GST invoice',
        ],
      'laptop' => const [
          'Charger',
          'Original box',
          'Laptop bag',
          'GST invoice',
        ],
      'accessories' => const [
          'Charging case',
          'Cable',
          'Ear tips',
          'Original box',
          'GST invoice',
        ],
      _ => const ['Original box', 'Cable', 'GST invoice'],
    };

const kDiscountChoices = [0, 3, 5, 8, 10, 15];

const kReturnDayChoices = [0, 7, 10, 15];

const _brands = {
  'mobile': [
    'Apple',
    'Samsung',
    'OnePlus',
    'Xiaomi',
    'Redmi',
    'Realme',
    'Vivo',
    'Oppo',
    'Google',
    'Motorola',
    'Nothing',
    'iQOO',
    'Poco',
  ],
  'laptop': ['Apple', 'Dell', 'HP', 'Lenovo', 'Asus', 'Acer', 'MSI'],
  'tablet': ['Apple', 'Samsung', 'Lenovo', 'Xiaomi', 'OnePlus'],
  'accessories': [
    'Apple',
    'Samsung',
    'Anker',
    'boAt',
    'Sony',
    'JBL',
    'Mi',
    'Logitech',
  ],
};

List<String> brandsFor(ProductType t) => _brands[t.key] ?? const [];

const _models = {
  'mobile|Apple': [
    'iPhone 16 Pro Max',
    'iPhone 16 Pro',
    'iPhone 16 Plus',
    'iPhone 16',
    'iPhone 15 Pro Max',
    'iPhone 15 Pro',
    'iPhone 15 Plus',
    'iPhone 15',
    'iPhone 14 Pro Max',
    'iPhone 14 Pro',
    'iPhone 14',
    'iPhone 13',
    'iPhone 12',
  ],
  'mobile|Samsung': [
    'Galaxy S24 Ultra',
    'Galaxy S24+',
    'Galaxy S24',
    'Galaxy S23 Ultra',
    'Galaxy S23',
    'Galaxy A55 5G',
    'Galaxy A35 5G',
    'Galaxy Z Fold5',
    'Galaxy Z Flip5',
  ],
  'mobile|OnePlus': ['OnePlus 12', 'OnePlus 12R', 'OnePlus 11', 'Nord CE 4'],
  'mobile|Xiaomi': ['Xiaomi 14', 'Xiaomi 14 Civi', 'Xiaomi 13T'],
  'mobile|Redmi': ['Redmi Note 13 Pro+', 'Redmi Note 13 5G', 'Redmi 12 5G'],
  'mobile|Google': ['Pixel 8 Pro', 'Pixel 8', 'Pixel 8a', 'Pixel 7a'],
  'laptop|Apple': [
    'MacBook Air M3',
    'MacBook Air M2',
    'MacBook Pro 14 M3',
    'MacBook Pro 16 M3',
  ],
  'tablet|Apple': [
    'iPad Pro 11 M4',
    'iPad Air M2',
    'iPad 10th Gen',
    'iPad mini 6'
  ],
  'tablet|Samsung': ['Galaxy Tab S9', 'Galaxy Tab S9 FE', 'Galaxy Tab A9+'],
};

List<String> modelsFor(ProductType t, String? brand) =>
    _models['${t.key}|${brand ?? ''}'] ?? const [];

/// One line of the vendor's physical self-check.
class QcItem {
  const QcItem(this.label, this.options);
  final String label;

  /// Best answer first (used as the default).
  final List<String> options;
  String get best => options.first;
}

const _fine = ['Working fine', 'Minor issue', 'Not working'];
const _body = ['Excellent', 'Good', 'Fair', 'Damaged'];
const _acc = ['Included', 'Partial', 'Not included'];

List<QcItem> checklistFor(ProductType t) => switch (t.key) {
      'mobile' || 'tablet' => const [
          QcItem('Screen Display', _fine),
          QcItem('Touch Function', _fine),
          QcItem('Camera', _fine),
          QcItem('Buttons', _fine),
          QcItem('Speaker & Mic', _fine),
          QcItem('Body Condition', _body),
          QcItem('Accessories', _acc),
        ],
      'laptop' => const [
          QcItem('Screen Display', _fine),
          QcItem('Keyboard & Trackpad', _fine),
          QcItem('Camera & Mic', _fine),
          QcItem('Ports', _fine),
          QcItem('Battery & Charging', _fine),
          QcItem('Body Condition', _body),
          QcItem('Accessories', _acc),
        ],
      _ => const [
          QcItem('Working Condition', _fine),
          QcItem('Body Condition', _body),
          QcItem('Accessories', _acc),
        ],
    };

/// Angles the Photo QC step asks for. Front and Back are mandatory.
class PhotoAngle {
  const PhotoAngle(this.key, this.label, {this.required = false});
  final String key;
  final String label;
  final bool required;
}

const kPhotoAngles = [
  PhotoAngle('front', 'Front', required: true),
  PhotoAngle('back', 'Back', required: true),
  PhotoAngle('left', 'Left'),
  PhotoAngle('right', 'Right'),
  PhotoAngle('top', 'Top'),
  PhotoAngle('bottom', 'Bottom'),
];

const kVideoChecks = [
  'Boots properly',
  'Touch works',
  'Camera works',
  'Sound works',
  'No physical damage',
];
