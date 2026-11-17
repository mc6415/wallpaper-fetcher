import 'dart:convert';

import '../models/display_target.dart';

enum RotationOrder {
  shuffle('Shuffle'),
  sequential('In order');

  const RotationOrder(this.label);
  final String label;
}

/// Where rotation draws images from.
sealed class RotationPool {
  const RotationPool();

  factory RotationPool.fromJson(Map<String, Object?> json) => switch (json['type']) {
    'favourites' => const FavouritesPool(),
    'tag' when json['tag'] is String => TagPool(json['tag']! as String),
    'source' when json['source'] is String => SourcePool(json['source']! as String),
    'daily' when json['source'] is String => DailyPool(json['source']! as String),
    _ => const AllPool(),
  };

  Map<String, Object?> toJson();
}

final class AllPool extends RotationPool {
  const AllPool();

  @override
  Map<String, Object?> toJson() => {'type': 'all'};

  @override
  bool operator ==(Object other) => other is AllPool;

  @override
  int get hashCode => 0;
}

final class FavouritesPool extends RotationPool {
  const FavouritesPool();

  @override
  Map<String, Object?> toJson() => {'type': 'favourites'};

  @override
  bool operator ==(Object other) => other is FavouritesPool;

  @override
  int get hashCode => 1;
}

final class TagPool extends RotationPool {
  const TagPool(this.tag);

  final String tag;

  @override
  Map<String, Object?> toJson() => {'type': 'tag', 'tag': tag};

  @override
  bool operator ==(Object other) => other is TagPool && other.tag == tag;

  @override
  int get hashCode => Object.hash('tag', tag);
}

/// Library images that came from one source.
final class SourcePool extends RotationPool {
  const SourcePool(this.sourceId);

  final String sourceId;

  @override
  Map<String, Object?> toJson() => {'type': 'source', 'source': sourceId};

  @override
  bool operator ==(Object other) => other is SourcePool && other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash('source', sourceId);
}

/// Today's picture from a daily source (Bing, Wikimedia), downloaded and set
/// once it changes. Every screen in the rotation gets the same picture.
final class DailyPool extends RotationPool {
  const DailyPool(this.sourceId);

  final String sourceId;

  @override
  Map<String, Object?> toJson() => {'type': 'daily', 'source': sourceId};

  @override
  bool operator ==(Object other) => other is DailyPool && other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash('daily', sourceId);
}

/// One schedule for every screen it covers. Each covered screen gets a
/// different image each time (pool size permitting).
final class RotationConfig {
  const RotationConfig({
    this.enabled = false,
    this.interval = const Duration(hours: 1),
    this.pool = const AllPool(),
    this.order = RotationOrder.shuffle,
    this.screens = const {},
    this.fit = FitMode.fill,
  });

  factory RotationConfig.fromJson(Map<String, Object?> json) => RotationConfig(
    enabled: json['enabled'] == true,
    interval: Duration(minutes: (json['intervalMinutes'] as int? ?? 60).clamp(1, 7 * 24 * 60)),
    pool: json['pool'] is Map
        ? RotationPool.fromJson((json['pool']! as Map).cast<String, Object?>())
        : const AllPool(),
    order: RotationOrder.values.asNameMap()[json['order']] ?? RotationOrder.shuffle,
    screens: {...?(json['screens'] as List?)?.whereType<String>()},
    fit: FitMode.values.asNameMap()[json['fit']] ?? FitMode.fill,
  );

  /// Reads the stored form; anything unreadable gives the defaults.
  static RotationConfig parse(String? stored) {
    if (stored == null) return const RotationConfig();
    try {
      final json = jsonDecode(stored);
      return json is Map ? RotationConfig.fromJson(json.cast<String, Object?>()) : const RotationConfig();
    } on FormatException {
      return const RotationConfig();
    }
  }

  static const _unset = Object();

  /// Automatic changes on; Next/Previous work either way.
  final bool enabled;
  final Duration interval;
  final RotationPool pool;
  final RotationOrder order;

  /// [DisplayTarget.id]s to rotate. Empty means every monitor (not the lock
  /// screen).
  final Set<String> screens;
  final FitMode fit;

  RotationConfig copyWith({
    bool? enabled,
    Duration? interval,
    RotationPool? pool,
    RotationOrder? order,
    Object? screens = _unset,
    FitMode? fit,
  }) => RotationConfig(
    enabled: enabled ?? this.enabled,
    interval: interval ?? this.interval,
    pool: pool ?? this.pool,
    order: order ?? this.order,
    screens: identical(screens, _unset) ? this.screens : screens! as Set<String>,
    fit: fit ?? this.fit,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'intervalMinutes': interval.inMinutes,
    'pool': pool.toJson(),
    'order': order.name,
    'screens': screens.toList()..sort(),
    'fit': fit.name,
  };

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) => other is RotationConfig && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}
