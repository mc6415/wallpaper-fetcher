import 'dart:async';

import 'package:logging/logging.dart';

import '../library/database.dart';
import '../library/download_manager.dart';
import '../library/history.dart';
import '../library/library.dart';
import '../models/display_target.dart';
import '../models/orientation.dart';
import '../settings/settings_store.dart';
import '../setters/applier.dart';
import '../setters/wallpaper_setter.dart';
import '../sources/wallpaper_source.dart';
import 'rotation_config.dart';
import 'rotation_picker.dart';

final _log = Logger('Rotation');

final class RotationState {
  const RotationState({required this.config, required this.paused, this.lastRun, this.nextDue});

  final RotationConfig config;
  final bool paused;
  final DateTime? lastRun;

  /// When the schedule next acts; null when off or paused.
  final DateTime? nextDue;
}

/// What a Next/Previous/scheduled change did.
final class RotationOutcome {
  const RotationOutcome(this.applied, {this.message});

  const RotationOutcome.nothing(String this.message) : applied = const {};

  /// Target id -> image now on it.
  final Map<String, LibraryItem> applied;

  /// Why nothing (or not everything) changed, for the user.
  final String? message;

  bool get changed => applied.isNotEmpty;
}

/// The one rotation schedule plus the Next / Previous / Favourite actions
/// shared by the tray, the app and the command line.
///
/// Next moves a screen forward again if Previous stepped it back; otherwise
/// it picks a fresh image from the pool. Either way it restarts the timer, so
/// an automatic change doesn't follow straight after a manual one.
class RotationService {
  RotationService({
    required this.setter,
    required this.applier,
    required this.library,
    required this.history,
    required this.settings,
    required this.downloads,
    required this.sources,
    RotationPicker? picker,
    DateTime Function()? now,
  }) : _picker = picker ?? RotationPicker(library, history),
       _now = now ?? DateTime.now;

  /// How often a daily pool checks for a new picture.
  static const dailyCheckInterval = Duration(hours: 1);

  final WallpaperSetter setter;
  final WallpaperApplier applier;
  final WallpaperLibrary library;
  final WallpaperHistory history;
  final SettingsStore settings;
  final DownloadManager downloads;
  final Map<String, WallpaperSource> sources;
  final RotationPicker _picker;
  final DateTime Function() _now;
  final _changes = StreamController<RotationState>.broadcast();

  RotationConfig _config = const RotationConfig();
  bool _paused = false;
  DateTime? _lastRun;
  Future<void> _busy = Future.value();

  RotationConfig get config => _config;
  bool get paused => _paused;

  RotationState get state => RotationState(config: _config, paused: _paused, lastRun: _lastRun, nextDue: nextDue);

  Stream<RotationState> get changes => _changes.stream;

  DateTime? get nextDue {
    if (!_config.enabled || _paused) return null;
    final every = _config.pool is DailyPool ? dailyCheckInterval : _config.interval;
    return (_lastRun ?? _now()).add(every);
  }

  /// How often a background job (Android's WorkManager, 15 minutes at the
  /// least) should look in: the interval itself up to an hour, then hourly.
  Duration get backgroundCheckInterval {
    if (_config.pool is DailyPool) return dailyCheckInterval;
    const shortest = Duration(minutes: 15);
    final every = _config.interval;
    if (every < shortest) return shortest;
    return every > dailyCheckInterval ? dailyCheckInterval : every;
  }

  Future<void> load() async {
    _config = RotationConfig.parse(await settings.get(SettingsKeys.rotationConfig));
    _paused = await settings.get(SettingsKeys.rotationPaused) == 'true';
    _lastRun = DateTime.tryParse(await settings.get(SettingsKeys.rotationLastRun) ?? '')?.toLocal();
    _emit();
  }

  Future<void> configure(RotationConfig config) async {
    final switchedOn = config.enabled && !_config.enabled;
    _config = config;
    await settings.set(SettingsKeys.rotationConfig, config.encode());
    // Count the interval from now rather than changing straight away.
    if (switchedOn) await _markRun();
    _emit();
  }

  Future<void> setPaused(bool paused) async {
    _paused = paused;
    await settings.set(SettingsKeys.rotationPaused, paused ? 'true' : null);
    // Resuming restarts the interval.
    if (!paused) await _markRun();
    _emit();
  }

  /// Called by the scheduler: changes the wallpaper if it's due. Null if not.
  ///
  /// A change due within [slack] counts as due: a background job that wakes a
  /// few minutes early would otherwise wait a whole extra interval.
  Future<RotationOutcome?> tick({Duration slack = Duration.zero}) => _serial(() async {
    final due = nextDue;
    if (due == null || _now().add(slack).isBefore(due)) return null;
    _log.info('Scheduled change (${_config.pool.toJson()})');
    try {
      return await _next(null, scheduled: true);
    } on Object catch (e) {
      // Don't retry every tick; wait for the next interval.
      await _markRun();
      _log.warning('Scheduled change failed: $e');
      return RotationOutcome.nothing('$e');
    }
  });

  Future<RotationOutcome> next({List<String>? targetIds}) => _serial(() => _next(targetIds, scheduled: false));

  Future<RotationOutcome> previous({List<String>? targetIds}) => _serial(() async {
    final targets = await resolveTargets(targetIds);
    final applied = <String, LibraryItem>{};
    for (final target in targets) {
      if (await applier.previous(target) case final item?) applied[target.id] = item;
    }
    return applied.isEmpty
        ? const RotationOutcome.nothing('Nothing earlier in the history.')
        : RotationOutcome(applied);
  });

  /// Favourites what's on the given screens now. Returns the images.
  Future<List<LibraryItem>> favouriteCurrent({List<String>? targetIds}) async {
    final targets = await resolveTargets(targetIds);
    final now = await history.nowShowing();
    final done = <LibraryItem>[];
    for (final target in targets) {
      final item = now[target.id]?.item;
      if (item == null || done.any((d) => d.id == item.id)) continue;
      await library.setFavourite(item, true);
      done.add(item);
    }
    return done;
  }

  /// The targets named by [ids], or the rotation's screens when null.
  /// The rotation's screens default to every monitor.
  Future<List<DisplayTarget>> resolveTargets(List<String>? ids) async {
    final all = await setter.targets();
    if (ids != null) return [for (final t in all) if (ids.contains(t.id)) t];
    final chosen = [for (final t in all) if (_config.screens.contains(t.id)) t];
    return chosen.isNotEmpty ? chosen : [for (final t in all) if (t.surface == TargetSurface.home) t];
  }

  Future<RotationOutcome> _next(List<String>? targetIds, {required bool scheduled}) async {
    final targets = await resolveTargets(targetIds);
    if (targets.isEmpty) {
      return RotationOutcome.nothing('No screens to change. ${setter.name} may not be supported yet.');
    }
    if (_config.pool case DailyPool(:final sourceId)) {
      return _applyDaily(sourceId, targets, onlyIfNew: scheduled);
    }

    // Screens that were stepped back go forward through their history first.
    final applied = <String, LibraryItem>{};
    final fresh = <DisplayTarget>[];
    for (final target in targets) {
      if (await history.cursor(target.id) > 0) {
        final item = await applier.next(target);
        if (item != null) {
          applied[target.id] = item;
          continue;
        }
      }
      fresh.add(target);
    }

    if (fresh.isNotEmpty) {
      final picks = await _picker.pick(
        _config,
        fresh,
        exclude: {for (final i in applied.values) i.id},
      );
      if (picks.isEmpty && applied.isEmpty) {
        await _markRun();
        return RotationOutcome.nothing(_emptyPoolMessage());
      }
      await applier.applyMany({for (final t in fresh) t: ?picks[t.id]}, fit: _config.fit);
      applied.addAll(picks);
    }
    await _markRun();
    return RotationOutcome(applied);
  }

  Future<RotationOutcome> _applyDaily(
    String sourceId,
    List<DisplayTarget> targets, {
    required bool onlyIfNew,
  }) async {
    final source = sources[sourceId];
    if (source == null) return RotationOutcome.nothing('Unknown source "$sourceId".');
    final page = await source.search(const SearchQuery(orientation: WallpaperOrientation.landscape));
    await _markRun();
    if (page.items.isEmpty) return RotationOutcome.nothing('${source.name} has no picture available yet.');
    final latest = page.items.first;
    if (onlyIfNew && await settings.get(SettingsKeys.rotationDailyLast) == latest.key) {
      return const RotationOutcome.nothing("Already showing today's picture.");
    }
    final item = await downloads.download(source, latest);
    await applier.applyMany({for (final t in targets) t: item}, fit: _config.fit);
    await settings.set(SettingsKeys.rotationDailyLast, latest.key);
    return RotationOutcome({for (final t in targets) t.id: item});
  }

  String _emptyPoolMessage() => switch (_config.pool) {
    AllPool() => 'Your library is empty (or every image is hidden). Download some wallpapers first.',
    FavouritesPool() => 'You have no favourites yet. Heart some wallpapers in the Library.',
    TagPool(:final tag) => 'Nothing in your library is tagged "$tag".',
    SourcePool(:final sourceId) => 'Your library has nothing from ${sources[sourceId]?.name ?? sourceId}.',
    DailyPool() => 'No daily picture available.',
  };

  Future<void> _markRun() async {
    _lastRun = _now();
    await settings.set(SettingsKeys.rotationLastRun, _lastRun!.toUtc().toIso8601String());
    _emit();
  }

  /// One change at a time: a scheduled change and a key press mustn't race.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _busy.then((_) => action());
    _busy = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(state);
  }

  Future<void> dispose() => _changes.close();
}

/// Calls [RotationService.tick] every [every]. Checking often (rather than
/// one long timer) copes with sleep/suspend and clock changes.
class RotationScheduler {
  RotationScheduler(this._service, {this.every = const Duration(seconds: 30)});

  final RotationService _service;
  final Duration every;
  Timer? _timer;

  void start() {
    _timer ??= Timer.periodic(every, (_) => _service.tick());
    unawaited(_service.tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
