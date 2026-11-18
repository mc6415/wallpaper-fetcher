import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import '../../platform/library_image.dart';
import '../../providers.dart';

/// Lets the user choose which part of [item] the [screens] show, when the
/// image is a different shape. Returns the focus point, or null if cancelled.
Future<FocusPoint?> showCropScreen(
  BuildContext context, {
  required LibraryItem item,
  required List<DisplayTarget> screens,
  String actionLabel = 'Set wallpaper',
}) => Navigator.of(context, rootNavigator: true).push<FocusPoint>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => CropScreen(item: item, screens: screens, actionLabel: actionLabel),
  ),
);

/// Worth asking about the crop: a screen would lose more than a sliver.
bool needsCrop(LibraryItem item, Iterable<DisplayTarget> screens) =>
    screens.any((s) => cropLoss(item.width, item.height, s.width, s.height) > 0.05);

class CropScreen extends ConsumerStatefulWidget {
  const CropScreen({super.key, required this.item, required this.screens, required this.actionLabel});

  final LibraryItem item;
  final List<DisplayTarget> screens;
  final String actionLabel;

  @override
  ConsumerState<CropScreen> createState() => _CropScreenState();
}

/// One frame per screen shape (a home screen and its lock screen share one).
typedef _Frame = ({String label, int width, int height});

class _CropScreenState extends ConsumerState<CropScreen> {
  late FocusPoint _focus = widget.item.focus ?? (x: 0.5, y: 0.5);

  List<_Frame> get _frames {
    final byShape = <(int, int), List<DisplayTarget>>{};
    for (final s in widget.screens) {
      (byShape[(s.width, s.height)] ??= []).add(s);
    }
    return [
      for (final MapEntry(key: (w, h), value: group) in byShape.entries)
        (
          label: (group.firstWhere((s) => s.surface == TargetSurface.home, orElse: () => group.first)).label,
          width: w,
          height: h,
        ),
    ];
  }

  void _moveTo(Offset local, Size size) => setState(() {
    _focus = (x: (local.dx / size.width).clamp(0.0, 1.0), y: (local.dy / size.height).clamp(0.0, 1.0));
  });

  void _moveBy(Offset delta, Size size) => setState(() {
    _focus = (
      x: (_focus.x + delta.dx / size.width).clamp(0.0, 1.0),
      y: (_focus.y + delta.dy / size.height).clamp(0.0, 1.0),
    );
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final storage = ref.watch(libraryProvider).storage;
    final frames = _frames;
    final colours = [theme.colorScheme.primary, theme.colorScheme.tertiary, theme.colorScheme.secondary];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose the crop'),
        actions: [
          TextButton(onPressed: () => setState(() => _focus = (x: 0.5, y: 0.5)), child: const Text('Centre')),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                frames.length > 1
                    ? 'Drag to choose what each screen shows. The crop is remembered for this image, '
                          'including when rotation picks it.'
                    : 'Drag to choose what the screen shows. The crop is remembered for this image, '
                          'including when rotation picks it.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = math.min(constraints.maxWidth / item.width, constraints.maxHeight / item.height);
                  final size = Size(item.width * scale, item.height * scale);
                  return Center(
                    child: SizedBox.fromSize(
                      size: size,
                      child: GestureDetector(
                        key: const ValueKey('crop-area'),
                        onTapUp: (d) => _moveTo(d.localPosition, size),
                        onPanUpdate: (d) => _moveBy(d.delta, size),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image(
                              image: LibraryImage(storage, item),
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              errorBuilder: (_, _, _) => ColoredBox(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                            CustomPaint(
                              painter: _FramesPainter(
                                frames: [
                                  for (final (i, f) in frames.indexed)
                                    (
                                      label: f.label,
                                      colour: colours[i % colours.length],
                                      rect: cropToFill(item.width, item.height, f.width, f.height, focus: _focus),
                                    ),
                                ],
                                scale: scale,
                                labelStyle: theme.textTheme.labelLarge!,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _focus),
                    icon: const Icon(Icons.check),
                    label: Text(widget.actionLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FramesPainter extends CustomPainter {
  _FramesPainter({required this.frames, required this.scale, required this.labelStyle});

  final List<({String label, Color colour, CropRect rect})> frames;
  final double scale;
  final TextStyle labelStyle;

  Rect _scaled(CropRect r) =>
      Rect.fromLTRB(r.left * scale, r.top * scale, r.right * scale, r.bottom * scale);

  @override
  void paint(Canvas canvas, Size size) {
    // Dim what no screen shows.
    var shown = Path();
    for (final f in frames) {
      shown = Path.combine(PathOperation.union, shown, Path()..addRect(_scaled(f.rect)));
    }
    final outside = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), shown);
    canvas.drawPath(outside, Paint()..color = Colors.black.withValues(alpha: 0.55));

    for (final (i, f) in frames.indexed) {
      final rect = _scaled(f.rect).deflate(1.5 + i * 3);
      canvas.drawRect(
        rect,
        Paint()
          ..color = f.colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      final text = TextPainter(
        text: TextSpan(text: ' ${f.label} ', style: labelStyle.copyWith(color: Colors.white, backgroundColor: f.colour)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(0, rect.width - 8));
      text.paint(canvas, rect.topLeft + Offset(4, 4 + i * (text.height + 2)));
    }
  }

  @override
  bool shouldRepaint(_FramesPainter old) =>
      old.scale != scale ||
      old.frames.length != frames.length ||
      [for (var i = 0; i < frames.length; i++) old.frames[i].rect != frames[i].rect].any((changed) => changed);
}
