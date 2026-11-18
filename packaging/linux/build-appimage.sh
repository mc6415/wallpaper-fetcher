#!/usr/bin/env bash
# Packs the Linux release build and the command line into one AppImage.
#
#   packaging/linux/build-appimage.sh VERSION [APPIMAGETOOL]
#
# With APPIMAGETOOL set to "none" it only assembles build/AppDir (whose
# AppRun can be run as is, for testing).
#
# Expects `flutter build linux --release` in packages/app and
# `dart build cli -t bin/wallpaper_fetcher.dart -o ../../build/cli` in
# packages/cli to have run. Writes build/dist/Wallpaper_Fetcher-VERSION-x86_64.AppImage.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
version="${1:?usage: build-appimage.sh VERSION [APPIMAGETOOL]}"
tool="${2:-appimagetool}"
here="$root/packaging/linux"
app_bundle="$root/packages/app/build/linux/x64/release/bundle"
cli_bundle="$root/build/cli/bundle"
appdir="$root/build/AppDir"
out="$root/build/dist/Wallpaper_Fetcher-$version-x86_64.AppImage"

[ -x "$app_bundle/wallpaper_fetcher" ] || { echo "No app build at $app_bundle" >&2; exit 1; }
[ -x "$cli_bundle/bin/wallpaper_fetcher" ] || { echo "No command-line build at $cli_bundle" >&2; exit 1; }

rm -rf "$appdir"
mkdir -p "$appdir/usr/lib" "$appdir/usr/share/applications" "$appdir/usr/share/icons/hicolor/256x256/apps" "$(dirname "$out")"
cp -a "$app_bundle" "$appdir/usr/lib/wallpaper-fetcher"
cp -a "$cli_bundle" "$appdir/usr/lib/wallpaper-fetcher-cli"
install -m 755 "$here/AppRun" "$appdir/AppRun"
install -m 644 "$here/dev.mcoombes.wallpaperfetcher.desktop" "$appdir/"
install -m 644 "$here/dev.mcoombes.wallpaperfetcher.desktop" "$appdir/usr/share/applications/"
install -m 644 "$root/packages/app/assets/app_icon.png" "$appdir/dev.mcoombes.wallpaperfetcher.png"
install -m 644 "$root/packages/app/assets/app_icon.png" "$appdir/usr/share/icons/hicolor/256x256/apps/dev.mcoombes.wallpaperfetcher.png"
ln -s dev.mcoombes.wallpaperfetcher.png "$appdir/.DirIcon"

if [ "$tool" = none ]; then
  echo "$appdir"
  exit 0
fi

rm -f "$out"
# Extract-and-run: no FUSE needed (CI containers, some distros).
ARCH=x86_64 VERSION="$version" APPIMAGE_EXTRACT_AND_RUN=1 "$tool" --no-appstream "$appdir" "$out"
echo "$out"
