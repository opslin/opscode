import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/addresses/domain/repositories/address_repository.dart';

class ValidatePincodeUseCase {
  const ValidatePincodeUseCase(this._repository);

  final AddressRepository _repository;

  Future<Either<Failure, PincodeValidationResult>> call(String pincode) {
    return _repository.validatePincode(pincode);
  }
}
