import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/checkout/domain/entities/coupon_entity.dart';
import 'package:dealker_app/features/checkout/domain/repositories/coupon_repository.dart';

class GetCouponsUseCase {
  const GetCouponsUseCase(this._repository);

  final CouponRepository _repository;

  Future<Either<Failure, List<CouponEntity>>> call() {
    return _repository.getCoupons();
  }
}
