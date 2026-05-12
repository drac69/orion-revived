# Upstream Issue Triage

Audit date: 2026-05-12

Upstream repository: <https://github.com/alamminsalo/orion>

The upstream repository is archived and had 79 open issues at the time this fork was created. This file tracks which issues are covered by this maintenance branch and which ones still need larger product or API work.

## Addressed in this fork

* #302 / #303: merged the unmerged QObject lifetime crash fix from upstream PR #303.
* #306: changed the mpv default hardware decoder from `auto` to `auto-copy` to avoid unsafe native-surface handling in the embedded renderer.
* #305: search result pages now size their initial and follow-up fetches from the visible grid capacity, with a small row buffer instead of a hard-coded 25 items.
* #301: VOD resume positions now compare against the previous saved value before overwriting it, so periodic progress updates are persisted.
* #286: high-DPI startup no longer depends on the deprecated `QT_AUTO_SCREEN_SCALE_FACTOR` path.
* #264: added a setting to enable or disable screensaver inhibition during playback.
* #134: added a Ctrl+Q application shortcut.
* #44: the existing version checker now checks this fork's releases instead of the archived upstream repository.
* #242: QML startup warnings are now printed before the fatal startup error, which exposes missing QML modules directly.
* #292: kept the upstream fix that avoids trying to play an empty stream URL and falls back to `source` quality when the stored quality is unavailable.
* #298 / #304: kept the upstream chat-emote initialization workaround from #294.
* #284: kept the upstream localhost OAuth response fix from #272.

## Partially addressed

* #288 / #300: the OAuth login URL and scopes now use the current Twitch authorization host, and the logged-in user response parser handles Helix `Get Users` responses. Follow, block, and browsing calls still need a full Helix migration.

## Already covered by the final upstream code

These issues remained open upstream but the final `master` code already contains the relevant setting, install rule, shortcut, or behavior:

* #207: setting to disable click-video-to-pause.
* #223: UI/text scaling and font selection settings.
* #275: Linux `make install` target in `orion.pro`.
* #190: Escape closes the emote picker.

## Needs Twitch API modernization

These issues are likely symptoms of old Twitch API, OAuth, playback, chat, or VOD endpoints and should be handled as a dedicated Helix/EventSub/chat migration rather than one-off fixes:

* #285, #283, #277, #268, #257, #243, #239, #224, #167, #142, #123, #47, #42, #34.

## Platform, packaging, and distribution follow-up

These are packaging/distribution requests or platform-specific reports that need maintainers with those target systems:

* #276, #267, #261, #236, #235, #232, #219, #216, #202, #119, #90.

## Feature requests not implemented here

These remain product work outside the maintenance pass:

* #295, #282, #278, #274, #273, #271, #270, #263, #254, #241, #240, #234, #226, #220, #217, #215, #212, #210, #205, #199, #195, #187, #178, #141, #108, #101, #89, #74, #45, #40, #26, #18.

## Administrative

* #307 records the original maintainer's farewell/archive notice.
