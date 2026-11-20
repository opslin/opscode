import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/auth/domain/entities/user_entity.dart';
import 'package:dealker_app/features/auth/domain/repositories/auth_repository.dart';

class VerifyOtpUseCase {
  const VerifyOtpUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, AuthEntity>> call({
    required String phone,
    required String otp,
  }) {
    return _repository.verifyOtp(
      phone: phone,
      otp: otp,
    );
  }
}
