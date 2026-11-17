import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

final _log = Logger('Ipc');

/// A command from the command line (or a second app launch) to the running
/// app. Sent as one line of JSON.
final class CommandRequest {
  const CommandRequest(this.command, {this.targets, this.argument, this.notify = false});

  factory CommandRequest.fromJson(Map<String, Object?> json) => CommandRequest(
    json['command'] as String? ?? '',
    targets: (json['targets'] as List?)?.whereType<String>().toList(),
    argument: json['argument'] as String?,
    notify: json['notify'] == true,
  );

  final String command;

  /// Screen ids; null means the command's default screens.
  final List<String>? targets;

  /// E.g. the image for `apply`.
  final String? argument;

  /// Show the outcome as a desktop notification: the command came from a
  /// keyboard shortcut or script with no terminal to print to.
  final bool notify;

  Map<String, Object?> toJson() => {
    'command': command,
    'targets': ?targets,
    'argument': ?argument,
    if (notify) 'notify': true,
  };
}

final class CommandResponse {
  const CommandResponse(this.ok, this.message);

  factory CommandResponse.fromJson(Map<String, Object?> json) =>
      CommandResponse(json['ok'] == true, json['message'] as String? ?? '');

  const CommandResponse.error(this.message) : ok = false;

  final bool ok;
  final String message;

  Map<String, Object?> toJson() => {'ok': ok, 'message': message};
}

typedef CommandCallback = Future<CommandResponse> Function(CommandRequest request);

class IpcAlreadyRunning implements Exception {
  @override
  String toString() => 'Another Wallpaper Fetcher is already running.';
}

/// Listens on a Unix socket (private to the user under `$XDG_RUNTIME_DIR`).
class IpcServer {
  IpcServer._(this.path, this._server, this._handler) {
    _server.listen(_serve, onError: (Object e) => _log.warning('Socket error: $e'));
  }

  final String path;
  final ServerSocket _server;
  final CommandCallback _handler;

  /// Throws [IpcAlreadyRunning] if another instance answers on [path].
  static Future<IpcServer> bind(String path, CommandCallback handler) async {
    final file = File(path);
    if (await file.exists()) {
      if (await IpcClient(path).ping()) throw IpcAlreadyRunning();
      await file.delete(); // left behind by a crash
    }
    await file.parent.create(recursive: true);
    final server = await ServerSocket.bind(InternetAddress(path, type: InternetAddressType.unix), 0);
    _log.info('Listening on $path');
    return IpcServer._(path, server, handler);
  }

  Future<void> _serve(Socket socket) async {
    try {
      final line = await utf8.decoder.bind(socket).transform(const LineSplitter()).first.timeout(
        const Duration(seconds: 5),
      );
      final json = jsonDecode(line);
      final request = CommandRequest.fromJson((json as Map).cast<String, Object?>());
      CommandResponse response;
      try {
        response = await _handler(request);
      } on Object catch (e, stack) {
        _log.warning('Command ${request.command} failed', e, stack);
        response = CommandResponse.error('$e');
      }
      socket.writeln(jsonEncode(response.toJson()));
      await socket.flush();
    } on Object catch (e) {
      _log.warning('Bad command connection: $e');
    } finally {
      await socket.close();
    }
  }

  Future<void> close() async {
    await _server.close();
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}

class IpcClient {
  IpcClient(this.path, {this.timeout = const Duration(seconds: 90)});

  final String path;

  /// Generous: a daily picture may need downloading first.
  final Duration timeout;

  /// The app's reply, or null if no app is listening.
  Future<CommandResponse?> send(CommandRequest request) async {
    final Socket socket;
    try {
      socket = await Socket.connect(
        InternetAddress(path, type: InternetAddressType.unix),
        0,
        timeout: const Duration(seconds: 2),
      );
    } on SocketException {
      return null;
    }
    try {
      socket.writeln(jsonEncode(request.toJson()));
      await socket.flush();
      final reply = (await utf8.decoder.bind(socket).join().timeout(timeout)).trim();
      if (reply.isEmpty) return const CommandResponse.error('Wallpaper Fetcher closed without answering.');
      final json = jsonDecode(reply);
      if (json is! Map) return const CommandResponse.error('Wallpaper Fetcher sent an unreadable answer.');
      return CommandResponse.fromJson(json.cast<String, Object?>());
    } on TimeoutException {
      return const CommandResponse.error('Wallpaper Fetcher took too long to answer.');
    } on FormatException {
      return const CommandResponse.error('Wallpaper Fetcher sent an unreadable answer.');
    } on SocketException {
      return const CommandResponse.error('Wallpaper Fetcher closed without answering.');
    } finally {
      socket.destroy();
    }
  }

  Future<bool> ping() async => (await send(const CommandRequest('ping')))?.ok ?? false;
}
