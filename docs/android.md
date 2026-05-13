# Android status

This fork keeps the legacy Qt 5 Android package sources in the tree, but Android release builds are not currently validated by CI and no Play Store or F-Droid package is published from this fork.

Current source-level maintenance:

* The Android manifest version now follows the fork version (`1.6.8`).
* The app no longer requests `WAKE_LOCK`; playback screen inhibition uses Android's `FLAG_KEEP_SCREEN_ON` window flag while the Activity exists.
* Android background running is disabled in the Qt manifest metadata so playback is suspended when Android backgrounds the Activity, such as during calls or app switching.
* Android now uses the same screen-density detection as desktop builds before the chat/emote providers are initialized, so high-density devices request 2x Twitch, BTTV, FFZ, Bits, and badge images instead of the low-resolution 1x assets.
* Optional Android OpenSSL libraries are only added to the package when `libs/libcrypto.so` and `libs/libssl.so` are actually present.

Release requirements still missing:

* A maintained Qt Android toolchain configuration, including Gradle/NDK versions.
* Target-device validation for playback pause/resume, phone-call audio focus, chat stability, emote resolution, and lifecycle behavior.
* F-Droid metadata plus a reproducible build recipe that does not depend on unpublished binary libraries.

Until those items are covered, treat the Android directory as source maintenance rather than a supported release channel.
