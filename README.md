# Wallpaper Fetcher

Fetches wallpapers from online sources, keeps them in a local library folder, and sets
them as your desktop or lock-screen wallpaper in a couple of clicks — a different image on
each monitor if you like.

Targets Linux, Windows and Android. See [`PROJECT_BRIEF.md`](PROJECT_BRIEF.md) for the full
plan and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how it's put together.

## Status

**Phase 3 — done.** (Phases 1 and 2 before it.)

| | KDE Plasma | Other Linux desktops | Windows | Android |
|---|---|---|---|---|
| Browse & download (Wallhaven, Unsplash, Bing, Wikimedia) | ✅ | ✅ | Phase 5 | Phase 4 |
| Library: favourites, tags, filters, search, folder import | ✅ | ✅ | Phase 5 | Phase 4 |
| Set wallpaper per monitor, Previous/Next history | ✅ | ✅ untested* | Phase 5 | Phase 4 |
| Set lock screen | ✅ | GNOME, untested* | Phase 5 | Phase 4 |
| Rotation, tray icon, start on login, command line | ✅ | ✅ untested* | Phase 5 | Phase 4 |

\* Built from each desktop tool's documentation and covered by tests against sample
output, but not yet run on a real GNOME, Cinnamon, MATE, Xfce, Sway, Hyprland or feh setup.

Coming next (Phase 4): Android, then Windows in Phase 5.

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
**Settings → Start when I log in** adds an autostart entry that starts it hidden in the
tray. Opening the app again while it's running brings the existing window forward.

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

It talks to the running app over a socket in `$XDG_RUNTIME_DIR`, or opens the library
itself when the app isn't running. Run from a keyboard shortcut (no terminal), it reports
problems and favourites as desktop notifications. In KDE: System Settings → Keyboard →
Shortcuts → Add New → Command or Script.

Build it with `dart build cli -t bin/wallpaper_fetcher.dart -o ../../build/cli` in
`packages/cli`; the executable is `build/cli/bundle/bin/wallpaper_fetcher` (packaged as
`wallpaper-fetcher` in Phase 6).

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
- **GNOME, Cinnamon, MATE**: `gsettings`; one wallpaper across all monitors (GNOME also
  sets the lock screen). The tray needs GNOME's AppIndicator extension.
- **Xfce**: `xfconf-query`, per monitor, every workspace.
- **Sway**: `swaymsg output … bg`, per output; lasts until Sway reloads its config.
- **Hyprland**: `swww`/`awww` if its daemon is running, otherwise `hyprpaper` via `hyprctl`.
- **Other X11 window managers**: `feh`, if installed (other monitors keep their images
  from `~/.fehbg`).

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

Layout: `packages/core` is plain Dart (sources, library, rotation, wallpaper setters,
command socket) shared by the Flutter app in `packages/app` and the command line in
`packages/cli` (`dart test` there too).
