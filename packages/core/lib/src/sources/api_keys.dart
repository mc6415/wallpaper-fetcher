/// API keys by source id, held in memory. The app loads them from the system
/// keyring at startup and updates them from Settings; sources read them on
/// every request, so a new key takes effect immediately.
class ApiKeys {
  ApiKeys([Map<String, String> initial = const {}]) {
    initial.forEach((k, v) => this[k] = v);
  }

  final _keys = <String, String>{};

  String? operator [](String sourceId) => _keys[sourceId];

  /// Null or blank removes the key.
  void operator []=(String sourceId, String? key) {
    final trimmed = key?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _keys.remove(sourceId);
    } else {
      _keys[sourceId] = trimmed;
    }
  }

  Set<String> get configured => _keys.keys.toSet();
}
