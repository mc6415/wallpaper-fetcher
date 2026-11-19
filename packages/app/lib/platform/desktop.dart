import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter/scheduler.dart';
import 'package:logging/logging.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:wallpaper_core/wallpaper_core.dart';
import 'package:window_manager/window_manager.dart' as win;

import '../services.dart';

final _log = Logger('Desktop');

/// Everything that makes the desktop app a resident one: the tray icon and
/// its menu, hiding instead of closing, the command socket the CLI talks to,
/// and the rotation timer.
class DesktopIntegration {
  DesktopIntegration._(this.services, {required this.keepInTray});

  final AppServices services;

  /// Closing the window hides it (true) or quits (false).
  bool keepInTray;

  final _notifier = DesktopNotifier();
  win.Window? _window;
  tray.TrayIcon? _tray; // must stay referenced, or the icon disappears
  IpcServer? _ipc;
  late final RotationScheduler _scheduler = RotationScheduler(services.rotation);
  late final CommandHandler _commands = CommandHandler(
    rotation: services.rotation,
    library: services.library,
    history: services.history,
    onShow: show,
    // Reply to the command line first, then go.
    onQuit: () async => Timer(const Duration(milliseconds: 300), quit),
  );
  final _subscriptions = <StreamSubscription<Object?>>[];
  Map<String, NowShowing> _now = const {};
  List<DisplayTarget> _targets = const [];
  bool _quitting = false;
  bool _toldAboutTray = false;

  bool get hasTray => _tray != null;

  /// The app's window, for its title bar and frame.
  win.Window? get window => _window;

  /// Null on platforms without a desktop shell (Android). Throws
  /// [IpcAlreadyRunning] if another instance owns the command socket.
  static Future<DesktopIntegration?> start(AppServices services) async {
    if (!Platform.isLinux && !Platform.isWindows) return null;
    final keep = services.initialSettings[SettingsKeys.keepInTray] != 'false';
    final desktop = DesktopIntegration._(services, keepInTray: keep);
    desktop._ipc = await IpcServer.bind(AppPaths.socket(), desktop._handleCommand);
    desktop._window = win.WindowManager.instance.getCurrent();
    desktop._window?.addListener(desktop._onWindowEvent);
    // The app draws its own title bar (WindowFrame). Windows keeps its
    // resize borders, snapping and shadow, and rounds the corners on 11.
    desktop._window?.titleBarStyle = win.TitleBarStyle.hidden;
    if (Platform.isWindows) desktop._window?.setCornerPreference(win.WindowCornerPreference.round);
    try {
      desktop._createTray();
    } on Object catch (e) {
      _log.warning('No tray icon (closing the window will quit): $e');
    }
    desktop._subscriptions
      ..add(services.rotation.changes.listen((_) => desktop._refreshTray()))
      ..add(services.history.watchNowShowing().listen((now) {
        desktop._now = now;
        desktop._refreshTray();
      }));
    unawaited(services.setter.targets().then((t) {
      desktop._targets = t;
      desktop._refreshTray();
    }, onError: (Object _) {}));
    desktop._scheduler.start();
    return desktop;
  }

  Future<void> show() async {
    final window = _window ??= win.WindowManager.instance.getCurrent();
    if (window == null) return;
    final wasHidden = !window.isVisible;
    _log.info('Show window${wasHidden ? ' (was hidden)' : ''}');
    window.show();
    window.focus();
    if (wasHidden && Platform.isLinux) _redrawAfterHide(window);
  }

  /// Flutter's Linux embedder doesn't draw into a window that was hidden and
  /// shown again: the content stays black, even with forced frames. Changing
  /// the size makes it set its surface up again, so nudge it by a pixel and
  /// back once the compositor has mapped the window.
  void _redrawAfterHide(win.Window window) {
    Timer(const Duration(milliseconds: 150), () {
      if (window.isMaximized) {
        // A maximised window ignores resizes; restore and re-maximise.
        window.unmaximize();
        Timer(const Duration(milliseconds: 150), window.maximize);
        return;
      }
      final size = window.contentSize.toSize();
      window.contentSize = Size(size.width + 1, size.height).toNative();
      Timer(const Duration(milliseconds: 150), () {
        window.contentSize = size.toNative();
        SchedulerBinding.instance.scheduleForcedFrame();
      });
    });
  }

  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    _log.info('Quitting');
    _scheduler.stop();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _ipc?.close();
    _tray?.dispose();
    _tray = null;
    await services.db.close();
    exit(0);
  }

  void _onWindowEvent(win.WindowEvent event) {
    if (event is! win.WindowCloseRequestedEvent || _quitting) return;
    if (keepInTray && hasTray) {
      event.request.cancel();
      _window?.hide();
      if (!_toldAboutTray) {
        _toldAboutTray = true;
        unawaited(_notifier.notify(
          'Still running in the tray',
          'Wallpaper Fetcher keeps your wallpaper rotating. Choose Quit from its tray menu to stop it.',
        ));
      }
    } else {
      event.request.cancel();
      unawaited(quit());
    }
  }

  Future<CommandResponse> _handleCommand(CommandRequest request) async {
    final response = await _commands.handle(request);
    if (request.notify && (!response.ok || request.command == 'favourite')) {
      await _notifier.notify(response.ok ? 'Wallpaper Fetcher' : "Couldn't ${request.command}", response.message);
    }
    return response;
  }

  // --- Tray ------------------------------------------------------------------

  void _createTray() {
    final icon = tray.TrayIcon.create() ?? (throw StateError('the desktop has no tray'));
    icon.icon = tray.ImageAsset.fromAsset('assets/tray_icon.png');
    icon.setContextMenuTrigger(tray.ContextMenuTrigger.rightClicked);
    // Windows/macOS report clicks; Linux panels open the menu themselves.
    icon.addListener((event) {
      if (event is tray.TrayIconClickedEvent) unawaited(show());
    });
    _tray = icon;
    _refreshTray();
    icon.setVisible(true);
  }

  void _refreshTray() {
    final icon = _tray;
    if (icon == null || _quitting) return;
    final state = services.rotation.state;
    icon.setTooltip([
      'Wallpaper Fetcher',
      if (!state.config.enabled)
        'Automatic changes off'
      else if (state.paused)
        'Rotation paused'
      else if (state.nextDue case final due?)
        'Next change at ${_time(due)}',
    ].join('\n'));

    final menu = tray.Menu.create()!;
    void item(String label, FutureOr<void> Function() onClick, {bool enabled = true}) {
      final entry = tray.MenuItem.createWithLabelAndType(label, tray.MenuItemType.normal)!;
      entry.isEnabled = enabled;
      entry.addListener((e) {
        if (e is tray.MenuItemClickedEvent) onClick();
      });
      menu.addItem(entry);
    }

    item('Next wallpaper', () => _run('next', services.rotation.next));
    item('Previous wallpaper', () => _run('previous', services.rotation.previous));

    final screens = [for (final t in _targets) if (_now[t.id]?.item != null) t];
    if (screens.isNotEmpty) {
      final submenu = tray.Menu.create()!;
      for (final screen in screens) {
        final current = _now[screen.id]!.item!;
        final entry = tray.MenuItem.createWithLabelAndType(
          '${screen.label}: ${_short(current.displayName)}${current.isFavourite ? ' ♥' : ''}',
          tray.MenuItemType.normal,
        )!;
        entry.isEnabled = !current.isFavourite;
        entry.addListener((e) {
          if (e is tray.MenuItemClickedEvent) unawaited(_favourite(screen));
        });
        submenu.addItem(entry);
      }
      final parent = tray.MenuItem.createWithLabelAndType('Add to favourites', tray.MenuItemType.submenu)!;
      parent.submenu = submenu;
      menu.addItem(parent);
    }

    menu.addSeparator();
    final pause = tray.MenuItem.createWithLabelAndType('Pause rotation', tray.MenuItemType.checkbox)!;
    pause.state = state.paused ? tray.MenuItemState.checked : tray.MenuItemState.unchecked;
    pause.isEnabled = state.config.enabled;
    pause.addListener((e) {
      if (e is tray.MenuItemClickedEvent) unawaited(services.rotation.setPaused(!services.rotation.paused));
    });
    menu.addItem(pause);
    menu.addSeparator();
    item('Open Wallpaper Fetcher', show);
    item('Quit', quit);
    icon.setContextMenu(menu);
  }

  Future<void> _run(String what, Future<RotationOutcome> Function() action) async {
    try {
      final outcome = await action();
      if (!outcome.changed) await _notifier.notify("Couldn't change wallpaper", outcome.message ?? 'Nothing to change.');
    } on Object catch (e) {
      _log.warning('Tray $what failed: $e');
      await _notifier.notify("Couldn't change wallpaper", '$e');
    }
  }

  Future<void> _favourite(DisplayTarget screen) async {
    final done = await services.rotation.favouriteCurrent(targetIds: [screen.id]);
    if (done.isNotEmpty) await _notifier.notify('Added to favourites', done.first.displayName);
  }

  static String _short(String name) => name.length <= 40 ? name : '${name.substring(0, 39)}…';

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
