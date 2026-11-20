import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/profile/data/profile_models.dart';

/// Read-only calls behind the Profile page (all vendor-scoped by the JWT).
class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _data(String path) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path);
      return (res.data?['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<VendorProfileInfo> vendor(String vendorId) async =>
      VendorProfileInfo.fromJson(await _data('/vendors/$vendorId'));

  Future<Membership> membership() async =>
      Membership.fromJson(await _data('/subscriptions/me'));

  Future<ListingCounts> listingCounts() async =>
      ListingCounts.fromJson(await _data('/vendor/listings/stats'));
}
