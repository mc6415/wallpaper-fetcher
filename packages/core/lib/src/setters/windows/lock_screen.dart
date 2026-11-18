import 'dart:io';

import '../wallpaper_setter.dart';

typedef PowerShellRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments, {Map<String, String>? environment});

Future<ProcessResult> _run(String executable, List<String> arguments, {Map<String, String>? environment}) =>
    Process.run(executable, arguments, environment: environment);

/// Sets the Windows lock screen picture with the Windows Runtime
/// `LockScreen.SetImageFileAsync`, which works for ordinary (unpackaged)
/// desktop programs. Called through Windows PowerShell, which can load
/// Windows Runtime types; the image path goes in an environment variable so
/// nothing needs quoting.
class LockScreenSetter {
  const LockScreenSetter({PowerShellRunner run = _run}) : _runner = run;

  final PowerShellRunner _runner;

  static const imageVariable = 'WALLPAPER_FETCHER_LOCK_IMAGE';

  static const script = r'''
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$methods = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 }
$asOperation = $methods | Where-Object { $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
$asAction = $methods | Where-Object { $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' } | Select-Object -First 1
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime] | Out-Null
$open = $asOperation.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null, @([Windows.Storage.StorageFile]::GetFileFromPathAsync($env:WALLPAPER_FETCHER_LOCK_IMAGE)))
$open.Wait(-1) | Out-Null
$set = $asAction.Invoke($null, @([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($open.Result)))
$set.Wait(-1) | Out-Null
''';

  /// Windows PowerShell 5.1, which every Windows 10/11 has.
  static String get powerShell {
    final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    return '$root\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
  }

  Future<void> set(String image) async {
    final ProcessResult result;
    try {
      result = await _runner(
        powerShell,
        ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-Command', script],
        environment: {imageVariable: image},
      );
    } on ProcessException catch (e) {
      throw WallpaperSetterException("Couldn't run Windows PowerShell to set the lock screen.", cause: e);
    }
    if (result.exitCode != 0) {
      final detail = '${result.stderr}'.trim().split('\n').where((l) => l.trim().isNotEmpty).firstOrNull;
      throw WallpaperSetterException(
        "Windows didn't set the lock screen${detail == null ? '.' : ': $detail'} "
        'It may be managed by your organisation, or Windows Spotlight may be on.',
      );
    }
  }
}
