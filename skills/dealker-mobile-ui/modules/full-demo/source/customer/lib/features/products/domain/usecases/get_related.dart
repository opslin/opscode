import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/products/domain/repositories/product_repository.dart';

class GetRelatedUseCase {
  const GetRelatedUseCase(this._repository);

  final ProductRepository _repository;

  Future<Either<Failure, List<ProductEntity>>> call(
    String productId, {
    int limit = 8,
  }) {
    return _repository.getRelated(productId, limit: limit);
  }
}
