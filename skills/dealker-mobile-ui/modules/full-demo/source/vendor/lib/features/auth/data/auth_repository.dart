import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/constants/api_constants.dart';
import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/core/storage/secure_storage_service.dart';

class VendorSession {
  const VendorSession({
    required this.userId,
    required this.phone,
    this.name,
    this.role,
    this.vendorId,
    this.vendorRoles = const [],
    this.isNewUser = false,
  });

  final String userId;
  final String phone;
  final String? name;
  final String? role;

  /// Null when the phone has no vendor membership yet (not onboarded/approved).
  final String? vendorId;
  final List<String> vendorRoles;
  final bool isNewUser;

  bool get hasVendorAccess => vendorId != null;

  factory VendorSession.fromUserJson(Map<String, dynamic> u) => VendorSession(
        userId: '${u['id']}',
        phone: '${u['phone'] ?? ''}',
        name: u['name'] as String?,
        role: u['role'] as String?,
        vendorId: u['vendor_id'] as String?,
        vendorRoles: ((u['vendor_roles'] as List?) ?? const [])
            .map((e) => '$e')
            .toList(),
        isNewUser: u['isNewUser'] == true,
      );
}

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final SecureStorageService _storage;

  Future<void> sendOtp(String phone) async {
    try {
      await _dio.post<dynamic>(ApiConstants.sendOtp, data: {'phone': phone});
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<VendorSession> verifyOtp(String phone, String otp) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiConstants.verifyOtp,
        data: {'phone': phone, 'otp': otp},
      );
      final data = (res.data?['data'] ?? res.data) as Map<String, dynamic>?;
      final access = data?['accessToken'] as String?;
      final refresh = data?['refreshToken'] as String?;
      final user = data?['user'] as Map<String, dynamic>?;
      if (access == null || refresh == null || user == null) {
        throw const ServerFailure(
            message: 'Sign-in response was incomplete. Please try again.');
      }
      final session = VendorSession.fromUserJson(user);
      await _storage.saveTokens(accessToken: access, refreshToken: refresh);
      await _storage.saveUserId(session.userId);
      await _storage.saveVendorProfile(
          vendorId: session.vendorId, name: session.name);
      return session;
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  /// First-time vendors: opens a vendor account for the signed-in phone and returns a fresh vendor session.
  Future<VendorSession> registerVendor(
      {required String name, required String email}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/vendors/register',
          data: {'name': name, 'email': email});
      final data = (res.data?['data'] ?? res.data) as Map<String, dynamic>?;
      final access = data?['accessToken'] as String?;
      final refresh = data?['refreshToken'] as String?;
      final user = data?['user'] as Map<String, dynamic>?;
      if (access == null || refresh == null || user == null) {
        throw const ServerFailure(
            message: 'Could not create your store. Please try again.');
      }
      final session = VendorSession.fromUserJson(user);
      await _storage.saveTokens(accessToken: access, refreshToken: refresh);
      await _storage.saveUserId(session.userId);
      await _storage.saveVendorProfile(vendorId: session.vendorId, name: name);
      return session;
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post<dynamic>(ApiConstants.logout);
    } catch (_) {
      // Best effort — local session is cleared regardless.
    }
    await _storage.clearAll();
  }
}
