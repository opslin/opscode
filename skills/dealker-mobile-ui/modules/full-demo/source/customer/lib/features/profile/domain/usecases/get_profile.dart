import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/profile/domain/repositories/profile_repository.dart';

class GetProfileUseCase {
  const GetProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Future<Either<Failure, ProfileData>> call() {
    return _repository.getProfile();
  }
}
