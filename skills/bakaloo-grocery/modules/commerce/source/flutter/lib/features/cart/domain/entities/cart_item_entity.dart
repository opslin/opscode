import 'package:bakaloo_flutter_app/demo/storefront.dart';

/// Local catalog adapter for the fields read by Bakaloo's cart item widget.
class CartItemEntity {
  const CartItemEntity(this.product, this.quantity);

  final ProductEntity product;
  final int quantity;

  String get productId => product.id;
  String get name => product.name;
  String get unit => product.unit;
  String? get thumbnailUrl => product.thumbnailUrl;
  double get price => product.price;
  double? get salePrice => product.salePrice;
  int get stockQuantity => product.stockQuantity;
  int? get displayDeliveryMinutes => product.displayDeliveryMinutes;
  double get effectivePrice => product.effectivePrice;
  double get total => effectivePrice * quantity;
  bool get hasEnoughStock => quantity <= stockQuantity;
  String? get optionLabel => null;
  String? get netQuantity => null;
}
