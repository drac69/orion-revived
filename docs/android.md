# Android status

This fork keeps the legacy Qt 5 Android package sources in the tree for
source-level maintenance only. Android, APK, Play Store, and F-Droid publishing
are retired release channels for this fork because no maintained Qt Android
toolchain, reproducible build recipe, or target-device validation is available.
The release-channel decision is recorded in
[issue #2](https://github.com/belagrf/orion-revived/issues/2).

Current source-level maintenance:

* The Android manifest version now follows the fork version (`1.6.9`).
* The app no longer requests `WAKE_LOCK`; playback screen inhibition uses
  Android's `FLAG_KEEP_SCREEN_ON` window flag while the Activity exists, and the
  native bridge methods use screen-on names instead of legacy WakeLock
  terminology.
* Android background running is disabled in the Qt manifest metadata so playback
  is suspended when Android backgrounds the Activity, such as during calls or app
  switching.
* Android now uses the same screen-density detection as desktop builds before the
  chat/emote providers are initialized, so high-density devices request 2x
  Twitch, BTTV, FFZ, Bits, and badge images instead of the low-resolution 1x
  assets.
* Mobile player surface taps now only reveal playback controls instead of
  toggling pause, avoiding accidental pauses from touch misses while keeping the
  explicit play/pause button available.
* Optional Android OpenSSL libraries are only added to the package when
  `libs/libcrypto.so` and `libs/libssl.so` are actually present.
* The legacy Android preparation helper no longer downloads prebuilt OpenSSL
  shared libraries. If a maintainer intentionally uses that helper, source-built
  libraries can be staged by setting `ORION_ANDROID_OPENSSL_LIBS_DIR` to a
  directory containing `libcrypto.so` and `libssl.so`.
* A disabled F-Droid metadata scaffold is present at
  `metadata/app.orion.android.yml`, pinned to the current release tag and marked
  disabled because the Android/F-Droid release channel is retired and Qt Android
  builds are not reproducibly validated.
* CI validates the Android manifest version, package name, lifecycle metadata,
  required network permissions, absence of `WAKE_LOCK`, `FLAG_KEEP_SCREEN_ON`
  source path, screen-on bridge names, the mobile tap-to-control playback
  contract, and the QML Back-key navigation contract.
* CI validates that the F-Droid metadata points at this maintained fork, matches
  the Android manifest version, remains disabled, and records the retired
  Android/F-Droid release channel decision.

Future restoration requirements:

* A maintained Qt Android toolchain configuration, including Qt, SDK, NDK, JDK,
  Gradle, and Android build-tools versions.
* A reproducible build recipe that builds any required Android OpenSSL libraries
  from source and can replace the disabled F-Droid metadata placeholder.
* Target-device or emulator validation for install/update behavior, login state,
  stream browsing, live and VOD playback/fallback behavior, playback
  pause/resume, phone-call audio focus, chat stability, emote resolution,
  settings persistence, lifecycle/backgrounding, and failure handling.

Until a future maintainer supplies that evidence, treat the Android directory as
source maintenance rather than a supported release channel.
