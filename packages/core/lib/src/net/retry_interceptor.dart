import 'dart:math';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

final _log = Logger('Retry');

/// Retries failed requests on connection problems, HTTP 429 and 5xx, with
/// exponential backoff. Honours `Retry-After`.
///
/// Set `extra['noRetry'] = true` on a request to opt out (downloads do, since
/// a half-written file can't simply be retried here).
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    Future<void> Function(Duration)? sleep,
  }) : _sleep = sleep ?? Future<void>.delayed;

  static const _attemptKey = 'retryAttempt';

  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;
  final Future<void> Function(Duration) _sleep;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = options.extra[_attemptKey] as int? ?? 0;
    if (options.extra['noRetry'] == true ||
        attempt >= maxRetries ||
        !shouldRetry(err)) {
      return handler.next(err);
    }
    final delay = _delayFor(err.response, attempt);
    _log.info(
      'Retrying ${options.uri.host}${options.uri.path} in ${delay.inMilliseconds}ms '
      '(attempt ${attempt + 1} of $maxRetries): ${err.type.name} ${err.response?.statusCode ?? ''}',
    );
    await _sleep(delay);
    options.extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<Object?>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  static bool shouldRetry(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.connectionError => true,
    DioExceptionType.badResponse => switch (e.response?.statusCode) {
      429 => true,
      final s? when s >= 500 => true,
      _ => false,
    },
    _ => false,
  };

  Duration _delayFor(Response<Object?>? response, int attempt) {
    final retryAfter = int.tryParse(response?.headers.value('retry-after') ?? '');
    final delay = retryAfter != null
        ? Duration(seconds: retryAfter)
        : baseDelay * pow(2, attempt).toInt();
    return delay > maxDelay ? maxDelay : delay;
  }
}
