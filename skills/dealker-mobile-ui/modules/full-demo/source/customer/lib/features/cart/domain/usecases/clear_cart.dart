import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/cart/domain/repositories/cart_repository.dart';

class ClearCartUseCase {
  const ClearCartUseCase(this._repository);

  final CartRepository _repository;

  Future<Either<Failure, void>> call() {
    return _repository.clearCart();
  }
}
