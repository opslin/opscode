import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/features/refund_requests/data/return_chat_repository.dart';
import 'package:dealker_app/features/refund_requests/data/return_media_repository.dart';
import 'package:dealker_app/features/refund_requests/data/return_policy_repository.dart';

final Provider<ReturnMediaRepository> returnMediaRepositoryProvider =
    Provider<ReturnMediaRepository>(
  (Ref ref) => ReturnMediaRepository(ref.watch(dioClientProvider)),
);

final Provider<ReturnChatRepository> returnChatRepositoryProvider =
    Provider<ReturnChatRepository>(
  (Ref ref) => ReturnChatRepository(ref.watch(dioClientProvider)),
);

final Provider<ReturnPolicyRepository> returnPolicyRepositoryProvider =
    Provider<ReturnPolicyRepository>(
  (Ref ref) => ReturnPolicyRepository(ref.watch(dioClientProvider)),
);

/// Return window + rules. A failed call just hides the window strip (never blocks the flow).
final FutureProvider<ReturnPolicy> returnPolicyProvider =
    FutureProvider<ReturnPolicy>(
  (Ref ref) => ref.watch(returnPolicyRepositoryProvider).fetch(),
);
