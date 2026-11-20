import 'package:dio/dio.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/features/business_profile/data/business_models.dart';

/// Business Profile: `GET/PATCH /vendors/:id` (+ `/profile`) and the KYC document list.
/// The server always acts on the vendor in the JWT, whatever id is in the URL.
class BusinessRepository {
  BusinessRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _req(String method, String path,
      {Object? body}) async {
    try {
      final res = await _dio.request<Map<String, dynamic>>(path,
          data: body, options: Options(method: method));
      return (res.data?['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<BusinessProfile> load(String vendorId) async {
    final vendor = await _req('GET', '/vendors/$vendorId');
    var docs = <KycDocument>[];
    try {
      final k = await _req('GET', '/vendor-kyc/$vendorId/kyc/status');
      docs = ((k['documents'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(KycDocument.fromJson)
          .toList();
    } catch (_) {
      // Documents are a nice-to-have on this screen; the details still load without them.
    }
    return BusinessProfile.fromJson(vendor, docs);
  }

  /// Uploads one photo/scan to private storage; returns its `file_key`.
  Future<String> uploadDocumentFile(String vendorId, String filePath) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
          '/vendor-kyc/$vendorId/files',
          data: FormData.fromMap(
              {'file': await MultipartFile.fromFile(filePath)}));
      return ((res.data?['data'] as Map?)?['file_key'] as String?) ?? '';
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  /// Attaches an uploaded file as a document (replaces a pending/rejected one of the same type).
  Future<void> attachDocument(String vendorId,
          {required String type, required String fileKey, String? number}) =>
      _req('POST', '/vendor-kyc/$vendorId/documents', body: {
        'document_type': type,
        'file_key': fileKey,
        if (number != null && number.trim().isNotEmpty)
          'document_number': number.trim(),
      });

  /// Sends the application for review. Throws a Failure listing what is still missing.
  Future<void> submitForReview(String vendorId) =>
      _req('POST', '/vendor-kyc/$vendorId/submit-review');

  /// A short-lived signed URL to view one of the vendor's own documents.
  Future<String> documentLink(String vendorId, String docId) async =>
      ((await _req('GET', '/vendor-kyc/$vendorId/documents/$docId/link'))['url']
          as String?) ??
      '';

  /// Store name, contact email and phone.
  Future<void> saveStore(String vendorId, Map<String, dynamic> changes) =>
      _req('PATCH', '/vendors/$vendorId', body: changes);

  /// Legal identity and address fields (snake_case keys, as the API expects).
  Future<void> saveProfile(String vendorId, Map<String, dynamic> changes) =>
      _req('PATCH', '/vendors/$vendorId/profile', body: changes);
}
