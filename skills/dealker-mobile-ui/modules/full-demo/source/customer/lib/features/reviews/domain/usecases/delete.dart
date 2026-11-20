import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/reviews/domain/repositories/review_repository.dart';

class DeleteUseCase {
  const DeleteUseCase(this._repository);

  final ReviewRepository _repository;

  Future<Either<Failure, void>> call(String reviewId) {
    return _repository.deleteReview(reviewId);
  }
}
