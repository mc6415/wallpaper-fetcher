import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHandler = Future<ResponseBody> Function(RequestOptions options);

/// A Dio adapter that answers from a function and records every request.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FakeHandler handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(FakeHandler handler) => Dio()..httpClientAdapter = FakeAdapter(handler);

FakeAdapter adapterOf(Dio dio) => dio.httpClientAdapter as FakeAdapter;

ResponseBody jsonBody(Object json, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(json),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody bytesBody(List<int> bytes, {int status = 200}) => ResponseBody.fromBytes(
  bytes,
  status,
  headers: {
    Headers.contentLengthHeader: ['${bytes.length}'],
    Headers.contentTypeHeader: ['image/png'],
  },
);

Map<String, Object?> fixture(String name) =>
    (jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map).cast<String, Object?>();

/// Bytes that start like a PNG of the given size. Enough for the header
/// reader; nothing here decodes pixels.
Uint8List fakePng(int width, int height, {int seed = 0}) {
  final b = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..add([0, 0, 0, 13])
    ..add(ascii.encode('IHDR'))
    ..add(_be32(width))
    ..add(_be32(height))
    ..add(List.filled(64, seed & 0xff));
  return b.toBytes();
}

List<int> _be32(int v) => [(v >> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff];
