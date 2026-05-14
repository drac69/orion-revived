#!/usr/bin/env bash
set -euo pipefail

fail=0
json_parser="src/util/jsonparser.cpp"
json_parser_header="src/util/jsonparser.h"
badge_container="src/model/badgecontainer.cpp"
badge_container_header="src/model/badgecontainer.h"
badge_image_provider="src/model/badgeimageprovider.cpp"
channel_manager="src/model/channelmanager.cpp"
channel_manager_header="src/model/channelmanager.h"
channel_model="src/model/channel.h"
channel_list_model="src/model/channellistmodel.h"
chat_view="src/qml/irc/ChatView.qml"
chat_qml="src/qml/irc/Chat.qml"
viewer_list="src/qml/irc/ViewerList.qml"
games_view="src/qml/GamesView.qml"
info_drawer="src/qml/components/InfoDrawer.qml"
grid_tooltip="src/qml/components/GridTooltip.qml"
game_model="src/model/game.h"
game_list_model="src/model/gamelistmodel.h"
irc_chat="src/model/ircchat.h"
network_manager="src/network/networkmanager.cpp"
network_manager_header="src/network/networkmanager.h"
vod_manager="src/model/vodmanager.cpp"
get_stream_block=$(sed -n '/void NetworkManager::getStream/,/^}/p' "$network_manager")
search_channels_block=$(sed -n '/void NetworkManager::searchChannels/,/^}/p' "$network_manager")
search_games_block=$(sed -n '/void NetworkManager::searchGames/,/^}/p' "$network_manager")
get_streams_for_language_block=$(sed -n '/void NetworkManager::getStreamsForLanguage/,/^}/p' "$network_manager")
get_streams_for_game_block=$(sed -n '/void NetworkManager::getStreamsForGame(/,/^}/p' "$network_manager")
get_streams_for_game_id_block=$(sed -n '/void NetworkManager::getStreamsForGameId/,/^}/p' "$network_manager")
get_channel_playback_block=$(sed -n '/void NetworkManager::getChannelPlaybackStream/,/^}/p' "$network_manager")
get_broadcasts_block=$(sed -n '/void NetworkManager::getBroadcasts/,/^}/p' "$network_manager")
broadcasts_reply_block=$(sed -n '/void NetworkManager::broadcastsReply/,/^}/p' "$network_manager")
get_broadcast_playback_block=$(sed -n '/void NetworkManager::getBroadcastPlaybackStream/,/^}/p' "$network_manager")
get_user_block=$(sed -n '/void NetworkManager::getUser/,/^}/p' "$network_manager")
user_reply_block=$(sed -n '/void NetworkManager::userReply/,/^}/p' "$network_manager")
get_user_favourites_block=$(sed -n '/void NetworkManager::getUserFavourites/,/^}/p' "$network_manager")
load_chatter_block=$(sed -n '/void NetworkManager::loadChatterList/,/^}/p' "$network_manager")
helix_chatter_block=$(sed -n '/void NetworkManager::requestHelixChatterList/,/^}/p' "$network_manager")
legacy_chatter_block=$(sed -n '/void NetworkManager::loadLegacyChatterList/,/^}/p' "$network_manager")
chatter_reply_block=$(sed -n '/void NetworkManager::chatterListReply/,/^}/p' "$network_manager")
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
vod_search_finished_block=$(sed -n '/void VodManager::onSearchFinished/,/^}/p' "$vod_manager")
vod_search_failed_block=$(sed -n '/void VodManager::onSearchFailed/,/^}/p' "$vod_manager")
vod_get_broadcasts_block=$(sed -n '/void VodManager::getBroadcasts/,/^}/p' "$vod_manager")
load_channel_badges_block=$(sed -n '/bool BadgeContainer::loadChannelBetaBadgeUrls/,/^}/p' "$badge_container")
load_channel_bits_block=$(sed -n '/bool BadgeContainer::loadChannelBitsUrls/,/^}/p' "$badge_container")
load_channel_bttv_block=$(sed -n '/bool BadgeContainer::loadChannelBttvEmotes/,/^}/p' "$badge_container")
load_channel_ffz_block=$(sed -n '/bool BadgeContainer::loadChannelFfzEmotes/,/^}/p' "$badge_container")
badge_canonical_block=$(sed -n '/QString BadgeImageProvider::getCanonicalKey/,/^}/p' "$badge_image_provider")
badge_url_block=$(sed -n '/const QUrl BadgeImageProvider::getUrlForKey/,/^}/p' "$badge_image_provider")
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

if ! rg -q 'www\.twitch\.tv/videos' src/qml/irc/Chat.qml \
    || ! rg -q 'Util\.twitchVodTimestamp\(startPos\)' src/qml/irc/Chat.qml; then
    printf 'VOD replay-chat fallback notices must include a timestamped direct Twitch VOD URL.\n' >&2
    fail=1
fi

for required_app_token_token in \
    'ORION_TWITCH_CLIENT_SECRET' \
    'https://id\.twitch\.tv/oauth2/token' \
    'grant_type", "client_credentials' \
    'appAccessTokenReply' \
    'appAccessTokenRefresh' \
    'requestAppAccessToken\(true\)' \
    '\(!refresh && !app_access_token.isEmpty\(\)\)' \
    'json.value\("expires_in"\).toInt\(\)' \
    'qMin\(expiresIn - 300, 24 \* 60 \* 60\)'
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

for required_language_token in \
    'channel->setLanguage(jsonObj["language"].toString())' \
    'channel->setLanguage(jsonObj["broadcaster_language"].toString())' \
    'channel->setLanguage(json["broadcaster_language"].toString())' \
    'roles[LanguageRole] = "language";' \
    'language: model.language' \
    'language: channel.language' \
    'item.language.toUpperCase()' \
    'Language " + html(channel.language.toUpperCase())'
do
    if ! rg -q -F "$required_language_token" "$json_parser" src/model/channellistmodel.cpp src/qml/components/ChannelGrid.qml src/qml/util.js "$info_drawer" "$grid_tooltip"; then
        printf 'Helix stream/channel language parsing and display is missing token: %s\n' "$required_language_token" >&2
        fail=1
    fi
done

for required_language_network_token in \
    'void getStreamsForGame(const QString&, const quint32&, const quint32&, const QString &language = QString());' \
    'QMap<quint32, QString> languageStreamsPageCursors;' \
    'void getStreamsForGameId(const QString &gameId, const quint32 offset, const quint32 limit, const QString &language = QString());'
do
    if ! rg -q -F "$required_language_network_token" "$network_manager_header"; then
        printf 'NetworkManager header must expose Helix language stream search support: %s\n' "$required_language_network_token" >&2
        fail=1
    fi
done

for required_language_stream_token in \
    'const QString normalizedLanguage = language.trimmed().toLower();' \
    'if (normalizedLanguage.isEmpty())' \
    'requireHelixAccessToken("Language stream search")' \
    'languageStreamsPageCursors.clear();' \
    'lastLanguageStreamsQuery = normalizedLanguage;' \
    'query.addQueryItem("language", normalizedLanguage);' \
    'request.setAttribute(RequestContextAttribute1, pageSize);' \
    'connect(reply, &QNetworkReply::finished, this, &NetworkManager::gameStreamsReply);'
do
    if ! printf '%s\n' "$get_streams_for_language_block" | rg -q -F "$required_language_stream_token"; then
        printf 'NetworkManager::getStreamsForLanguage must use current Helix language search semantics: %s\n' "$required_language_stream_token" >&2
        fail=1
    fi
done

for required_game_language_token in \
    'const QString normalizedLanguage = language.trimmed().toLower();' \
    'const QString queryKey = gameName + "\n" + normalizedLanguage;' \
    'getStreamsForGameId(gameId, offset, pageSize, normalizedLanguage);' \
    'request.setAttribute(RequestContextAttribute3, normalizedLanguage);'
do
    if ! printf '%s\n' "$get_streams_for_game_block" | rg -q -F "$required_game_language_token"; then
        printf 'NetworkManager::getStreamsForGame must carry game language filters through lookup: %s\n' "$required_game_language_token" >&2
        fail=1
    fi
done

for required_game_id_language_token in \
    'const QString normalizedLanguage = language.trimmed().toLower();' \
    'if (!normalizedLanguage.isEmpty())' \
    'query.addQueryItem("language", normalizedLanguage);'
do
    if ! printf '%s\n' "$get_streams_for_game_id_block" | rg -q -F "$required_game_id_language_token"; then
        printf 'NetworkManager::getStreamsForGameId must add Helix language filters to game streams: %s\n' "$required_game_id_language_token" >&2
        fail=1
    fi
done

for required_language_reply_token in \
    'const bool isHelixLanguageStreams = isHelixStreams && query.hasQueryItem("language") && !query.hasQueryItem("game_id");' \
    'if (isHelixGameStreams || isHelixLanguageStreams)' \
    'languageStreamsPageCursors.insert(nextOffset, out.cursor);' \
    'const QString language = reply->request().attribute(RequestContextAttribute3).toString();' \
    'getStreamsForGameId(gameId, offset, limit, language);'
do
    if ! rg -q -F "$required_language_reply_token" "$network_manager"; then
        printf 'NetworkManager stream replies must preserve language pagination and game lookup context: %s\n' "$required_language_reply_token" >&2
        fail=1
    fi
done

for required_language_command_token in \
    'game.lastIndexOf(" /language ", -1, Qt::CaseInsensitive)' \
    'game.lastIndexOf(" /lang ", -1, Qt::CaseInsensitive)' \
    'language = game.mid(languageIndex + languagePrefixLength).trimmed();' \
    'game = game.left(languageIndex).trimmed();' \
    'netman->getStreamsForGame(game, offset, limit, language);' \
    'query.startsWith("/language ") || query.startsWith("/lang ")' \
    "query.section(' ', 1).trimmed()" \
    'netman->getStreamsForLanguage(language, offset, limit);'
do
    if ! printf '%s\n' "$channel_manager_search_channels_block" | rg -q -F "$required_language_command_token"; then
        printf 'ChannelManager search commands must route language filters correctly: %s\n' "$required_language_command_token" >&2
        fail=1
    fi
done

for required_games_language_token in \
    'property var languageCodes:' \
    'property var languageNames:' \
    'text: "Stream language"' \
    'model: root.languageNames' \
    'var language = languageOption.currentIndex >= 0 ? languageCodes[languageOption.currentIndex] : ""' \
    'query += " /language " + language'
do
    if ! rg -q -F "$required_games_language_token" "$games_view"; then
        printf 'GamesView must expose and apply the stream-language selector: %s\n' "$required_games_language_token" >&2
        fail=1
    fi
done

if ! rg -q -F '/language en' README.md; then
    printf 'README must document the language search command.\n' >&2
    fail=1
fi

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

for required_low_latency_token in \
    'Q_PROPERTY(bool lowLatencyPlayback READ lowLatencyPlayback WRITE setLowLatencyPlayback NOTIFY lowLatencyPlaybackChanged)' \
    'setLowLatencyPlayback(settings.value("lowLatencyPlayback", mLowLatencyPlayback).toBool());' \
    'settings.setValue("lowLatencyPlayback", lowLatencyPlayback);' \
    'checked: Settings.lowLatencyPlayback' \
    'onClicked: Settings.lowLatencyPlayback = checked' \
    'if (SettingsManager::getInstance()->lowLatencyPlayback())' \
    'query.addQueryItem("fast_bread", "true");' \
    'liveStreamActive = start < 0' \
    'configureLowLatencyProfile(liveStreamActive && Settings.lowLatencyPlayback)' \
    'renderer.setOption("profile-restore", "copy")' \
    'renderer.command(["apply-profile", "low-latency"])' \
    'renderer.command(["apply-profile", "low-latency", "restore"])' \
    'property bool lowLatencyProfileApplied: false' \
    'onLowLatencyPlaybackChanged: configureLowLatencyProfile(liveStreamActive && Settings.lowLatencyPlayback)'
do
    if ! rg -q -F "$required_low_latency_token" \
        src/model/settingsmanager.h \
        src/model/settingsmanager.cpp \
        src/qml/OptionsView.qml \
        src/qml/MpvBackend.qml \
        src/util/jsonparser.cpp; then
        printf 'Low-latency playback contract token is required: %s\n' "$required_low_latency_token" >&2
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
    || ! printf '%s\n' "$get_broadcasts_block" | rg -q 'emit broadcastsOperationFailed\(channelId, offset, videoType, requestId\)' \
    || ! printf '%s\n' "$get_broadcasts_block" | rg -q 'request\.setAttribute\(RequestContextAttribute2, channelId\)' \
    || ! printf '%s\n' "$get_broadcasts_block" | rg -q 'request\.setAttribute\(RequestContextAttribute3, videoType\)' \
    || ! printf '%s\n' "$get_broadcasts_block" | rg -q 'request\.setAttribute\(RequestContextAttribute4, requestId\)' \
    || ! printf '%s\n' "$get_broadcasts_block" | rg -q 'emit broadcastsOperationFinished\(empty, channelId, offset, videoType, requestId\)'; then
    printf 'VOD listing requests must reject zero channel ids before calling Helix.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$broadcasts_reply_block" | rg -q 'const quint64 channelId = reply->request\(\)\.attribute\(RequestContextAttribute2\)\.toULongLong\(\)' \
    || ! printf '%s\n' "$broadcasts_reply_block" | rg -q 'const QString type = reply->request\(\)\.attribute\(RequestContextAttribute3\)\.toString\(\)' \
    || ! printf '%s\n' "$broadcasts_reply_block" | rg -q 'const quint64 requestId = reply->request\(\)\.attribute\(RequestContextAttribute4\)\.toULongLong\(\)' \
    || ! printf '%s\n' "$broadcasts_reply_block" | rg -q 'emit broadcastsOperationFailed\(channelId, offset, type, requestId\)' \
    || ! printf '%s\n' "$broadcasts_reply_block" | rg -q 'emit broadcastsOperationFinished\(result\.items, channelId, offset, type, requestId\)'; then
    printf 'VOD listing replies must carry channel/type/offset/search context for stale-reply rejection.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$vod_search_block" | rg -q 'if \(channelId == 0\)' \
    || ! printf '%s\n' "$vod_search_block" | rg -q '_model->clear\(\)' \
    || ! printf '%s\n' "$vod_search_block" | rg -q 'emit searchFailed\(\)'; then
    printf 'VodManager::search must reject zero channel ids and end the QML loading state.\n' >&2
    fail=1
fi

if ! rg -q 'bool VodManager::isCurrentSearch\(quint64 channelId, const QString &type, quint64 requestId\) const' "$vod_manager" \
    || ! rg -q 'currentSearchRequestId' "$vod_manager" \
    || ! printf '%s\n' "$vod_search_block" | rg -q '\+\+currentSearchRequestId' \
    || ! printf '%s\n' "$vod_search_block" | rg -q 'netman->getBroadcasts\(channelId, offset, limit, videoType, currentSearchRequestId\)' \
    || ! printf '%s\n' "$vod_search_finished_block" | rg -q '!isCurrentSearch\(channelId, type, requestId\)' \
    || ! printf '%s\n' "$vod_search_finished_block" | rg -q 'Ignoring stale VOD listing reply' \
    || ! printf '%s\n' "$vod_search_finished_block" | rg -q 'qDeleteAll\(items\)' \
    || ! printf '%s\n' "$vod_search_finished_block" | rg -q '_model->mergePage\(items, offset\)' \
    || ! printf '%s\n' "$vod_search_failed_block" | rg -q '!isCurrentSearch\(channelId, type, requestId\)' \
    || ! printf '%s\n' "$vod_search_failed_block" | rg -q 'Ignoring stale failed VOD listing reply'; then
    printf 'VodManager must ignore stale VOD listing replies after channel/type/search-generation changes.\n' >&2
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

for required_network_error_token in \
    'QString networkReplyErrorMessage(QNetworkReply *reply)' \
    'QNetworkRequest::HttpStatusCodeAttribute' \
    'QJsonDocument::fromJson(body, &parseError)' \
    'object.value(QStringLiteral("message")).toString()' \
    'qDebug().noquote() << message'
do
    if ! rg -qF "$required_network_error_token" "$network_manager"; then
        printf 'Network errors must include HTTP status and API response details when available: %s\n' "$required_network_error_token" >&2
        fail=1
    fi
done

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

if ! rg -q '"moderator:read:chatters"' src/qml/OptionsView.qml \
    || ! rg -q 'encodeURIComponent\(twitchLoginScopes\(\).join\(" "\)\)' src/qml/OptionsView.qml; then
    printf 'OAuth login must request moderator:read:chatters through the structured scope list for Helix viewer-list support.\n' >&2
    fail=1
fi

if ! rg -q 'moderator:read:chatters' README.md \
    || ! rg -q 'legacy TMI chatters endpoint' README.md; then
    printf 'README must document Helix viewer-list scope requirements and legacy TMI fallback behavior.\n' >&2
    fail=1
fi

if ! rg -q 'Q_INVOKABLE quint64 getUser_id\(\) const;' "$channel_manager_header"; then
    printf 'ChannelManager must expose the logged-in user ID to QML for Helix viewer-list requests.\n' >&2
    fail=1
fi

if ! rg -qF 'Viewers.loadChatterList(chat.channel, chat.channelId || 0, ChannelManager.getUser_id())' "$viewer_list"; then
    printf 'ViewerList must pass broadcaster and moderator user IDs to viewer-list loading.\n' >&2
    fail=1
fi

for required_viewer_reload_token in \
    'property string loadedRequestKey' \
    'function viewerRequestKey()' \
    'function scheduleReload()' \
    'Qt.callLater(reload)' \
    'onChannelChanged: root.scheduleReload()' \
    'onChannelIdChanged: root.scheduleReload()'
do
    if ! rg -qF "$required_viewer_reload_token" "$viewer_list"; then
        printf 'ViewerList must reload when the visible chat channel context changes: %s\n' "$required_viewer_reload_token" >&2
        fail=1
    fi
done

if ! rg -q 'loadChatterList\(const QString channel, const quint64 broadcasterId = 0, const quint64 moderatorId = 0\)' "$network_manager_header" \
    || ! rg -q 'quint64 chatterListRequestId = 0;' "$network_manager_header" \
    || ! printf '%s\n' "$load_chatter_block" | rg -q 'broadcasterId != 0' \
    || ! printf '%s\n' "$load_chatter_block" | rg -q 'moderatorId != 0' \
    || ! printf '%s\n' "$load_chatter_block" | rg -q '!access_token\.isEmpty\(\)' \
    || ! printf '%s\n' "$load_chatter_block" | rg -q 'access_token_scopes\.contains\(QStringLiteral\("moderator:read:chatters"\)\)' \
    || ! printf '%s\n' "$load_chatter_block" | rg -q 'const quint64 requestId = \+\+chatterListRequestId' \
    || ! printf '%s\n' "$load_chatter_block" | rg -q 'requestHelixChatterList\(normalizedChannel, broadcasterId, moderatorId, requestId\)' \
    || ! printf '%s\n' "$load_chatter_block" | rg -q 'loadLegacyChatterList\(normalizedChannel, requestId\)'; then
    printf 'Viewer-list loading must prefer Helix when logged-in IDs are available, keep legacy fallback, and tag requests for stale-reply rejection.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$helix_chatter_block" | rg -q '/chat/chatters' \
    || ! printf '%s\n' "$helix_chatter_block" | rg -q 'query\.addQueryItem\("broadcaster_id", QString::number\(broadcasterId\)\)' \
    || ! printf '%s\n' "$helix_chatter_block" | rg -q 'query\.addQueryItem\("moderator_id", QString::number\(moderatorId\)\)' \
    || ! printf '%s\n' "$helix_chatter_block" | rg -q 'query\.addQueryItem\("first", "1000"\)' \
    || ! printf '%s\n' "$helix_chatter_block" | rg -q 'addHelixHeaders\(request, HelixAuthMode::UserOnly\)' \
    || ! printf '%s\n' "$helix_chatter_block" | rg -q 'setAttribute\(RequestContextAttribute4, requestId\)'; then
    printf 'Helix viewer-list requests must use Get Chatters with user auth, maximum documented page size, and request IDs.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$legacy_chatter_block" | rg -q 'TWITCH_TMI_USER_API' \
    || ! printf '%s\n' "$legacy_chatter_block" | rg -q 'QUrl::toPercentEncoding\(channel\)' \
    || ! printf '%s\n' "$legacy_chatter_block" | rg -q 'setAttribute\(RequestContextAttribute4, requestId\)'; then
    printf 'Legacy viewer-list fallback must preserve the old TMI path with encoded channel names and request IDs.\n' >&2
    fail=1
fi

if ! rg -q 'parseHelixChatterListPage' "$json_parser_header" "$json_parser" \
    || ! printf '%s\n' "$chatter_reply_block" | rg -q 'requestId != chatterListRequestId' \
    || ! printf '%s\n' "$chatter_reply_block" | rg -q 'Ignoring stale viewer-list reply' \
    || ! printf '%s\n' "$chatter_reply_block" | rg -q 'JsonParser::parseHelixChatterListPage\(data\)' \
    || ! printf '%s\n' "$chatter_reply_block" | rg -q 'pendingHelixChatters\.append\(result\.items\)' \
    || ! printf '%s\n' "$chatter_reply_block" | rg -q 'requestHelixChatterList\(channel, broadcasterId, moderatorId, requestId, result\.cursor\)' \
    || ! printf '%s\n' "$chatter_reply_block" | rg -q 'loadLegacyChatterList\(channel, requestId\)'; then
    printf 'Viewer-list replies must reject stale replies, parse/paginate Helix Get Chatters, and fall back when Helix is unavailable.\n' >&2
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

if ! rg -q 'static QString badgeKey\(const QString &badgeName, const QString &version\);' src/model/badgeimageprovider.h \
    || ! rg -q 'QUrl::toPercentEncoding\(value, QByteArray\(\), "-"\)' "$badge_image_provider" \
    || ! rg -q 'QUrl::fromPercentEncoding\(value\.toLatin1\(\)\)' "$badge_image_provider" \
    || ! rg -q 'BadgeImageProvider::badgeKey\(badgeName, version\)' src/model/ircchat.cpp \
    || ! rg -q 'function getBadgeLocalUrl\(badgeName, version\)' "$chat_qml" \
    || ! rg -q 'chat\.getBadgeLocalUrl\(badgeName, version\)' "$chat_qml" \
    || ! rg -q 'chat\.getBadgeLocalUrl\(badgeName, versionStr\)' "$chat_view"; then
    printf 'Badge image keys must percent-encode badge/version components before joining them.\n' >&2
    fail=1
fi

if ! printf '%s\n' "$badge_canonical_block" | rg -q 'key\.split\("-"\)' \
    || printf '%s\n' "$badge_canonical_block" | rg -q 'key\.indexOf\("-"\)' \
    || ! printf '%s\n' "$badge_url_block" | rg -q 'badgeKeyPartValue\(parts\.at\(1\)\)' \
    || ! printf '%s\n' "$badge_url_block" | rg -q 'badgeKeyPartValue\(parts\.at\(2\)\)'; then
    printf 'Badge image providers must preserve hyphenated Twitch badge set IDs.\n' >&2
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
