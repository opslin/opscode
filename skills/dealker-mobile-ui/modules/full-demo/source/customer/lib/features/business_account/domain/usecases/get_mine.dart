import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/business_account/domain/entities/business_account_entity.dart';
import 'package:dealker_app/features/business_account/domain/repositories/business_account_repository.dart';

class GetMyBusinessAccountUseCase {
  const GetMyBusinessAccountUseCase(this._repository);

  final BusinessAccountRepository _repository;

  Future<Either<Failure, BusinessAccountEntity?>> call() {
    return _repository.getMine();
  }
}
