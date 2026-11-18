# Architecture

Approved in Phase 0 (2026-11-17). See `PROJECT_BRIEF.md` for the full requirements.

## Identity
- App name: **Wallpaper Fetcher**
- Android application ID / Linux application ID: `dev.mcoombes.wallpaperfetcher`

## Layout

Three packages in one Dart workspace. The command line has to work when the app isn't
running, so everything it relies on lives in a plain-Dart `core` package with no Flutter
imports.

```
wallpaper-fetcher/
├── PROJECT_BRIEF.md
├── README.md
├── pubspec.yaml                  # workspace root
├── docs/
├── packages/
│   ├── core/                     # plain Dart: shared by app and CLI
│   │   ├── lib/src/
│   │   │   ├── models/           # wallpaper, library item, display target, credits
│   │   │   ├── sources/          # WallpaperSource + wallhaven/ unsplash/ pexels/ bing/ apod/
│   │   │   ├── library/          # drift database, rescan, JSON sidecars, duplicate checks
│   │   │   ├── setters/          # WallpaperSetter + linux/ (detection, kde, gnome, ...) + windows/
│   │   │   ├── platform/         # Windows registry helper
│   │   │   ├── rotation/         # next image per target, history
│   │   │   ├── net/              # HTTP client, rate limiting, retries
│   │   │   ├── settings/
│   │   │   └── ipc/              # CLI <-> running tray app
│   │   ├── test/fixtures/        # saved API responses
│   │   └── tool/windows_smoke.dart  # drives the real Windows calls in CI
│   ├── cli/                      # wallpaper-fetcher next|previous|favourite|apply|status (Phase 3)
│   └── app/                      # Flutter app
│       ├── lib/features/         # browse/ library/ detail/ rotation/ settings/
│       ├── lib/platform/         # tray, accent colour; android/ (setter, picked folders, rotation job)
│       └── android/.../wallpaperfetcher/  # WallpaperChannel, StorageChannel + SafTree, RotationWorker
├── packaging/linux/              # AppRun, desktop entry, build-appimage.sh
├── packaging/windows/            # Inno Setup script, wallpaper-fetcher.cmd
└── .github/workflows/build.yml   # tests + AppImage + APK + installer; releases on v* tags
```

- The CLI forwards commands to the tray app when it is running; otherwise it does the work
  itself through `core`.
- The database stores file paths relative to the library folder, so moving the library is a
  plain file move.
- The library reaches its files through `LibraryStorage`: a plain folder
  (`LocalLibraryStorage`) everywhere, or on Android a folder picked with the system picker
  (`SafLibraryStorage`, backed by `StorageChannel.kt`), which has no file paths. Such files
  are addressed as `<tree uri>#<relative path>`.

## Core interfaces

```dart
abstract interface class WallpaperSource {
  String get id;                        // 'wallhaven', 'unsplash', 'bing', ...
  String get name;
  SourceCapabilities get capabilities;  // search? orientation? colour? daily? needs a key?

  Future<SourcePage> search(SearchQuery query, {String? cursor});
  Future<DownloadTicket> prepareDownload(RemoteWallpaper w); // URL, headers, fuller metadata;
}                                                            // Unsplash's download ping goes here

abstract interface class WallpaperSetter {
  Future<List<DisplayTarget>> targets();             // re-read every time; monitors change
  Future<SetterCapabilities> capabilities();         // per-target? lock screen? fit modes?
  Future<void> apply(List<Assignment> assignments);  // all targets in one go
}
```

A `DisplayTarget` is anything that can show a wallpaper (a monitor, the lock screen, a phone
screen) with its real pixel size. An `Assignment` pairs a target with an image, a fit mode and
an optional focus point. "A different image per screen" is a list of assignments, so the two
desktop monitors and the Fold's screens use the same model.

## Decisions
- Desktop default: a different image per monitor. Default minimum resolution 3840x2160.
- Fold: a separate image per screen if Samsung's undocumented cover-screen flag works
  (tested at the start of Phase 4); otherwise one image with a per-screen crop.
  Android's public API (checked against SDK 36 and 37) only offers `FLAG_SYSTEM` and
  `FLAG_LOCK`.
- Desktop rotation runs from the tray icon.
- Built in from the start: CLI controls, and system accent colour (XDG portal on Linux,
  Material You on Android).
- Not wanted: a shared library across OSes, web builds, usage analytics.
- Phase 3: one rotation schedule for all chosen screens, each getting a different image;
  shape match beats variety when picking. Next after Previous moves forward through
  history before picking anew. The CLI talks to the running app over a Unix socket and
  falls back to opening the library itself; the same `CommandHandler` serves both.
- Phase order: Android is Phase 4 and Windows Phase 5 (swapped 2026-11-17).
- Phase 6 (2026-11-18), packaging:
  - **AppImage, not Flatpak**: the app drives desktop tools (Plasma over D-Bus,
    kwriteconfig6, gsettings, swaymsg, xfconf-query, feh) and shares a socket with the CLI;
    a Flatpak sandbox would need host access that defeats it. Built on Ubuntu 22.04 for an
    older glibc with appimagetool 1.9.1 (checksum pinned). One AppImage holds app and CLI:
    `AppRun` runs the CLI for any argument other than `--hidden`, or when started through a
    link named `wallpaper-fetcher`. Start on login and the shortcut commands use `$APPIMAGE`
    (the executable inside lives in a mount that changes every run).
  - **Inno Setup, not MSIX**: MSIX redirects a packaged app's AppData and HKCU writes into a
    private store, which the CLI (outside the package) couldn't see and which breaks the
    `Run` key; it also needs a trusted signing certificate. The installer is per user (no
    admin), puts the CLI in `cli\bin` (optionally on PATH, with a `wallpaper-fetcher.cmd`
    shim), quits a running copy before upgrading or uninstalling, and removes the PATH entry
    and `Run` value on uninstall. Not code-signed (SmartScreen warns).
  - Windows notifications: the Start menu shortcut carries the AppUserModelID
    `dev.mcoombes.wallpaperfetcher` (the runner sets the same id on the process), and toasts
    are sent through Windows PowerShell with `ToastNotificationManager`. nativeapi's own
    notifications need its WinUI 3 build and the Windows App SDK runtime.
  - Android: a release key made for this app (`~/Android/wallpaper-fetcher-release.jks`),
    given to CI as encrypted secrets; CI fails rather than fall back to the debug key.
    Release builds skip AGP's "lint vital" pass, which crashes in AGP 9.3 on
    file_selector_android's sources (a lint bug). The release APK (R8, AOT) was checked on
    the Pixel emulator, including the background rotation job.
  - App icon from `assets/app_icon.png`: an adaptive Android icon (picture tile on
    `#6750A4`), a multi-size Windows `.ico`, and the AppImage icon.
  - Releases: a `v*` tag matching the pubspec version publishes a GitHub release with the
    AppImage, the installer and the APK.
- Phase 5 (2026-11-18), Windows:
  - Built and tested in GitHub Actions on Windows (private repo `mc6415/wallpaper-fetcher`),
    since Windows can't be built from Linux. `tool/windows_smoke.dart` drives the real calls
    there, and the workflow starts the built app and talks to it from the built CLI.
  - Wallpapers per monitor with `IDesktopWallpaper` (package `win32` 6.x, from core so the
    CLI can use it). Monitor ids are the `\\.\DISPLAYn` names (matched to
    `IDesktopWallpaper`'s device paths with `EnumDisplayDevices`), labelled by position.
    Calls run in a short-lived isolate that initialises COM and per-monitor DPI awareness
    itself, so sizes are physical pixels in the app and the CLI alike.
  - Windows has one wallpaper position for all monitors: the last fit chosen wins.
    `FitMode.span` (Windows only; Linux setters list `FitMode.perScreen`) puts one image
    across every monitor, and rotation picks a single image for it.
  - Fallback when the COM service fails: `SystemParametersInfo(SPI_SETDESKWALLPAPER)` with
    `WallpaperStyle`/`TileWallpaper` in `HKCU\Control Panel\Desktop`; one image for all.
  - Lock screen: Windows Runtime `LockScreen.SetImageFileAsync` works for unpackaged apps
    (confirmed on Windows Server 2025 / build 26100 in CI), called through Windows
    PowerShell 5.1 with the path in an environment variable rather than via WinRT FFI.
  - The CLI finds the app's data because `AppPaths` on Windows mirrors path_provider:
    `%APPDATA%\<CompanyName>\<ProductName>` from `windows/runner/Runner.rc`
    (`dev.mcoombes` / `Wallpaper Fetcher`); keep them in step.
  - Command socket: Dart supports Unix sockets on Windows (10 1803+), so it's the same
    `IpcServer` as Linux, with the socket in the app's data folder.
  - Start on login: `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`; the runner
    keeps the window hidden when started with `--hidden`.
  - Accent colour: `HKCU\Software\Microsoft\Windows\DWM\AccentColor` (0xAABBGGRR), re-read
    when the window comes back to the front. Light/dark comes from Flutter.
  - No Windows notifications yet: unpackaged apps need a registered app id (Start-menu
    shortcut), which belongs with the installer (Phase 6).
- Phase 4 (2026-11-18):
  - **Fold screens work separately.** One UI keeps a wallpaper per screen and reads extra
    bits in `which`: 16 for the cover ("sub") screen, 4 for the main screen. The public
    `WallpaperManager.setStream(stream, crop, allowBackup, which)` passes them through, so
    `which` = 5/17 (home) and 6/18 (lock). Without a screen bit One UI changes only the
    screen in use. `SEM_FLAG_SUB_DISPLAY` (16) is on Samsung's SDK list and readable by
    reflection, which is how a Samsung foldable is recognised (with the hinge sensor and
    two screen sizes); the main-screen bit (`FLAG_DISPLAY_PHONE`) is hidden, so 4 is a
    constant. Checked on the SM-F976B (One UI 9, Android 17) with `dumpsys wallpaper`,
    which lists the four wallpapers separately.
  - Other foldables: per-screen crops (`setStreamWithCrops`) aren't public API in SDK 37,
    so they get one image cropped for the screen in use.
  - Android crops to fill only. Each image can have a focus point (database + sidecar),
    chosen in a crop screen that shows a frame per screen shape; rotation uses it too.
  - Background rotation: `androidx.work` called directly from `RotationWorker.kt`, which
    starts a headless Flutter engine running `rotationWorkerMain`. Not the `workmanager`
    plugin: engines it creates only get pub plugins, not the app's own channels. The job
    checks every 15 minutes to an hour (`RotationService.backgroundCheckInterval`) and
    counts a change due within half a check as due. Both engines share one database
    connection (drift's `shareAcrossIsolates`), so the open app sees background changes.
  - Material You: `android.R.color.system_accent1_500` read over the channel and used as
    the seed colour, like the desktop accent. No `dynamic_color` package.
  - Library on a picked folder: `ACTION_OPEN_DOCUMENT_TREE` with a persisted permission,
    released when the library moves away. Importing on Android copies from a picked folder
    (never moves).
- Phase 2: Wikimedia Commons Picture of the Day replaces NASA APOD (APOD API broken);
  Wallhaven searches default to the General category only. Pexels dropped: its API
  guidelines forbid wallpaper apps. Unsplash treats setting a wallpaper as a download,
  which must be reported through `download_location`.

## Packages (maintenance re-checked when each phase starts)

| Package | Purpose | Phase |
|---|---|---|
| flutter_riverpod | App state | 1 |
| go_router | Navigation | 1 |
| drift + drift_flutter | SQLite library database | 1 |
| dio | Downloads with progress/cancel, rate limiting, retries | 1 |
| dbus | KDE Plasma scripting, XDG portal (accent colour) | 1 |
| path_provider, file_selector, crypto | App folders, folder picker, duplicate detection | 1 |
| mocktail | Tests | 1 |
| flutter_secure_storage | API keys (KWallet on KDE) | 2 |
| tray_manager 0.9 + window_manager 0.7 | Tray icon, hide to tray on close (their new nativeapi-based APIs, not the deprecated `legacy` bridge) | 3 |
| args | CLI parsing | 3 |
| win32 6.x, ffi | Windows wallpaper COM API, registry, known folders | 5 |
| androidx.work (Gradle, not pub) | Android background rotation | 4 |

## Known risks
1. Fold cover screen relies on undocumented One UI `which` bits. Works on One UI 9 /
   Android 17; a future One UI could change them.
2. API key storage on KDE needs KWallet's Secret Service to be enabled (check in Phase 2).
3. WorkManager timing on Android is approximate and can be delayed further by battery
   saving (Doze, app standby).
