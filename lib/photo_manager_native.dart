import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'photo_manager.dart';

// Written: Friday 22-Jun-2025 10:13 am

Future<String> savePhoto(Uint8List imageData) async {
  final directory = await getApplicationDocumentsDirectory();
  final filename = await hashFilename();
  final file = File("${directory.path}/$filename");

  await file.writeAsBytes(imageData);

  return filename;
}
