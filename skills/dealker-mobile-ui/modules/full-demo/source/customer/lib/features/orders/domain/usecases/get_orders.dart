import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/orders/domain/repositories/order_repository.dart';

class GetOrdersUseCase {
  const GetOrdersUseCase(this._repository);

  final OrderRepository _repository;

  Future<Either<Failure, OrderPageResult>> call({
    int page = 1,
    int limit = 10,
    String? status,
    bool paymentFailed = false,
  }) {
    return _repository.getOrders(
      page: page,
      limit: limit,
      status: status,
      paymentFailed: paymentFailed,
    );
  }
}
