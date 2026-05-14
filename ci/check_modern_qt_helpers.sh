#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
json_parser="$repo_dir/src/util/jsonparser.cpp"
parse_game_results_block=$(sed -n '/PagedResult<Game\*> JsonParser::parseGameResults/,/^}/p' "$json_parser")
game_find_block=$(sed -n '/Game \*GameListModel::find/,/^}/p' "$repo_dir/src/model/gamelistmodel.cpp")
game_add_all_block=$(sed -n '/void GameListModel::addAll/,/^}/p' "$repo_dir/src/model/gamelistmodel.cpp")
game_add_game_block=$(sed -n '/void GameListModel::addGame/,/^}/p' "$repo_dir/src/model/gamelistmodel.cpp")
vod_find_block=$(sed -n '/Vod \*VodListModel::find/,/^}/p' "$repo_dir/src/model/vodlistmodel.cpp")
channel_add_block=$(sed -n '/void ChannelListModel::addChannel/,/^}/p' "$repo_dir/src/model/channellistmodel.cpp")
channel_update_stream_block=$(sed -n '/bool ChannelListModel::updateStream/,/^}/p' "$repo_dir/src/model/channellistmodel.cpp")
channel_manager_check_streams_block=$(sed -n '/void ChannelManager::checkStreams/,/^}/p' "$repo_dir/src/model/channelmanager.cpp")
channel_manager_channel_ids_block=$(sed -n '/QString commaSeparatedChannelIds/,/^}/p' "$repo_dir/src/model/channelmanager.cpp")
channel_manager_add_favourite_full_block=$(sed -n '/void ChannelManager::addToFavourites(const quint32 &id, const QString &serviceName/,/^}/p' "$repo_dir/src/model/channelmanager.cpp")
channel_manager_add_favourite_id_block=$(sed -n '/void ChannelManager::addToFavourites(const quint32 &id)/,/^}/p' "$repo_dir/src/model/channelmanager.cpp")
channel_manager_remove_favourite_block=$(sed -n '/void ChannelManager::removeFromFavourites/,/^}/p' "$repo_dir/src/model/channelmanager.cpp")
channel_manager_add_search_results_block=$(sed -n '/void ChannelManager::addSearchResults/,/^}/p' "$repo_dir/src/model/channelmanager.cpp")
channel_manager_update_favourites_block=$(sed -n '/void ChannelManager::updateFavourites/,/^}/p' "$repo_dir/src/model/channelmanager.cpp")
channel_manager_notify_multiple_block=$(sed -n '/void ChannelManager::notifyMultipleChannelsOnline/,/^}/p' "$repo_dir/src/model/channelmanager.cpp")
channel_manager_add_followed_results_block=$(sed -n '/void ChannelManager::addFollowedResults/,/^}/p' "$repo_dir/src/model/channelmanager.cpp")
vod_add_all_block=$(sed -n '/void VodListModel::addAll/,/^}/p' "$repo_dir/src/model/vodlistmodel.cpp")
vod_merge_page_block=$(sed -n '/void VodListModel::mergePage/,/^}/p' "$repo_dir/src/model/vodlistmodel.cpp")

if rg -n '\bforeach\s*\(' "$repo_dir/src"; then
    printf 'src must use range-based loops instead of Qt foreach.\n' >&2
    exit 1
fi

if rg -n '\b(NULL|Q_NULLPTR)\b' "$repo_dir/src"; then
    printf 'src must use nullptr/FALSE instead of legacy null macros.\n' >&2
    exit 1
fi

if rg -n 'Q_ASSERT\((0|false)\)' "$repo_dir/src"; then
    printf 'Unreachable code paths must use Q_UNREACHABLE() instead of release-noop Q_ASSERT constants.\n' >&2
    exit 1
fi

if rg -n '\b(Q_OS_MAC|Q_OS_OSX|Q_WS_MAC)\b' "$repo_dir/src"; then
    printf 'src must use Q_OS_MACOS for macOS-specific code instead of deprecated Qt platform macros.\n' >&2
    exit 1
fi

if rg -n 'QtWebKit|QtWebKitWidgets|QWebView|QWebPage' "$repo_dir/src"; then
    printf 'src must not reintroduce legacy QtWebKit dependencies.\n' >&2
    exit 1
fi

if rg -n '\((MpvObject|QTcpSocket|QRgb)\s*\* ?\)|\((uint64_t|M3U8TYPE)\)' \
    "$repo_dir/src/player/mpvobject.cpp" \
    "$repo_dir/src/network/httpserver.cpp" \
    "$repo_dir/src/network/networkmanager.cpp" \
    "$repo_dir/src/notification/notificationsender.cpp"; then
    printf 'Modernized C++ code must use named casts or qobject_cast instead of legacy C-style casts.\n' >&2
    exit 1
fi

if rg -n '\.toStdString\(\)\.c_str\(\)' "$repo_dir/src"; then
    printf 'src must write Qt strings through explicit Qt byte arrays instead of temporary std::string c_str pointers.\n' >&2
    exit 1
fi

if rg -n '\*\s*[A-Za-z_][A-Za-z0-9_]*\s*=\s*0\s*(;|,|\))|\*\s*parent\s*=\s*0\b' "$repo_dir/src"; then
    printf 'Pointer declarations and default arguments must use nullptr instead of 0.\n' >&2
    exit 1
fi

if rg -n 'QVariant::Type|\.type\(\)' "$repo_dir/src/player/qthelper.hpp"; then
    printf 'qthelper.hpp must use QVariant::userType() for Qt meta-type checks.\n' >&2
    exit 1
fi

if rg -n '\.(setAttribute|attribute)\(static_cast<QNetworkRequest::Attribute>\(QNetworkRequest::User \+' "$repo_dir/src/network"; then
    printf 'Network request context must use named request attributes instead of inline QNetworkRequest::User offsets.\n' >&2
    exit 1
fi

if ! rg -q 'bytesWritten == data\.size\(\) && file\.flush\(\)' "$repo_dir/src/util/fileutils.cpp"; then
    printf 'File write helpers must verify full writes and flush success.\n' >&2
    exit 1
fi

if rg -Uq 'file\.write\(data\);\s*return true;' "$repo_dir/src/util/fileutils.cpp"; then
    printf 'File write helpers must not report success without checking write results.\n' >&2
    exit 1
fi

if rg -q 'writeImage|std::ofstream|FILE \*data' "$repo_dir/src/util/fileutils.cpp" "$repo_dir/src/util/fileutils.h"; then
    printf 'fileutils must not keep the unused writeImage(FILE*) helper that wrote pointer values.\n' >&2
    exit 1
fi

if ! rg -q 'Favourite channel settings sync failed with status' "$repo_dir/src/model/channelmanager.cpp"; then
    printf 'ChannelManager must warn when favourite channel settings fail to sync.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$parse_game_results_block" | rg -q 'delete game;'; then
    printf 'JsonParser must delete ignored game result objects instead of leaking them.\n' >&2
    exit 1
fi

if ! rg -q 'int total = 0;' "$repo_dir/src/util/jsonparser.h"; then
    printf 'Paged JSON parse results must default total to zero for failed or partial responses.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$game_find_block" | rg -q 'return nullptr;'; then
    printf 'GameListModel::find must return nullptr for missing games.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$game_add_all_block" | rg -q 'newItems\.append\(game\)' \
    || ! printf '%s\n' "$game_add_all_block" | rg -q 'newItems\.size\(\)'; then
    printf 'GameListModel::addAll must insert only filtered non-null game pointers.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$game_add_game_block" | rg -q 'if \(!game\)'; then
    printf 'GameListModel::addGame must ignore null game pointers.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$vod_find_block" | rg -q 'return nullptr;'; then
    printf 'VodListModel::find must return nullptr for missing VODs.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$channel_add_block" | rg -q 'find\(channel->getId\(\)\) != channel'; then
    printf 'ChannelListModel::addChannel must not delete an already-owned channel pointer.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$channel_add_block" | rg -q 'delete channel;'; then
    printf 'ChannelListModel::addChannel must delete duplicate input channels after updating existing rows.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$channel_update_stream_block" | rg -q 'if \(!item\)'; then
    printf 'ChannelListModel::updateStream must ignore null stream update items.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$channel_manager_check_streams_block" | rg -q 'validChannels\.append\(channel\)' \
    || ! printf '%s\n' "$channel_manager_check_streams_block" | rg -q 'validChannels\.isEmpty\(\)' \
    || ! printf '%s\n' "$channel_manager_check_streams_block" | rg -q 'channel && channel->getId\(\)'; then
    printf 'ChannelManager::checkStreams must filter null or id-less channels before building Helix requests.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$channel_manager_add_search_results_block" | rg -q '!channel \|\| !channel->getId\(\)' \
    || ! printf '%s\n' "$channel_manager_add_search_results_block" | rg -q 'validChannels\.append\(channel\)' \
    || ! printf '%s\n' "$channel_manager_add_search_results_block" | rg -q 'resultsModel->addAll\(validChannels\)' \
    || ! printf '%s\n' "$channel_manager_add_search_results_block" | rg -q 'checkStreams\(validChannels\)'; then
    printf 'ChannelManager::addSearchResults must filter null or id-less channel results before model updates and stream checks.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$channel_manager_channel_ids_block" | rg -q 'if \(channel\)'; then
    printf 'Channel ID formatting must skip null channel pointers.\n' >&2
    exit 1
fi

for block in \
    "$channel_manager_add_favourite_full_block" \
    "$channel_manager_add_favourite_id_block" \
    "$channel_manager_remove_favourite_block"
do
    if ! printf '%s\n' "$block" | rg -q 'if \(id == 0\)'; then
        printf 'ChannelManager favourite operations must reject id 0.\n' >&2
        exit 1
    fi
done

if ! printf '%s\n' "$channel_manager_update_favourites_block" | rg -q '!c \|\| !c->getId\(\)' \
    || ! printf '%s\n' "$channel_manager_update_favourites_block" | rg -q 'validChannels\.append\(c\)' \
    || ! printf '%s\n' "$channel_manager_update_favourites_block" | rg -q 'favouritesModel->updateChannels\(validChannels\)'; then
    printf 'ChannelManager::updateFavourites must filter null or id-less channel pointers before updating favourites.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$channel_manager_notify_multiple_block" | rg -q 'if \(!c\)' \
    || ! printf '%s\n' "$channel_manager_notify_multiple_block" | rg -q '!str\.isEmpty\(\)'; then
    printf 'ChannelManager::notifyMultipleChannelsOnline must skip null channels and avoid empty notifications.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$channel_manager_add_followed_results_block" | rg -q '!c \|\| !c->getId\(\)' \
    || ! printf '%s\n' "$channel_manager_add_followed_results_block" | rg -q 'validChannels\.append\(c\)' \
    || ! printf '%s\n' "$channel_manager_add_followed_results_block" | rg -q 'favouritesModel->mergeAll\(validChannels\)' \
    || ! printf '%s\n' "$channel_manager_add_followed_results_block" | rg -q 'checkStreams\(validChannels\)'; then
    printf 'ChannelManager::addFollowedResults must filter null or id-less followed-channel results before model updates and stream checks.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$vod_add_all_block" | rg -q 'if \(!vod\)'; then
    printf 'VodListModel::addAll must skip null incoming VOD pointers.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$vod_merge_page_block" | rg -q 'newItems\.append\(vod\)' \
    || ! printf '%s\n' "$vod_merge_page_block" | rg -q 'newItems\.isEmpty\(\)' \
    || ! printf '%s\n' "$vod_merge_page_block" | rg -q 'newItems\.size\(\)'; then
    printf 'VodListModel::mergePage must insert only filtered non-null VOD pointers.\n' >&2
    exit 1
fi

required_override_lines=(
    "$repo_dir/src/model/channellistmodel.h|Qt::ItemFlags flags(const QModelIndex &index) const override;"
    "$repo_dir/src/model/gamelistmodel.h|Qt::ItemFlags flags(const QModelIndex &index) const override;"
    "$repo_dir/src/model/vodlistmodel.h|Qt::ItemFlags flags(const QModelIndex &index) const override;"
    "$repo_dir/src/model/imageprovider.h|QImage requestImage(const QString &id, QSize * size, const QSize & requestedSize) override;"
    "$repo_dir/src/model/badgeimageprovider.h|QString getCanonicalKey(QString key) override;"
    "$repo_dir/src/player/mpvobject.h|Renderer *createRenderer() const override;"
    "$repo_dir/src/player/mpvobject.h|bool event(QEvent *event) override;"
    "$repo_dir/src/player/mpvobject.cpp|void render() override"
)

for entry in "${required_override_lines[@]}"; do
    file=${entry%%|*}
    line=${entry#*|}
    if ! rg -Fq "$line" "$file"; then
        printf 'Missing expected C++ override annotation in %s: %s\n' "$file" "$line" >&2
        exit 1
    fi
done

model_data_sources=(
    "$repo_dir/src/model/channellistmodel.cpp|index.column() != 0 || index.row() < 0 || index.row() >= channels.size()"
    "$repo_dir/src/model/gamelistmodel.cpp|index.column() != 0 || index.row() < 0 || index.row() >= games.size()"
    "$repo_dir/src/model/vodlistmodel.cpp|index.column() != 0 || index.row() < 0 || index.row() >= vods.size()"
    "$repo_dir/src/model/channellistmodel.cpp|if (!index.isValid())"
    "$repo_dir/src/model/gamelistmodel.cpp|if (!index.isValid())"
    "$repo_dir/src/model/vodlistmodel.cpp|if (!index.isValid())"
    "$repo_dir/src/model/channellistmodel.cpp|if (parent.isValid())"
    "$repo_dir/src/model/gamelistmodel.cpp|if (parent.isValid())"
    "$repo_dir/src/model/vodlistmodel.cpp|if (parent.isValid())"
    "$repo_dir/src/model/channellistmodel.cpp|if (!channel)"
)

for entry in "${model_data_sources[@]}"; do
    file=${entry%%|*}
    guard=${entry#*|}
    if ! rg -Fq "$guard" "$file"; then
        printf 'Model data() must guard stale or out-of-range QModelIndex rows in %s.\n' "$file" >&2
        exit 1
    fi
done
