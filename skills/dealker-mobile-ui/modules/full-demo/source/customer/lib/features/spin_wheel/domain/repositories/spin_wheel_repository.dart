import 'package:dartz/dartz.dart';

import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/features/spin_wheel/domain/entities/spin_appearance.dart';
import 'package:dealker_app/features/spin_wheel/domain/entities/spin_eligibility.dart';
import 'package:dealker_app/features/spin_wheel/domain/entities/spin_prize.dart';
import 'package:dealker_app/features/spin_wheel/domain/entities/spin_result.dart';

abstract class SpinWheelRepository {
  Future<Either<Failure, List<SpinPrize>>> getConfig();
  Future<Either<Failure, SpinAppearance>> getAppearance();
  Future<Either<Failure, SpinEligibility>> getEligibility();
  Future<Either<Failure, SpinResult>> spin();
}
