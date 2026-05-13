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
* #240: Helix stream and channel language fields are parsed and shown in stream details, authenticated searches support `/language <code>` using Helix `Get Streams`, `/game <name> /language <code>` combines game and language filtering, and the Games view includes a stream-language selector.
* #268: Twitch `USERNOTICE` raid messages append a channel URL from the raid `msg-param-login` tag, chat system notices render URLs as selectable/clickable links, and an opt-in setting can automatically follow live raids in the player.
* #292: kept the upstream fix that avoids trying to play an empty stream URL and falls back to `source` quality when the stored quality is unavailable; playback startup now retries short-lived stalls and shows a header error instead of leaving only the spinner when no playable quality or URL is available.
* #298 / #304: kept the upstream chat-emote initialization workaround from #294.
* #284: kept the upstream localhost OAuth response fix from #272.
* #108: hidden live chat sends desktop notifications for incoming whispers and `@username` mentions, outgoing `/w` whispers are flagged as whispers, and chat now has a dedicated Whispers tab with unread state.
* #101: added configurable log levels, per-sink stdout/stderr/file/journal log thresholds, optional file logging, optional Linux systemd journal output when built with `libsystemd`, and an in-app recent-log viewer with copy/clear actions.
* #278: added optional compact and desktop side-navigation settings; combined with the existing right-side chat position, this covers the requested 1.5.x-style left-nav/right-chat layout without changing the default layout.
* #142: the emote picker now includes a common Unicode emoji subset that inserts real Unicode text while displaying image-backed Twemoji assets with font fallback when an image cannot be loaded.
* #187: documented multi-backend builds, kept the manual player selector for builds with more than one backend, and added runtime fallback that removes a compiled backend from the selector when its QML module fails to load.

## Partially addressed

* #288 / #300: the OAuth login URL and scopes now use the current Twitch authorization host, the logged-in user response parser handles Helix `Get Users` responses, chat block/unblock plus blocked-user list calls now use Helix, the followed-channel list now uses Helix `Get Followed Channels`, stream-status checks now use Helix `Get Streams`, channel search now uses Helix `Search Channels`, game/category browsing now uses Helix `Get Top Games`, `Search Categories`, `Get Games`, and game/language-filtered `Get Streams`, VOD listing now uses Helix `Get Videos`, chat badge metadata now uses Helix `Get Channel Chat Badges` / `Get Global Chat Badges` or Twitch's public badges display feed, emote-set loading now uses Helix `Get Emote Sets` with string-safe IDs and the current v2 static CDN template, and Bits/Cheermote metadata now uses Helix `Get Cheermotes`. The removed Twitch follow/unfollow mutation endpoints are no longer called; logged-in users are sent to twitch.tv for those actions while unauthenticated local favourites still work. Public Helix metadata requests can now use a user token or an opt-in app access token supplied with `ORION_TWITCH_APP_ACCESS_TOKEN` and, when needed, `ORION_TWITCH_CLIENT_ID`; the fork still does not embed a client secret or automatically run the server-side client-credentials flow from the desktop app. Logged-out search/category/VOD requests without a token still stop their spinners and show a token-required state instead of appearing to hang, and failed Twitch metadata/list/emote replies now emit empty completion results where callers expect collections. Server-side Twitch API failures are surfaced through the UI error footer while transport outages continue to use the connection banner. The unsupported v5 VOD replay-chat API is no longer called, and CI now blocks reintroducing Kraken/v5/replay-chat code outside the documented playback-token exception. VOD playback still needs a deeper replacement.
* #212: bundled Noto Sans and Material Icons fonts are registered with Qt before QML loads, Noto Sans is selected as the process default font before controls are created, stale saved font families are cleared back to the bundled default, and CI guards the bundled-font startup contract; the original openSUSE/KDE/Qt 5.9 rendering path has not been reproduced in this environment.
* #74: QML now runs a one-time main-window position refresh after startup and again before context menus if startup did not apply it, matching the historical Qt multi-screen workaround for stale window/screen association; CI guards the startup and menu contracts. The original multi-monitor bug has not been reproduced in this environment.
* #285: live and VOD playlist requests now use the current HTTPS `usher.ttvnw.net` host, the live `allow_audio_only` query parameter typo is fixed, master playlist parsing now reads quoted HLS attributes instead of depending on `VIDEO=` field order, empty token-parser results now fail as token errors instead of fetching an empty URL, and playback-token/playlist/quality failures keep the highlighted Twitch fallback control visible; the old playback-token endpoints still need a deeper replacement.
* #167: fixed a network-recovery condition that always reloaded playback on network-up events, guarded stream-status polling against stale/no current channel state, and made Twitch IRC reconnects keep a queued room target that rejoins once TLS/authentication is ready. Chat now uses Twitch's documented TLS IRC port, responds to `PING` with the server payload, handles server `RECONNECT`, reports legacy `HOSTTARGET` notices when Twitch sends them, and avoids QML issuing duplicate `JOIN` commands after backend reconnects. Expected IRC housekeeping commands (`CAP`, numeric welcome/name replies, `JOIN`, `PART`, `ROOMSTATE`) no longer produce noisy unrecognized-command logs. Hosted-channel behavior still needs live reproduction because Twitch's old hosting product no longer behaves like the 2017 report.
* #271: returning to the VOD view no longer forces the grid back to the beginning, the loaded VOD list can now be filtered by title/game/language/description/date/type text, the loaded list can be reversed oldest-first, the player can queue the current filtered VOD list with automatic end-of-VOD advance, local VOD progress writes are explicitly synced and rewrite the complete saved-position array, archive/highlight/upload/all type filters use Helix `Get Videos`, loaded VOD pages are cached per channel/type while refreshing with configurable cache expiry, supported Helix VOD metadata such as description, language, published time, URL, and muted sections is preserved in the VOD model and tooltip, muted VOD sections from Helix metadata are shown/filterable in the grid, marked on the VOD timeline, and skippable from the player controls, and VOD playback positions are mirrored to an atomic JSON snapshot in the app data folder for folder-level backup/sync and startup recovery with the path exposed in settings. Broad public chapter/tag filtering and Twitch cloud sync remain because Twitch's documented `Get Videos` response does not expose chapter titles or tag metadata for arbitrary VODs, and documented stream markers are scoped to the owning broadcaster/editor token.
* #119: the README now explains that the GitHub build commands are terminal commands, separates build/run/install steps, and documents that revalidated Windows/macOS installers are not published yet.
* #210: new Windows installs now default to ANGLE D3D11 instead of the older D3D9 renderer, and saved D3D9 defaults are migrated to D3D11 to reduce exposure to the Fraps/Qt render-thread crash path; the Fraps-specific crash has not been reproduced in this environment.
* #90: focused QML text fields now request the Qt input method, and Windows tablet/slate systems also launch the OS touch keyboard (`TabTip.exe`/`osk.exe`) when text inputs gain focus; the Windows tablet behavior has not been reproduced in this environment.
* #243: added an opt-in live low-latency playlist request flag (`fast_bread=true`) for live HLS requests, and the mpv backend applies mpv's documented `low-latency` runtime profile for live streams while restoring it for VOD/default playback. The heavier Twitch prefetch-segment proxy remains unimplemented because the upstream prototype was reported as skippy and needing a security review.
* #202: Android Back key presses from the player view now return to the last non-player tab instead of leaving the player stuck in place, and CI guards that QML Back-navigation contract. The Android Activity now uses `FLAG_KEEP_SCREEN_ON` instead of a deprecated wakelock, Qt background running is disabled so playback is suspended when Android backgrounds the Activity, Android now participates in screen-density detection before chat/emote providers are initialized so high-density devices request 2x Twitch/BTTV/FFZ/Bits/badge assets, and mobile player surface taps reveal controls without toggling pause so touch misses do not pause the stream. Android playback pause/resume, call-audio behavior, crash reproduction, emote rendering, and Play Store packaging still need target-device validation.
* #283: the player header now offers a direct Twitch fallback for the current live channel or VOD, and playback-token/playlist failures force that highlighted control visible with an explicit fallback label, giving users a supported path when Orion's native playlist-token flow fails; a documented native HLS playback-token replacement remains unavailable.

## Already covered by the final upstream code

These issues remained open upstream but the final `master` code already contains the relevant setting, install rule, shortcut, or behavior:

* #207: setting to disable click-video-to-pause.
* #223: UI/text scaling and font selection settings.
* #220: VOD timestamp/position display is present in the player controls.
* #217: chat background opacity is configurable in the chat settings.
* #215: VOD seek/open paths no longer emit duplicate online notifications in the current channel model update flow.
* #275: Linux `make install` target in `orion.pro`; CI now stages and validates the installed binary, AppStream metadata, desktop entry, and icon paths.
* #47: later upstream Windows builds resolved the reported no-content/SSL packaging failure path according to the reporter's 1.6.0-beta retest; this fork does not publish revalidated Windows installers yet.

## Needs Twitch API or product support

Twitch documents Helix metadata APIs and embeddable players, but not a supported native HLS playback-token API. The remaining playback-token work therefore needs either an official Twitch replacement API or a product decision to embed/open Twitch's player instead of preserving native HLS playback.

Twitch's current Drops documentation is aimed at game developers and entitlement fulfillment systems, not third-party viewing clients. The documented flow covers account linking, EventSub or Twitch API entitlement delivery, and marking Drop entitlements fulfilled for a game-owned campaign; it does not expose a supported replacement for a native viewer heartbeat or rewards-credit signal. For reward-sensitive viewing, this fork's supported path is to open the channel or VOD on twitch.tv from the player header.

* #283.
* #224: Twitch does not document a current VOD replay-chat export API; the fork no longer calls the unsupported v5 comments API, shows the replay-chat unavailable notice for current Helix numeric VOD IDs, and points users to the Twitch VOD fallback for native replay chat.
* #226 / #257.

References:

* <https://dev.twitch.tv/docs/api/videos>
* <https://dev.twitch.tv/docs/api/markers/>
* <https://dev.twitch.tv/docs/drops/>
* <https://dev.twitch.tv/docs/drops/technical-guide/>
* <https://dev.twitch.tv/docs/extensions/frontend-api-usage/>
* <https://mpv.io/manual/stable/#low-latency-playback>

## Platform, packaging, and distribution follow-up

These are packaging/distribution requests or platform-specific reports that need maintainers with those target systems:

* #276: added FreeBSD dependency notes to the README.
* #216: added FreeBSD SSL-runtime troubleshooting for the reported `SSL_CTX_set1_groups` startup failure; the original FreeBSD 11 crash has not been reproduced in this environment.
* #235 / #219: Linux desktop packaging metadata now points at this maintained fork, uses a reverse-DNS AppStream component ID with a desktop launchable, includes screenshot captions, and is validated in CI with `appstreamcli`, `desktop-file-validate`, and a staged `make install`. Obsolete Travis/AppVeyor release helpers are now documented as legacy and require an explicit opt-in before running; publishing distro packages or a PPA remains maintainer/distribution work.
* #239: Fedora's package was built with the Qt Multimedia/GStreamer backend and missing codec/video sink dependencies, while distro comments recommend rebuilding with mpv; this remains distro packaging work.
* #277: the failed VOD thumbnail URLs also failed on Twitch's own website according to upstream triage, so this is an upstream Twitch data/thumbnail issue rather than an Orion API bug.
* #34: the Fluendo/GStreamer codec-pack playback failure depends on an old Qt Multimedia/GStreamer backend path and proprietary codec pack behavior that has not been reproduced here.
* #42: duplicate/random playback stop report linked upstream to closed #43; startup stalls, active-playback buffering stalls, unexpected live stops, and VOD stops before the final seconds now schedule bounded automatic reloads while user-requested stops and normal VOD endings remain stopped. Remaining validation needs target OS/GPU/backend reproduction.
* #267 / #261: Android source metadata now follows the fork version, CI validates the Android manifest/version/lifecycle/permission invariants that can be checked without an Android toolchain, and Android/F-Droid release status is documented in `docs/android.md`; publishing a Play Store or F-Droid package still needs a maintained Android build recipe and target-device validation.

## Administrative

* #307 records the original maintainer's farewell/archive notice.
