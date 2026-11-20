import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/auth/domain/repositories/auth_repository.dart';

class LogoutUseCase {
  const LogoutUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, void>> call() {
    return _repository.logout();
  }
}
