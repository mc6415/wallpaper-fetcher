# Wallpaper Fetcher

Fetches wallpapers from online sources, keeps them in a local library folder, and sets
them as your desktop or lock-screen wallpaper in a couple of clicks — a different image on
each monitor if you like.

Targets Linux, Windows and Android. See [`PROJECT_BRIEF.md`](PROJECT_BRIEF.md) for the full
plan and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how it's put together.

## Status

**Phase 2 — done.** (Phase 1, the Linux MVP, before it.)

| | Linux (KDE Plasma) | Other Linux desktops | Windows | Android |
|---|---|---|---|---|
| Browse & download (Wallhaven, Unsplash, Bing, Wikimedia) | ✅ | ✅ | Phase 4 | Phase 5 |
| Library: favourites, tags, filters, search, folder import | ✅ | ✅ | Phase 4 | Phase 5 |
| Set wallpaper per monitor, history with Previous/Next | ✅ | Phase 3 | Phase 4 | Phase 5 |
| Set lock screen | ✅ | Phase 3 | Phase 4 | Phase 5 |

Coming next (Phase 3): automatic rotation, a tray icon, start on login, command-line
controls for keyboard shortcuts, and other Linux desktops.

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

Images you drop into the library folder yourself are picked up on the next start or with
**Rescan**.

### Where things are stored (Linux)

| What | Where |
|---|---|
| Wallpapers | Your library folder: `<source>/<source>_<id>.<ext>`, plus a `.json` with credits |
| Database, logs | `~/.local/share/dev.mcoombes.wallpaperfetcher/` |
| Thumbnails | `~/.cache/dev.mcoombes.wallpaperfetcher/thumbnails/` |

The database can be deleted safely: a rescan rebuilds it from the folder and the `.json`
files, including favourites, tags and hidden flags (only apply history is lost).

## Sources and API keys

| Source | Key needed | Notes |
|---|---|---|
| Wallhaven | No | Safe-for-work only; General category by default. 45 requests/min limit, kept under. |
| Unsplash | Yes, free | Create an app at [unsplash.com/oauth/applications](https://unsplash.com/oauth/applications) and add its **Access Key** in Settings. New keys allow 50 requests/hour. Downloads are reported to Unsplash and photographers credited, as their terms require. |
| Bing | No | Image of the day, last 15 days, in your locale's market. Copyrighted: personal use only. |
| Wikimedia | No | Commons' Picture of the Day. Freely licensed; credits and licence are kept with each image. |

Keys are stored in the system keyring (Secret Service on Linux), never in a file; the
keyring is only opened once a key has been saved.

Not included: **Pexels** (its API guidelines forbid wallpaper apps) and **NASA APOD**
(its API returns a placeholder for every date as of November 2026).

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
