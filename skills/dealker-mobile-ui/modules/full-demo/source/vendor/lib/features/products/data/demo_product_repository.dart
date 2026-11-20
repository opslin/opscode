import 'package:dio/dio.dart';

import 'package:dealker_vendor/features/products/data/product_models.dart';
import 'package:dealker_vendor/features/products/data/product_repository.dart';

const _img = 'https://api.dealker.agnixstudio.in/uploads/products';

/// DEMO ONLY (`.env` DEMO_HOME=true) — in-memory listings so the whole
/// Add Product / My Products flow can be reviewed without a vendor login.
/// Photos are the platform's real catalogue photos. Delete with the switch in
/// `product_providers.dart`.
class DemoProductRepository extends ProductRepository {
  DemoProductRepository() : super(Dio());

  static int _seq = 100;
  final List<Map<String, dynamic>> _rows = [
    _seed('p1', 'Apple iPhone 15 Pro (256GB)', 'Apple', 'iPhone 15 Pro',
        '256GB', 'apple-iphone-15-pro-256gb-natural-titanium',
        condition: 'NEW',
        approval: 'APPROVED',
        price: 119900,
        mrp: 127900,
        stock: 24,
        wholesale: 112500,
        moq: 3,
        b2b: true,
        qc: 'QC_PASSED',
        warranty: '1 Year',
        days: 1),
    _seed(
        'p2',
        'Samsung Galaxy S24 Ultra (256GB)',
        'Samsung',
        'Galaxy S24 Ultra',
        '256GB',
        'samsung-galaxy-s24-ultra-5g-12gb-256gb-titanium-gray',
        condition: 'NEW',
        approval: 'APPROVED',
        price: 104999,
        mrp: 129999,
        stock: 15,
        qc: 'QC_PASSED',
        warranty: '1 Year',
        days: 3),
    _seed('p3', 'OnePlus 12 (256GB)', 'OnePlus', 'OnePlus 12', '256GB',
        'oneplus-12-5g-12gb-256gb-silky-black',
        condition: 'NEW',
        approval: 'PENDING',
        price: 58500,
        mrp: 62999,
        stock: 20,
        wholesale: 58500,
        moq: 5,
        b2c: false,
        b2b: true,
        qc: 'QC_PENDING',
        days: 0),
    _seed('p4', 'Google Pixel 8a (128GB)', 'Google', 'Pixel 8a', '128GB',
        'google-pixel-8a-8gb-128gb-obsidian',
        condition: 'USED_LIKE_NEW',
        approval: 'APPROVED',
        price: 38500,
        mrp: 52999,
        stock: 1,
        qc: 'QC_PASSED',
        warranty: '6 Months',
        days: 5),
    _seed('p5', 'Redmi Note 13 Pro+ (256GB)', 'Redmi', 'Redmi Note 13 Pro+',
        '256GB', 'redmi-note-13-pro-5g-8gb-256gb-fusion-purple',
        condition: 'NEW',
        approval: 'REJECTED',
        price: 27999,
        mrp: 29999,
        stock: 30,
        qc: 'QC_FAILED',
        reason:
            'The back photo is blurry. Add a clear photo of the back and submit again.',
        days: 2),
    _seed('p6', 'Apple iPhone 15 (128GB)', 'Apple', 'iPhone 15', '128GB',
        'apple-iphone-15-128gb-blue',
        condition: 'NEW',
        approval: 'APPROVED',
        status: 'PAUSED',
        price: 66900,
        mrp: 69900,
        stock: 9,
        qc: 'QC_PASSED',
        warranty: '1 Year',
        days: 8),
    _seed('p7', 'Apple iPhone 16 (128GB)', 'Apple', 'iPhone 16', '128GB',
        'apple-iphone-16-128gb-black',
        condition: 'NEW',
        approval: 'APPROVED',
        status: 'OUT_OF_STOCK',
        price: 72900,
        mrp: 74900,
        stock: 0,
        qc: 'QC_PASSED',
        warranty: '1 Year',
        days: 9),
  ];

  static Map<String, dynamic> _seed(
    String id,
    String name,
    String brand,
    String model,
    String storage,
    String slug, {
    required String condition,
    required String approval,
    String status = 'ACTIVE',
    required num price,
    required num mrp,
    required int stock,
    num? wholesale,
    int moq = 1,
    bool b2c = true,
    bool b2b = false,
    String qc = 'QC_PENDING',
    String warranty = '',
    String? reason,
    int days = 1,
  }) =>
      {
        'id': id,
        'name': name,
        'brand': brand,
        'description': '',
        'category_name': 'Electronics',
        'condition': condition,
        'condition_notes': condition.startsWith('USED')
            ? 'Phone is in excellent shape; no scratches.'
            : '',
        'images': ['$_img/$slug.jpg', '$_img/$slug.jpg', '$_img/$slug.jpg'],
        'video_url': null,
        'selling_price': price,
        'mrp': mrp,
        'stock_quantity': stock,
        'warranty_info': warranty,
        'accessories_included': 'Included',
        'return_policy_days': 7,
        'specifications': {
          'product_type': 'mobile',
          'model': model,
          'storage': storage
        },
        'approval_status': approval,
        'listing_status': status,
        'rejection_reason': reason,
        'qc_status': qc,
        'qc_score': qc == 'QC_PASSED' ? 92 : null,
        'qc_notes': reason ?? '',
        'sell_b2c': b2c,
        'sell_b2b': b2b,
        'wholesale_price': wholesale,
        'min_order_qty': moq,
        'b2b_discount_pct': b2b ? 5 : null,
        'b2b_notes': b2b ? 'Bulk orders available with extra discount.' : '',
        'vendor_qc': {
          'checklist': {'Screen Display': 'Working fine'}
        },
        'created_at':
            DateTime.now().subtract(Duration(days: days)).toIso8601String(),
      };

  Map<String, dynamic> _find(String id) =>
      _rows.firstWhere((r) => r['id'] == id,
          orElse: () => throw Exception('Listing not found'));

  Map<String, dynamic> _card(Map<String, dynamic> d) => {
        ...d,
        'price': d['selling_price'],
        'stock': d['stock_quantity'],
        'thumbnail_url':
            (d['images'] as List).isEmpty ? null : (d['images'] as List).first,
      };

  @override
  Future<List<CategoryOption>> categories() async =>
      const [CategoryOption('demo-electronics', 'Electronics')];

  @override
  Future<ListingStats> stats() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return ListingStats(
      total: _rows.length,
      pending: _rows.where((r) => r['approval_status'] == 'PENDING').length,
      rejected: _rows.where((r) => r['approval_status'] == 'REJECTED').length,
      outOfStock: _rows.where((r) => r['stock_quantity'] == 0).length,
    );
  }

  @override
  Future<ListingPage> list(
      {String? approval, String search = '', int limit = 50}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final q = search.trim().toLowerCase();
    final rows = _rows
        .where((r) => approval == null || r['approval_status'] == approval)
        .where((r) => q.isEmpty || '${r['name']}'.toLowerCase().contains(q))
        .toList();
    return ListingPage(
        items: rows.map((r) => ListingCard.fromJson(_card(r))).toList(),
        total: rows.length);
  }

  @override
  Future<ListingDetail> detail(String id) async =>
      ListingDetail.fromJson(_find(id));

  Map<String, dynamic> _apply(Map<String, dynamic> d, Map<String, dynamic> b) {
    const direct = {
      'name': 'name',
      'brand': 'brand',
      'description': 'description',
      'condition': 'condition',
      'conditionNotes': 'condition_notes',
      'images': 'images',
      'videoUrl': 'video_url',
      'mrp': 'mrp',
      'warrantyInfo': 'warranty_info',
      'accessoriesIncluded': 'accessories_included',
      'returnPolicyDays': 'return_policy_days',
      'sellB2c': 'sell_b2c',
      'sellB2b': 'sell_b2b',
      'wholesalePrice': 'wholesale_price',
      'moq': 'min_order_qty',
      'b2bDiscountPct': 'b2b_discount_pct',
      'b2bNotes': 'b2b_notes',
      'vendorQc': 'vendor_qc',
      'specifications': 'specifications',
    };
    b.forEach((k, v) {
      if (direct.containsKey(k)) d[direct[k]!] = v;
    });
    if (b['price'] != null) d['selling_price'] = b['price'];
    if (b['sellB2c'] == false && b['wholesalePrice'] != null) {
      d['selling_price'] = b['wholesalePrice'];
    }
    if (b['stock'] != null) {
      d['stock_quantity'] = b['stock'];
      if (d['listing_status'] != 'PAUSED') {
        d['listing_status'] =
            (b['stock'] as num) > 0 ? 'ACTIVE' : 'OUT_OF_STOCK';
      }
    }
    return d;
  }

  @override
  Future<ListingDetail> create(Map<String, dynamic> body) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final id = 'demo-${_seq++}';
    final d = _seed(
        id, '${body['name']}', '${body['brand'] ?? ''}', '', '', 'x',
        condition: '${body['condition']}',
        approval: 'PENDING',
        price: 0,
        mrp: 0,
        stock: 0,
        days: 0);
    d
      ..['images'] = body['images']
      ..['specifications'] = body['specifications'] ?? {}
      ..['sell_b2b'] = false
      ..['wholesale_price'] = null
      ..['b2b_discount_pct'] = null
      ..['b2b_notes'] = ''
      ..['accessories_included'] = ''
      ..['qc_status'] = 'QC_PENDING';
    _apply(d, body);
    _rows.insert(0, d);
    return ListingDetail.fromJson(d);
  }

  @override
  Future<ListingDetail> update(String id, Map<String, dynamic> body) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final d = _find(id);
    _apply(d, body);
    const content = ['name', 'images', 'condition', 'conditionNotes', 'brand'];
    if (content.any(body.containsKey)) {
      d
        ..['approval_status'] = 'PENDING'
        ..['rejection_reason'] = null
        ..['qc_status'] = 'QC_PENDING';
    }
    return ListingDetail.fromJson(d);
  }

  @override
  Future<ListingDetail> setStatus(String id, String status) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final d = _find(id)..['listing_status'] = status;
    return ListingDetail.fromJson(d);
  }

  @override
  Future<void> remove(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _rows.removeWhere((r) => r['id'] == id);
  }

  // Picked files stay on the device in demo mode (shown via Image.file).
  @override
  Future<String> uploadImage(String filePath) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return filePath;
  }

  @override
  Future<String> uploadVideo(String filePath) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return filePath;
  }
}
