import 'dart:io';

import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/profile/domain/repositories/profile_repository.dart';

class UploadAvatarUseCase {
  const UploadAvatarUseCase(this._repository);

  final ProfileRepository _repository;

  Future<Either<Failure, String>> call(File imageFile) {
    return _repository.uploadAvatar(imageFile);
  }
}
