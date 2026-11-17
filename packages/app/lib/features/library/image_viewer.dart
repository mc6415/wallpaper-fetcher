import 'package:material_ui/material_ui.dart';

/// A zoomable image on a dark backdrop, showing [placeholder] (a thumbnail)
/// while the full image loads.
class ImageViewer extends StatelessWidget {
  const ImageViewer({super.key, required this.image, this.placeholder});

  final ImageProvider image;
  final ImageProvider? placeholder;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
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
    );
  }
}
