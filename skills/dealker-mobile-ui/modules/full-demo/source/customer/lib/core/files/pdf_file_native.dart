import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Saves the document to a temporary file and opens it with the device viewer.
Future<String> savePdf(List<int> bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<bool> openSavedPdf(String path) async =>
    (await OpenFile.open(path)).type == ResultType.done;
