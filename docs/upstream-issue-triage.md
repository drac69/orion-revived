# Upstream Issue Triage

Audit date: 2026-05-13

Upstream repository: <https://github.com/alamminsalo/orion>

The upstream repository is archived and had 79 open issues at the time this fork was created. This file tracks which issues are covered by this maintenance branch and which ones still need larger product or API work.

## Addressed in this fork

* #302 / #303: merged the unmerged QObject lifetime crash fix from upstream PR #303.
* #18: added an mpv playback-stats overlay with codec, resolution, FPS, bitrate, dropped frame, sync, cache, and hardware-decoder data.
* #26: added Linux MPRIS media-control support for play, pause, stop, seek, volume, and metadata over D-Bus.
* #295: added an optional mpv audio-compressor filter for reducing stream volume swings.
* #306: changed the mpv default hardware decoder from `auto` to `auto-copy` to avoid unsafe native-surface handling in the embedded renderer.
* #305: search result pages now size their initial and follow-up fetches from the visible grid capacity, with a small row buffer instead of a hard-coded 25 items.
* #301: VOD resume positions now compare against the previous saved value before overwriting it, so periodic progress updates are persisted.
* #286: high-DPI startup no longer depends on the deprecated `QT_AUTO_SCREEN_SCALE_FACTOR` path.
* #265: fullscreen playback no longer toggles the main navigation header on top-edge hover, avoiding the repeated resize loop.
* #264: added a setting to enable or disable screensaver inhibition during playback.
* #260: Linux screensaver reset calls now only run while screensaver inhibition is active.
* #89 / #205: multiple-stream use is supported through the persisted multiple-instance setting; second instances are blocked unless that setting is enabled.
* #134: added a Ctrl+Q application shortcut.
* #44: the existing version checker now checks this fork's releases instead of the archived upstream repository.
* #242: QML startup warnings are now printed before the fatal startup error, which exposes missing QML modules directly.
* #274: added a default stream-quality setting with lower-quality fallback when the exact variant is unavailable.
* #282: added `--channel` and positional `twitch.tv` URL startup handling for opening a specific channel from a launcher.
* #273: chat lines mentioning the logged-in username are highlighted.
* #270: added a persisted chat blacklist for hiding messages containing configured terms.
* #263: the emote picker now follows the selected light/dark theme.
* #241: added a highlighted-user list for chat styling of specific chatters.
* #234: BTTV emotes now carry direct source URLs and render through `AnimatedImage`, allowing animated formats to move.
* #141: added FrankerFaceZ global and channel emote loading, rendering, and picker entries.
* #123: added `--libmpv-config` / `--mpv-config` for loading an explicit mpv config file with the mpv backend, and the saved mpv hardware-decoder preference is now applied when the backend loads.
* #254: added an optional per-channel stream quality memory on top of the global default quality preset.
* #178: stopped VOD playback now preserves the last position when replaying/reloading, including the Qt Multimedia stopped-state reset path.
* #199: chat input focus is restored after sending a message.
* #195: chat input text now follows the chat text scaling setting.
* #190: Escape is handled as an application shortcut while the emote picker is open.
* #40: chat text segments are selectable and copyable, and whole messages can still be copied from the row context menu.
* #232: the single-instance lock now uses an app-specific runtime/temp path instead of an opaque fixed temp filename, and startup warnings include the lock path.
* #236: Ubuntu/Linux Mint build instructions include `libmpv-dev` for the `mpv/client.h` header, and the README now points users to `orion --debug` plus the Qt Labs Settings QML package when a build starts without showing a window.
* #45: Windows desktop notifications are wired through the in-app QML notification surface again, with settings for notification corner and target screen so multi-monitor users can choose where alerts appear.
* #292: kept the upstream fix that avoids trying to play an empty stream URL and falls back to `source` quality when the stored quality is unavailable.
* #298 / #304: kept the upstream chat-emote initialization workaround from #294.
* #284: kept the upstream localhost OAuth response fix from #272.

## Partially addressed

* #288 / #300: the OAuth login URL and scopes now use the current Twitch authorization host, the logged-in user response parser handles Helix `Get Users` responses, chat block/unblock plus blocked-user list calls now use Helix, the followed-channel list now uses Helix `Get Followed Channels`, authenticated stream-status checks now use Helix `Get Streams`, authenticated channel search now uses Helix `Search Channels`, authenticated game/category browsing now uses Helix `Get Top Games`, `Search Categories`, `Get Games`, and game/language-filtered `Get Streams`, authenticated VOD listing now uses Helix `Get Videos`, authenticated chat badge metadata now uses Helix `Get Channel Chat Badges` and `Get Global Chat Badges`, authenticated emote-set loading now uses Helix `Get Emote Sets`, and authenticated Bits/Cheermote metadata now uses Helix `Get Cheermotes`. The removed Twitch follow/unfollow mutation endpoints are no longer called; logged-in users are sent to twitch.tv for those actions while unauthenticated local favourites still work. Unauthenticated app-token handling, VOD playback/chat, legacy badge compatibility calls, and any remaining browsing calls still need a full Helix migration.
* #101: added configurable command-line log levels, optional file logging, and optional Linux systemd journal output when built with `libsystemd`; no in-app log viewer was added.
* #108: hidden live chat now sends desktop notifications for incoming whispers and `@username` mentions; a dedicated private-message inbox is still not implemented.
* #187: the existing player selector is limited to backends compiled into the binary, and saved backend settings are now validated against that compiled list at startup; runtime detection of separately installed backend plugins is still not implemented.
* #240: Helix stream and channel language fields are parsed and shown in stream details, and authenticated searches support `/language <code>` using Helix `Get Streams`; no dedicated language picker UI was added.
* #212: bundled Noto Sans and Material Icons fonts are registered with Qt before QML loads to avoid startup fallback rendering of missing text/icons; the original openSUSE/KDE/Qt 5.9 rendering path has not been reproduced in this environment.
* #74: QML context menus now run a one-time main-window position refresh before opening, matching the historical Qt multi-screen workaround; the original multi-monitor bug has not been reproduced in this environment.
* #285: live and VOD playlist requests now use the current HTTPS `usher.ttvnw.net` host, the live `allow_audio_only` query parameter typo is fixed, and empty token-parser results now fail as token errors instead of fetching an empty URL; the old playback-token endpoints still need a deeper replacement.
* #167: fixed a network-recovery condition that always reloaded playback on network-up events, and guarded stream-status polling against stale/no current channel state; hosted-channel IRC behavior still needs live reproduction.
* #271: returning to the VOD view no longer forces the grid back to the beginning, so the current scroll position is preserved while navigating away and back; broader VOD filtering, sorting, playlist, chapter, muted-section, and cache work remains.
* #119: the README now explains that the GitHub build commands are terminal commands, separates build/run/install steps, and documents that revalidated Windows/macOS installers are not published yet.
* #210: new Windows installs now default to ANGLE D3D11 instead of the older D3D9 renderer, and saved D3D9 defaults are migrated to D3D11 to reduce exposure to the Fraps/Qt render-thread crash path; the Fraps-specific crash has not been reproduced in this environment.
* #90: focused QML text fields now request the Qt input method, and Windows tablet/slate systems also launch the OS touch keyboard (`TabTip.exe`/`osk.exe`) when text inputs gain focus; the Windows tablet behavior has not been reproduced in this environment.
* #243: added an opt-in live low-latency playlist request flag (`fast_bread=true`) for live HLS requests; the heavier prefetch segment/proxy approach remains unimplemented.
* #202: Android Back key presses from the player view now return to the last non-player tab instead of leaving the player stuck in place; Android playback pause/resume, call-audio handling, crash reproduction, emote resolution, and Play Store packaging still need target-device validation.
* #268: Twitch `USERNOTICE` raid messages now append a channel URL from the raid `msg-param-login` tag, and chat system notices render URLs as selectable/clickable links; automatic in-client raid redirection is still not implemented.

## Already covered by the final upstream code

These issues remained open upstream but the final `master` code already contains the relevant setting, install rule, shortcut, or behavior:

* #207: setting to disable click-video-to-pause.
* #223: UI/text scaling and font selection settings.
* #220: VOD timestamp/position display is present in the player controls.
* #217: chat background opacity is configurable in the chat settings.
* #215: VOD seek/open paths no longer emit duplicate online notifications in the current channel model update flow.
* #275: Linux `make install` target in `orion.pro`.

## Needs Twitch API modernization

These issues are likely symptoms of old Twitch API, OAuth, playback, chat, or VOD endpoints and should be handled as a dedicated Helix/EventSub/chat migration rather than one-off fixes:

* #283, #277, #257, #239, #224, #142, #47, #42, #34.

## Platform, packaging, and distribution follow-up

These are packaging/distribution requests or platform-specific reports that need maintainers with those target systems:

* #276: added FreeBSD dependency notes to the README.
* #267, #261, #235, #219, #216.

## Feature requests not implemented here

These remain product work outside the maintenance pass:

* #278, #226.

## Administrative

* #307 records the original maintainer's farewell/archive notice.
