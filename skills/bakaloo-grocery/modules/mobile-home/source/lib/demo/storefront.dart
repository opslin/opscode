import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Storefront {
  const Storefront({
    required this.brand,
    required this.address,
    required this.deliveryMinutes,
    required this.categories,
    required this.promos,
    required this.products,
  });

  static Future<Storefront> load() async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/demo/storefront.json'),
    ) as Map<String, dynamic>;
    return Storefront(
      brand: json['brand'] as String,
      address: json['address'] as String,
      deliveryMinutes: json['deliveryMinutes'] as int,
      categories: List.unmodifiable(
        (json['categories'] as List).map(
          (item) => DemoCategory.fromJson(item as Map<String, dynamic>),
        ),
      ),
      promos: List.unmodifiable(
        (json['promos'] as List).map(
          (item) => DemoPromo.fromJson(item as Map<String, dynamic>),
        ),
      ),
      products: List.unmodifiable(
        (json['products'] as List).map(
          (item) => ProductEntity.fromJson(item as Map<String, dynamic>),
        ),
      ),
    );
  }

  final String brand;
  final String address;
  final int deliveryMinutes;
  final List<DemoCategory> categories;
  final List<DemoPromo> promos;
  final List<ProductEntity> products;
}

class DemoCategory {
  const DemoCategory(this.id, this.name, this.icon);

  factory DemoCategory.fromJson(Map<String, dynamic> json) => DemoCategory(
    json['id'] as String,
    json['name'] as String,
    json['icon'] as String,
  );

  final String id;
  final String name;
  final String icon;
}

class DemoPromo {
  const DemoPromo(this.label, this.image, this.category);

  factory DemoPromo.fromJson(Map<String, dynamic> json) => DemoPromo(
    json['label'] as String,
    json['image'] as String,
    json['category'] as String,
  );

  final String label;
  final String image;
  final String category;
}

/// The fields used by the bundled Bakaloo ProductCard, backed by demo data.
class ProductEntity {
  const ProductEntity({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.price,
    required this.stockQuantity,
    required this.thumbnailUrl,
    this.salePrice,
    this.categoryId,
    this.tags = const [],
    this.foodType = 'NONE',
    this.avgRating = 0,
    this.ratingCount = 0,
    this.displayDeliveryMinutes,
  });

  factory ProductEntity.fromJson(Map<String, dynamic> json) => ProductEntity(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    unit: json['unit'] as String,
    price: (json['price'] as num).toDouble(),
    salePrice: (json['salePrice'] as num?)?.toDouble(),
    categoryId: json['categoryId'] as String?,
    tags:
        (json['tags'] as List?)?.whereType<String>().toList(growable: false) ??
        const [],
    stockQuantity: json['stockQuantity'] as int,
    thumbnailUrl: json['image'] as String?,
    foodType: json['foodType'] as String? ?? 'NONE',
    avgRating: (json['rating'] as num?)?.toDouble() ?? 0,
    ratingCount: json['ratingCount'] as int? ?? 0,
    displayDeliveryMinutes: json['deliveryMinutes'] as int?,
  );

  final String id;
  final String name;
  final String category;
  final String unit;
  final double price;
  final double? salePrice;
  final String? categoryId;
  final List<String> tags;
  final int stockQuantity;
  final String? thumbnailUrl;
  final String foodType;
  final double avgRating;
  final int ratingCount;
  final int? displayDeliveryMinutes;

  // The standalone fixture has one retail listing per product.
  List<String> get images => const [];
  int get optionCount => 1;
  bool get hasMultipleOptions => optionCount > 1;
  bool get isImported => false;
  bool get hasOriginTag => false;
  String get displayUnit => unit;
  bool get inStock => stockQuantity > 0;
  bool get isVeg => foodType == 'VEG';
  bool get isNonVeg => foodType == 'NON_VEG';
  bool get isEgg => foodType == 'EGG';
  bool get hasFoodMarker => foodType != 'NONE';
  bool get hasRating => avgRating > 0 && ratingCount > 0;
  bool get hasDeliveryTime => (displayDeliveryMinutes ?? 0) > 0;
  String get formattedDeliveryTime =>
      hasDeliveryTime ? '$displayDeliveryMinutes mins' : '';
  double get effectivePrice => salePrice ?? price;
  int get discountPercent => (salePrice == null || salePrice! >= price)
      ? 0
      : (((price - salePrice!) / price) * 100).round();

  String get formattedRating {
    if (avgRating <= 0) return '';
    if (ratingCount <= 10) return avgRating.toStringAsFixed(1);
    final count = ratingCount >= 1000
        ? '${(ratingCount / 1000).toStringAsFixed(1)}k'
        : '$ratingCount';
    return '${avgRating.toStringAsFixed(1)} · $count';
  }
}

class ProductArtwork {
  const ProductArtwork(this.url);

  final String? url;
  int get memCacheWidth => 360;
  int get memCacheHeight => 320;
}

class DemoShopState {
  const DemoShopState({this.quantities = const {}, this.wishlist = const {}});

  final Map<String, int> quantities;
  final Set<String> wishlist;

  int quantity(String productId) => quantities[productId] ?? 0;
  int get count => quantities.values.fold(0, (sum, value) => sum + value);
}

final demoShopProvider = NotifierProvider<DemoShop, DemoShopState>(
  DemoShop.new,
);

class DemoShop extends Notifier<DemoShopState> {
  @override
  DemoShopState build() => const DemoShopState();

  void setQuantity(ProductEntity product, int quantity) {
    final next = quantity.clamp(0, product.stockQuantity);
    if (next == state.quantity(product.id)) return;
    final quantities = Map.of(state.quantities);
    if (next == 0) {
      quantities.remove(product.id);
    } else {
      quantities[product.id] = next;
    }
    state = DemoShopState(
      quantities: Map.unmodifiable(quantities),
      wishlist: state.wishlist,
    );
  }

  void clearCart() {
    state = DemoShopState(wishlist: state.wishlist);
  }

  void toggleWishlist(String productId) {
    final wishlist = Set.of(state.wishlist);
    if (!wishlist.remove(productId)) wishlist.add(productId);
    state = DemoShopState(
      quantities: state.quantities,
      wishlist: Set.unmodifiable(wishlist),
    );
  }
}
