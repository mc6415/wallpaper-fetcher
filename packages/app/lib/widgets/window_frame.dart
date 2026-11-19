import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart' as win;

/// The window's own chrome on the desktop, in place of the system title bar:
/// a slim bar to drag (double-click maximises) with the window buttons, and
/// on Linux rounded corners, a hairline edge and resize handles, with the
/// shadow drawn around them by the window. Windows keeps its own resize
/// borders, shadow and (on 11) rounded corners.
class WindowFrame extends StatefulWidget {
  const WindowFrame({super.key, required this.window, required this.child});

  final win.Window window;
  final Widget child;

  static const cornerRadius = 12.0;
  static const titleBarHeight = 40.0;

  @override
  State<WindowFrame> createState() => _WindowFrameState();
}

class _WindowFrameState extends State<WindowFrame> {
  late final win.ListenerId _listener;
  late bool _maximized = _isMaximized;
  late bool _focused = widget.window.isFocused;

  /// The runner makes the window see-through when there's a compositor to
  /// show it (see linux/runner/my_application.cc); otherwise corners stay square.
  static final _canRound = Platform.isLinux && Platform.environment['WALLPAPER_FETCHER_TRANSLUCENT'] == '1';

  bool get _isMaximized => widget.window.isMaximized || widget.window.isFullScreen;

  @override
  void initState() {
    super.initState();
    _listener = widget.window.addListener((event) {
      if (!mounted) return;
      final maximized = _isMaximized;
      final focused = widget.window.isFocused;
      if (maximized != _maximized || focused != _focused) {
        setState(() {
          _maximized = maximized;
          _focused = focused;
        });
      }
    });
  }

  @override
  void dispose() {
    widget.window.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Its own overlay, for the title bar's tooltips: it sits above the
    // app's navigator, and so above the navigator's overlay.
    Widget frame = Overlay.wrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TitleBar(window: widget.window, maximized: _maximized, focused: _focused),
          Expanded(child: widget.child),
        ],
      ),
    );

    if (Platform.isLinux && !_maximized) {
      final radius = BorderRadius.circular(_canRound ? WindowFrame.cornerRadius : 0);
      final edge = Theme.of(context).colorScheme.outlineVariant;
      frame = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: _focused ? edge : edge.withValues(alpha: 0.5)),
        ),
        child: ClipRRect(borderRadius: radius, child: frame),
      );
    }

    return win.DragToResizeArea(
      window: widget.window,
      // Windows resizes from its own borders, except along the top, which
      // the hidden title bar took.
      enableResizeEdges: _maximized
          ? const []
          : Platform.isWindows
          ? const [win.ResizeEdge.topLeft, win.ResizeEdge.top, win.ResizeEdge.topRight]
          : null,
      child: frame,
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.window, required this.maximized, required this.focused});

  final win.Window window;
  final bool maximized;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = focused ? scheme.onSurfaceVariant : scheme.onSurfaceVariant.withValues(alpha: 0.6);

    return Material(
      color: scheme.surface,
      child: SizedBox(
        height: WindowFrame.titleBarHeight,
        child: Row(
          children: [
            Expanded(
              child: win.DragToMoveArea(
                window: window,
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Row(
                    children: [
                      Image.asset('assets/app_icon.png', width: 18, height: 18),
                      const SizedBox(width: 10),
                      Text('Wallpaper Fetcher', style: theme.textTheme.titleSmall?.copyWith(color: ink)),
                    ],
                  ),
                ),
              ),
            ),
            // Window buttons are pointer-only, as the system's are, so Tab
            // starts in the app rather than here.
            ExcludeFocus(
              child: Row(
                children: [
                  _WindowButton(icon: Icons.remove, tooltip: 'Minimise', ink: ink, onPressed: window.minimize),
                  win.MaximizeButtonArea(
                    window: window,
                    child: _WindowButton(
                      icon: maximized ? Icons.filter_none : Icons.crop_square,
                      iconSize: maximized ? 14 : 16,
                      tooltip: maximized ? 'Restore' : 'Maximise',
                      ink: ink,
                      onPressed: maximized ? window.unmaximize : window.maximize,
                    ),
                  ),
                  _WindowButton(
                    icon: Icons.close,
                    tooltip: 'Close',
                    ink: ink,
                    // Through the close listeners, so it goes to the tray if set to.
                    onPressed: window.close,
                    hover: (background: scheme.error, foreground: scheme.onError),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.ink,
    required this.onPressed,
    this.iconSize = 16,
    this.hover,
  });

  final IconData icon;
  final String tooltip;
  final Color ink;
  final VoidCallback onPressed;
  final double iconSize;

  /// Colours while the pointer is over it (the close button's red).
  final ({Color background, Color foreground})? hover;

  @override
  Widget build(BuildContext context) {
    final hover = this.hover;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        style: ButtonStyle(
          iconSize: WidgetStatePropertyAll(iconSize),
          fixedSize: const WidgetStatePropertyAll(Size.square(30)),
          minimumSize: const WidgetStatePropertyAll(Size.square(30)),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => hover != null && states.contains(WidgetState.hovered) ? hover.foreground : ink,
          ),
          backgroundColor: hover == null
              ? null
              : WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.hovered) ? hover.background : null,
                ),
        ),
      ),
    );
  }
}
