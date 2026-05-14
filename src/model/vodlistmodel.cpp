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

#include "vodlistmodel.h"
#include <QSet>

VodListModel::VodListModel(QObject *parent) :
    QAbstractListModel(parent)
{

}

VodListModel::~VodListModel()
{
    clear();
}

Qt::ItemFlags VodListModel::flags(const QModelIndex &index) const
{
    if (!index.isValid()) {
        return Qt::NoItemFlags;
    }

    if (index.column() != 0 || index.row() < 0 || index.row() >= vods.size()) {
        return Qt::NoItemFlags;
    }

    return Qt::ItemIsEnabled;
}

QVariant VodListModel::data(const QModelIndex &index, int role) const
{
    QVariant var;

    if (!index.isValid()){
        return var;
    }

    if (index.column() != 0 || index.row() < 0 || index.row() >= vods.size()) {
        return var;
    }

    Vod *vod = vods.at(index.row());

    if (vod){
        switch(role){
        case Title:
            var.setValue(vod->getTitle());
            break;

        case Duration:
            var.setValue(vod->getDuration());
            break;

        case Preview:
            var.setValue(vod->getPreview());
            break;

        case Views:
            var.setValue(vod->getViews());
            break;

        case Id:
            var.setValue(vod->getId());
            break;

        case Game:
            var.setValue(vod->getGame());
            break;

        case Type:
            var.setValue(vod->getType());
            break;

        case CreatedAt:
            var.setValue(vod->getCreatedAt());
            break;

        case PublishedAt:
            var.setValue(vod->getPublishedAt());
            break;

        case Description:
            var.setValue(vod->getDescription());
            break;

        case Language:
            var.setValue(vod->getLanguage());
            break;

        case Url:
            var.setValue(vod->getUrl());
            break;

        case SeekPreviews:
            var.setValue(vod->getSeekPreviews());
            break;

        case MutedSegments:
            var.setValue(vod->getMutedSegments());
            break;

        case MutedSegmentRanges:
            var.setValue(vod->getMutedSegmentRanges());
            break;
        }
    }

    return var;
}

int VodListModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }

    return vods.size();
}

QHash<int, QByteArray> VodListModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[Title] = "title";
    roles[Preview] = "preview";
    roles[Id] = "id";
    roles[Game] = "game";
    roles[Type] = "type";
    roles[Duration] = "duration";
    roles[Views] = "views";
    roles[CreatedAt] = "createdAt";
    roles[PublishedAt] = "publishedAt";
    roles[Description] = "description";
    roles[Language] = "language";
    roles[Url] = "url";
    roles[SeekPreviews] = "seekPreviews";
    roles[MutedSegments] = "mutedSegments";
    roles[MutedSegmentRanges] = "mutedSegmentRanges";
    return roles;
}

void VodListModel::addAll(QList<Vod *> &items)
{
    QList<Vod *> newItems;
    const QList<Vod *> &incomingItems = items;
    for (Vod *vod : incomingItems) {
        if (!vod) {
            continue;
        }

        Vod *existing = find(vod->getId());
        if (existing) {
            *existing = *vod;
            const int row = vods.indexOf(existing);
            if (row >= 0) {
                const QModelIndex itemIndex = index(row, 0);
                emit dataChanged(itemIndex, itemIndex);
            }
        } else {
            newItems.append(vod);
        }
    }

    if (!newItems.isEmpty()){
        beginInsertRows(QModelIndex(), vods.size(), vods.size() + newItems.size() - 1);
        for (Vod *vod : newItems) {
            vods.append(new Vod(*vod));
        }
        endInsertRows();
    }
}

void VodListModel::mergePage(QList<Vod *> &items, quint32 offset)
{
    if (items.isEmpty()) {
        return;
    }

    QSet<QString> incomingIds;
    QList<Vod *> newItems;
    const QList<Vod *> &incomingItems = items;
    for (Vod *vod : incomingItems) {
        if (vod) {
            incomingIds.insert(vod->getId());
            newItems.append(vod);
        }
    }

    if (newItems.isEmpty()) {
        return;
    }

    for (int row = vods.size() - 1; row >= 0; row--) {
        Vod *vod = vods.at(row);
        if (vod && incomingIds.contains(vod->getId())) {
            beginRemoveRows(QModelIndex(), row, row);
            delete vods.takeAt(row);
            endRemoveRows();
        }
    }

    const int requestedRow = static_cast<int>(offset);
    const int insertRow = qMax(0, qMin(requestedRow, vods.size()));
    beginInsertRows(QModelIndex(), insertRow, insertRow + newItems.size() - 1);
    for (int i = 0; i < newItems.size(); i++) {
        vods.insert(insertRow + i, new Vod(*newItems.at(i)));
    }
    endInsertRows();
}

Vod *VodListModel::find(const QString id)
{
    const QList<Vod *> &knownVods = vods;
    for (Vod *vod : knownVods) {
        if (vod->getId() == id) {
            return vod;
        }
    }
    return nullptr;
}

void VodListModel::clear()
{
    if (!vods.isEmpty()){
        beginRemoveRows(QModelIndex(), 0, vods.size() - 1);
        qDeleteAll(vods);
        vods.clear();
        endRemoveRows();
    }
}

int VodListModel::count() const
{
    return rowCount();
}
