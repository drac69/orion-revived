#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
vods_view_qml="$repo_dir/src/qml/VodsView.qml"
player_view_qml="$repo_dir/src/qml/PlayerView.qml"
vod_manager="$repo_dir/src/model/vodmanager.cpp"
vod_list_model="$repo_dir/src/model/vodlistmodel.cpp"
vod_filter_model="$repo_dir/src/model/vodfilterproxymodel.cpp"
vod_filter_header="$repo_dir/src/model/vodfilterproxymodel.h"
json_parser="$repo_dir/src/util/jsonparser.cpp"

for required in \
    'function hasSelectedChannelId()' \
    'if (!hasSelectedChannelId()) {' \
    'selectedChannel = undefined' \
    'channelVodPositions = ({})' \
    'if (!channel || !channel.name || !vod || !vod._id)' \
    'var vod = vodsModel.itemAt(i)' \
    'if (vod) {' \
    'if (!selectedChannel || !item) {' \
    'if (selectedChannel && selectedChannel.name === channel && channelVodPositions)' \
    'position: channelVodPositions ? (channelVodPositions[model.id] || 0) : 0' \
    'if (g_tooltip && item)' \
    'if (hasSelectedChannelId() && !vodSearchInProgress'
do
    if ! rg -q -F "$required" "$vods_view_qml"; then
        printf 'VodsView must guard selected-channel and VOD item state before model access: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'property string selectedVodType: "archive"' \
    'property var vodTypeOptions: [' \
    '{ "label": "Highlights", "type": "highlight" }' \
    '{ "label": "Uploads", "type": "upload" }' \
    '{ "label": "All", "type": "" }' \
    'placeholderText: "Filter VOD metadata"' \
    'text: vodsModel.filterText' \
    'vodsModel.filterText = text' \
    'ToolTip.text: "Play filtered list"' \
    'playerView.startVodQueue(selectedChannel, vods, 0)' \
    'selectedVodType = vodTypeOptions[index].type' \
    'ToolTip.text: checked ? "Oldest first" : "Newest first"'
do
    if ! rg -q -F "$required" "$vods_view_qml"; then
        printf 'VodsView must expose VOD filter/type/reverse/queue controls: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)' \
    'Q_PROPERTY(bool oldestFirst READ oldestFirst WRITE setOldestFirst NOTIFY oldestFirstChanged)' \
    'Q_INVOKABLE QVariantMap itemAt(int row) const;' \
    'bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;' \
    'bool lessThan(const QModelIndex &left, const QModelIndex &right) const override;'
do
    if ! rg -q -F "$required" "$vod_filter_header"; then
        printf 'VodFilterProxyModel must expose filter, reverse-sort, and item lookup contracts: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'setDynamicSortFilter(true);' \
    'sort(0, Qt::DescendingOrder);' \
    'sort(0, mOldestFirst ? Qt::AscendingOrder : Qt::DescendingOrder);' \
    'out.insert(QStringLiteral("_id"), value);' \
    'model->data(sourceIndex, VodListModel::Description).toString()' \
    'model->data(sourceIndex, VodListModel::Language).toString()' \
    'model->data(sourceIndex, VodListModel::Type).toString()' \
    'model->data(sourceIndex, VodListModel::PublishedAt).toString()' \
    'model->data(sourceIndex, VodListModel::Url).toString()' \
    'QStringLiteral("muted ") + mutedSegments' \
    'mFilterText.split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts)' \
    'haystack.contains(token, Qt::CaseInsensitive)'
do
    if ! rg -q -F "$required" "$vod_filter_model"; then
        printf 'VodFilterProxyModel must filter/sort VOD metadata and muted sections: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'roles[Type] = "type";' \
    'roles[PublishedAt] = "publishedAt";' \
    'roles[Description] = "description";' \
    'roles[Language] = "language";' \
    'roles[Url] = "url";' \
    'roles[SeekPreviews] = "seekPreviews";' \
    'roles[MutedSegments] = "mutedSegments";' \
    'roles[MutedSegmentRanges] = "mutedSegmentRanges";'
do
    if ! rg -q -F "$required" "$vod_list_model"; then
        printf 'VodListModel must expose supported Helix VOD metadata roles: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'vod->setDescription(json["description"].toString());' \
    'vod->setLanguage(json["language"].toString());' \
    'vod->setType(json["type"].toString());' \
    'vod->setPublishedAt(json["published_at"].toString());' \
    'vod->setUrl(json["url"].toString());' \
    'if (json["muted_segments"].isArray())' \
    'segment.contains("offset")' \
    'segment.contains("duration")' \
    'vod->setMutedSegments(segments.join(", "));' \
    'vod->setMutedSegmentRanges(ranges.join(";"));'
do
    if ! rg -q -F "$required" "$json_parser"; then
        printf 'JsonParser must preserve current Helix VOD metadata and muted segments: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    '++currentSearchRequestId;' \
    'currentSearchType = videoType;' \
    'loadCachedVods(channelId, videoType);' \
    'netman->getBroadcasts(channelId, offset, limit, videoType, currentSearchRequestId);' \
    'bool VodManager::isCurrentSearch(quint64 channelId, const QString &type, quint64 requestId) const' \
    'currentSearchType == type.trimmed()' \
    'currentSearchRequestId == requestId' \
    'qDeleteAll(items);' \
    'saveCachedVods(currentSearchChannelId, currentSearchType);'
do
    if ! rg -q -F "$required" "$vod_manager"; then
        printf 'VodManager must tag VOD pages and reject stale channel/type replies: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'QString vodCacheKey(quint64 channelId, const QString &type)' \
    'settings.beginGroup("vodCache");' \
    'settings.beginGroup(vodCacheKey(channelId, type));' \
    'SettingsManager::getInstance()->vodCacheMaxAgeHours();' \
    'vod->setPublishedAt(settings.value("publishedAt").toString());' \
    'vod->setDescription(settings.value("description").toString());' \
    'vod->setLanguage(settings.value("language").toString());' \
    'vod->setUrl(settings.value("url").toString());' \
    'settings.setValue("publishedAt", _model->data(index, VodListModel::PublishedAt));' \
    'settings.setValue("description", _model->data(index, VodListModel::Description));' \
    'settings.setValue("language", _model->data(index, VodListModel::Language));' \
    'settings.setValue("url", _model->data(index, VodListModel::Url));' \
    'settings.setValue("mutedSegments", _model->data(index, VodListModel::MutedSegments));' \
    'settings.setValue("mutedSegmentRanges", _model->data(index, VodListModel::MutedSegmentRanges));' \
    'warnSettingsSyncFailure(settings, "VOD cache settings");'
do
    if ! rg -q -F "$required" "$vod_manager"; then
        printf 'VodManager must cache VOD pages by channel/type with preserved metadata: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'QString VodManager::playbackPositionSnapshotPath() const' \
    'QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)' \
    'return QDir(basePath).filePath(QStringLiteral("vod-progress.json"));' \
    'int VodManager::loadPlaybackPositionSnapshot()' \
    'doc.object().value(QStringLiteral("positions")).toArray();' \
    'vodMap.insert(vod, {lastPosition, true, -1});' \
    'void VodManager::savePlaybackPositionSnapshot() const' \
    'root.insert(QStringLiteral("version"), 1);' \
    'QSaveFile file(snapshotPath);' \
    'bytesWritten != snapshotData.size()' \
    'file.cancelWriting();' \
    'file.commit()'
do
    if ! rg -q -F "$required" "$vod_manager"; then
        printf 'VodManager must mirror VOD positions to an atomic snapshot: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'root.mutedSegmentRanges = parseMutedSegmentRanges(vod.mutedSegmentRanges)' \
    '"vodType": isVod ? vod.type : ""' \
    '"language": isVod ? (vod.language || "") : (channel.language || "")' \
    '"description": isVod ? vod.description : ""' \
    '"url": isVod ? vod.url : ""' \
    '"mutedSegments": isVod ? vod.mutedSegments : ""' \
    '"mutedSegmentRanges": isVod ? vod.mutedSegmentRanges : ""' \
    'visible: root.isVod && root.duration > 0 && root.mutedSegmentRanges.length > 0' \
    'visible: isVod && mutedSegmentRanges.length > 0' \
    'ToolTip.text: "Skip current muted section"' \
    'skipMutedSegment()'
do
    if ! rg -q -F "$required" "$player_view_qml"; then
        printf 'PlayerView must route VOD metadata and muted sections into playback controls: %s\n' "$required" >&2
        exit 1
    fi
done

for forbidden in \
    'if (selectedChannel.name === channel)' \
    'position: channelVodPositions[model.id] || 0' \
    'if (g_tooltip)'
do
    if rg -q -F "$forbidden" "$vods_view_qml"; then
        printf 'VodsView must not dereference selectedChannel/channelVodPositions or tooltip items without guards: %s\n' "$forbidden" >&2
        exit 1
    fi
done
