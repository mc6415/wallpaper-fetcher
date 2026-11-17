import 'package:material_ui/material_ui.dart';

/// A centred icon, title, optional message and optional action. Used for
/// empty, error and "not supported" states.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A chip that shows the current choice and opens a menu of alternatives.
class ChoiceMenuChip<T> extends StatelessWidget {
  const ChoiceMenuChip({
    super.key,
    required this.icon,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onSelected,
    this.tooltip,
  });

  final IconData icon;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final option in options)
          MenuItemButton(
            leadingIcon: option == value
                ? const Icon(Icons.check, size: 18)
                : const SizedBox(width: 18),
            onPressed: () => onSelected(option),
            child: Text(labelOf(option)),
          ),
      ],
      builder: (context, controller, _) => ActionChip(
        avatar: Icon(icon, size: 18),
        tooltip: tooltip,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(labelOf(value)), const Icon(Icons.arrow_drop_down, size: 18)],
        ),
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}

String formatSize(int width, int height) => '$width × $height';

String formatDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final local = date.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}
