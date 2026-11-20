import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Downloads authenticated bytes without exposing a session token in a URL.
Future<String> savePdf(List<int> bytes, String fileName) async {
  final blob = html.Blob([Uint8List.fromList(bytes)], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final link = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body!.append(link);
  try {
    link.click();
  } finally {
    link.remove();
    // Keep the object URL alive long enough for the browser to start reading it.
    Timer(const Duration(minutes: 1), () => html.Url.revokeObjectUrl(url));
  }
  return '';
}

/// Saving already starts the browser download; there is no native viewer.
Future<bool> openSavedPdf(String path) async => true;
