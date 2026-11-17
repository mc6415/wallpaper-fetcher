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
    this.leadingOf,
  });

  final IconData icon;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;
  final String? tooltip;

  /// Optional per-option leading widget (e.g. a colour swatch). The chosen
  /// option then gets a trailing tick instead of a leading one.
  final Widget? Function(T)? leadingOf;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final option in options)
          MenuItemButton(
            leadingIcon: leadingOf != null
                ? (leadingOf!(option) ?? const SizedBox(width: 18))
                : option == value
                ? const Icon(Icons.check, size: 18)
                : const SizedBox(width: 18),
            trailingIcon: leadingOf != null && option == value ? const Icon(Icons.check, size: 18) : null,
            onPressed: () => onSelected(option),
            child: Text(labelOf(option)),
          ),
      ],
      builder: (context, controller, _) => ActionChip(
        avatar: leadingOf?.call(value) ?? Icon(icon, size: 18),
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

/// A chip for choosing several options at once (e.g. Wallhaven categories).
/// Unticking the last option isn't allowed, so something is always chosen.
class MultiChoiceMenuChip<T> extends StatelessWidget {
  const MultiChoiceMenuChip({
    super.key,
    required this.icon,
    required this.selected,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.tooltip,
  });

  final IconData icon;
  final Set<T> selected;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<Set<T>> onChanged;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final label = selected.length == options.length
        ? 'All'
        : [for (final o in options) if (selected.contains(o)) labelOf(o)].join(' + ');
    return MenuAnchor(
      menuChildren: [
        for (final option in options)
          CheckboxMenuButton(
            value: selected.contains(option),
            closeOnActivate: false,
            onChanged: (checked) {
              final next = {...selected};
              checked == true ? next.add(option) : next.remove(option);
              if (next.isNotEmpty) onChanged(next);
            },
            child: Text(labelOf(option)),
          ),
      ],
      builder: (context, controller, _) => ActionChip(
        avatar: Icon(icon, size: 18),
        tooltip: tooltip,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(label), const Icon(Icons.arrow_drop_down, size: 18)],
        ),
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class Swatch extends StatelessWidget {
  const Swatch(this.color, {super.key, this.size = 18});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
  );
}

/// "just now", "5 min ago", "3 h ago", "yesterday", or a date.
String formatRelative(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return formatDate(time);
}
