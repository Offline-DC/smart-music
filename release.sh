#!/usr/bin/env bash
#
# Publish a Spotify APK as a public GitHub Release on Offline-DC/smart-music.
#
# The APK itself is never committed — it lives only as a release asset. The
# launcher's quack diagnostics "install spotify" row downloads it from
#
#   https://github.com/Offline-DC/smart-music/releases/latest/download/spotify.apk
#
# so every release MUST carry an asset named exactly `spotify.apk` and be marked
# "latest". This script guarantees both.
#
# Usage:
#   ./release.sh                     # pull com.spotify.music off the plugged-in phone, release it
#   ./release.sh path/to/base.apk    # release an APK you already have
#
# Options (env):
#   ADB_SERIAL=<serial>   which phone to pull from when more than one is plugged in
#   DRAFT=1               create the release as a draft (nothing changes for phones)
#
# Needs: gh (logged in, with push access), and adb when pulling from a phone.
set -euo pipefail

REPO="Offline-DC/smart-music"
PKG="com.spotify.music"
ASSET_NAME="spotify.apk"   # the launcher depends on this exact name

die() { echo "error: $*" >&2; exit 1; }
command -v gh >/dev/null || die "gh not installed (brew install gh)"
gh auth status >/dev/null 2>&1 || die "gh not logged in (gh auth login)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
apk="$work/$ASSET_NAME"
version=""

adb_() { if [[ -n "${ADB_SERIAL:-}" ]]; then adb -s "$ADB_SERIAL" "$@"; else adb "$@"; fi; }

if [[ $# -ge 1 ]]; then
  [[ -f "$1" ]] || die "no such file: $1"
  cp "$1" "$apk"
else
  command -v adb >/dev/null || die "adb not installed — or pass an APK path"
  paths="$(adb_ shell pm path "$PKG" | tr -d '\r' | sed 's/^package://')"
  [[ -n "$paths" ]] || die "$PKG is not installed on the connected phone"
  # The launcher installs a single APK with `pm install`, so a split install
  # (base + split_config.*.apk) can't be released this way.
  [[ "$(echo "$paths" | wc -l | tr -d ' ')" == "1" ]] \
    || die "Spotify on this phone is a split APK ($(echo "$paths" | wc -l | tr -d ' ') files); this flow only supports a single base.apk"
  echo "pulling $paths"
  adb_ pull "$paths" "$apk" >/dev/null
  version="$(adb_ shell dumpsys package "$PKG" | tr -d '\r' | sed -n 's/^ *versionName=//p' | head -1)"
fi

# Read the version from the APK when we didn't get it from the phone.
if [[ -z "$version" ]]; then
  aapt="$(command -v aapt || ls -1 "${ANDROID_HOME:-$HOME/Library/Android/sdk}"/build-tools/*/aapt 2>/dev/null | tail -1 || true)"
  if [[ -n "$aapt" ]]; then
    badging="$("$aapt" dump badging "$apk" 2>/dev/null | head -1)"
    [[ "$badging" == *"name='$PKG'"* ]] || die "that APK isn't $PKG"
    version="$(sed -n "s/.*versionName='\([^']*\)'.*/\1/p" <<<"$badging")"
  fi
fi
[[ -n "$version" ]] || version="$(date +%Y%m%d)"

tag="spotify-v$version"
sha="$(shasum -a 256 "$apk" | cut -d' ' -f1)"
size="$(du -h "$apk" | cut -f1)"

gh release view "$tag" --repo "$REPO" >/dev/null 2>&1 \
  && die "release $tag already exists — delete it first (gh release delete $tag --repo $REPO --cleanup-tag)"

notes="Spotify $version ($PKG) for Dumb.Co phones.

Phones install this from quack diagnostics → \"install spotify\".

- size: $size
- sha256: \`$sha\`"

echo "creating release $tag ($size)…"
gh release create "$tag" "$apk" \
  --repo "$REPO" \
  --title "Spotify $version" \
  --notes "$notes" \
  --latest \
  ${DRAFT:+--draft}

echo
echo "done: https://github.com/$REPO/releases/tag/$tag"
echo "phones download: https://github.com/$REPO/releases/latest/download/$ASSET_NAME"
