# Upstream Issue Triage

Audit date: 2026-05-12

Upstream repository: <https://github.com/alamminsalo/orion>

The upstream repository is archived and had 79 open issues at the time this fork was created. This file tracks which issues are covered by this maintenance branch and which ones still need larger product or API work.

## Addressed in this fork

* #302 / #303: merged the unmerged QObject lifetime crash fix from upstream PR #303.
* #18: added an mpv playback-stats overlay with codec, resolution, FPS, bitrate, dropped frame, sync, cache, and hardware-decoder data.
* #295: added an optional mpv audio-compressor filter for reducing stream volume swings.
* #306: changed the mpv default hardware decoder from `auto` to `auto-copy` to avoid unsafe native-surface handling in the embedded renderer.
* #305: search result pages now size their initial and follow-up fetches from the visible grid capacity, with a small row buffer instead of a hard-coded 25 items.
* #301: VOD resume positions now compare against the previous saved value before overwriting it, so periodic progress updates are persisted.
* #286: high-DPI startup no longer depends on the deprecated `QT_AUTO_SCREEN_SCALE_FACTOR` path.
* #265: fullscreen playback no longer toggles the main navigation header on top-edge hover, avoiding the repeated resize loop.
* #264: added a setting to enable or disable screensaver inhibition during playback.
* #260: Linux screensaver reset calls now only run while screensaver inhibition is active.
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
* #199: chat input focus is restored after sending a message.
* #195: chat input text now follows the chat text scaling setting.
* #190: Escape is handled as an application shortcut while the emote picker is open.
* #40: chat text segments are selectable and copyable, and whole messages can still be copied from the row context menu.
* #292: kept the upstream fix that avoids trying to play an empty stream URL and falls back to `source` quality when the stored quality is unavailable.
* #298 / #304: kept the upstream chat-emote initialization workaround from #294.
* #284: kept the upstream localhost OAuth response fix from #272.

## Partially addressed

* #288 / #300: the OAuth login URL and scopes now use the current Twitch authorization host, and the logged-in user response parser handles Helix `Get Users` responses. Follow, block, and browsing calls still need a full Helix migration.

## Already covered by the final upstream code

These issues remained open upstream but the final `master` code already contains the relevant setting, install rule, shortcut, or behavior:

* #207: setting to disable click-video-to-pause.
* #205: multiple-instance setting, now exposed in the options view.
* #223: UI/text scaling and font selection settings.
* #220: VOD timestamp/position display is present in the player controls.
* #217: chat background opacity is configurable in the chat settings.
* #215: VOD seek/open paths no longer emit duplicate online notifications in the current channel model update flow.
* #275: Linux `make install` target in `orion.pro`.

## Needs Twitch API modernization

These issues are likely symptoms of old Twitch API, OAuth, playback, chat, or VOD endpoints and should be handled as a dedicated Helix/EventSub/chat migration rather than one-off fixes:

* #285, #283, #277, #268, #257, #243, #239, #224, #167, #142, #123, #47, #42, #34.

## Platform, packaging, and distribution follow-up

These are packaging/distribution requests or platform-specific reports that need maintainers with those target systems:

* #276: added FreeBSD dependency notes to the README.
* #267, #261, #236, #235, #232, #219, #216, #202, #119, #90.

## Feature requests not implemented here

These remain product work outside the maintenance pass:

* #278, #271, #254, #240, #226, #212, #210, #187, #178, #141, #108, #101, #89, #74, #45, #26.

## Administrative

* #307 records the original maintainer's farewell/archive notice.
