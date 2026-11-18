import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Reads and writes values under `HKEY_CURRENT_USER` (Windows only).
abstract final class UserRegistry {
  /// A `REG_SZ` value, or null if it isn't there.
  static String? readString(String key, String name) => using((arena) {
    final size = arena<Uint32>();
    final type = arena<Uint32>();
    var result = RegGetValue(HKEY_CURRENT_USER, arena.pcwstr(key), arena.pcwstr(name), RRF_RT_REG_SZ, type, null, size);
    if (result != ERROR_SUCCESS) return null;
    final buffer = arena.allocate<Uint16>(size.value + 2).cast<Utf16>();
    result = RegGetValue(HKEY_CURRENT_USER, arena.pcwstr(key), arena.pcwstr(name), RRF_RT_REG_SZ, type, buffer, size);
    return result == ERROR_SUCCESS ? buffer.toDartString() : null;
  });

  /// A `REG_DWORD` value, or null if it isn't there.
  static int? readDword(String key, String name) => using((arena) {
    final value = arena<Uint32>();
    final size = arena<Uint32>()..value = sizeOf<Uint32>();
    final result = RegGetValue(HKEY_CURRENT_USER, arena.pcwstr(key), arena.pcwstr(name), RRF_RT_REG_DWORD, null, value, size);
    return result == ERROR_SUCCESS ? value.value : null;
  });

  /// Creates the key if needed. Throws [WindowsException] on failure.
  static void writeString(String key, String name, String value) => using((arena) {
    final data = arena.pcwstr(value);
    final bytes = (value.length + 1) * sizeOf<Uint16>();
    final result = RegSetKeyValue(HKEY_CURRENT_USER, arena.pcwstr(key), arena.pcwstr(name), REG_SZ, data, bytes);
    if (result != ERROR_SUCCESS) throw WindowsException(result.toHRESULT());
  });

  /// Does nothing if the value isn't there.
  static void delete(String key, String name) => using((arena) {
    final result = RegDeleteKeyValue(HKEY_CURRENT_USER, arena.pcwstr(key), arena.pcwstr(name));
    if (result != ERROR_SUCCESS && result != ERROR_FILE_NOT_FOUND) throw WindowsException(result.toHRESULT());
  });
}
