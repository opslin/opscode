import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/home/domain/repositories/home_repository.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';

class GetFeaturedProductsUseCase {
  const GetFeaturedProductsUseCase(this._repository);

  final HomeRepository _repository;

  Future<Either<Failure, List<ProductEntity>>> call({int limit = 12}) {
    return _repository.getFeaturedProducts(limit: limit);
  }
}
