// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'photo_manager.dart';

// @date Friday 22-Jun-2025 10:13 am
Future<String> savePhoto(Uint8List imageData) async {
  final filename = await hashFilename();
  final blob = html.Blob([imageData]);
  final url = html.Url.createObjectUrlFromBlob(blob);

  final _ = html.AnchorElement(href: url)
    ..setAttribute("download", filename)
    ..click();
  html.Url.revokeObjectUrl(url);

  return filename;
}
