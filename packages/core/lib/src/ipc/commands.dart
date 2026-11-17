import 'package:path/path.dart' as p;

import '../library/database.dart';
import '../library/history.dart';
import '../library/library.dart';
import '../models/display_target.dart';
import '../rotation/rotation_config.dart';
import '../rotation/rotation_service.dart';
import 'ipc.dart';

extension LibraryItemName on LibraryItem {
  /// Its title, or its file name.
  String get displayName => title ?? p.basenameWithoutExtension(relativePath);
}

/// Runs commands for both the running app (over IPC) and the command line
/// when the app isn't running. App-only commands (`show`, `quit`) come in
/// through [onShow] / [onQuit].
class CommandHandler {
  CommandHandler({
    required this.rotation,
    required this.library,
    required this.history,
    this.onShow,
    this.onQuit,
  });

  final RotationService rotation;
  final WallpaperLibrary library;
  final WallpaperHistory history;
  final Future<void> Function()? onShow;
  final Future<void> Function()? onQuit;

  static const commands = {
    'next': 'Change to the next wallpaper',
    'previous': 'Go back to the previous wallpaper',
    'favourite': "Favourite what's on the screen now",
    'apply': 'Set a library image (by id or file path)',
    'status': "Show what's on each screen and the rotation schedule",
    'screens': 'List screen ids for --screen',
    'pause': 'Pause automatic rotation',
    'resume': 'Resume automatic rotation',
    'show': 'Open the app window (app must be running)',
    'quit': 'Quit the app (app must be running)',
  };

  Future<CommandResponse> handle(CommandRequest request) async {
    var targets = request.targets;
    // `--all` arrives as '*'.
    if (targets != null && targets.contains('*')) {
      targets = [for (final t in await rotation.setter.targets()) t.id];
    }
    switch (request.command) {
      case 'ping':
        return const CommandResponse(true, 'pong');
      case 'next':
        return _outcome(await rotation.next(targetIds: targets));
      case 'previous':
        return _outcome(await rotation.previous(targetIds: targets));
      case 'favourite':
        // Default to the primary monitor: with two screens, a shortcut that
        // favourites both is rarely what you meant.
        final ids = targets ?? [await _primaryId()];
        final done = await rotation.favouriteCurrent(targetIds: ids);
        return done.isEmpty
            ? const CommandResponse.error('Nothing to favourite: no wallpaper set by this app on that screen yet.')
            : CommandResponse(true, 'Added to favourites: ${done.map((i) => i.displayName).join(', ')}');
      case 'apply':
        return _apply(request.argument, targets);
      case 'status':
        return CommandResponse(true, await _status());
      case 'screens':
        final all = await rotation.setter.targets();
        return CommandResponse(true, [for (final t in all) '${t.id}\t${t.label}\t${t.width}x${t.height}'].join('\n'));
      case 'pause':
        await rotation.setPaused(true);
        return const CommandResponse(true, 'Rotation paused.');
      case 'resume':
        await rotation.setPaused(false);
        return const CommandResponse(true, 'Rotation resumed.');
      case 'show':
        if (onShow == null) return const CommandResponse.error("Wallpaper Fetcher isn't running.");
        await onShow!();
        return const CommandResponse(true, 'Shown.');
      case 'quit':
        if (onQuit == null) return const CommandResponse.error("Wallpaper Fetcher isn't running.");
        await onQuit!();
        return const CommandResponse(true, 'Quitting.');
      default:
        return CommandResponse.error('Unknown command "${request.command}".');
    }
  }

  Future<String> _primaryId() async {
    final screens = await rotation.setter.targets();
    return (screens.where((t) => t.isPrimary).firstOrNull ??
            screens.where((t) => t.surface == TargetSurface.home).firstOrNull ??
            screens.first)
        .id;
  }

  Future<CommandResponse> _outcome(RotationOutcome outcome) async {
    if (!outcome.changed) return CommandResponse.error(outcome.message ?? 'Nothing changed.');
    final labels = {for (final t in await rotation.setter.targets()) t.id: t.label};
    return CommandResponse(
      true,
      [for (final MapEntry(:key, :value) in outcome.applied.entries) '${labels[key] ?? key}: ${value.displayName}'].join('\n'),
    );
  }

  Future<CommandResponse> _apply(String? what, List<String>? targetIds) async {
    if (what == null || what.isEmpty) return const CommandResponse.error('Say which image: a library id or a file path.');
    LibraryItem? item;
    if (int.tryParse(what) case final id?) {
      item = await library.byId(id);
    } else if (library.root case final root?) {
      final relative = p.isAbsolute(what) ? p.relative(what, from: root) : what;
      final stored = p.posix.joinAll(p.split(relative));
      item = (await library.items()).where((i) => i.relativePath == stored).firstOrNull;
    }
    if (item == null) return CommandResponse.error('No library image matches "$what". Try "wallpaper-fetcher status" or the app.');
    final targets = await rotation.resolveTargets(targetIds);
    if (targets.isEmpty) return const CommandResponse.error('No matching screens.');
    await rotation.applier.applyMany({for (final t in targets) t: item}, fit: rotation.config.fit);
    return CommandResponse(true, 'Set ${item.displayName} on ${targets.map((t) => t.label).join(', ')}.');
  }

  Future<String> _status() async {
    final screens = await rotation.setter.targets();
    final now = await history.nowShowing();
    final state = rotation.state;
    final config = state.config;
    final pool = switch (config.pool) {
      AllPool() => 'whole library',
      FavouritesPool() => 'favourites',
      TagPool(:final tag) => 'tag "$tag"',
      SourcePool(:final sourceId) => 'from $sourceId',
      DailyPool(:final sourceId) => "today's $sourceId picture",
    };
    final schedule = !config.enabled
        ? 'off (Next/Previous still work)'
        : state.paused
        ? 'paused'
        : 'every ${_duration(config.interval)} from $pool, ${config.order.label.toLowerCase()}'
              '${state.nextDue == null ? '' : '; next change ${_until(state.nextDue!)}'}';
    return [
      for (final s in screens)
        '${s.label} [${s.id}]: ${now[s.id]?.item?.displayName ?? '(not set by Wallpaper Fetcher)'}',
      'Rotation: $schedule',
    ].join('\n');
  }

  static String _duration(Duration d) => d.inMinutes % (24 * 60) == 0
      ? (d.inDays == 1 ? 'day' : '${d.inDays} days')
      : d.inMinutes % 60 == 0
      ? (d.inHours == 1 ? 'hour' : '${d.inHours} hours')
      : (d.inMinutes == 1 ? 'minute' : '${d.inMinutes} minutes');

  static String _until(DateTime due) {
    final left = due.difference(DateTime.now());
    if (left.inMinutes < 1) return 'within a minute';
    if (left.inMinutes < 60) return 'in ${left.inMinutes} min';
    return 'in ${left.inHours} h ${left.inMinutes % 60} min';
  }
}
