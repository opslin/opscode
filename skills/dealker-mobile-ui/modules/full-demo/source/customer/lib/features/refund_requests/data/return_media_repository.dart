import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dealker_app/core/network/picked_file_upload.dart';

/// Uploads the proof files for a return. Images go to `/uploads/local`, the video to `/uploads/local/video`;
/// both answer with the stored file's public URL, which the refund request then references.
class ReturnMediaRepository {
  const ReturnMediaRepository(this._dio);

  final Dio _dio;

  Future<String> uploadImage(XFile file) => _upload('/uploads/local', file);

  Future<String> uploadVideo(XFile file) => _upload(
        '/uploads/local/video',
        file,
        timeout: const Duration(minutes: 4),
      );

  Future<String> _upload(
    String endpoint,
    XFile file, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final Response<dynamic> r = await _dio.post<dynamic>(
      endpoint,
      data: FormData.fromMap(<String, dynamic>{
        'file': await pickedFileMultipart(file),
      }),
      options: Options(sendTimeout: timeout, receiveTimeout: timeout),
    );
    final Object? data = (r.data as Map)['data'];
    if (data is Map) {
      final Object? urls = data['urls'];
      if (urls is List && urls.isNotEmpty) return urls.first.toString();
      final Object? url = data['url'];
      if (url != null) return url.toString();
    }
    throw StateError('Upload failed');
  }
}
