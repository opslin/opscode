import '../features/products/data/models/product_model.dart';

Map<String, dynamic> listing(
  String id,
  String name,
  num price,
  num sale,
  String image, {
  String category = 'mobile',
  String seller = 'Demo Electronics',
  int stock = 18,
}) => {
  'id': id,
  'slug': id,
  'name': name,
  'price': price,
  'sale_price': sale,
  'stock_quantity': stock,
  'unit': '1 unit',
  'thumbnail_url': image,
  'images': [image],
  'category_id': category,
  'sold_by': seller,
  'avg_rating': 4.8,
  'rating_count': 38,
  'display_delivery_minutes': 25,
  'custom_badges': stock == 0 ? [] : ['Assured'],
};

final catalogRows = [
  listing(
    'phone',
    '5G Smartphone · 128 GB',
    24999,
    18499,
    'assets/categories/smartphones.png',
  ),
  listing(
    'audio',
    'Wireless Studio Headphones',
    3499,
    1799,
    'assets/categories/headphones.png',
    category: 'accessories',
  ),
  listing(
    'charge',
    '65 W Fast Charger',
    2999,
    1399,
    'assets/categories/charger.png',
    category: 'parts',
  ),
  listing(
    'tablet',
    '10-inch Wi-Fi Tablet',
    19999,
    16499,
    'assets/categories/tablets.png',
    category: 'electronics',
  ),
  listing(
    'watch',
    'AMOLED Smartwatch',
    6999,
    3999,
    'assets/categories/smartwatch.png',
    category: 'electronics',
  ),
  listing(
    'speaker',
    'Portable Bluetooth Speaker',
    2899,
    1999,
    'assets/categories/speaker.png',
    category: 'accessories',
    stock: 0,
  ),
  listing(
    'phone-pro',
    'Pro Smartphone · 256 GB',
    35999,
    27999,
    'assets/loading/mobile.png',
    seller: 'City Mobile Supply',
  ),
];

final catalog = catalogRows
    .map((row) => ProductModel.fromJson(row).toEntity())
    .toList(growable: false);

final priceSaleConfig = <String, dynamic>{
  'title': 'Electronics Sale',
  'subtitle': 'Shop deals under',
  'tabs': [
    {
      'label': 'Audio',
      'sub_label': '₹2,000',
      'price_text': '₹2,000',
      'header_left_url': 'assets/categories/headphones.png',
      'header_right_url': 'assets/categories/charger.png',
      'category_ids': ['accessories'],
      'products': [catalogRows[1], catalogRows[2]],
    },
    {
      'label': 'Devices',
      'sub_label': '₹20,000',
      'price_text': '₹20,000',
      'header_left_url': 'assets/categories/tablets.png',
      'header_right_url': 'assets/categories/smartphones.png',
      'category_ids': ['mobile'],
      'products': [catalogRows[0], catalogRows[3], catalogRows[4]],
    },
  ],
};
