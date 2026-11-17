# Wallpaper Fetcher

Fetches wallpapers from online sources, keeps them in a local library folder, and sets
them as your desktop or lock-screen wallpaper in a couple of clicks — a different image on
each monitor if you like.

Targets Linux, Windows and Android. See [`PROJECT_BRIEF.md`](PROJECT_BRIEF.md) for the full
plan and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how it's put together.

## Status

**Phase 1 (Linux MVP) — done.**

| | Linux (KDE Plasma) | Other Linux desktops | Windows | Android |
|---|---|---|---|---|
| Browse & download (Wallhaven) | ✅ | ✅ | Phase 4 | Phase 5 |
| Library | ✅ | ✅ | Phase 4 | Phase 5 |
| Set wallpaper per monitor | ✅ | Phase 3 | Phase 4 | Phase 5 |
| Set lock screen | ✅ | Phase 3 | Phase 4 | Phase 5 |

Coming next (Phase 2): Unsplash, Pexels, Bing and NASA APOD; favourites, tags and filters;
history; importing an existing folder.

## Using it

1. On first run, pick a library folder (default `~/Pictures/Wallpapers`). Anything already
   in it is added to the library.
2. **Browse** Wallhaven: search, sort, and filter by shape and minimum size (defaults to
   your largest screen). Click the download button on a thumbnail, or open it for details.
3. **Library**: click the wallpaper button on any image (or right-click it) and choose a
   monitor, all monitors, the lock screen, or everywhere.

Images you drop into the library folder yourself are picked up on the next start or with
**Rescan**.

### Where things are stored (Linux)

| What | Where |
|---|---|
| Wallpapers | Your library folder: `<source>/<source>_<id>.<ext>`, plus a `.json` with credits |
| Database, logs | `~/.local/share/dev.mcoombes.wallpaperfetcher/` |
| Thumbnails | `~/.cache/dev.mcoombes.wallpaperfetcher/thumbnails/` |

The database can be deleted safely: a rescan rebuilds it from the folder and the `.json`
files (only apply history is lost).

## Sources and API keys

| Source | Key needed | Notes |
|---|---|---|
| Wallhaven | No | Safe-for-work images only. Rate limit 45 requests/min; the app stays under it. |

Unsplash, Pexels and NASA APOD (Phase 2) will need free keys, entered in Settings and
stored in your system keyring.

## Desktop support notes

- **KDE Plasma 6**: wallpapers are set per monitor through Plasma's scripting API over
  D-Bus; the lock screen through `kscreenlockerrc` (`kwriteconfig6`). Monitor names and
  real resolutions come from `kscreen-doctor`. If a monitor is set to a plain colour,
  setting an image switches it to an image wallpaper.
- **Other desktops**: detected, but setting wallpapers isn't implemented yet (Phase 3).
  Browsing and the library still work.

## Development

Requirements: Flutter 3.50+ (Dart 3.14), and on Linux `clang cmake ninja pkgconf gtk3`.

```sh
cd packages/app
flutter run -d linux          # run the app
flutter test                  # widget tests

cd ../core
dart test                     # core tests (no Flutter needed)
dart run build_runner build   # after changing the database tables
```

Layout: `packages/core` is plain Dart (sources, library, wallpaper setters) shared by the
Flutter app in `packages/app` and the command line coming in Phase 3.
