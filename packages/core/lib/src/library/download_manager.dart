import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import '../models/remote_wallpaper.dart';
import '../sources/wallpaper_source.dart';
import '../util/semaphore.dart';
import 'database.dart';
import 'hashing.dart';
import 'image_header.dart';
import 'library.dart';
import 'library_layout.dart';
import 'sidecar.dart';

final _log = Logger('Downloads');

enum DownloadStatus { queued, downloading, failed }

final class DownloadProgress {
  const DownloadProgress(this.status, {this.received = 0, this.total, this.error});

  final DownloadStatus status;
  final int received;
  final int? total;

  /// A message suitable for showing to the user.
  final String? error;

  /// 0..1, or null when the size isn't known yet.
  double? get fraction => switch (total) {
    final t? when t > 0 => (received / t).clamp(0, 1).toDouble(),
    _ => null,
  };
}

/// Downloads wallpapers into the library, a few at a time.
///
/// Progress for active and failed downloads is published on [changes], keyed
/// by [RemoteWallpaper.key]. Finished downloads drop out of the map and show
/// up in the library instead.
class DownloadManager {
  DownloadManager({
    required this._dio,
    required this._library,
    int concurrency = 3,
  }) : _slots = Semaphore(concurrency);

  final Dio _dio;
  final WallpaperLibrary _library;
  final Semaphore _slots;
  final _inFlight = <String, Future<LibraryItem>>{};
  final _cancelTokens = <String, CancelToken>{};
  final _progress = <String, DownloadProgress>{};
  final _changes = StreamController<Map<String, DownloadProgress>>.broadcast();

  Map<String, DownloadProgress> get current => Map.unmodifiable(_progress);
  Stream<Map<String, DownloadProgress>> get changes => _changes.stream;

  /// Downloads [wallpaper], or returns the library entry if it's already
  /// there. Calling again while it's downloading returns the same future.
  Future<LibraryItem> download(WallpaperSource source, RemoteWallpaper wallpaper) {
    final key = wallpaper.key;
    // A block body matters: `=> _inFlight.remove(key)` would return this very
    // future to whenComplete, which would then wait on itself forever.
    return _inFlight[key] ??= _run(source, wallpaper).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  void cancel(String key) => _cancelTokens[key]?.cancel();

  /// Forgets a failed download so its tile goes back to normal.
  void dismiss(String key) {
    if (_progress[key]?.status == DownloadStatus.failed) _set(key, null);
  }

  Future<LibraryItem> _run(WallpaperSource source, RemoteWallpaper wallpaper) async {
    final key = wallpaper.key;
    final existing = await _library.bySource(wallpaper.sourceId, wallpaper.id);
    if (existing != null) return existing;

    _set(key, const DownloadProgress(DownloadStatus.queued));
    await _slots.acquire();
    File? part;
    try {
      final ticket = await source.prepareDownload(wallpaper);
      final relative = LibraryLayout.relativePathFor(
        wallpaper.sourceId,
        wallpaper.id,
        ticket.fileExtension,
      );
      final finalPath = _library.absoluteFor(relative);
      await File(finalPath).parent.create(recursive: true);
      part = File('$finalPath.part');

      final token = _cancelTokens[key] = CancelToken();
      var lastFraction = -1.0;
      _set(key, DownloadProgress(DownloadStatus.downloading, total: wallpaper.fileSize));
      await _dio.download(
        ticket.url.toString(),
        part.path,
        cancelToken: token,
        options: Options(headers: ticket.headers, extra: {'noRetry': true}),
        onReceiveProgress: (received, total) {
          final progress = DownloadProgress(
            DownloadStatus.downloading,
            received: received,
            total: total > 0 ? total : wallpaper.fileSize,
          );
          // Every 2% is plenty for a progress ring.
          final f = progress.fraction ?? 0;
          if (f - lastFraction >= 0.02 || f >= 1) {
            lastFraction = f;
            _set(key, progress);
          }
        },
      );

      final hash = await hashFile(part.path);
      final duplicate = await _library.byHash(hash);
      if (duplicate != null) {
        _log.info('${wallpaper.key} is the same image as library item ${duplicate.id}');
        await part.delete();
        _set(key, null);
        return duplicate;
      }

      final size = switch ((wallpaper.width, wallpaper.height)) {
        (final w?, final h?) => (width: w, height: h),
        _ => await readImageSizeFromFile(part.path),
      };
      if (size == null) {
        throw LibraryException("The downloaded file isn't an image we can read.");
      }
      final fileSize = await part.length();
      await part.rename(finalPath);
      part = null;

      final meta = Sidecar.fromRemote(ticket.wallpaper);
      await meta.write(LibraryLayout.sidecarFor(finalPath));
      final item = await _library.insert(
        meta,
        relativePath: relative,
        width: size.width,
        height: size.height,
        fileSize: fileSize,
        sha256: hash,
      );
      _set(key, null);
      _log.info('Downloaded ${wallpaper.key} to $relative');
      return item;
    } on Object catch (e, stack) {
      final message = switch (e) {
        DioException(type: DioExceptionType.cancel) => 'Download cancelled.',
        DioException() => SourceException.fromDio(source.name, e).message,
        SourceException(:final message) || LibraryException(:final message) => message,
        FileSystemException(:final message, :final path) =>
          "Couldn't save the file ($message${path == null ? '' : ': $path'}).",
        _ => 'Download failed: $e',
      };
      _log.warning('Download of ${wallpaper.key} failed: $message', e, stack);
      _set(key, DownloadProgress(DownloadStatus.failed, error: message));
      rethrow;
    } finally {
      _slots.release();
      _cancelTokens.remove(key);
      if (part != null) {
        try {
          if (await part.exists()) await part.delete();
        } on FileSystemException catch (e) {
          _log.warning('Left a partial download behind: $e');
        }
      }
    }
  }

  void _set(String key, DownloadProgress? progress) {
    if (progress == null) {
      _progress.remove(key);
    } else {
      _progress[key] = progress;
    }
    _changes.add(Map.unmodifiable(_progress));
  }

  Future<void> dispose() => _changes.close();
}
