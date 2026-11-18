# Wallpaper Fetcher

Fetches wallpapers from online sources, keeps them in a local library folder, and sets
them as your desktop or lock-screen wallpaper in a couple of clicks — a different image on
each monitor if you like.

Targets Linux, Windows and Android. See [`PROJECT_BRIEF.md`](PROJECT_BRIEF.md) for the full
plan and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how it's put together.

## Status

**Phase 6 — done:** all six phases of the plan, with packaged releases for every platform.

| | KDE Plasma | Other Linux desktops | Android | Windows 10/11 |
|---|---|---|---|---|
| Browse & download (Wallhaven, Unsplash, Bing, Wikimedia) | ✅ | ✅ | ✅ | ✅ |
| Library: favourites, tags, filters, search, folder import | ✅ | ✅ | ✅ | ✅ |
| Set wallpaper per screen, Previous/Next history | ✅ | ✅ untested* | ✅ (Fold: main and cover screens separately) | ✅† |
| Set lock screen | ✅ | GNOME, untested* | ✅ (Fold: both lock screens) | ✅† |
| Automatic rotation | ✅ tray | ✅ tray, untested* | ✅ in the background | ✅ tray† |
| Tray icon, start on login, command line | ✅ | ✅ untested* | not applicable | ✅† |

\* Built from each desktop tool's documentation and covered by tests against sample
output, but not yet run on a real GNOME, Cinnamon, MATE, Xfce, Sway, Hyprland or feh setup.

† Checked by automated runs on a Windows machine (GitHub Actions, Windows Server 2025 —
the Windows 11 24H2 base — with one virtual monitor): the real wallpaper, lock screen and
registry calls, plus starting the app and driving it from the command line. Not yet tried
by hand on a multi-monitor PC.

Android has been tested on a Galaxy Fold (SM-F976B, Android 17).

## Installing

Download from the repository's **Releases** page:

| | File | |
|---|---|---|
| Linux | `Wallpaper_Fetcher-<version>-x86_64.AppImage` | `chmod +x` it and run it. It's also the command line (below). Built on Ubuntu 22.04, so it runs on that and anything newer; needs GTK 3 and, for API keys, libsecret, which desktops have. |
| Windows 10 (1803+) / 11 | `Wallpaper_Fetcher-<version>-Setup.exe` | Installs for you only (no administrator) into `%LOCALAPPDATA%\Programs`, with a Start menu entry and, if you tick it, the `wallpaper-fetcher` command on PATH. Not code-signed, so SmartScreen asks first ("More info" → "Run anyway"). Uninstalls from Settings → Apps; your library and settings stay. |
| Android 8+ | `Wallpaper_Fetcher-<version>.apk` | Allow installing apps from your browser or file manager when asked. Release builds are signed with the project's release key, so a debug build (from `flutter run`) has to be uninstalled first, which deletes a library kept in the app's own storage. |

## Using it

1. On first run, pick a library folder (default `~/Pictures/Wallpapers`). Anything already
   in it is added to the library.
2. **Browse** one tab per source: search, sort, and filter by shape, minimum size (defaults
   to your largest screen), colour and Wallhaven category. Click the download button on a
   thumbnail, or open it for details and credits.
3. **Library**: click the wallpaper button on any image (or right-click it) and choose a
   monitor, all monitors, the lock screen, or everywhere. The strip at the top shows what
   each screen has, with **Previous / Next** to step through what it had before.
4. Favourite images with the heart, add your own tags on the detail page, mark images to
   leave out of rotation, and filter or search the library by any of these.
5. **Import a folder** (⋮ menu) copies or moves existing images into the library;
   **History** lists everything you've set.
6. **Rotation**: switch on automatic changes, pick how often (15 minutes to daily) and
   from what (whole library, favourites, a tag, a source, or today's Bing / Wikimedia
   picture), shuffled or in order, and which screens. Each screen gets a different image.

### Tray and start on login

Closing the window leaves Wallpaper Fetcher in the tray (Settings can change that), where
its menu has Next, Previous, Add to favourites (per screen), Pause rotation, Open and Quit.
**Settings → Start when I log in** adds an autostart entry (Linux) or a `Run` registry
value (Windows) that starts it hidden in the tray. Opening the app again while it's
running brings the existing window forward.

### Command line and keyboard shortcuts

```sh
wallpaper-fetcher next                     # next wallpaper on every rotation screen
wallpaper-fetcher previous --screen DP-2   # back one, on one screen
wallpaper-fetcher favourite                # favourite what's on the main monitor
wallpaper-fetcher status                   # what's on each screen, and the schedule
wallpaper-fetcher screens                  # screen ids for --screen
wallpaper-fetcher apply wallhaven/wallhaven_abc.jpg --all
wallpaper-fetcher pause | resume | show | quit
```

It talks to the running app over a socket in `$XDG_RUNTIME_DIR` (on Windows, in the app's
data folder), or opens the library itself when the app isn't running. Run from a keyboard
shortcut (no terminal) on Linux, it reports problems and favourites as desktop
notifications. In KDE: System Settings → Keyboard → Shortcuts → Add New → Command or
Script. On Windows: right-click the desktop → New → Shortcut, enter the command, then set
a **Shortcut key** in its Properties (Windows only honours keys on shortcuts on the desktop
or in the Start menu); screen ids there are `DISPLAY1`, `DISPLAY2`…

Where the command comes from:

- **AppImage**: the AppImage itself takes the commands
  (`~/Apps/Wallpaper_Fetcher-0.6.0-x86_64.AppImage next`). For the short name, the
  Rotation tab's **Add wallpaper-fetcher to ~/.local/bin** button links it there.
- **Windows installer**: `wallpaper-fetcher` on PATH if you ticked that box; keyboard
  shortcuts should use the full path the Rotation tab shows
  (`…\Programs\Wallpaper Fetcher\cli\bin\wallpaper_fetcher.exe`).
- **From source**: `dart build cli -t bin/wallpaper_fetcher.dart -o ../../build/cli` in
  `packages/cli`; the executable is `build/cli/bundle/bin/wallpaper_fetcher`.

Images you drop into the library folder yourself are picked up on the next start or with
**Rescan**.

### On Android

- **Library folder**: on first run, use the app's own storage (no permissions, but
  removed if the app is uninstalled) or **Pick a folder…** with Android's folder picker,
  for example `Pictures/Wallpapers`, so the images survive an uninstall and show up in
  other apps. You can switch either way later in Settings, moving the images or not.
- **Browse** starts with portrait wallpapers at least as big as your phone's screen.
- **Set as wallpaper** offers the home screen and lock screen. On a Samsung foldable it
  offers the **main** and **cover** screens and their lock screens separately, so each can
  have its own image.
- **Choosing the crop**: when an image is a different shape from a screen, you drag a
  frame for each screen to pick what it shows. The choice is remembered for that image,
  including when rotation picks it (**Adjust the crop…** on its page changes it).
- **Rotation** runs in the background, even with the app closed. Android decides the
  exact moment, so changes can come a few minutes early or late, and 15 minutes is the
  shortest interval.
- **Import a folder** copies images from a folder you pick; the originals are left alone.

### Where things are stored (Linux)

| What | Where |
|---|---|
| Wallpapers | Your library folder: `<source>/<source>_<id>.<ext>`, plus a `.json` with credits |
| Database, logs | `~/.local/share/dev.mcoombes.wallpaperfetcher/` |
| Thumbnails | `~/.cache/dev.mcoombes.wallpaperfetcher/thumbnails/` |

### Where things are stored (Windows)

| What | Where |
|---|---|
| Wallpapers | Your library folder (default `Pictures\Wallpapers`), same layout as on Linux |
| Database, logs, command socket | `%APPDATA%\dev.mcoombes\Wallpaper Fetcher\` |
| Thumbnails | `%LOCALAPPDATA%\dev.mcoombes\Wallpaper Fetcher\` (cache) |

### Where things are stored (Android)

| What | Where |
|---|---|
| Wallpapers | `Android/data/dev.mcoombes.wallpaperfetcher/files/Wallpapers`, or the folder you picked |
| Database, logs | The app's private storage (cleared with the app's data) |
| Thumbnails | The app's cache |

The database can be deleted safely: a rescan rebuilds it from the folder and the `.json`
files, including favourites, tags, hidden flags and chosen crops (only apply history is
lost).

## Sources and API keys

| Source | Key needed | Notes |
|---|---|---|
| Wallhaven | No | Safe-for-work only; General category by default. 45 requests/min limit, kept under. |
| Unsplash | Yes, free | Create an app at [unsplash.com/oauth/applications](https://unsplash.com/oauth/applications) and add its **Access Key** in Settings. New keys allow 50 requests/hour. Downloads are reported to Unsplash and photographers credited, as their terms require. |
| Bing | No | Image of the day, last 15 days, in your locale's market. Copyrighted: personal use only. |
| Wikimedia | No | Commons' Picture of the Day. Freely licensed; credits and licence are kept with each image. |

Keys are stored in the system keyring (Secret Service on Linux), never in a file; the
keyring is only opened once a key has been saved. On Android they're kept encrypted with
a key from the Android Keystore, and on Windows encrypted with your Windows account (DPAPI).

Not included: **Pexels** (its API guidelines forbid wallpaper apps) and **NASA APOD**
(its API returns a placeholder for every date as of November 2026).

## Desktop support notes

- **KDE Plasma 6**: wallpapers are set per monitor through Plasma's scripting API over
  D-Bus; the lock screen through `kscreenlockerrc` (`kwriteconfig6`). Monitor names and
  real resolutions come from `kscreen-doctor`. If a monitor is set to a plain colour,
  setting an image switches it to an image wallpaper.
- **GNOME, Cinnamon, MATE**: `gsettings`; one wallpaper across all monitors (GNOME also
  sets the lock screen). The tray needs GNOME's AppIndicator extension.
- **Xfce**: `xfconf-query`, per monitor, every workspace.
- **Sway**: `swaymsg output … bg`, per output; lasts until Sway reloads its config.
- **Hyprland**: `swww`/`awww` if its daemon is running, otherwise `hyprpaper` via `hyprctl`.
- **Other X11 window managers**: `feh`, if installed (other monitors keep their images
  from `~/.fehbg`).

### Windows notes

- **Per monitor** through Windows' own wallpaper service (`IDesktopWallpaper`); monitors
  are named by position and display (`Left monitor (DISPLAY1)`). If that service isn't
  available the app falls back to the classic single wallpaper for all monitors and says so
  in Settings.
- **One fit for all monitors**: Windows has a single fit setting, so the last one you pick
  applies to every monitor. **Span** stretches one image across all of them (rotation then
  picks one image for everything).
- **Lock screen** uses Windows' `LockScreen` API, called through Windows PowerShell (so a
  PowerShell window may flash briefly). Organisation policy can block it, and it replaces
  Windows Spotlight on the lock screen.
- **Notifications** need the installer: Windows only shows them for an app with a Start
  menu entry. Run from a plain build, problems from tray actions go to the log only.
- The command line needs Windows 10 version 1803 or later (Unix sockets).

### Android notes

- Only **Fill** is available: Android crops wallpapers to the screen, so the app crops
  around the point you chose (or the middle).
- **Samsung foldables** (Fold and Flip): the main and cover screens each get their own
  wallpaper through One UI's display flags. These are undocumented: they work on One UI 9
  / Android 17, but a future One UI could change them.
- **Other foldables** (Pixel Fold and the like): Android has no public way to set the two
  screens separately, so the app sets one wallpaper cropped for the screen that was in
  use when it started; the other screen shows Android's own crop of it.
- A picked folder can't be the root of the phone's storage or of `Download` (Android's
  rule); pick or create a folder inside them.

## Development

Requirements: Flutter 3.50+ (Dart 3.14), and on Linux `clang cmake ninja pkgconf gtk3`
(plus `libsecret`).
For Android: the Android SDK (platform 36+) and a JDK 17+, set with `flutter config
--android-sdk` and `--jdk-dir`.

Windows builds need a Windows machine (Visual Studio with "Desktop development with C++"):
`flutter run -d windows` / `flutter build windows` in `packages/app`.

### CI and releases

`.github/workflows/build.yml` runs on every push to `main` or a `phase-*` branch:

- **linux** (Ubuntu 22.04): all tests, the release build, the AppImage
  (`packaging/linux/build-appimage.sh`), then starts the AppImage headless and drives it
  with its own command line.
- **android**: the release APK, signed with the release key from the repository secrets.
- **windows**: all tests, `packages/core/tool/windows_smoke.dart` against the real Windows
  calls, the installer (`packaging/windows/wallpaper-fetcher.iss`, Inno Setup), then
  installs it silently, starts the app, drives it from the command line, sends a toast, and
  uninstalls, checking everything is cleaned up.

The files are kept as workflow artifacts for two weeks. To publish a release, bump
`version:` in `packages/app/pubspec.yaml` (and `packages/core`, `packages/cli`), push to
`main`, then tag it: `git tag v0.7.0 && git push origin v0.7.0`. The workflow checks the tag
matches the version and creates the GitHub release with all three files.

**Android release key**: `~/Android/wallpaper-fetcher-release.jks`, with its passwords in
`~/Android/wallpaper-fetcher-release.properties` (`packages/app/android/key.properties`
links to it for local release builds; git ignores it). CI gets the same key from the
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and
`ANDROID_KEY_PASSWORD` secrets. **Keep a backup of both files**: without the key, new
versions can't be installed over old ones. Without a key (e.g. a fresh clone), release
builds fall back to the debug key, except in CI, where that's an error.

```sh
cd packages/app
flutter run -d linux          # run the app
flutter run -d <phone>        # on Android (see `flutter devices`)
flutter build apk --release   # signed with the release key if key.properties is there
flutter test                  # widget tests

cd ../core
dart test                     # core tests (no Flutter needed)
dart run build_runner build   # after changing the database tables
```

Layout: `packages/core` is plain Dart (sources, library, rotation, wallpaper setters,
command socket) shared by the Flutter app in `packages/app` and the command line in
`packages/cli` (`dart test` there too). Android's platform code (setting wallpapers,
picked folders, background rotation) is Kotlin in
`packages/app/android/app/src/main/kotlin/dev/mcoombes/wallpaperfetcher/`.
