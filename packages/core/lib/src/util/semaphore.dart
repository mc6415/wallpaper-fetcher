import 'dart:async';
import 'dart:collection';

/// Limits how many async operations run at once.
class Semaphore {
  Semaphore(this._permits) : assert(_permits > 0);

  int _permits;
  final _waiters = Queue<Completer<void>>();

  Future<void> acquire() {
    if (_permits > 0) {
      _permits--;
      return Future.value();
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    return waiter.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    } else {
      _permits++;
    }
  }

  Future<T> withPermit<T>(Future<T> Function() action) async {
    await acquire();
    try {
      return await action();
    } finally {
      release();
    }
  }
}
