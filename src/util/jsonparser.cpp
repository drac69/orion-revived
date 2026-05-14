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

#include "jsonparser.h"
#include "../model/settingsmanager.h"
#include <QJsonValue>
#include <QRandomGenerator>
#include <QStringList>
#include <QUrlQuery>
#include <QVersionNumber>

namespace {
QString playlistNonce()
{
    return QString::number(QRandomGenerator::global()->bounded(1000000));
}

QString formatVodOffset(const quint32 totalSeconds)
{
    const quint32 hours = totalSeconds / 3600;
    const quint32 minutes = (totalSeconds % 3600) / 60;
    const quint32 seconds = totalSeconds % 60;

    if (hours > 0) {
        return QString("%1:%2:%3")
                .arg(hours)
                .arg(minutes, 2, 10, QLatin1Char('0'))
                .arg(seconds, 2, 10, QLatin1Char('0'));
    }

    return QString("%1:%2")
            .arg(minutes)
            .arg(seconds, 2, 10, QLatin1Char('0'));
}

QString vodIdFromJson(const QJsonValue &value)
{
    if (value.isString()) {
        return value.toString().trimmed();
    }
    if (value.isDouble()) {
        const quint64 id = static_cast<quint64>(value.toDouble());
        if (id != 0) {
            return QString::number(id);
        }
    }

    return QString();
}

quint64 unsignedIdFromJson(const QJsonValue &value)
{
    if (value.isString()) {
        bool ok = false;
        const quint64 id = value.toString().trimmed().toULongLong(&ok);
        return ok ? id : 0;
    }
    if (value.isDouble()) {
        return static_cast<quint64>(value.toDouble());
    }

    return 0;
}

QString stringIdFromJson(const QJsonValue &value)
{
    if (value.isString()) {
        return value.toString().trimmed();
    }
    if (value.isDouble()) {
        return QString::number(static_cast<quint64>(value.toDouble()));
    }

    return QString();
}

QString normalizedVersionNumberText(QString value)
{
    value = value.trimmed();
    if (value.startsWith(QLatin1Char('v'), Qt::CaseInsensitive)) {
        value = value.mid(1);
    }

    if (value.isEmpty() || value.startsWith(QLatin1Char('.'))
            || value.endsWith(QLatin1Char('.')) || value.contains(QStringLiteral(".."))) {
        return QString();
    }

    for (const QChar &character : value) {
        if (!character.isDigit() && character != QLatin1Char('.')) {
            return QString();
        }
    }

    return value;
}

void updateVersionCandidate(const QString &tag, QString &version, QVersionNumber &latest)
{
    const QString normalized = normalizedVersionNumberText(tag);
    if (normalized.isEmpty()) {
        return;
    }

    const QVersionNumber candidate = QVersionNumber::fromString(normalized);
    if (candidate.isNull()) {
        return;
    }

    if (version.isEmpty() || candidate > latest) {
        version = tag;
        latest = candidate;
    }
}
}

PagedResult<Channel*> JsonParser::parseStreams(const QByteArray &data)
{
    PagedResult<Channel*> out;

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data,&error);
    if (error.error == QJsonParseError::NoError){
        QJsonObject json = doc.object();

        if (json.contains("data")) {
            // Helix Get Streams response.
            const QJsonArray arr = json["data"].toArray();
            for (const QJsonValue &item : arr) {
                out.items.append(JsonParser::parseStreamJson(item.toObject(), true));
            }

            out.cursor = json["pagination"].toObject()["cursor"].toString();
            out.total = out.items.size();
        }
        else {
            //Online streams
            QJsonArray arr = json["streams"].toArray();
            for (const QJsonValue &item : arr) {
                out.items.append(JsonParser::parseStreamJson(item.toObject(), true));
            }

            out.total = json["_total"].toInt();
        }

        //Caller must use request context to determine offline streams
    }

    return out;
}

Channel *JsonParser::parseStream(const QByteArray &data)
{
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data,&error);
    if (error.error == QJsonParseError::NoError){
        QJsonObject json = doc.object();
        if (json.contains("data")) {
            const QJsonArray arr = json["data"].toArray();
            if (arr.isEmpty()) {
                return new Channel();
            }
            return parseStreamJson(arr.first().toObject(), true);
        }

        return parseStreamJson(json, false);
    }
    return new Channel();
}

Channel* JsonParser::parseStreamJson(const QJsonObject &json, const bool expectChannel)
{
    Channel* channel = new Channel();

    QJsonObject jsonObj;

    if (json.contains("stream")) {
        if (json["stream"].isNull()) {
            return channel;
        }
        jsonObj = json["stream"].toObject();
    } else {
        jsonObj = json;
    }

    if (jsonObj.contains("user_id")) {
        channel->setId(unsignedIdFromJson(jsonObj["user_id"]));
        channel->setServiceName(jsonObj["user_login"].toString());
        channel->setName(jsonObj["user_name"].toString());
        channel->setInfo(jsonObj["title"].toString());
        channel->setGame(jsonObj["game_name"].toString());
        channel->setLanguage(jsonObj["language"].toString());
        channel->setViewers(jsonObj["viewer_count"].toInt());

        QString previewUrl = jsonObj["thumbnail_url"].toString();
        previewUrl.replace("{width}", "640");
        previewUrl.replace("{height}", "360");
        channel->setPreviewurl(previewUrl);

        channel->setOnline(jsonObj["type"].toString() == "live");
        return channel;
    }

    if (!jsonObj["preview"].isNull()){

        QJsonObject preview = jsonObj["preview"].toObject();

        if (!preview["large"].isNull()){
            channel->setPreviewurl(preview["large"].toString());
        }
    }

    if (!jsonObj["viewers"].isNull()){
        channel->setViewers(jsonObj["viewers"].toInt());
    }

    if (!jsonObj["game"].isNull()){
        channel->setGame(jsonObj["game"].toString());
    }

    if (!jsonObj["broadcaster_language"].isNull()){
        channel->setLanguage(jsonObj["broadcaster_language"].toString());
    }
    else if (!jsonObj["language"].isNull()){
        channel->setLanguage(jsonObj["language"].toString());
    }

    if (!jsonObj["channel"].isNull()){

        Channel *c = parseChannelJson(jsonObj["channel"].toObject());
        channel->setServiceName(c->getServiceName());
        channel->setId(c->getId());
        channel->setName(c->getName());
        channel->setLogourl(c->getLogourl());
        channel->setInfo(c->getInfo());
        channel->setLanguage(c->getLanguage());

        delete c;
    }
    else if (expectChannel) {
        qDebug() << "expected channel; stream will not have channel id to correlate";
    }

    channel->setOnline(true);

    return channel;
}

QList<Game*> JsonParser::parseGames(const QByteArray &data)
{
    return parseGameResults(data).items;
}

PagedResult<Game*> JsonParser::parseGameResults(const QByteArray &data)
{
    PagedResult<Game*> out;

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data,&error);
    if (error.error == QJsonParseError::NoError) {
        QJsonObject json = doc.object();

        QString arg = (!json["data"].isNull() ? "data" : (!json["top"].isNull() ? "top" : (!json["games"].isNull() ? "games" : "")));

        if (!arg.isEmpty()){
            QJsonArray arr = json[arg].toArray();
            for (const QJsonValue &item : arr) {
                Game* game = parseGame(item.toObject());
                if (!game->getName().isEmpty()){
                    out.items.append(game);
                }
                else {
                    delete game;
                }
            }
        }

        out.cursor = json["pagination"].toObject()["cursor"].toString();
        out.total = out.items.size();
    }

    return out;
}


Game* JsonParser::parseGame(const QJsonObject &json)
{
    Game* game = new Game();

    if (json.contains("box_art_url")) {
        game->setId(stringIdFromJson(json["id"]));
        game->setName(json["name"].toString());

        QString boxArtUrl = json["box_art_url"].toString();
        boxArtUrl.replace("{width}", "285");
        boxArtUrl.replace("{height}", "380");
        game->setLogo(boxArtUrl);
        game->setPreview(boxArtUrl);
    }
    //From top games
    else if (json.contains("game") && !json["game"].isNull()){
        const QJsonObject gameObj = json["game"].toObject();

        if (!gameObj["_id"].isNull())
            game->setId(stringIdFromJson(gameObj["_id"]));

        if (!json["viewers"].isNull())
            game->setViewers(json["viewers"].toInt());

        if (!gameObj["name"].isNull())
            game->setName(gameObj["name"].toString());

        if (!gameObj["box"].isNull() && !gameObj["box"].toObject()["medium"].isNull())
            game->setLogo(gameObj["box"].toObject()["medium"].toString());

        if (!gameObj["logo"].isNull() && !gameObj["logo"].toObject()["medium"].isNull())
            game->setPreview(gameObj["logo"].toObject()["medium"].toString());
    }
    //From games search
    else {
        if (!json["_id"].isNull())
            game->setId(stringIdFromJson(json["_id"]));

        if (!json["name"].isNull())
            game->setName(json["name"].toString());

        if (!json["viewers"].isNull())
            game->setViewers(json["viewers"].toInt());

        if (!json["box"].isNull() && !json["box"].toObject()["medium"].isNull())
            game->setLogo(json["box"].toObject()["medium"].toString());

        if (!json["logo"].isNull() && !json["logo"].toObject()["medium"].isNull())
            game->setPreview(json["logo"].toObject()["medium"].toString());
    }

    return game;
}

Channel* JsonParser::parseChannel(const QByteArray &data){
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data,&error);
    if (error.error == QJsonParseError::NoError){
        return parseChannelJson(doc.object());
    }
    return new Channel();
}

Channel* JsonParser::parseChannelJson(const QJsonObject &json)
{
    Channel* channel = new Channel();

    if (json.contains("broadcaster_login")) {
        channel->setId(unsignedIdFromJson(json["id"]));
        channel->setServiceName(json["broadcaster_login"].toString());
        channel->setName(json["display_name"].toString());
        channel->setInfo(json["title"].toString());
        channel->setGame(json["game_name"].toString());
        channel->setLanguage(json["broadcaster_language"].toString());

        QString thumbnailUrl = json["thumbnail_url"].toString();
        thumbnailUrl.replace("{width}", "300");
        thumbnailUrl.replace("{height}", "300");
        channel->setLogourl(thumbnailUrl);

        channel->setOnline(json["is_live"].toBool());
    }
    else if (!json["name"].isNull()){

        channel->setServiceName(json["name"].toString());

       // qDebug() << "Parsing channel data for " <<  channel.getUriName();

        if (!json["name"].isNull()){
            channel->setServiceName(json["name"].toString());
        }

        if (!json["display_name"].isNull()){
            channel->setName(json["display_name"].toString());
        }

        if (!json["status"].isNull()){
            channel->setInfo(json["status"].toString());
        }

        if (!json["logo"].isNull()){
            channel->setLogourl(json["logo"].toString());
        }

        if (!json["broadcaster_language"].isNull()){
            channel->setLanguage(json["broadcaster_language"].toString());
        }
        else if (!json["language"].isNull()){
            channel->setLanguage(json["language"].toString());
        }

        if (!json["_id"].isNull()){
            const QJsonValue & _id = json["_id"];
            channel->setId(unsignedIdFromJson(_id));
        }
    }

    return channel;
}

Vod *JsonParser::parseVod(const QJsonObject &json)
{
    Vod *vod = new Vod();

    if (!json["id"].isNull())
        vod->setId(json["id"].toString());
    else if (!json["_id"].isNull())
        vod->setId(json["_id"].toString());

    if (!json["thumbnail_url"].isNull()) {
        QString thumbnailUrl = json["thumbnail_url"].toString();
        thumbnailUrl.replace("%{width}", "320");
        thumbnailUrl.replace("%{height}", "180");
        vod->setPreview(thumbnailUrl);
    }
    else if (!json["preview"].isNull()) {
        const QJsonValue & preview = json["preview"];
        if (preview.isString()) {
            vod->setPreview(preview.toString());
        }
        else if (preview.isObject()) {
            const QJsonValue & previewUrl = preview.toObject()["large"];
            if (previewUrl.isString()) {
                vod->setPreview(previewUrl.toString());
            }
        }
    }

    if (!json["seek_previews_url"].isNull())
        vod->setSeekPreviews(json["seek_previews_url"].toString());

    if (!json["title"].isNull())
        vod->setTitle(json["title"].toString());

    if (!json["description"].isNull())
        vod->setDescription(json["description"].toString());

    if (!json["duration"].isNull()) {
        quint32 totalSeconds = 0;
        QString number;
        const QString duration = json["duration"].toString();
        for (const QChar &ch : duration) {
            if (ch.isDigit()) {
                number.append(ch);
                continue;
            }

            const quint32 value = number.toUInt();
            number.clear();
            if (ch == QLatin1Char('h')) {
                totalSeconds += value * 3600;
            }
            else if (ch == QLatin1Char('m')) {
                totalSeconds += value * 60;
            }
            else if (ch == QLatin1Char('s')) {
                totalSeconds += value;
            }
        }
        vod->setDuration(totalSeconds);
    }
    else if (!json["length"].isNull())
        vod->setDuration(json["length"].toInt());

    if (!json["game_name"].isNull())
        vod->setGame(json["game_name"].toString());
    else if (!json["game"].isNull())
        vod->setGame(json["game"].toString());

    if (!json["language"].isNull())
        vod->setLanguage(json["language"].toString());

    if (!json["type"].isNull())
        vod->setType(json["type"].toString());

    if (!json["view_count"].isNull())
        vod->setViews(json["view_count"].toInt());
    else if (!json["views"].isNull())
        vod->setViews(json["views"].toInt());

    if (!json["created_at"].isNull())
        vod->setCreatedAt(json["created_at"].toString());

    if (!json["published_at"].isNull())
        vod->setPublishedAt(json["published_at"].toString());

    if (!json["url"].isNull())
        vod->setUrl(json["url"].toString());

    if (json["muted_segments"].isArray()) {
        QStringList segments;
        QStringList ranges;
        for (const QJsonValue &segmentValue : json["muted_segments"].toArray()) {
            const QJsonObject segment = segmentValue.toObject();
            if (!segment.contains("offset") || !segment.contains("duration")) {
                continue;
            }

            const int offset = segment["offset"].toInt(-1);
            const int segmentDuration = segment["duration"].toInt(0);
            if (offset < 0 || segmentDuration <= 0) {
                continue;
            }

            const int end = offset + segmentDuration;
            segments.append(QString("%1-%2")
                            .arg(formatVodOffset(static_cast<quint32>(offset)))
                            .arg(formatVodOffset(static_cast<quint32>(end))));
            ranges.append(QString("%1-%2").arg(offset).arg(end));
        }
        vod->setMutedSegments(segments.join(", "));
        vod->setMutedSegmentRanges(ranges.join(";"));
    }

    return vod;
}

PagedResult<Channel*> JsonParser::parseChannels(const QByteArray &data)
{
    PagedResult<Channel*> out;

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data,&error);
    if (error.error == QJsonParseError::NoError){
        QJsonObject json = doc.object();

        if (json.contains("data")) {
            QJsonArray arr = json["data"].toArray();
            for (const QJsonValue &item : arr) {
                out.items.append(JsonParser::parseChannelJson(item.toObject()));
            }

            out.cursor = json["pagination"].toObject()["cursor"].toString();
            out.total = out.items.size();
        }
        else {
            QJsonArray arr = json["channels"].toArray();
            for (const QJsonValue &item : arr) {
                out.items.append(JsonParser::parseChannelJson(item.toObject()));
            }

            out.total = json["_total"].toInt();
        }
    }

    return out;
}

PagedResult<Channel *> JsonParser::parseFavourites(const QByteArray &data)
{
    PagedResult<Channel *> out;

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data,&error);
    if (error.error == QJsonParseError::NoError){
        QJsonObject json = doc.object();

        if (json.contains("data")) {
            const QJsonArray arr = json["data"].toArray();
            for (const QJsonValue &item : arr) {
                const QJsonObject follow = item.toObject();
                const QString login = follow["broadcaster_login"].toString();
                const QString displayName = follow["broadcaster_name"].toString();
                const quint64 channelId = unsignedIdFromJson(follow["broadcaster_id"]);

                if (channelId == 0 && login.isEmpty() && displayName.isEmpty()) {
                    continue;
                }

                Channel *channel = new Channel();
                channel->setId(channelId);
                channel->setServiceName(login);
                channel->setName(displayName.isEmpty() ? login : displayName);
                out.items.append(channel);
            }

            out.cursor = json["pagination"].toObject()["cursor"].toString();
            out.total = json["total"].toInt(out.items.size());
        }
        else {
            out.total = json["_total"].toInt();

            QJsonArray arr = json["follows"].toArray();
            for (const QJsonValue &item : arr) {
                out.items.append(JsonParser::parseChannelJson(item.toObject()["channel"].toObject()));
            }
        }
    }

    return out;
}

QList<Channel *> JsonParser::parseFeatured(const QByteArray &data)
{
    QList<Channel*> channels;

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data,&error);
    if (error.error == QJsonParseError::NoError){
        QJsonObject json = doc.object();

        if (!json["featured"].isNull()){
            for (const QJsonValue &item : json["featured"].toArray()) {
                channels.append(JsonParser::parseStreamJson(item.toObject()["stream"].toObject(), true));
            }
        }
    }

    return channels;
}

QList<Vod *> JsonParser::parseVods(const QByteArray &data)
{
    return parseVodResults(data).items;
}

PagedResult<Vod *> JsonParser::parseVodResults(const QByteArray &data)
{
    PagedResult<Vod *> out;

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data,&error);
    if (error.error == QJsonParseError::NoError){
        QJsonObject json = doc.object();

        if (json.contains("data")) {
            for (const QJsonValue &item : json["data"].toArray()) {
                out.items.append(JsonParser::parseVod(item.toObject()));
            }

            out.cursor = json["pagination"].toObject()["cursor"].toString();
            out.total = out.items.size();
        }
        else if (!json["videos"].isNull()){
            for (const QJsonValue &item : json["videos"].toArray()) {
                out.items.append(JsonParser::parseVod(item.toObject()));
            }
        }
    }

    return out;
}

QString JsonParser::parseChannelStreamExtractionInfo(const QByteArray &data)
{
    QString url;

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data,&error);
    if (error.error == QJsonParseError::NoError){
        QJsonObject json = doc.object();

        QString tokenData = json["token"].toString();

        //Strip escape markings and spaces
        //tokenData = tokenData.trimmed().remove("\\");

        QString channel;

        QJsonDocument tokenDoc = QJsonDocument::fromJson(tokenData.toUtf8(), &error);
        if (error.error == QJsonParseError::NoError){
            QJsonObject tokenJson = tokenDoc.object();
            channel = tokenJson["channel"].toString();
        }

        QString sig = json["sig"].toString();

        if (channel.isEmpty() || tokenData.isEmpty() || sig.isEmpty()) {
            return url;
        }

        QUrl playlistUrl(QString("https://usher.ttvnw.net/api/channel/hls/%1.m3u8").arg(channel));
        QUrlQuery query;
        query.addQueryItem("player", "twitchweb");
        query.addQueryItem("token", tokenData);
        query.addQueryItem("sig", sig);
        query.addQueryItem("allow_source", "true");
        query.addQueryItem("allow_audio_only", "true");
        query.addQueryItem("type", "any");
        query.addQueryItem("p", playlistNonce());
        if (SettingsManager::getInstance()->lowLatencyPlayback()) {
            query.addQueryItem("fast_bread", "true");
        }
        playlistUrl.setQuery(query);
        url = playlistUrl.toString(QUrl::FullyEncoded);
    }

    return url;
}

QString JsonParser::parseVodExtractionInfo(const QByteArray &data)
{
    QString url;

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data,&error);
    if (error.error == QJsonParseError::NoError){
        QJsonObject json = doc.object();

        QString tokenData = json["token"].toString();
        QString sig = json["sig"].toString();

        //Strip escape markings and spaces
        tokenData = tokenData.trimmed().remove("\\");

        QString vod;

        QJsonDocument tokenDoc = QJsonDocument::fromJson(tokenData.toUtf8(), &error);
        if (error.error == QJsonParseError::NoError){
            QJsonObject tokenJson = tokenDoc.object();
            vod = vodIdFromJson(tokenJson["vod_id"]);
        }

        bool vodOk = false;
        const quint64 vodId = vod.toULongLong(&vodOk);
        if (!vodOk || vodId == 0 || tokenData.isEmpty() || sig.isEmpty()) {
            return url;
        }

        QUrl playlistUrl(QString("https://usher.ttvnw.net/vod/%1.m3u8").arg(vod));
        QUrlQuery query;
        query.addQueryItem("nauth", tokenData);
        query.addQueryItem("nauthsig", sig);
        query.addQueryItem("p", playlistNonce());
        query.addQueryItem("type", "any");
        query.addQueryItem("player", "twitchweb");
        query.addQueryItem("allow_source", "true");
        query.addQueryItem("allow_audio_only", "true");
        playlistUrl.setQuery(query);
        url = playlistUrl.toString(QUrl::FullyEncoded);
    }

    return url;
}

QPair<QString, quint64> JsonParser::parseUser(const QByteArray &data)
{
    QString displayName;
    quint64 userId = 0;
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data,&error);

    if (error.error == QJsonParseError::NoError){
        QJsonObject json = doc.object();

        if (json["data"].isArray() && !json["data"].toArray().isEmpty()) {
            json = json["data"].toArray().first().toObject();
        }

        if (!json["display_name"].isNull())
            displayName = json["display_name"].toString();
        else if (!json["name"].isNull())
            displayName = json["name"].toString();

        if (!json["id"].isNull())
            userId = json["id"].toString().toULongLong();
        else
            userId = json["_id"].toString().toULongLong();
    }

    return qMakePair(displayName, userId);
}

QList<quint64> JsonParser::parseUsers(const QByteArray &data)
{
    QList<quint64> out;

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    if (error.error == QJsonParseError::NoError) {
        QJsonObject json = doc.object();

        const QJsonArray helixUsers = json["data"].toArray();
        if (!helixUsers.isEmpty()) {
            for (const auto &user : helixUsers) {
                const auto userId = user.toObject()["id"].toString().toULongLong();
                if (userId != 0) {
                    out.append(userId);
                }
            }
        }
        else {
            for (const auto & user : json["users"].toArray()) {
                auto userId = user.toObject()["_id"];
                if (userId.isDouble()) {
                    out.append(static_cast<quint64>(userId.toDouble()));
                }
                else {
                    out.append(userId.toString().toULongLong());
                }
            }
        }
    }

    return out;
}

QMap<QString, QMap<QString, QString>> JsonParser::parseEmoteSets(const QByteArray &data) {
    QMap<QString, QMap<QString, QString>> out;

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    //qDebug() << "parsing emote sets response" << data;

    if (error.error == QJsonParseError::NoError) {
        QJsonObject json = doc.object();
        if (json["data"].isArray()) {
            for (const auto &emoteEntry : json["data"].toArray()) {
                const QJsonObject emote = emoteEntry.toObject();
                const QString setId = emote["emote_set_id"].toString();
                const QString emoteId = emote["id"].toString();
                const QString name = emote["name"].toString();
                if (!setId.isEmpty() && !emoteId.isEmpty() && !name.isEmpty()) {
                    out[setId].insert(emoteId, name);
                }
            }
        }
        else if (!json["emoticon_sets"].isNull()) {
            auto emoticon_sets = json["emoticon_sets"].toObject();
            for (auto emoticonSetEntry = emoticon_sets.begin(); emoticonSetEntry != emoticon_sets.end(); emoticonSetEntry++) {
                auto emoticonSetID = emoticonSetEntry.key();
                QMap<QString, QString> curSetEmoticons;
                auto emoticons = emoticonSetEntry.value().toArray();
                for (auto emoticonEntry = emoticons.begin(); emoticonEntry != emoticons.end(); emoticonEntry++) {
                    auto emoticonObj = emoticonEntry->toObject();
                    auto id = emoticonObj["id"];
                    auto code = emoticonObj["code"];
                    if ((id.isDouble() || id.isString()) && code.isString()) {
                        const QString emoteId = id.isString()
                                ? id.toString()
                                : QString::number(static_cast<qulonglong>(id.toDouble()));
                        curSetEmoticons.insert(emoteId, code.toString());
                    }
                }
                //qDebug() << "saving set id" << emoticonSetID;
                out.insert(emoticonSetID, curSetEmoticons);
            }
        }
    }

    return out;
}

QMap<QString, QString> convertJsonStringMap(const QJsonObject & obj) {
    QMap<QString, QString> out;

    for (auto entry = obj.constBegin(); entry != obj.constEnd(); entry++) {
        if (entry.value().isString()) {
            out.insert(entry.key(), entry.value().toString());
        }
    }

    return out;
}

QMap<QString, QMap<QString, QMap<QString, QString>>> JsonParser::parseBadgeUrlsBetaFormat(const QByteArray &data) {
    QMap<QString, QMap<QString, QMap<QString, QString>>> out;
    
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    if (error.error == QJsonParseError::NoError) {
        QJsonObject json = doc.object();
        if (json["data"].isArray()) {
            for (const auto &badgeSetEntry : json["data"].toArray()) {
                const QJsonObject badgeSetJson = badgeSetEntry.toObject();
                const QString badgeSetName = badgeSetJson["set_id"].toString();
                if (badgeSetName.isEmpty()) {
                    continue;
                }

                QMap<QString, QMap<QString, QString>> loadedBadgeSet;
                for (const auto &versionEntry : badgeSetJson["versions"].toArray()) {
                    const QJsonObject versionJson = versionEntry.toObject();
                    const QString version = versionJson["id"].toString();
                    if (!version.isEmpty()) {
                        loadedBadgeSet.insert(version, convertJsonStringMap(versionJson));
                    }
                }

                out.insert(badgeSetName, loadedBadgeSet);
            }
        }
        else if (!json["badge_sets"].isNull()) {
            auto badge_sets = json["badge_sets"].toObject();
            for (auto badge_set_entry = badge_sets.constBegin(); badge_set_entry != badge_sets.end(); badge_set_entry++) {
                QString badge_set_name = badge_set_entry.key();

                if (!badge_set_entry.value().isNull()) {
                    auto badge_set_json = badge_set_entry.value().toObject();
                    if (!badge_set_json["versions"].isNull()) {

                        QMap<QString, QMap<QString, QString>> loadedBadgeSet;

                        auto versions_json = badge_set_json["versions"].toObject();
                        for (auto version_entry = versions_json.constBegin(); version_entry != versions_json.constEnd(); version_entry++) {
                            QString version_str = version_entry.key();
                            
                            if (version_entry.value().isObject()) {
                                loadedBadgeSet.insert(version_str, convertJsonStringMap(version_entry.value().toObject()));
                            }
                        }

                        out.insert(badge_set_name, loadedBadgeSet);

                    }

                }
            }
        }
    }

    return out;
}

void JsonParser::parseBitsData(const QByteArray &data, QMap<QString, QMap<QString, QString>> & outUrls, QMap<QString, QMap<QString, QString>> & outColors)
{
    const QString BITS_THEME = "dark";
    const QString BITS_TYPE = "animated";
    const QString BITS_SIZE_LODPI = "1";
    const QString BITS_SIZE_HIDPI = "2";

    const QString BITS_SIZE = SettingsManager::getInstance()->hiDpi() ? BITS_SIZE_HIDPI : BITS_SIZE_LODPI;

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    if (error.error == QJsonParseError::NoError) {
        QJsonObject json = doc.object();

        QJsonArray actions = json["data"].isArray() ? json["data"].toArray() : json["actions"].toArray();
        for (const auto & actionEntry : actions) {
            
            QMap<QString, QString> actionUrlsMap;
            QMap<QString, QString> actionColorsMap;

            const QJsonObject & actionObj = actionEntry.toObject();
            QString actionPrefix = actionObj["prefix"].toString();

            const QJsonArray & tiers = actionObj["tiers"].toArray();
            for (const auto & tierEntry : tiers) {
                const QJsonObject & tierObj = tierEntry.toObject();

                int minBits = tierObj["min_bits"].toInt();

                const QString & url = tierObj["images"].toObject()[BITS_THEME].toObject()[BITS_TYPE].toObject()[BITS_SIZE].toString();
                qDebug() << "bits url for" << actionPrefix << "minBits" << minBits << "is" << url;
                actionUrlsMap.insert(QString::number(minBits), url);

                const QString & color = tierObj["color"].toString();
                actionColorsMap.insert(QString::number(minBits), color);
            }

            if (actionUrlsMap.size() > 0) {
                outUrls.insert(actionPrefix, actionUrlsMap);
            }

            if (actionColorsMap.size() > 0) {
                outColors.insert(actionPrefix, actionColorsMap);
            }
        }
    }
}

int JsonParser::parseTotal(const QByteArray &data)
{
    int total = 0;
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data,&error);

    if (error.error == QJsonParseError::NoError){
        QJsonObject json = doc.object();
        if (!json["_total"].isNull())
            total = json["_total"].toInt();
    }

    return total;
}

QMap<QString, QList<QString>> JsonParser::parseChatterList(const QByteArray &data)
{
    QMap<QString, QList<QString>> out;
    
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    if (error.error == QJsonParseError::NoError) {
        QJsonObject json = doc.object();

        QJsonObject chatters = json["chatters"].toObject();
        
        for (auto groupEntry = chatters.constBegin(); groupEntry != chatters.constEnd(); groupEntry++) {
            QList<QString> groupChatters;
            const QJsonArray & groupChattersJson = groupEntry.value().toArray();
            for (const auto & chatter : groupChattersJson) {
                groupChatters.append(chatter.toString());
            }
            out.insert(groupEntry.key(), groupChatters);
        }
    }

    return out;
    
}

PagedResult<QString> JsonParser::parseBlockList(const QByteArray &data)
{
    PagedResult<QString> out;

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    if (error.error == QJsonParseError::NoError) {
        QJsonObject json = doc.object();

        const QJsonArray helixBlocks = json["data"].toArray();
        if (!helixBlocks.isEmpty() || json.contains("pagination")) {
            for (const auto & block : helixBlocks) {
                const auto blockObj = block.toObject();
                const QString login = blockObj["user_login"].toString();
                const QString displayName = blockObj["display_name"].toString();
                if (!login.isEmpty()) {
                    out.items.append(login);
                } else if (!displayName.isEmpty()) {
                    out.items.append(displayName);
                }
            }

            out.cursor = json["pagination"].toObject()["cursor"].toString();
            out.total = out.items.size();
        }
        else {
            out.total = json["_total"].toInt();

            QJsonArray blocks = json["blocks"].toArray();

            for (const auto & block : blocks) {
                const auto & blockObj = block.toObject();
                const auto & name = blockObj["user"].toObject()["name"].toString();
                if (!name.isEmpty()) {
                    out.items.append(name);
                }
            }
        }
    }

    return out;
}


QMap<QString, QString> JsonParser::parseBttvEmotesData(const QByteArray &data)
{
    QMap<QString, QString> out;

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    if (error.error == QJsonParseError::NoError) {
        QJsonObject json = doc.object();

        QJsonArray emotes = json["emotes"].toArray();

        for (const auto & emote : emotes) {
            const auto & emoteObj = emote.toObject();
            const auto & id = emoteObj["id"].toString();
            const auto & code = emoteObj["code"].toString();
            if (!id.isEmpty() && !code.isEmpty()) {
                out.insert(code, id);
            }
        }
    }

    return out;
}

QMap<QString, QString> JsonParser::parseFfzEmotesData(const QByteArray &data)
{
    QMap<QString, QString> out;

    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);

    if (error.error == QJsonParseError::NoError) {
        const QJsonObject json = doc.object();
        const QJsonObject sets = json["sets"].toObject();

        for (auto set = sets.constBegin(); set != sets.constEnd(); ++set) {
            const QJsonArray emotes = set.value().toObject()["emoticons"].toArray();
            for (const auto &emote : emotes) {
                const QJsonObject emoteObj = emote.toObject();
                if (emoteObj["hidden"].toBool()) {
                    continue;
                }

                const QJsonValue idValue = emoteObj["id"];
                const QString id = idValue.isString() ? idValue.toString() : QString::number(idValue.toInt());
                const QString code = emoteObj["name"].toString();
                if (!id.isEmpty() && !code.isEmpty()) {
                    out.insert(code, id);
                }
            }
        }
    }

    return out;
}

QPair<QString,QString> JsonParser::parseVersion(const QByteArray &data)
{
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(data, &error);
    QString version;
    QString url;

    if (error.error == QJsonParseError::NoError) {
        if (doc.isObject()) {
            const QJsonObject json = doc.object();
            version = json["tag_name"].toString().trimmed();
            if (version.isEmpty()) {
                version = json["name"].toString().trimmed();
            }
            url = json["html_url"].toString().trimmed();
        } else if (doc.isArray()) {
            QVersionNumber latest;
            const QJsonArray tags = doc.array();
            for (const QJsonValue &tagValue : tags) {
                updateVersionCandidate(tagValue.toObject()["name"].toString().trimmed(), version, latest);
            }
        }
    }

    return qMakePair<QString,QString>(version, url);
}
