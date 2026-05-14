#pragma once

#include <QObject>
#include <QStringList>
#include "../network/networkmanager.h"
#include "imageprovider.h"
#include "badgeimageprovider.h"

#include "singletonprovider.h"

class BadgeContainer: public QObject
{
    ORION_QML_SINGLETON
    Q_OBJECT

    bool haveEmoteSets;
    QStringList lastRequestedEmoteSetIDs;
    QMap<QString, QMap<QString, QString>> lastEmoteSets;
    QMap<QString, QMap<QString, QMap<QString, QMap<QString, QString>>>> channelBadgeBetaUrls;
    QMap<QString, QMap<QString, QString>> channelBttvEmotes;
    QMap<QString, QMap<QString, QString>> channelFfzEmotes;
    QMap<qint64, QMap<QString, QMap<QString, QString>>> channelBitsUrls;
    QMap<qint64, QMap<QString, QMap<QString, QString>>> channelBitsColors;

    NetworkManager *netman;

    static BadgeContainer *instance;

    BadgeImageProvider badgeImageProvider;
    BitsImageProvider bitsImageProvider;

    BadgeContainer();
public:
    static BadgeContainer *getInstance();

    BadgeImageProvider * getBadgeImageProvider() {
        return &badgeImageProvider;
    }

    BitsImageProvider * getBitsImageProvider() {
        return &bitsImageProvider;
    }

    bool getChannelBadgeBetaUrl(const QString channel, const QString badgeName, const QString version, const QString imageFormat, QString & outUrl) const;

    bool getChannelBitsUrl(const qint64 channelId, const QString & prefix, const QString & minBits, QString & outUrl) const;

    const QUrl getBitsUrlForKey(const QString & key) const;

    bool getChannelBitsColor(const qint64 channelId, const QString & prefix, const QString & minBits, QString & outColor);

public slots:
    void onEmoteSetsUpdated(const QMap<QString, QMap<QString, QString>>);
    void innerChannelBadgeBetaUrlsLoaded(const quint64 channelId, const QMap<QString, QMap<QString, QMap<QString, QString>>> badgeData);
    void innerGlobalBadgeBetaUrlsLoaded(const QMap<QString, QMap<QString, QMap<QString, QString>>> badgeData);
    void innerChannelBitsDataLoaded(qint64 channelID, BitsQStringsMap channelBitsUrls, BitsQStringsMap channelBitsColors);
    void innerGlobalBitsDataLoaded(BitsQStringsMap globalBitsUrls, BitsQStringsMap globalBitsColors);
    void innerChannelBttvEmotesLoaded(const QString channel, QMap<QString, QString> & emotesByCode);
    void innerGlobalBttvEmotesLoaded(QMap<QString, QString> & emotesByCode);
    void innerChannelFfzEmotesLoaded(const QString channel, QMap<QString, QString> emotesByCode);
    void innerGlobalFfzEmotesLoaded(QMap<QString, QString> emotesByCode);
    bool loadEmoteSets(bool reload, const QStringList &emoteSetIDs);
    bool loadChannelBetaBadgeUrls(quint64 channel);
    bool loadChannelBitsUrls(qint64 channel);
    bool loadChannelBttvEmotes(const QString channel);
    bool loadChannelFfzEmotes(const QString channel);

signals:
    void emoteSetsLoaded(QVariantMap emoteSets);
    void channelBadgeBetaUrlsLoaded(const QString &channel, QVariantMap badgeSetData);

    void channelBitsUrlsLoaded(const qint64 channelID, BitsQStringsMap bitsUrls, BitsQStringsMap bitsColors);

    void channelBttvEmotesLoaded(const QString channel, QMap<QString, QString> emotesByCode);
    void channelFfzEmotesLoaded(const QString channel, QMap<QString, QString> emotesByCode);
};
