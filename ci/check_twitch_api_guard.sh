#!/usr/bin/env bash
set -euo pipefail

fail=0
json_parser="src/util/jsonparser.cpp"
badge_container="src/model/badgecontainer.cpp"
badge_container_header="src/model/badgecontainer.h"
channel_manager="src/model/channelmanager.cpp"
channel_model="src/model/channel.h"
channel_list_model="src/model/channellistmodel.h"
game_model="src/model/game.h"
game_list_model="src/model/gamelistmodel.h"
irc_chat="src/model/ircchat.h"
network_manager="src/network/networkmanager.cpp"
vod_manager="src/model/vodmanager.cpp"
get_stream_block=$(sed -n '/void NetworkManager::getStream/,/^}/p' "$network_manager")
search_channels_block=$(sed -n '/void NetworkManager::searchChannels/,/^}/p' "$network_manager")
search_games_block=$(sed -n '/void NetworkManager::searchGames/,/^}/p' "$network_manager")
get_streams_for_game_block=$(sed -n '/void NetworkManager::getStreamsForGame(/,/^}/p' "$network_manager")
get_streams_for_game_id_block=$(sed -n '/void NetworkManager::getStreamsForGameId/,/^}/p' "$network_manager")
get_channel_playback_block=$(sed -n '/void NetworkManager::getChannelPlaybackStream/,/^}/p' "$network_manager")
get_broadcasts_block=$(sed -n '/void NetworkManager::getBroadcasts/,/^}/p' "$network_manager")
get_broadcast_playback_block=$(sed -n '/void NetworkManager::getBroadcastPlaybackStream/,/^}/p' "$network_manager")
get_user_block=$(sed -n '/void NetworkManager::getUser/,/^}/p' "$network_manager")
user_reply_block=$(sed -n '/void NetworkManager::userReply/,/^}/p' "$network_manager")
get_user_favourites_block=$(sed -n '/void NetworkManager::getUserFavourites/,/^}/p' "$network_manager")
get_blocked_user_list_block=$(sed -n '/void NetworkManager::getBlockedUserList/,/^}/p' "$network_manager")
edit_user_block_block=$(sed -n '/void NetworkManager::editUserBlock(/,/^}/p' "$network_manager")
get_channel_badges_block=$(sed -n '/void NetworkManager::getChannelBadgeUrlsBeta/,/^}/p' "$network_manager")
get_channel_bits_block=$(sed -n '/void NetworkManager::getChannelBitsUrls/,/^}/p' "$network_manager")
get_channel_bttv_block=$(sed -n '/void NetworkManager::getChannelBttvEmotes/,/^}/p' "$network_manager")
get_channel_ffz_block=$(sed -n '/void NetworkManager::getChannelFfzEmotes/,/^}/p' "$network_manager")
channel_badges_reply_block=$(sed -n '/void NetworkManager::channelBadgeUrlsBetaReply/,/^}/p' "$network_manager")
channel_bits_reply_block=$(sed -n '/void NetworkManager::channelBitsUrlsReply/,/^}/p' "$network_manager")
channel_bttv_reply_block=$(sed -n '/void NetworkManager::channelBttvEmotesReply/,/^}/p' "$network_manager")
channel_ffz_reply_block=$(sed -n '/void NetworkManager::channelFfzEmotesReply/,/^}/p' "$network_manager")
vod_search_block=$(sed -n '/void VodManager::search/,/^}/p' "$vod_manager")
vod_get_broadcasts_block=$(sed -n '/void VodManager::getBroadcasts/,/^}/p' "$vod_manager")
load_channel_badges_block=$(sed -n '/bool BadgeContainer::loadChannelBetaBadgeUrls/,/^}/p' "$badge_container")
load_channel_bits_block=$(sed -n '/bool BadgeContainer::loadChannelBitsUrls/,/^}/p' "$badge_container")
load_channel_bttv_block=$(sed -n '/bool BadgeContainer::loadChannelBttvEmotes/,/^}/p' "$badge_container")
load_channel_ffz_block=$(sed -n '/bool BadgeContainer::loadChannelFfzEmotes/,/^}/p' "$badge_container")
channel_manager_search_channels_block=$(sed -n '/void ChannelManager::searchChannels/,/^}/p' "$channel_manager")
channel_manager_search_games_block=$(sed -n '/void ChannelManager::searchGames/,/^}/p' "$channel_manager")
channel_manager_on_user_updated_block=$(sed -n '/void ChannelManager::onUserUpdated/,/^}/p' "$channel_manager")
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

if ! rg -q 'QSslSocket::supportsSsl\(\)' src/model/ircchat.cpp \
    || ! rg -q 'sslLibraryBuildVersionString' src/model/ircchat.cpp \
    || ! rg -q 'sslLibraryVersionString' src/model/ircchat.cpp; then
    printf 'Twitch IRC TLS setup must report unavailable Qt SSL runtime details.\n' >&2
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

if ! rg -q 'quint64 user_id;' "$irc_chat"; then
    printf 'Twitch chat user IDs must be stored as quint64 before Helix block-list/edit calls.\n' >&2
    fail=1
fi

if ! rg -q 'quint64 id;' "$channel_model" \
    || ! rg -q 'quint64 getId\(\) const;' "$channel_model" \
    || ! rg -q 'void setId\(const quint64 &value\);' "$channel_model" \
    || ! rg -q 'QHash<quint64, Channel \*> channelIdIndex;' "$channel_list_model"; then
    printf 'Twitch channel IDs must be stored and indexed as quint64.\n' >&2
    fail=1
fi

if rg -q 'channel->setId\(.*(static_cast<quint32>|\.toInt\(\))' "$json_parser"; then
    printf 'Twitch channel ID parsing must not narrow IDs to 32-bit integers.\n' >&2
    fail=1
fi

if ! rg -q 'QString id;' "$game_model" \
    || ! rg -q 'QString getId\(\) const;' "$game_model" \
    || ! rg -q 'void setId\(const QString &value\);' "$game_model" \
    || ! rg -q 'Game \*find\(const QString &\);' "$game_list_model"; then
    printf 'Twitch category IDs must be stored as strings.\n' >&2
    fail=1
fi

if rg -q 'game->setId\(.*\.to(UInt|Int)\(\)|QString::number\(result\.items\.first\(\)->getId\(\)\)' "$json_parser" "$network_manager"; then
    printf 'Twitch category ID parsing and lookups must not narrow string IDs to integers.\n' >&2
    fail=1
fi

if ! rg -q 'QMap<qint64, QMap<QString, QMap<QString, QString>>> channelBitsUrls;' "$badge_container_header" \
    || ! rg -q 'bool loadChannelBitsUrls\(qint64 channel\);' "$badge_container_header"; then
    printf 'Twitch channel Bits metadata caches must preserve 64-bit channel IDs.\n' >&2
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

if ! printf '%s\n' "$get_stream_block" | rg -q 'if \(channelId == 0\)' \
    || ! printf '%s\n' "$get_stream_block" | rg -q 'emit streamGetOperationFinished\(channelId, false\)'; then
    printf 'Single stream-status requests must reject zero channel ids before calling Helix.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$search_channels_block" | rg -q 'const QString normalizedQuery = query\.trimmed\(\)' \
    || ! printf '%s\n' "$search_channels_block" | rg -q 'if \(normalizedQuery\.isEmpty\(\)\)' \
    || ! printf '%s\n' "$search_channels_block" | rg -q 'emit searchChannelsOperationFinished\(empty, 0\)' \
    || ! printf '%s\n' "$search_channels_block" | rg -q 'urlQuery\.addQueryItem\("query", normalizedQuery\)'; then
    printf 'Channel searches must trim and reject empty queries before calling Helix.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$search_games_block" | rg -q 'const QString normalizedQuery = query\.trimmed\(\)' \
    || ! printf '%s\n' "$search_games_block" | rg -q 'if \(normalizedQuery\.isEmpty\(\)\)' \
    || ! printf '%s\n' "$search_games_block" | rg -q 'emit searchGamesOperationFinished\(empty\)' \
    || ! printf '%s\n' "$search_games_block" | rg -q 'urlQuery\.addQueryItem\("query", normalizedQuery\)'; then
    printf 'Category searches must trim and reject empty queries before calling Helix.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$channel_manager_search_channels_block" | rg -q 'const QString query = q\.trimmed\(\)' \
    || ! printf '%s\n' "$channel_manager_search_channels_block" | rg -q 'if \(query\.isEmpty\(\)\)' \
    || ! printf '%s\n' "$channel_manager_search_channels_block" | rg -q 'netman->searchChannels\(query, offset, limit\)'; then
    printf 'ChannelManager search dispatch must normalize channel search text before routing it.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$channel_manager_search_games_block" | rg -q 'const QString query = q\.trimmed\(\)' \
    || ! printf '%s\n' "$channel_manager_search_games_block" | rg -q 'if \(query\.isEmpty\(\)\)' \
    || ! printf '%s\n' "$channel_manager_search_games_block" | rg -q 'netman->searchGames\(query\)'; then
    printf 'ChannelManager game search dispatch must normalize category search text before routing it.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$get_streams_for_game_block" | rg -q 'const QString gameName = game\.trimmed\(\)' \
    || ! printf '%s\n' "$get_streams_for_game_block" | rg -q 'if \(gameName\.isEmpty\(\)\)' \
    || ! printf '%s\n' "$get_streams_for_game_block" | rg -q 'emit gameStreamsOperationFinished\(empty, offset\)'; then
    printf 'Game stream searches must reject empty game names before calling Helix.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$get_streams_for_game_id_block" | rg -q 'const QString normalizedGameId = gameId\.trimmed\(\)' \
    || ! printf '%s\n' "$get_streams_for_game_id_block" | rg -q 'if \(normalizedGameId\.isEmpty\(\)\)' \
    || ! printf '%s\n' "$get_streams_for_game_id_block" | rg -q 'query\.addQueryItem\("game_id", normalizedGameId\)'; then
    printf 'Game stream lookups must reject empty game IDs and query with normalized IDs.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$get_channel_playback_block" | rg -q 'const QString normalizedChannelName = channelName\.trimmed\(\)' \
    || ! printf '%s\n' "$get_channel_playback_block" | rg -q 'if \(normalizedChannelName\.isEmpty\(\)\)' \
    || ! printf '%s\n' "$get_channel_playback_block" | rg -q 'emit m3u8OperationFinished\(QVariantMap\(\)\)' \
    || ! printf '%s\n' "$get_channel_playback_block" | rg -q 'arg\(normalizedChannelName\)'; then
    printf 'Live playback-token requests must reject empty channel names before calling Twitch.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$get_broadcasts_block" | rg -q 'if \(channelId == 0\)' \
    || ! printf '%s\n' "$get_broadcasts_block" | rg -q 'emit broadcastsOperationFailed\(\)'; then
    printf 'VOD listing requests must reject zero channel ids before calling Helix.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$vod_search_block" | rg -q 'if \(channelId == 0\)' \
    || ! printf '%s\n' "$vod_search_block" | rg -q '_model->clear\(\)' \
    || ! printf '%s\n' "$vod_search_block" | rg -q 'emit searchFailed\(\)'; then
    printf 'VodManager::search must reject zero channel ids and end the QML loading state.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$vod_get_broadcasts_block" | rg -q 'vod\.remove\(QRegularExpression' \
    || ! printf '%s\n' "$vod_get_broadcasts_block" | rg -q 'if \(vod\.isEmpty\(\)\)' \
    || ! printf '%s\n' "$vod_get_broadcasts_block" | rg -q 'emit streamsGetFinished\(QVariantMap\(\)\)'; then
    printf 'VodManager::getBroadcasts must reject invalid VOD ids before playback-token lookup.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$get_broadcast_playback_block" | rg -q 'const QString normalizedVod = vod\.trimmed\(\)' \
    || ! printf '%s\n' "$get_broadcast_playback_block" | rg -q 'normalizedVod\.toULongLong\(&vodOk\)' \
    || ! printf '%s\n' "$get_broadcast_playback_block" | rg -q 'if \(!vodOk \|\| vodId == 0\)' \
    || ! printf '%s\n' "$get_broadcast_playback_block" | rg -q 'emit m3u8OperationBFinished\(QVariantMap\(\)\)'; then
    printf 'VOD playback-token requests must reject malformed or zero VOD ids before calling Twitch.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$get_user_block" | rg -q 'requireHelixAccessToken\("User profile loading", HelixAuthMode::UserOnly\)' \
    || ! printf '%s\n' "$get_user_block" | rg -q 'emit userOperationFinished\(QString\(\), 0\)'; then
    printf 'User profile loading must require user auth and emit an empty result on missing auth.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$user_reply_block" | rg -q 'emit userOperationFinished\(QString\(\), 0\)' \
    || ! printf '%s\n' "$user_reply_block" | rg -q 'JsonParser::parseUser'; then
    printf 'User profile replies must emit an empty result on network/API failure.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$channel_manager_on_user_updated_block" | rg -q 'if \(name\.isEmpty\(\) \|\| userId == 0\)' \
    || ! printf '%s\n' "$channel_manager_on_user_updated_block" | rg -q 'emit userNameUpdated\(user_name\)' \
    || ! printf '%s\n' "$channel_manager_on_user_updated_block" | rg -q 'return;'; then
    printf 'ChannelManager must not start logged-in flows for empty user profile results.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$get_user_favourites_block" | rg -q 'if \(userId == 0\)' \
    || ! printf '%s\n' "$get_user_favourites_block" | rg -q 'emit favouritesReplyFinished\(empty, offset, offset\)' \
    || ! printf '%s\n' "$get_user_favourites_block" | rg -q 'requireHelixAccessToken\("Followed channel loading", HelixAuthMode::UserOnly\)' \
    || ! printf '%s\n' "$get_user_favourites_block" | rg -q '!userFavouritesPageCursors\.contains\(offset\)'; then
    printf 'Followed-channel requests must reject zero users, require user auth, and guard invalid cursors.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$get_blocked_user_list_block" | rg -q 'userId == 0' \
    || ! printf '%s\n' "$get_blocked_user_list_block" | rg -q 'requireHelixAccessToken\("Blocked user list loading", HelixAuthMode::UserOnly\)' \
    || ! printf '%s\n' "$get_blocked_user_list_block" | rg -q 'emit blockedUserListLoadOperationFinished\(empty, offset, offset\)' \
    || ! printf '%s\n' "$get_blocked_user_list_block" | rg -q '!blockedUserListPageCursors\.contains\(offset\)' \
    || ! printf '%s\n' "$get_blocked_user_list_block" | rg -q 'qMax<quint32>\(1, qMin<quint32>\(limit, 100\)\)'; then
    printf 'Blocked-user list requests must reject invalid users/auth/cursors and clamp page size.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$edit_user_block_block" | rg -q 'const QString normalizedBlockUsername = blockUsername\.trimmed\(\)' \
    || ! printf '%s\n' "$edit_user_block_block" | rg -q 'if \(myUserId == 0 \|\| normalizedBlockUsername\.isEmpty\(\)\)' \
    || ! printf '%s\n' "$edit_user_block_block" | rg -q 'requireHelixAccessToken\("Blocked user editing", HelixAuthMode::UserOnly\)' \
    || ! printf '%s\n' "$edit_user_block_block" | rg -q 'query\.addQueryItem\("login", normalizedBlockUsername\)' \
    || ! printf '%s\n' "$edit_user_block_block" | rg -q 'setAttribute\(RequestContextAttribute1, normalizedBlockUsername\)'; then
    printf 'Blocked-user edits must reject missing users/names and use normalized login names.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$get_channel_badges_block" | rg -q 'if \(channelID == 0\)' \
    || ! printf '%s\n' "$get_channel_badges_block" | rg -q 'emit getChannelBadgeBetaUrlsOperationFinished\(channelID, empty\)'; then
    printf 'Channel badge metadata requests must reject non-positive channel IDs.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$get_channel_bits_block" | rg -q 'if \(channelID <= 0\)' \
    || ! printf '%s\n' "$get_channel_bits_block" | rg -q 'emit getChannelBitsUrlsOperationFinished\(channelID, emptyUrls, emptyColors\)'; then
    printf 'Channel Cheermote metadata requests must reject non-positive channel IDs.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$channel_badges_reply_block" | rg -q 'request\(\)\.attribute\(QNetworkRequest::User\)\.toULongLong\(\)' \
    || printf '%s\n' "$channel_badges_reply_block" | rg -q 'lastIndexOf|startsWith\(CHANNEL_BADGES_BETA_URL_PREFIX\)'; then
    printf 'Channel badge metadata replies must use request context instead of reparsing URLs.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$channel_bits_reply_block" | rg -q 'request\(\)\.attribute\(QNetworkRequest::User\)\.toLongLong\(\)' \
    || printf '%s\n' "$channel_bits_reply_block" | rg -q "lastIndexOf|mid\\(eqPos|toString\\(\\)"; then
    printf 'Channel Cheermote metadata replies must use request context instead of reparsing URLs.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$get_channel_bttv_block" | rg -q 'const QString normalizedChannel = channel\.trimmed\(\)' \
    || ! printf '%s\n' "$get_channel_bttv_block" | rg -q 'if \(normalizedChannel\.isEmpty\(\)\)' \
    || ! printf '%s\n' "$get_channel_bttv_block" | rg -q 'emit getChannelBttvEmotesOperationFinished\(QString\(\), empty\)' \
    || ! printf '%s\n' "$get_channel_bttv_block" | rg -q 'QUrl::toPercentEncoding\(normalizedChannel\)' \
    || ! printf '%s\n' "$get_channel_bttv_block" | rg -q 'setAttribute\(RequestContextAttribute1, normalizedChannel\)'; then
    printf 'BTTV channel emote requests must normalize and reject empty channel names.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$get_channel_ffz_block" | rg -q 'const QString normalizedChannel = channel\.trimmed\(\)' \
    || ! printf '%s\n' "$get_channel_ffz_block" | rg -q 'if \(normalizedChannel\.isEmpty\(\)\)' \
    || ! printf '%s\n' "$get_channel_ffz_block" | rg -q 'emit getChannelFfzEmotesOperationFinished\(QString\(\), empty\)' \
    || ! printf '%s\n' "$get_channel_ffz_block" | rg -q 'QUrl::toPercentEncoding\(normalizedChannel\)' \
    || ! printf '%s\n' "$get_channel_ffz_block" | rg -q 'setAttribute\(RequestContextAttribute1, normalizedChannel\)'; then
    printf 'FFZ channel emote requests must normalize and reject empty channel names.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$channel_bttv_reply_block" | rg -q 'request\(\)\.attribute\(RequestContextAttribute1\)\.toString\(\)' \
    || printf '%s\n' "$channel_bttv_reply_block" | rg -q 'lastIndexOf\("/"\)'; then
    printf 'BTTV channel emote replies must use request context instead of reparsing URLs.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$channel_ffz_reply_block" | rg -q 'request\(\)\.attribute\(RequestContextAttribute1\)\.toString\(\)' \
    || printf '%s\n' "$channel_ffz_reply_block" | rg -q 'lastIndexOf\("/"\)'; then
    printf 'FFZ channel emote replies must use request context instead of reparsing URLs.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$load_channel_badges_block" | rg -q 'if \(channel != 0\)' \
    || ! printf '%s\n' "$load_channel_badges_block" | rg -q 'netman->getGlobalBadgesUrlsBeta\(\)'; then
    printf 'BadgeContainer must skip invalid channel badge requests while still loading global badges.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$load_channel_bits_block" | rg -q 'if \(channel > 0\)' \
    || ! printf '%s\n' "$load_channel_bits_block" | rg -q 'netman->getGlobalBitsUrls\(\)'; then
    printf 'BadgeContainer must skip invalid channel Bits requests while still loading global Bits metadata.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$load_channel_bttv_block" | rg -q 'const QString normalizedChannel = channel\.trimmed\(\)' \
    || ! printf '%s\n' "$load_channel_bttv_block" | rg -q 'if \(!normalizedChannel\.isEmpty\(\)\)' \
    || ! printf '%s\n' "$load_channel_bttv_block" | rg -q 'netman->getChannelBttvEmotes\(normalizedChannel\)' \
    || ! printf '%s\n' "$load_channel_bttv_block" | rg -q 'netman->getGlobalBttvEmotes\(\)'; then
    printf 'BadgeContainer must normalize BTTV channel emote requests and still load global BTTV emotes.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$load_channel_ffz_block" | rg -q 'const QString normalizedChannel = channel\.trimmed\(\)' \
    || ! printf '%s\n' "$load_channel_ffz_block" | rg -q 'if \(!normalizedChannel\.isEmpty\(\)\)' \
    || ! printf '%s\n' "$load_channel_ffz_block" | rg -q 'netman->getChannelFfzEmotes\(normalizedChannel\)' \
    || ! printf '%s\n' "$load_channel_ffz_block" | rg -q 'netman->getGlobalFfzEmotes\(\)'; then
    printf 'BadgeContainer must normalize FFZ channel emote requests and still load global FFZ emotes.\n' >&2
    fail=1
fi

exit "$fail"
