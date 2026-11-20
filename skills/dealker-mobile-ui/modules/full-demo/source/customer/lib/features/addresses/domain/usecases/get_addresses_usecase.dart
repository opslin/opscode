import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/addresses/domain/entities/address_entity.dart';
import 'package:dealker_app/features/addresses/domain/repositories/address_repository.dart';

class GetAddressesUseCase {
  const GetAddressesUseCase(this._repository);

  final AddressRepository _repository;

  Future<Either<Failure, List<AddressEntity>>> call() {
    return _repository.getAddresses();
  }
}
