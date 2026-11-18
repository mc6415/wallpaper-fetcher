import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../services.dart';

final _log = Logger('BackgroundRotation');

const rotationChannel = MethodChannel('dev.mcoombes.wallpaperfetcher/rotation');

/// What `RotationWorker.kt` runs each time WorkManager wakes it: change the
/// wallpaper if it's due, then report back so the engine can shut down.
Future<void> runBackgroundRotation() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  AppServices? services;
  try {
    services = await AppServices.create(background: true);
    final rotation = services.rotation;
    // WorkManager's timing drifts by a few minutes; don't let that push a
    // change back by a whole check.
    final outcome = await rotation.tick(slack: rotation.backgroundCheckInterval ~/ 2);
    _log.info(switch (outcome) {
      null => 'Not due yet',
      RotationOutcome(changed: true, :final applied) => 'Changed ${applied.keys.join(', ')}',
      RotationOutcome(:final message) => 'Nothing changed: $message',
    });
  } on Object catch (e, stack) {
    _log.warning('Background rotation failed', e, stack);
  } finally {
    await services?.dispose();
    await rotationChannel.invokeMethod<void>('done');
  }
}

/// Keeps WorkManager's job in step with the rotation settings: scheduled
/// while rotation is on and not paused, at [RotationService.backgroundCheckInterval].
class AndroidRotationSchedule {
  AndroidRotationSchedule(this._rotation, {this._channel = rotationChannel});

  final RotationService _rotation;
  final MethodChannel _channel;
  StreamSubscription<RotationState>? _subscription;

  /// Minutes between checks as last told to WorkManager; 0 when cancelled.
  int? _scheduled;

  void start() {
    _subscription ??= _rotation.changes.listen((_) => unawaited(sync()));
    unawaited(sync());
  }

  Future<void> sync() async {
    final state = _rotation.state;
    final minutes = state.config.enabled && !state.paused ? _rotation.backgroundCheckInterval.inMinutes : 0;
    if (minutes == _scheduled) return;
    _scheduled = minutes;
    try {
      if (minutes == 0) {
        await _channel.invokeMethod<void>('cancel');
        _log.info('Background rotation off');
      } else {
        await _channel.invokeMethod<void>('schedule', {'minutes': minutes});
        _log.info('Background rotation checks every $minutes min');
      }
    } on PlatformException catch (e) {
      _scheduled = null;
      _log.warning("Couldn't schedule background rotation: ${e.message}");
    }
  }

  /// When WorkManager next runs the job, if it's scheduled.
  Future<DateTime?> nextRun() async {
    try {
      final status = await _channel.invokeMapMethod<String, Object?>('status');
      return switch (status?['nextRun']) {
        final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        _ => null,
      };
    } on PlatformException {
      return null;
    }
  }

  Future<void> dispose() async => _subscription?.cancel();
}
