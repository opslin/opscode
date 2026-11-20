import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/orders/domain/repositories/order_repository.dart';

class ReorderUseCase {
  const ReorderUseCase(this._repository);

  final OrderRepository _repository;

  Future<Either<Failure, ReorderResult>> call(String orderId) {
    return _repository.reorder(orderId);
  }
}
