import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/reviews/domain/entities/review_entity.dart';
import 'package:dealker_app/features/reviews/domain/repositories/review_repository.dart';

class UpdateUseCase {
  const UpdateUseCase(this._repository);

  final ReviewRepository _repository;

  Future<Either<Failure, ReviewEntity>> call(
    String reviewId,
    ReviewUpdateParams params,
  ) {
    return _repository.updateReview(reviewId, params);
  }
}
