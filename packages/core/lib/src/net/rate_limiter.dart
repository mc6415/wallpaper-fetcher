import 'dart:collection';

/// Allows at most [maxRequests] calls to [acquire] to complete per [window]
/// (sliding window). Callers beyond that wait their turn, in order.
class RateLimiter {
  RateLimiter({
    required this.maxRequests,
    required this.window,
    DateTime Function()? now,
    Future<void> Function(Duration)? sleep,
  }) : _now = now ?? DateTime.now,
       _sleep = sleep ?? Future<void>.delayed;

  final int maxRequests;
  final Duration window;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _sleep;
  final _stamps = Queue<DateTime>();
  Future<void> _tail = Future.value();

  Future<void> acquire() {
    final next = _tail.then((_) => _acquireOne());
    _tail = next.catchError((_) {});
    return next;
  }

  Future<void> _acquireOne() async {
    while (true) {
      final now = _now();
      while (_stamps.isNotEmpty && now.difference(_stamps.first) >= window) {
        _stamps.removeFirst();
      }
      if (_stamps.length < maxRequests) {
        _stamps.add(now);
        return;
      }
      await _sleep(window - now.difference(_stamps.first));
    }
  }
}
