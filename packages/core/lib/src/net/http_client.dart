import 'package:dio/dio.dart';

import 'retry_interceptor.dart';

const defaultUserAgent = 'WallpaperFetcher/0.3 (Dart)';

Dio createHttpClient({String userAgent = defaultUserAgent}) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'User-Agent': userAgent},
    ),
  );
  dio.interceptors.add(RetryInterceptor(dio));
  return dio;
}
