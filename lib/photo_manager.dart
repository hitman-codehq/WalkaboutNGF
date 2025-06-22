import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';

export 'photo_manager_web.dart' if (dart.library.io) 'photo_manager_native.dart';

// Written: Sunday 17-Aug-2025 10:13 am, Nol Guesthouse, Busan, South Korea

Future<String> hashFilename() async {
  final lat = await Geolocator.getCurrentPosition().then((p) => p.latitude);
  final long = await Geolocator.getCurrentPosition().then((p) => p.longitude);
  final hash = sha1.convert(utf8.encode("$lat$long")).toString();

  return "$hash.jpg";
}
