/*
 * Copyright © 2015-2016 Antti Lamminsalo
 *
 * This file is part of Orion.
 *
 * Orion is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * You should have received a copy of the GNU General Public License
 * along with Orion.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "vodmanager.h"
#include <QSettings>
#include <QCoreApplication>
#include <QDateTime>
#include <cmath>

namespace {
QString vodCacheKey(quint64 channelId, const QString &type)
{
    const QString normalizedType = type.trimmed().isEmpty() ? QStringLiteral("all") : type.trimmed();
    return QString::number(channelId) + QStringLiteral("_") + normalizedType;
}
}

VodManager::VodManager(QObject *parent) :
    QObject(parent),
    netman(NetworkManager::getInstance())
{
    qmlRegisterInterface<VodListModel>("VodListModel");
    _model = new VodListModel(this);
    _filteredModel = new VodFilterProxyModel(this);
    _filteredModel->setSourceModel(_model);

    connect(netman, &NetworkManager::broadcastsOperationFinished, this, &VodManager::onSearchFinished);
    connect(netman, &NetworkManager::broadcastsOperationFailed, this, &VodManager::onSearchFailed);
    connect(netman, &NetworkManager::m3u8OperationBFinished, this, &VodManager::streamsGetFinished);

    QSettings settings(QCoreApplication::organizationName(), QCoreApplication::applicationName());
    int numLastPositions = settings.beginReadArray("lastPositions");
    for (int i = 0; i < numLastPositions; i++) {
        settings.setArrayIndex(i);
        const QString channel = settings.value("channel").toString();
        const QString vod = settings.value("vod").toString();
        const quint64 lastPosition = settings.value("position").toULongLong();

        vodLastPlaybackPositionLoaded(channel, vod, lastPosition, i);
    }
    settings.endArray();

    emit modelChanged();

    std::atexit([](){
       VodManager::getInstance()->saveSettings();
    });
}

VodManager *VodManager::getInstance() {
    static VodManager instance;
    return &instance;
}

VodManager::~VodManager()
{
    saveSettings();
    delete _filteredModel;
    delete _model;
}

void VodManager::search(const quint64 channelId, const quint32 offset, const quint32 limit, const QString &type)
{
    const QString videoType = type.trimmed();
    currentSearchChannelId = channelId;
    currentSearchOffset = offset;
    currentSearchType = videoType;
    if (offset == 0) {
        _model->clear();
        loadCachedVods(channelId, videoType);
        emit searchStarted();
    }

    netman->getBroadcasts(channelId, offset, limit, videoType);
}

void VodManager::onSearchFinished(QList<Vod *> items)
{
    _model->mergePage(items, currentSearchOffset);
    if (currentSearchChannelId != 0) {
        saveCachedVods(currentSearchChannelId, currentSearchType);
    }

    qDeleteAll(items);
    items.clear();

    emit searchFinished();
}

void VodManager::onSearchFailed()
{
    emit searchFailed();
}

VodListModel *VodManager::getModel() const
{
    return _model;
}

VodFilterProxyModel *VodManager::getFilteredModel() const
{
    return _filteredModel;
}

int VodManager::loadedCount() const
{
    return _model->count();
}

void VodManager::loadCachedVods(quint64 channelId, const QString &type)
{
    if (channelId == 0) {
        return;
    }

    QSettings settings(QCoreApplication::organizationName(), QCoreApplication::applicationName());
    settings.beginGroup("vodCache");
    settings.beginGroup(vodCacheKey(channelId, type));

    QList<Vod *> items;
    const int savedCount = settings.beginReadArray("items");
    for (int i = 0; i < savedCount; i++) {
        settings.setArrayIndex(i);
        const QString id = settings.value("id").toString();
        if (id.isEmpty()) {
            continue;
        }

        Vod *vod = new Vod();
        vod->setId(id);
        vod->setTitle(settings.value("title").toString());
        vod->setGame(settings.value("game").toString());
        vod->setType(settings.value("type").toString());
        vod->setDuration(settings.value("duration").toUInt());
        vod->setViews(settings.value("views").toULongLong());
        vod->setPreview(settings.value("preview").toString());
        vod->setCreatedAt(settings.value("createdAt").toString());
        vod->setSeekPreviews(settings.value("seekPreviews").toString());
        vod->setMutedSegments(settings.value("mutedSegments").toString());
        items.append(vod);
    }
    settings.endArray();

    _model->addAll(items);
    qDeleteAll(items);

    settings.endGroup();
    settings.endGroup();
}

void VodManager::saveCachedVods(quint64 channelId, const QString &type) const
{
    if (channelId == 0) {
        return;
    }

    QSettings settings(QCoreApplication::organizationName(), QCoreApplication::applicationName());
    settings.beginGroup("vodCache");
    settings.beginGroup(vodCacheKey(channelId, type));
    settings.setValue("updatedAt", QDateTime::currentDateTimeUtc().toString(Qt::ISODate));

    const int count = _model->rowCount(QModelIndex());
    settings.beginWriteArray("items", count);
    for (int row = 0; row < count; row++) {
        const QModelIndex index = _model->index(row, 0);
        settings.setArrayIndex(row);
        settings.setValue("id", _model->data(index, VodListModel::Id));
        settings.setValue("title", _model->data(index, VodListModel::Title));
        settings.setValue("game", _model->data(index, VodListModel::Game));
        settings.setValue("type", _model->data(index, VodListModel::Type));
        settings.setValue("duration", _model->data(index, VodListModel::Duration));
        settings.setValue("views", _model->data(index, VodListModel::Views));
        settings.setValue("preview", _model->data(index, VodListModel::Preview));
        settings.setValue("createdAt", _model->data(index, VodListModel::CreatedAt));
        settings.setValue("seekPreviews", _model->data(index, VodListModel::SeekPreviews));
        settings.setValue("mutedSegments", _model->data(index, VodListModel::MutedSegments));
    }
    settings.endArray();
    settings.endGroup();
    settings.endGroup();
    settings.sync();
}

void VodManager::saveSettings() {
    //Save
    QSettings settings(QCoreApplication::organizationName(), QCoreApplication::applicationName());

    //Write last positions
    int nextLastPositionEntry = settings.beginReadArray("lastPositions");
    settings.endArray();

    settings.beginWriteArray("lastPositions");
    for (auto channelEntry = channelVodLastPositions.begin(); channelEntry != channelVodLastPositions.end(); channelEntry++) {
        auto & vods = channelEntry.value();
        for (auto vodEntry = vods.begin(); vodEntry != vods.end(); vodEntry++) {
            auto & lastPosition = vodEntry.value();
            if (lastPosition.modified) {
                if (lastPosition.settingsIndex == -1) {
                    lastPosition.settingsIndex = nextLastPositionEntry++;
                }

                settings.setArrayIndex(lastPosition.settingsIndex);
                settings.setValue("channel", channelEntry.key());
                settings.setValue("vod", vodEntry.key());
                settings.setValue("position", vodEntry.value().lastPosition);
                lastPosition.modified = false;
            }
        }
    }
    settings.endArray();
    settings.sync();

}

QString VodManager::getGame() const
{
    return game;
}

void VodManager::getBroadcasts(QString vod)
{
    //Remove leading NaN characters
    vod.remove(QRegExp("[^0-9]"));

    netman->getBroadcastPlaybackStream(vod);
}

void VodManager::setVodLastPlaybackPosition(const QString & channel, const QString & vod, quint64 position) {
    auto channelEntry = channelVodLastPositions.find(channel);
    if (channelEntry == channelVodLastPositions.end()) {
        channelEntry = channelVodLastPositions.insert(channel, QMap<QString, LastPosition>());
    }

    auto & vodMap = channelEntry.value();
    auto vodEntry = vodMap.find(vod);
    if (vodEntry != vodMap.end()) {
        const auto previousPosition = vodEntry.value().lastPosition;
        vodEntry.value().lastPosition = position;
        vodEntry.value().modified = true;
        if (std::fabs(static_cast<double>(previousPosition) - static_cast<double>(position)) >= 10) {
            saveSettings();
        }
    } else {
        // -1 index to be replaced at settings save time
        vodMap.insert(vod, {position, true, -1});
        saveSettings();
    }

    emit vodLastPositionUpdated(channel, vod, position);
}

void VodManager::vodLastPlaybackPositionLoaded(const QString & channel, const QString & vod, quint64 position, int settingsIndex) {
    auto channelEntry = channelVodLastPositions.find(channel);
    if (channelEntry == channelVodLastPositions.end()) {
        channelEntry = channelVodLastPositions.insert(channel, QMap<QString, LastPosition>());
    }

    auto & vodMap = channelEntry.value();
    vodMap.remove(vod);
    vodMap.insert(vod, {position, false, settingsIndex});
}

QVariant VodManager::getVodLastPlaybackPosition(const QString & channel, const QString & vod) {
    auto channelEntry = channelVodLastPositions.find(channel);
    if (channelEntry == channelVodLastPositions.end()) {
        return QVariant();
    }

    auto & vodMap = channelEntry.value();
    auto vodEntry = vodMap.find(vod);
    if (vodEntry == vodMap.end()) {
        return QVariant();
    }

    return vodEntry.value().lastPosition;
}

QVariantMap VodManager::getChannelVodsLastPlaybackPositions(const QString & channel) {
    QVariantMap out;
    auto channelEntry = channelVodLastPositions.find(channel);
    if (channelEntry != channelVodLastPositions.end()) {
        auto & vodMap = channelEntry.value();
        for (auto vodEntry = vodMap.constBegin(); vodEntry != vodMap.constEnd(); vodEntry++) {
            out.insert(vodEntry.key(), vodEntry.value().lastPosition);
        }
    }
    return out;
}
