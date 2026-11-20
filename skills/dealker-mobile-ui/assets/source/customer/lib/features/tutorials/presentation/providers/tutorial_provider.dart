import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/features/tutorials/data/datasources/tutorial_remote_datasource.dart';
import 'package:dealker_app/features/tutorials/domain/entities/tutorial_video_entity.dart';

final tutorialRemoteDataSourceProvider = Provider<TutorialRemoteDataSource>((
  Ref ref,
) {
  return TutorialRemoteDataSource(ref.watch(apiClientProvider));
});

final tutorialsProvider = FutureProvider<List<TutorialVideoEntity>>((
  Ref ref,
) async {
  return ref.watch(tutorialRemoteDataSourceProvider).getTutorials();
});
