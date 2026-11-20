import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/profile/domain/repositories/profile_repository.dart';

class UpdateProfileUseCase {
  const UpdateProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Future<Either<Failure, ProfileData>> call(UpdateProfileParams params) {
    return _repository.updateProfile(params);
  }
}
