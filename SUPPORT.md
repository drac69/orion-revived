# Support Policy

This fork is maintained from the archived upstream Orion source. Support is
focused on keeping current source builds usable and making remaining platform or
Twitch API gaps explicit.

## Supported scope

Supported reports should use the current `modernize-maintenance` branch or the
latest GitHub Release from this fork.

Official maintained releases are source-only. CI-built desktop binaries are
validation evidence, not signed or notarized release artifacts.

Currently maintained:

* Linux and FreeBSD source builds using Qt 5.15 and the mpv backend.
* macOS source builds validated by GitHub Actions with Homebrew `qt@5` and
  `mpv`.
* Windows source builds validated by GitHub Actions with MSYS2 UCRT64, Qt 5,
  and mpv.
* Source-level Android metadata and manifest checks documented in
  `docs/android.md`.

Not currently published or supported as release channels:

* Signed Windows installers.
* Signed or notarized macOS packages.
* Play Store packages, F-Droid packages, or APK releases.
* Legacy upstream binary packages unless a report is also reproduced on this
  maintained fork.

## Filing issues

Use the structured issue forms and include the tested version or commit,
platform, build source, player backend, and relevant `orion --debug` output.

For Twitch API behavior, include links to current official Twitch
documentation. Unsupported native HLS playlist-token behavior, VOD replay chat,
and rewards-credit behavior may need a product fallback to twitch.tv instead of
a native implementation.

For Android, include the target device or emulator, Android version, ABI, screen
density, Qt/SDK/NDK/toolchain versions, and validation results for playback,
chat, emotes, lifecycle/backgrounding, and audio-focus behavior.

Do not paste OAuth tokens, client secrets, cookies, passwords, signing keys, or
keystore passwords into public issues, pull requests, logs, or screenshots.
