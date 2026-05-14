#!/usr/bin/env bash
set -euo pipefail

fail=0
json_parser="src/util/jsonparser.cpp"
network_manager="src/network/networkmanager.cpp"
add_offline_channels_block=$(sed -n '/void addOfflineChannels/,/^}/p' "$network_manager")
add_ulong_list_block=$(sed -n '/void addULongLongStringList/,/^}/p' "$network_manager")

check_absent() {
    local label="$1"
    local pattern="$2"
    local matches

    matches=$(rg -n --glob '!*.md' --glob '!distfiles/**' --glob '!ci/check_twitch_api_guard.sh' "$pattern" src ci .github || true)
    if [[ -n "$matches" ]]; then
        printf 'Deprecated Twitch API usage found: %s\n%s\n' "$label" "$matches" >&2
        fail=1
    fi
}

check_absent "Kraken/v5 API constants and Accept headers" 'TWITCH_API_V5|application/vnd\.twitchtv\.v5|api\.twitch\.tv/kraken|\bkraken\b'
check_absent "unsupported VOD replay chat/comments API" 'replaychat|vodChatPiece|getVodChatPiece|getNextVodChatPiece|cancelLastVodChatRequest|resetVodChat|/comments'
check_absent "plain HTTP Twitch web links" 'http://(www\.)?twitch\.tv'
check_absent "plain HTTP Twitch CDN image links" 'http://static-cdn\.jtvnw\.net'

legacy_host_files=$(rg -l 'api\.twitch\.tv/api' src || true)
if [[ "$legacy_host_files" != "src/network/urls.h" ]]; then
    printf 'Unexpected api.twitch.tv/api host reference. Only the documented playback-token macro may remain.\n%s\n' "$legacy_host_files" >&2
    fail=1
fi

unexpected_macro_refs=$(rg -n '\bTWITCH_API\b' src | rg -v '^src/network/(urls\.h|networkmanager\.cpp):' || true)
if [[ -n "$unexpected_macro_refs" ]]; then
    printf 'Unexpected TWITCH_API macro use outside the known playback-token implementation.\n%s\n' "$unexpected_macro_refs" >&2
    fail=1
fi

networkmanager_macro_refs=$(rg -n '\bTWITCH_API\b' src/network/networkmanager.cpp || true)
networkmanager_macro_count=$(printf '%s\n' "$networkmanager_macro_refs" | sed '/^$/d' | wc -l)
if (( networkmanager_macro_count > 2 )); then
    printf 'TWITCH_API macro is only allowed for live and VOD playback-token requests.\n%s\n' "$networkmanager_macro_refs" >&2
    fail=1
fi

if ! rg -q 'const qint16 IrcChat::PORT = 6697;' src/model/ircchat.cpp; then
    printf 'Twitch IRC TLS connections must use the documented IRC port 6697.\n' >&2
    fail=1
fi

for required_irc_command in RECONNECT HOSTTARGET CLEARMSG ROOMSTATE; do
    if ! rg -q "$required_irc_command" src/model/ircchat.cpp; then
        printf 'Twitch IRC %s command handling is required for current chat behavior.\n' "$required_irc_command" >&2
        fail=1
    fi
done

if ! rg -q 'ircCommandKeyword' src/model/ircchat.cpp; then
    printf 'Twitch IRC command parsing must use the structured command keyword helper.\n' >&2
    fail=1
fi

if rg -q 'joinChannel\(root\.channel' src/qml/irc/Chat.qml; then
    printf 'QML connected-state handling must not issue duplicate chat JOIN commands.\n' >&2
    fail=1
fi

for required_chat_settings_sync in 'syncSettings("chat blacklist")' 'syncSettings("chat highlight users")'; do
    if ! rg -qF "$required_chat_settings_sync" src/model/settingsmanager.cpp; then
        printf 'Chat setting persistence is missing sync token: %s\n' "$required_chat_settings_sync" >&2
        fail=1
    fi
done

if ! rg -q 'www\.twitch\.tv/videos' src/qml/irc/Chat.qml; then
    printf 'VOD replay-chat fallback notices must include a direct Twitch VOD URL.\n' >&2
    fail=1
fi

for required_app_token_token in \
    'ORION_TWITCH_CLIENT_SECRET' \
    'https://id\.twitch\.tv/oauth2/token' \
    'grant_type", "client_credentials' \
    'appAccessTokenReply'
do
    if ! rg -q "$required_app_token_token" src/network/networkmanager.*; then
        printf 'Helix app access token client-credentials support is missing token: %s\n' "$required_app_token_token" >&2
        fail=1
    fi
done

if ! rg -q 'ORION_TWITCH_CLIENT_SECRET' README.md docs/upstream-issue-triage.md; then
    printf 'Twitch client-credentials environment variables must be documented.\n' >&2
    fail=1
fi

for required_vod_field in description language published_at url muted_segments; do
    if ! rg -q "\"$required_vod_field\"" "$json_parser"; then
        printf 'Helix VOD metadata field %s must be parsed for filtering/display.\n' "$required_vod_field" >&2
        fail=1
    fi
done

if rg -qF 'QString::number(tokenJson["vod_id"].toInt())' "$json_parser"; then
    printf 'VOD playback-token parsing must not coerce string vod_id values to zero.\n' >&2
    fail=1
fi

for required_vod_token_parser_token in 'vodIdFromJson' 'vod.toULongLong(&vodOk)' 'vodId == 0'; do
    if ! rg -qF "$required_vod_token_parser_token" "$json_parser"; then
        printf 'VOD playback-token parsing is missing token: %s\n' "$required_vod_token_parser_token" >&2
        fail=1
    fi
done

for required_vod_role in Description Language PublishedAt Url MutedSegments; do
    if ! rg -q "$required_vod_role" src/model/vodlistmodel.h || ! rg -q "$required_vod_role" src/model/vodlistmodel.cpp; then
        printf 'VOD model must expose role %s.\n' "$required_vod_role" >&2
        fail=1
    fi
done

for required_filter_role in Description Language PublishedAt Url MutedSegments; do
    if ! rg -q "VodListModel::$required_filter_role" src/model/vodfilterproxymodel.cpp; then
        printf 'VOD filter must search role %s.\n' "$required_filter_role" >&2
        fail=1
    fi
done

for required_vod_filter_guard in \
    'const QAbstractItemModel *model = sourceModel()' \
    'if (!model)' \
    'if (sourceParent.isValid())' \
    'if (!sourceIndex.isValid())' \
    'if (!model || !left.isValid() || !right.isValid())'
do
    if ! rg -qF "$required_vod_filter_guard" src/model/vodfilterproxymodel.cpp; then
        printf 'VOD filter proxy must guard invalid model/index state: %s\n' "$required_vod_filter_guard" >&2
        fail=1
    fi
done

if ! rg -q 'fast_bread' src/util/jsonparser.cpp; then
    printf 'Low-latency live playback must request Twitch fast_bread playlists.\n' >&2
    fail=1
fi

for required_mpv_low_latency_token in 'profile-restore' 'apply-profile' 'low-latency' 'lowLatencyProfileApplied'; do
    if ! rg -q "$required_mpv_low_latency_token" src/qml/MpvBackend.qml; then
        printf 'mpv low-latency playback token %s is required.\n' "$required_mpv_low_latency_token" >&2
        fail=1
    fi
done

if ! printf '%s\n' "$add_offline_channels_block" | rg -q 'channel && channel->getId\(\) != 0' \
    || ! printf '%s\n' "$add_offline_channels_block" | rg -q 'if \(id != 0\)'; then
    printf 'Offline stream reconciliation must ignore null channels and zero channel ids.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$add_ulong_list_block" | rg -q 'bool ok = false' \
    || ! printf '%s\n' "$add_ulong_list_block" | rg -q 's\.toULongLong\(&ok\)' \
    || ! printf '%s\n' "$add_ulong_list_block" | rg -q 'ok && value != 0'; then
    printf 'Stream query id extraction must reject malformed or zero channel ids.\n' >&2
    fail=1
fi

exit "$fail"
