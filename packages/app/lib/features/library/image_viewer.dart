import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// A zoomable image on a dark backdrop, showing [placeholder] (a thumbnail)
/// while the full image loads. Arrows over its edges call [onPrevious] and
/// [onNext]; each is left out when null (at either end of the list).
class ImageViewer extends StatelessWidget {
  const ImageViewer({super.key, required this.image, this.placeholder, this.onPrevious, this.onNext});

  final ImageProvider image;
  final ImageProvider? placeholder;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: InteractiveViewer(
            maxScale: 6,
            child: Center(
              child: Image(
                image: image,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  final total = progress.expectedTotalBytes;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (placeholder != null) Image(image: placeholder!, fit: BoxFit.contain),
                      CircularProgressIndicator(
                        value: total == null ? null : progress.cumulativeBytesLoaded / total,
                      ),
                    ],
                  );
                },
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
              ),
            ),
          ),
        ),
        if (onPrevious != null)
          Align(
            alignment: Alignment.centerLeft,
            child: _Arrow(icon: Icons.chevron_left, tooltip: 'Previous wallpaper', onPressed: onPrevious!),
          ),
        if (onNext != null)
          Align(
            alignment: Alignment.centerRight,
            child: _Arrow(icon: Icons.chevron_right, tooltip: 'Next wallpaper', onPressed: onNext!),
          ),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: IconButton(
      tooltip: tooltip,
      iconSize: 32,
      style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
      icon: Icon(icon),
      onPressed: onPressed,
    ),
  );
}

/// The left and right arrow keys call [onPrevious] and [onNext] anywhere in
/// [child], unless whatever has focus uses them itself (a text field).
class ArrowKeyPaging extends StatelessWidget {
  const ArrowKeyPaging({super.key, required this.child, this.onPrevious, this.onNext});

  final Widget child;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): ?onPrevious,
      const SingleActivator(LogicalKeyboardKey.arrowRight): ?onNext,
    },
    child: Focus(autofocus: true, child: child),
  );
}
