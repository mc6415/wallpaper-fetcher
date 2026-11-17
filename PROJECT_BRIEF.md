# Project: Wallpaper Fetcher

## Goal
Build a cross-platform app that fetches wallpapers from online sources, saves them into a
user-chosen folder, applies them as the desktop (and where possible lock-screen) wallpaper,
and maintains a browsable local library so I can switch wallpaper in one or two clicks
instead of digging through system settings menus.

## Targets and environment
- Targets: Windows 10/11, Linux, Android 8.0+ (API 26+). Structure the code so macOS/iOS
  could be added later, but don't build them now.
- My dev machine: CachyOS (Arch-based), KDE Plasma on Wayland. Linux/KDE is the first
  platform to get fully working and where I test day to day.
- Desktop displays: two 3840x2160 monitors side by side (KDE scale 150%).
- Windows builds happen on a Windows machine or GitHub Actions (no cross-compiling from Linux).
- Android test device: Samsung Galaxy Fold (SM-F976B), Android 17 / API 37. Two screens:
  cover 1080x2520 (tall, narrow) and inner 2256x2504 (near-square). The AYN Thor is not a
  target. Emulator `Pixel_9_API_36` is available as a fallback.

## Decisions from Phase 0 (details in `docs/ARCHITECTURE.md`)
- Name: Wallpaper Fetcher. App ID: `dev.mcoombes.wallpaperfetcher`.
- Desktop: a different image per monitor by default; default minimum resolution 3840x2160.
- Fold: a separate image per screen if possible, otherwise one image cropped per screen.
- Desktop rotation runs from the tray icon.
- Build in from the start: CLI controls (`wallpaper-fetcher next` etc. for KDE shortcuts) and
  the system accent colour.

## Tech stack
- Flutter (Dart), one codebase for all targets.
- State management: Riverpod.
- Database: SQLite via drift (must work on Windows, Linux and Android).
- HTTP with retry and backoff.
- API keys stored with flutter_secure_storage.
- Wallpaper-setting code is ours, not a third-party plugin: Dart FFI/win32 on Windows,
  process/D-Bus calls on Linux, a small Kotlin method channel on Android.
- Before adding any other significant dependency, tell me what it's for and confirm it's
  actively maintained.

## Features (v1)

### 1. Browse and fetch
- Browse screen with a tab per enabled source; keyword search where supported; filters for
  orientation, minimum resolution and colour where supported.
- Default minimum resolution = current screen size on desktop, portrait phone size on Android.
- Thumbnail grid with infinite scroll; tap for a preview showing resolution, author, source
  and licence.
- Download saves the full-resolution file to the library with progress shown; allow several
  downloads at once with a sensible concurrency limit.
- Skip duplicates (same source + source ID, or same file hash).

### 2. Library
- User picks the library folder on first run (sensible default offered) and can change it
  later in Settings, with an option to move existing files.
- Files saved as `<library>/<source>/<source>_<sourceId>.<ext>`, plus a small JSON sidecar
  per image holding its attribution metadata so the library is portable.
- Library screen: thumbnail grid; sort by date added, last used, most used, resolution;
  filter by source, orientation, favourites, tags; search on title/tags/author.
- Favourites, custom tags, and "hide from rotation".
- Import an existing folder of images (source = "local").
- On startup, rescan the folder to pick up files added or deleted outside the app.
- Thumbnails cached in the app cache directory, not the library folder.

### 3. Apply
- One-click "Set as wallpaper" from the Browse preview, the Library grid and the detail view.
- Targets: desktop, lock screen, or both, where the platform supports it.
- Fit mode (fill, fit, stretch, centre, span) where supported.
- Multi-monitor on desktop: same image on all screens or one per screen where supported,
  falling back gracefully.
- History of applied wallpapers with Previous/Next.

### 4. Rotation
- Optional automatic switching on an interval (15 min, 1 h, daily, custom), drawing from:
  whole library, favourites, a tag, or a source. Random or sequential; avoid recent repeats.
- Optional "daily" mode: fetch and apply today's Bing or NASA APOD image.
- Desktop: system tray icon with Next, Previous, Favourite current, Pause rotation,
  Open app, Quit. Optional start on login.
- Android: WorkManager (minimum 15 min interval).

### 5. Settings
Library folder, enabled sources, per-source API keys, default filters, rotation, start on
login, light/dark/system theme.

## Wallpaper sources
Implement each behind a common `WallpaperSource` interface (paged list/search, details,
download URL, attribution, capability flags like supportsSearch/supportsOrientation/isDaily)
so adding a source means adding one class.

1. Wallhaven (primary): API v1 at `https://wallhaven.cc/api/v1/search`. No key needed for
   SFW. Limit 45 requests/min. Supports keyword, categories, `atleast` (min resolution),
   ratios, and sorting (toplist, random, date_added, views, favorites). SFW only
   (`purity=100`) in v1.
2. Unsplash: free Access Key required (demo tier 50 requests/hour). Follow their API
   guidelines: credit the photographer and Unsplash, and call the photo's
   `links.download_location` endpoint whenever a photo is downloaded.
3. Pexels: free API key (200 requests/hour, 20,000/month). Credit photographer and Pexels.
4. Bing image of the day: unofficial endpoint
   `https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=8&mkt=en-US` (last 8 days).
   Use the UHD variant (`urlbase` + `_UHD.jpg`). Store and show the copyright text.
5. NASA APOD: `https://api.nasa.gov/planetary/apod`, user-supplied key with `DEMO_KEY`
   fallback. Skip entries where `media_type` isn't `image`; prefer `hdurl`.
6. Local folder import (see Library).

For every source: client-side throttling plus backoff on HTTP 429, short-lived caching of
list responses, and attribution metadata saved with every download. API keys are entered by
me in Settings and kept in secure storage. Never hardcode or commit keys.

## Setting the wallpaper, per platform
Put this behind a `WallpaperSetter` interface (`setDesktop(path, monitor?, fit)`,
`setLockScreen(path)`, `capabilities()`). Unsupported features return a clear error and are
hidden or greyed out in the UI; nothing fails silently.

Windows
- Use the `IDesktopWallpaper` COM interface (per-monitor + fit position); fall back to
  `SystemParametersInfoW(SPI_SETDESKWALLPAPER, ..., SPIF_UPDATEINIFILE | SPIF_SENDCHANGE)`.
- Lock screen: investigate; implement only if it works for an unpackaged desktop app,
  otherwise mark unsupported.
- Start on login via the HKCU `Run` registry key.

Linux (no single API, so detect the environment)
- Detect via `XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE` and compositor env vars
  (`HYPRLAND_INSTANCE_SIGNATURE`, `SWAYSOCK`).
- KDE Plasma first (my setup): `plasma-apply-wallpaperimage <path>`; per-monitor via the
  `org.kde.PlasmaShell` D-Bus `evaluateScript` method; lock screen via `kwriteconfig6` on
  `kscreenlockerrc` (Greeter > Wallpaper > org.kde.image > General > Image).
- Then GNOME (`gsettings` `org.gnome.desktop.background` `picture-uri` and
  `picture-uri-dark`, plus `picture-options`), Cinnamon, MATE, XFCE (`xfconf-query`),
  Sway (`swaymsg output * bg`), Hyprland (hyprpaper or swww), and `feh` for plain X11 WMs.
- Some desktops won't refresh if the new path equals the current one; handle it.
- Tray uses StatusNotifierItem: native on KDE, needs the AppIndicator extension on GNOME.
  Detect and degrade gracefully.
- Start on login via a `.desktop` file in `~/.config/autostart`.

Android
- `WallpaperManager` with `FLAG_SYSTEM` / `FLAG_LOCK` through a Kotlin method channel;
  declare the `SET_WALLPAPER` permission.
- Library defaults to app-specific storage; a custom folder uses the Storage Access
  Framework (`ACTION_OPEN_DOCUMENT_TREE`) with a persisted URI permission. No broad
  storage permissions.
- Default Browse filters to portrait; let me pick the crop/focus area before applying a
  landscape image.

## Data model (SQLite, stored in the app data directory, not the library folder)
- `wallpapers`: id, source, source_id, source_page_url, download_url, file_path, width,
  height, orientation, file_size, sha256, title, author_name, author_url, licence, tags,
  dominant_colour, added_at, last_applied_at, apply_count, is_favourite, is_hidden.
- `apply_history`: id, wallpaper_id, applied_at, target (desktop / lock / monitor id).
- Settings in a key-value table or equivalent.
- If the database is lost, a rescan plus the JSON sidecars must rebuild the library.

## Quality bar
- UI never blocks on network or disk; every screen has loading, empty and error states.
- Library works fully offline.
- Friendly, specific errors (e.g. "Unsplash key missing. Add it in Settings").
- Rotating log file in the app data directory.
- Unit tests: each source's response parsing (using saved sample JSON), duplicate detection,
  library rescan, Linux desktop detection. Widget tests for the main screens.
- README covering setup, getting each API key, building per platform, and known
  limitations per desktop environment.

## Out of scope for v1
NSFW content, animated/video/live wallpapers, accounts or cloud sync, macOS and iOS,
web builds (web support is disabled in the Flutter config).

## How to work
Work in phases and stop for my review after each one; don't start the next until I confirm.
Commit at the end of each phase with a clear message and keep the README current.

- Phase 0 (plan only): ask me clarifying questions, then propose the folder structure, key
  packages, and the `WallpaperSource` / `WallpaperSetter` interfaces. No code until I approve.
- Phase 1 (Linux MVP): git init, scaffold, Wallhaven source, download to library, Library
  screen, apply on KDE Plasma.
- Phase 2: Unsplash, Pexels, Bing, NASA APOD; favourites, tags, filters; history; local import.
- Phase 3: rotation, system tray, start on login; other Linux desktops.
- Phase 4: Windows.
- Phase 5: Android.
- Phase 6: packaging and CI: GitHub Actions producing a Linux AppImage or Flatpak, a Windows
  installer (MSIX or Inno Setup), and an Android APK.
