# smart-music

Public release host for the Spotify APK that Dumb.Co phones install from the
launcher (All Apps → long-press **quack** → diagnostics → **install spotify**).

The APK is not committed here. It's published as a GitHub Release asset, and
the launcher always fetches:

```
https://github.com/Offline-DC/smart-music/releases/latest/download/spotify.apk
```

## Releasing

Plug in a phone that has the Spotify build you want, then:

```bash
./release.sh
```

It pulls `com.spotify.music` off the phone, tags the release `spotify-v<versionName>`,
uploads it as `spotify.apk` and marks it latest. Phones get it the next time
someone presses "install spotify".

Already have the APK?

```bash
./release.sh ~/repos/spotify-apk/base.apk
```

`ADB_SERIAL=<serial>` picks a phone when several are plugged in; `DRAFT=1`
creates a draft release that phones won't see until you publish it.

Requirements: `gh` (logged in with push access to this repo) and `adb`.

Only single-APK installs are supported. The launcher installs with a plain
`pm install`, so a split install (`base.apk` + `split_config.*.apk`) is rejected.
