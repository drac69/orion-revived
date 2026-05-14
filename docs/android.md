# Android status

This fork keeps the legacy Qt 5 Android package sources in the tree, but Android release builds are not currently validated by CI and no Play Store or F-Droid package is published from this fork.

Current source-level maintenance:

* The Android manifest version now follows the fork version (`1.6.8`).
* The app no longer requests `WAKE_LOCK`; playback screen inhibition uses Android's `FLAG_KEEP_SCREEN_ON` window flag while the Activity exists, and the native bridge methods use screen-on names instead of legacy WakeLock terminology.
* Android background running is disabled in the Qt manifest metadata so playback is suspended when Android backgrounds the Activity, such as during calls or app switching.
* Android now uses the same screen-density detection as desktop builds before the chat/emote providers are initialized, so high-density devices request 2x Twitch, BTTV, FFZ, Bits, and badge images instead of the low-resolution 1x assets.
* Mobile player surface taps now only reveal playback controls instead of toggling pause, avoiding accidental pauses from touch misses while keeping the explicit play/pause button available.
* Optional Android OpenSSL libraries are only added to the package when `libs/libcrypto.so` and `libs/libssl.so` are actually present.
* The legacy Android preparation helper no longer downloads prebuilt OpenSSL shared libraries. If a maintainer intentionally uses that helper, source-built libraries can be staged by setting `ORION_ANDROID_OPENSSL_LIBS_DIR` to a directory containing `libcrypto.so` and `libssl.so`.
* CI validates the Android manifest version, package name, lifecycle metadata, required network permissions, absence of `WAKE_LOCK`, `FLAG_KEEP_SCREEN_ON` source path, screen-on bridge names, the mobile tap-to-control playback contract, and the QML Back-key navigation contract.

Release requirements still missing:

* A maintained Qt Android toolchain configuration, including Gradle/NDK versions.
* Target-device validation for playback pause/resume, phone-call audio focus, chat stability, emote resolution, and lifecycle behavior.
* F-Droid metadata plus a reproducible build recipe that builds any required Android OpenSSL libraries from source.

Until those items are covered, treat the Android directory as source maintenance rather than a supported release channel.
