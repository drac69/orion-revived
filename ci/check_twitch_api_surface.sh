#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
doc="$repo_dir/docs/twitch-api-surface.md"
readme="$repo_dir/README.md"
readiness="$repo_dir/docs/release-readiness.md"
triage="$repo_dir/docs/upstream-issue-triage.md"
network_manager="$repo_dir/src/network/networkmanager.cpp"
urls_header="$repo_dir/src/network/urls.h"
json_parser="$repo_dir/src/util/jsonparser.cpp"
irc_chat="$repo_dir/src/model/ircchat.cpp"
chat_qml="$repo_dir/src/qml/irc/Chat.qml"
player_qml="$repo_dir/src/qml/PlayerView.qml"

require_token() {
    local file=$1
    local token=$2
    local description=$3

    if ! rg -Fq "$token" "$file"; then
        printf '%s is missing %s\n' "${file#"$repo_dir"/}" "$description" >&2
        exit 1
    fi
}

if [[ ! -s "$doc" ]]; then
    printf 'Missing Twitch API surface document: docs/twitch-api-surface.md\n' >&2
    exit 1
fi

for token in \
    "Last reviewed: 2026-05-14." \
    "Native live and VOD playback remains a best-effort feature." \
    "supported Helix integration" \
    "VOD replay chat is disabled in native chat" \
    "Drops, channel-point rewards, and viewer reward-credit signals are not" \
    "Reward-sensitive viewing should use the \`twitch.tv\` fallback." \
    "## Supported Twitch Paths" \
    "## Fallback And Unsupported Paths" \
    "## Current Official References"
do
    require_token "$doc" "$token" "Twitch API surface policy token: $token"
done

for official_url in \
    "https://dev.twitch.tv/docs/api/" \
    "https://dev.twitch.tv/docs/api/reference/" \
    "https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/" \
    "https://dev.twitch.tv/docs/authentication/validate-tokens/" \
    "https://dev.twitch.tv/docs/api/videos/" \
    "https://dev.twitch.tv/docs/chat" \
    "https://dev.twitch.tv/docs/embed/video-and-clips/" \
    "https://dev.twitch.tv/docs/eventsub/" \
    "https://dev.twitch.tv/docs/pubsub/" \
    "https://dev.twitch.tv/docs/drops/" \
    "https://dev.twitch.tv/docs/drops/technical-guide/"
do
    require_token "$doc" "$official_url" "official Twitch reference $official_url"
done

for supported_path in \
    "https://id.twitch.tv/oauth2/authorize" \
    "https://id.twitch.tv/oauth2/token" \
    "https://id.twitch.tv/oauth2/validate" \
    "/helix/users" \
    "/helix/streams" \
    "/helix/games/top" \
    "/helix/games" \
    "/helix/search/channels" \
    "/helix/search/categories" \
    "/helix/videos" \
    "/helix/channels/followed" \
    "/helix/users/blocks" \
    "/helix/chat/chatters" \
    "/helix/chat/emotes/set" \
    "/helix/chat/badges" \
    "/helix/chat/badges/global" \
    "/helix/bits/cheermotes" \
    "irc.chat.twitch.tv:6697"
do
    require_token "$doc" "$supported_path" "supported Twitch path $supported_path"
done

for fallback_path in \
    "https://api.twitch.tv/api/channels/<channel>/access_token" \
    "https://api.twitch.tv/api/vods/<vod>/access_token" \
    "https://usher.ttvnw.net/api/channel/hls/<channel>.m3u8" \
    "https://usher.ttvnw.net/vod/<vod>.m3u8" \
    "https://tmi.twitch.tv/group/user/<channel>/chatters" \
    "https://badges.twitch.tv/v1/badges/.../display" \
    "BetterTTV and FrankerFaceZ emote APIs"
do
    require_token "$doc" "$fallback_path" "fallback or unsupported Twitch path $fallback_path"
done

for source_ref in \
    "src/network/networkmanager.cpp" \
    "src/network/urls.h" \
    "src/util/jsonparser.cpp" \
    "src/model/ircchat.cpp" \
    "src/qml/irc/Chat.qml" \
    "src/qml/PlayerView.qml"
do
    require_token "$doc" "$source_ref" "source reference $source_ref"
done

require_token "$readme" "docs/twitch-api-surface.md" "Twitch API surface document link"
require_token "$readiness" "docs/twitch-api-surface.md" "Twitch API surface release-readiness link"
require_token "$triage" "docs/twitch-api-surface.md" "Twitch API surface triage link"

require_token "$network_manager" "This endpoint is not a supported Helix API." "live playback-token unsupported-path comment"
require_token "$network_manager" "player-header twitch.tv fallback" "playback-token fallback comment"
require_token "$urls_header" "api.twitch.tv/api" "documented private playback-token host"
require_token "$json_parser" "usher.ttvnw.net/api/channel/hls" "documented live HLS host"
require_token "$json_parser" "usher.ttvnw.net/vod" "documented VOD HLS host"
require_token "$irc_chat" "Twitch no longer exposes VOD replay chat through a supported public API" "replay-chat disabled warning"
require_token "$chat_qml" "VOD chat replay is unavailable through Twitch's current supported APIs." "replay-chat QML fallback notice"
require_token "$player_qml" "Open VOD on Twitch" "VOD Twitch fallback label"
require_token "$player_qml" "Open channel on Twitch" "live Twitch fallback label"

if rg -q 'replaychat|vodChatPiece|getVodChatPiece|getNextVodChatPiece|cancelLastVodChatRequest|resetVodChat|/comments|api\.twitch\.tv/kraken|application/vnd\.twitchtv\.v5' "$repo_dir/src" "$repo_dir/.github"; then
    printf 'Removed Twitch v5/replay-chat paths must not reappear outside documentation.\n' >&2
    exit 1
fi

if rg -q 'PubSub|pubsub|channel-points.*heartbeat|reward.*heartbeat|Drops.*heartbeat|drop.*claim|reward.*claim' "$repo_dir/src"; then
    printf 'Native rewards-credit or Drops heartbeat behavior must not be implemented without a supported API decision.\n' >&2
    exit 1
fi
