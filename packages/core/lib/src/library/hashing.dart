import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

/// SHA-256 of a file as lowercase hex, computed off the calling isolate so
/// large images don't stall the UI.
Future<String> hashFile(String path) => Isolate.run(() async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
});
