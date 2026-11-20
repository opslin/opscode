import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/auth/application/auth_controller.dart';

/// The customer app's `dioClientProvider`, backed by the vendor app's authenticated Dio.
final Provider<Dio> dioClientProvider = Provider<Dio>((Ref ref) => ref.watch(dioProvider));

class RepairUser {
  const RepairUser(this.id, this.name, this.phone, [this.email]);
  final String? id;
  final String? name;
  final String? phone;
  final String? email;
}

/// The signed-in vendor, shaped like the customer app's `currentUserProvider`.
final Provider<RepairUser?> currentUserProvider = Provider<RepairUser?>((Ref ref) {
  final s = ref.watch(authControllerProvider).session;
  if (s == null) return null;
  return RepairUser(s.userId, s.name, s.phone);
});
