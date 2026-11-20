import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/wishlist/domain/entities/wishlist_entity.dart';

abstract class WishlistRepository {
  Future<Either<Failure, WishlistEntity>> getWishlist();

  Future<Either<Failure, WishlistEntity>> toggleWishlist(
    String productId, {
    required bool isInWishlist,
  });

  Future<Either<Failure, int>> moveToCart();
}
