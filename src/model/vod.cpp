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

#include "vod.h"

Vod::Vod() { }

QString Vod::getPreview() const
{
    return preview;
}

void Vod::setPreview(const QString &value)
{
    preview = value;
}

quint64 Vod::getViews() const
{
    return views;
}

void Vod::setViews(const quint64 &value)
{
    views = value;
}

quint32 Vod::getDuration() const
{
    return duration;
}

void Vod::setDuration(const quint32 &value)
{
    duration = value;
}

QString Vod::getGame() const
{
    return game;
}

void Vod::setGame(const QString &value)
{
    game = value;
}

QString Vod::getType() const
{
    return type;
}

void Vod::setType(const QString &value)
{
    type = value;
}

QString Vod::getId() const
{
    return id;
}

void Vod::setId(const QString &value)
{
    id = value;
}

QString Vod::getTitle() const
{
    return title;
}

void Vod::setTitle(const QString &value)
{
    title = value;
}

QString Vod::getDescription() const
{
    return description;
}

void Vod::setDescription(const QString &value)
{
    description = value;
}

QString Vod::getCreatedAt() const
{
    return createdAt;
}

void Vod::setCreatedAt(const QString &value)
{
    createdAt = value;
}

QString Vod::getPublishedAt() const
{
    return publishedAt;
}

void Vod::setPublishedAt(const QString &value)
{
    publishedAt = value;
}

QString Vod::getUrl() const
{
    return url;
}

void Vod::setUrl(const QString &value)
{
    url = value;
}

QString Vod::getLanguage() const
{
    return language;
}

void Vod::setLanguage(const QString &value)
{
    language = value;
}

QString Vod::getSeekPreviews() const
{
    return seekPreviews;
}

void Vod::setSeekPreviews(const QString &value)
{
    seekPreviews = value;
}

QString Vod::getMutedSegments() const
{
    return mutedSegments;
}

void Vod::setMutedSegments(const QString &value)
{
    mutedSegments = value;
}

QString Vod::getMutedSegmentRanges() const
{
    return mutedSegmentRanges;
}

void Vod::setMutedSegmentRanges(const QString &value)
{
    mutedSegmentRanges = value;
}
