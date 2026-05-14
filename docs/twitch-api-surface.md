# Twitch API Surface

Last reviewed: 2026-05-14.

This maintained fork separates Twitch integrations into supported API paths,
fallback-only paths, and disabled behavior. The goal is to avoid promising a
native Twitch feature when Twitch does not publish a supported API for it.

## Product Decision

Native live and VOD playback remains a best-effort feature. Orion still tries
the legacy playback-token and HLS playlist path so existing desktop users can
keep using mpv or Qt Multimedia when Twitch accepts that path, but it is not a
supported Helix integration and must not be described as a supported native
Twitch API. If token, playlist, quality, or backend loading fails, the player
header keeps the direct `twitch.tv` fallback visible.

VOD replay chat is disabled in native chat because Twitch does not publish a
current VOD chat export API. The app shows a notice with a timestamped Twitch
VOD link instead of calling removed `/comments` or v5 replay-chat endpoints.

Drops, channel-point rewards, and viewer reward-credit signals are not
implemented in native playback. Twitch's documented Drops flow is for game
developers and entitlement systems, and channel-point redemptions are exposed
through broadcaster/moderator API and EventSub flows rather than a third-party
viewer heartbeat. Reward-sensitive viewing should use the `twitch.tv` fallback.

## Supported Twitch Paths

| Source | Runtime path | Classification | Evidence |
| --- | --- | --- | --- |
| `src/network/networkmanager.cpp` | `https://id.twitch.tv/oauth2/authorize` | Supported user OAuth implicit grant | Twitch OAuth docs describe the implicit grant and recommend state validation. |
| `src/network/networkmanager.cpp` | `https://id.twitch.tv/oauth2/token` | Supported client-credentials app token when the user supplies their own client ID and secret | Twitch OAuth docs describe app access tokens and the client-credentials grant. |
| `src/network/networkmanager.cpp` | `https://id.twitch.tv/oauth2/validate` | Required token validation | Twitch token validation docs require desktop apps that maintain an OAuth session to validate on startup and hourly. |
| `src/network/networkmanager.cpp` | `/helix/users` | Supported Helix `Get Users` | Twitch API Reference. |
| `src/network/networkmanager.cpp` | `/helix/streams` | Supported Helix `Get Streams` for stream status, top streams, language search, and game search | Twitch API Reference. |
| `src/network/networkmanager.cpp` | `/helix/games/top`, `/helix/games` | Supported Helix `Get Top Games` and `Get Games` | Twitch API Reference. |
| `src/network/networkmanager.cpp` | `/helix/search/channels`, `/helix/search/categories` | Supported Helix search | Twitch API Reference. |
| `src/network/networkmanager.cpp` | `/helix/videos` | Supported Helix VOD metadata | Twitch Videos guide and API Reference. |
| `src/network/networkmanager.cpp` | `/helix/channels/followed` | Supported Helix followed-channel list with user auth | Twitch API Reference. |
| `src/network/networkmanager.cpp` | `/helix/users/blocks` | Supported Helix block-list and block/unblock behavior with user auth | Twitch API Reference. |
| `src/network/networkmanager.cpp` | `/helix/chat/chatters` | Supported Helix viewer list when broadcaster and moderator IDs plus `moderator:read:chatters` scope are available | Twitch API Reference. |
| `src/network/networkmanager.cpp` | `/helix/chat/emotes/set` | Supported Helix emote-set metadata | Twitch API Reference. |
| `src/network/networkmanager.cpp` | `/helix/chat/badges`, `/helix/chat/badges/global` | Supported Helix chat badge metadata when a token is available | Twitch API Reference. |
| `src/network/networkmanager.cpp` | `/helix/bits/cheermotes` | Supported Helix Cheermote metadata | Twitch API Reference. |
| `src/model/ircchat.cpp` | `irc.chat.twitch.tv:6697` | Supported legacy Twitch IRC chat path with known limitations | Twitch Chat docs still document IRC as a historical interface while recommending EventSub/API for full chatbot functionality. |

## Fallback And Unsupported Paths

| Source | Runtime path | Classification | Required behavior |
| --- | --- | --- | --- |
| `src/network/urls.h`, `src/network/networkmanager.cpp` | `https://api.twitch.tv/api/channels/<channel>/access_token` | Unsupported/private playback-token path | Use only as best-effort native playback setup. On failure, emit the token error and keep the player-header Twitch fallback visible. |
| `src/network/urls.h`, `src/network/networkmanager.cpp` | `https://api.twitch.tv/api/vods/<vod>/access_token` | Unsupported/private playback-token path | Use only as best-effort native playback setup. Reject malformed or zero VOD IDs before making the request. |
| `src/util/jsonparser.cpp` | `https://usher.ttvnw.net/api/channel/hls/<channel>.m3u8` | Unsupported native HLS playlist path | Parse defensively, support standard HLS attributes, and surface playlist failures through the fallback UI. |
| `src/util/jsonparser.cpp` | `https://usher.ttvnw.net/vod/<vod>.m3u8` | Unsupported native HLS playlist path | Parse defensively, preserve string VOD IDs, and surface playlist failures through the fallback UI. |
| `src/network/networkmanager.cpp` | `https://tmi.twitch.tv/group/user/<channel>/chatters` | Legacy best-effort viewer-list fallback | Prefer Helix `Get Chatters` when auth and IDs allow it; otherwise tag TMI replies so stale data cannot replace the current channel. |
| `src/network/networkmanager.cpp` | `https://badges.twitch.tv/v1/badges/.../display` | Public badge display-feed fallback | Prefer Helix chat badge endpoints when a token is available; use the display feed only for logged-out badge metadata. |
| `src/model/ircchat.cpp`, `src/qml/irc/Chat.qml` | VOD replay chat | Disabled | Do not call v5, `/comments`, or replay-chat APIs. Show the timestamped Twitch VOD fallback notice. |
| `src/qml/PlayerView.qml` | Drops, channel points, and rewards credit | Fallback-only | Do not claim native reward credit. Use the direct `twitch.tv` channel or VOD fallback for reward-sensitive viewing. |
| `src/network/networkmanager.cpp` | BetterTTV and FrankerFaceZ emote APIs | Third-party best-effort metadata | Keep failures non-fatal and independent from Twitch Helix support claims. |

## Current Official References

* Twitch API overview and Reference: <https://dev.twitch.tv/docs/api/> and <https://dev.twitch.tv/docs/api/reference/>
* Twitch OAuth token flows: <https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/>
* Twitch OAuth token validation: <https://dev.twitch.tv/docs/authentication/validate-tokens/>
* Twitch Videos guide: <https://dev.twitch.tv/docs/api/videos/>
* Twitch Chat docs: <https://dev.twitch.tv/docs/chat>
* Twitch Video and Clips embed docs: <https://dev.twitch.tv/docs/embed/video-and-clips/>
* Twitch EventSub overview: <https://dev.twitch.tv/docs/eventsub/>
* Twitch legacy PubSub migration: <https://dev.twitch.tv/docs/pubsub/>
* Twitch Drops overview and technical guide: <https://dev.twitch.tv/docs/drops/> and <https://dev.twitch.tv/docs/drops/technical-guide/>
