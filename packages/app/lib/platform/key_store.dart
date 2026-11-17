import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API keys in the system keyring (Secret Service on Linux, Credential Manager
/// on Windows, Keystore on Android).
class ApiKeyStore {
  ApiKeyStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _prefix = 'wallpaper_fetcher.apiKey.';

  final FlutterSecureStorage _storage;

  Future<Map<String, String>> load(Iterable<String> sourceIds) async => {
    for (final id in sourceIds) id: ?await _storage.read(key: '$_prefix$id'),
  };

  Future<void> save(String sourceId, String key) => _storage.write(key: '$_prefix$sourceId', value: key);

  Future<void> remove(String sourceId) => _storage.delete(key: '$_prefix$sourceId');
}
