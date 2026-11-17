import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:wallpaper_core/wallpaper_core.dart';

import 'support/fake_http.dart';

void main() {
  group('RateLimiter', () {
    test('lets requests through until the window is full, then waits', () async {
      var now = DateTime(2026);
      final sleeps = <Duration>[];
      final limiter = RateLimiter(
        maxRequests: 2,
        window: const Duration(minutes: 1),
        now: () => now,
        sleep: (d) async {
          sleeps.add(d);
          now = now.add(d);
        },
      );

      await limiter.acquire();
      now = now.add(const Duration(seconds: 10));
      await limiter.acquire();
      expect(sleeps, isEmpty);

      await limiter.acquire();
      expect(sleeps, [const Duration(seconds: 50)]);
    });

    test('serves waiting callers in order', () async {
      var now = DateTime(2026);
      final limiter = RateLimiter(
        maxRequests: 1,
        window: const Duration(seconds: 1),
        now: () => now,
        sleep: (d) async => now = now.add(d),
      );
      final order = <int>[];
      await Future.wait([
        for (var i = 0; i < 4; i++) limiter.acquire().then((_) => order.add(i)),
      ]);
      expect(order, [0, 1, 2, 3]);
    });
  });

  group('RetryInterceptor', () {
    Dio dioWith(List<int> statuses, List<Duration> sleeps) {
      var call = 0;
      final dio = fakeDio((_) async {
        final status = statuses[call.clamp(0, statuses.length - 1)];
        call++;
        return jsonBody({'ok': status == 200}, status: status);
      });
      dio.interceptors.add(RetryInterceptor(dio, sleep: (d) async => sleeps.add(d)));
      return dio;
    }

    test('retries 429 and 5xx with backoff, then succeeds', () async {
      final sleeps = <Duration>[];
      final dio = dioWith([429, 503, 200], sleeps);

      final response = await dio.get<Object?>('https://example.test/');

      expect(response.statusCode, 200);
      expect(sleeps, [const Duration(seconds: 1), const Duration(seconds: 2)]);
    });

    test('gives up after maxRetries', () async {
      final sleeps = <Duration>[];
      final dio = dioWith([500], sleeps);

      await expectLater(dio.get<Object?>('https://example.test/'), throwsA(isA<DioException>()));
      expect(sleeps, hasLength(3));
    });

    test('does not retry 404 or opted-out requests', () async {
      final sleeps = <Duration>[];
      await expectLater(
        dioWith([404], sleeps).get<Object?>('https://example.test/'),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        dioWith([500], sleeps).get<Object?>(
          'https://example.test/',
          options: Options(extra: {'noRetry': true}),
        ),
        throwsA(isA<DioException>()),
      );
      expect(sleeps, isEmpty);
    });
  });
}
