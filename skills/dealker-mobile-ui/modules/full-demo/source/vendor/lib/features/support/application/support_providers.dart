import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/core/realtime/live_service.dart';
import 'package:dealker_vendor/features/support/data/support_repository.dart';

final supportRepositoryProvider =
    Provider<SupportRepository>((ref) => SupportRepository(ref.watch(dioProvider)));

final supportContactProvider = FutureProvider.autoDispose<SupportContact>(
    (ref) => ref.watch(supportRepositoryProvider).contact());

/// The vendor's conversations, newest first. Refreshes on live events.
final supportTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>((ref) {
  ref.watch(liveTickProvider);
  return ref.watch(supportRepositoryProvider).tickets();
});

final notificationsProvider =
    FutureProvider.autoDispose<({List<AppNotification> items, int unread})>((ref) {
  ref.watch(liveTickProvider);
  return ref.watch(supportRepositoryProvider).notifications();
});
