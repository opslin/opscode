import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/auth/data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      AuthRepository(ref.watch(dioProvider), ref.watch(secureStorageProvider)),
);

enum VendorRole {
  vendor('Vendor', '(B2B)'),
  retailer('Retailer', '(B2C)'),
  repairPartner('Repair Partner', '(Service)');

  const VendorRole(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

/// What the user typed on the Register screen. Held in memory only: the
/// backend has no self-service vendor registration endpoint yet (see
/// PROGRESS.md → Backend gaps), so nothing here is sent until one exists.
class RegistrationDraft {
  const RegistrationDraft(
      {required this.role, required this.businessName, required this.phone});
  final VendorRole role;
  final String businessName;
  final String phone;
}

class AuthState {
  const AuthState({this.session, this.restoring = true, this.draft});
  final VendorSession? session;
  final bool restoring;
  final RegistrationDraft? draft;

  bool get isSignedIn => session != null;

  AuthState copyWith(
          {VendorSession? session,
          bool? restoring,
          RegistrationDraft? draft,
          bool clearSession = false}) =>
      AuthState(
        session: clearSession ? null : (session ?? this.session),
        restoring: restoring ?? this.restoring,
        draft: draft ?? this.draft,
      );
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    ref.listen(forceLogoutProvider,
        (_, __) => state = const AuthState(restoring: false));
    // DEMO: `.env` DEMO_HOME=true skips login so the home can be reviewed.
    if (dotenv.env['DEMO_HOME'] == 'true') {
      return const AuthState(
        restoring: false,
        session: VendorSession(
            userId: 'demo',
            phone: '',
            vendorId: 'demo',
            name: 'DM Mobile Store'),
      );
    }
    _restore();
    return const AuthState();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _restore() async {
    // Tokens persist across launches; the profile is re-established on the next
    // verified login, so a stored token alone only proves "has a session".
    final storage = ref.read(secureStorageProvider);
    // Four independent keychain reads: do them together so the splash screen waits for one, not four.
    final r = await Future.wait<String?>([
      storage.getAccessToken(),
      storage.getUserId(),
      storage.getDisplayName(),
      storage.getVendorId(),
    ]);
    final token = r[0], userId = r[1];
    if (token != null && token.isNotEmpty && userId != null) {
      state = state.copyWith(
        restoring: false,
        session: VendorSession(
          userId: userId,
          phone: '',
          name: r[2],
          vendorId: r[3],
        ),
      );
    } else {
      state = state.copyWith(restoring: false);
    }
  }

  void saveDraft(RegistrationDraft draft) =>
      state = state.copyWith(draft: draft);

  Future<void> sendOtp(String phone) => _repo.sendOtp(phone);

  /// Throws a [Failure] on error.
  Future<VendorSession> verifyOtp(String phone, String otp) async {
    final session = await _repo.verifyOtp(phone, otp);
    state = state.copyWith(session: session);
    return session;
  }

  /// Throws a [Failure] on error.
  Future<void> registerVendor(
      {required String name, required String email}) async {
    final session = await _repo.registerVendor(name: name, email: email);
    state = state.copyWith(session: session);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(restoring: false);
  }
}

String failureMessage(Object e) =>
    e is Failure ? e.message : 'Something went wrong. Please try again.';
