import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/addresses/domain/repositories/address_repository.dart';

class DeleteAddressUseCase {
  const DeleteAddressUseCase(this._repository);

  final AddressRepository _repository;

  Future<Either<Failure, void>> call(String id) {
    return _repository.deleteAddress(id);
  }
}
