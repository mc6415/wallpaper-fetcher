import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// A log file that rolls over to `.1`, `.2`, ... once it reaches [maxBytes].
class RotatingLogFile {
  RotatingLogFile(this.path, {this.maxBytes = 1024 * 1024, this.keep = 3}) {
    final file = File(path);
    _size = file.existsSync() ? file.lengthSync() : 0;
  }

  final String path;
  final int maxBytes;

  /// How many old files to keep besides the current one.
  final int keep;
  late int _size;

  void write(String line) {
    final bytes = utf8.encode('$line\n');
    if (_size > 0 && _size + bytes.length > maxBytes) _rotate();
    File(path).writeAsBytesSync(bytes, mode: FileMode.append);
    _size += bytes.length;
  }

  void _rotate() {
    final oldest = File('$path.$keep');
    if (oldest.existsSync()) oldest.deleteSync();
    for (var i = keep - 1; i >= 1; i--) {
      final f = File('$path.$i');
      if (f.existsSync()) f.renameSync('$path.${i + 1}');
    }
    final current = File(path);
    if (current.existsSync()) current.renameSync('$path.1');
    _size = 0;
  }
}

StreamSubscription<LogRecord>? _subscription;

/// Sends all `package:logging` output to `<directory>/wallpaper_fetcher.log`.
/// Returns the log file path.
String setupLogging({
  required String directory,
  Level level = Level.INFO,
  bool echoToConsole = false,
}) {
  Directory(directory).createSync(recursive: true);
  final file = RotatingLogFile(p.join(directory, 'wallpaper_fetcher.log'));
  Logger.root.level = level;
  _subscription?.cancel();
  _subscription = Logger.root.onRecord.listen((r) {
    final buffer = StringBuffer()
      ..write('${r.time.toIso8601String()} ${r.level.name.padRight(7)} ')
      ..write('${r.loggerName}: ${r.message}');
    if (r.error != null) buffer.write(' | ${r.error}');
    if (r.stackTrace != null) buffer.write('\n${r.stackTrace}');
    final line = buffer.toString();
    try {
      file.write(line);
    } on FileSystemException {
      // Logging must never take the app down.
    }
    if (echoToConsole) stdout.writeln(line);
  });
  return file.path;
}
