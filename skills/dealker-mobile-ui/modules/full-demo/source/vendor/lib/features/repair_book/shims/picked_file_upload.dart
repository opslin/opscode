import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

/// Browser picker paths are blob URLs, so multipart uploads need their bytes.
Future<MultipartFile> pickedFileMultipart(XFile file, {bool isWeb = kIsWeb}) async {
  final filename = file.name.isEmpty ? 'upload.jpg' : file.name;
  final mimeType = file.mimeType;
  final contentType = mimeType == null || mimeType.isEmpty ? null : DioMediaType.parse(mimeType);
  if (isWeb) {
    return MultipartFile.fromBytes(await file.readAsBytes(), filename: filename, contentType: contentType);
  }
  return MultipartFile.fromFile(file.path, filename: filename, contentType: contentType);
}
