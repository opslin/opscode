import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/notifications/domain/repositories/notification_repository.dart';

class MarkCampaignOpenedUseCase {
  const MarkCampaignOpenedUseCase(this._repository);

  final NotificationRepository _repository;

  Future<Either<Failure, Unit>> call(String campaignId) {
    return _repository.markCampaignOpened(campaignId);
  }
}
