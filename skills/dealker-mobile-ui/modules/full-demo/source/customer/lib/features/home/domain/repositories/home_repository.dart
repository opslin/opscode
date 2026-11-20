import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/home/domain/entities/banner_entity.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';

abstract class HomeRepository {
  Future<Either<Failure, List<BannerEntity>>> getBanners({String? placement});

  Future<Either<Failure, List<ProductEntity>>> getFeaturedProducts({
    int limit = 12,
  });
}
