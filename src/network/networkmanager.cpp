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

#include "networkmanager.h"
#include "../util/fileutils.h"
#include "../util/jsonparser.h"
#include "../util/m3u8parser.h"
#include <QEventLoop>
#include <QSet>
#include <QSslSocket>
#include <QtGlobal>
#include <QUrlQuery>
#include "../model/settingsmanager.h"

namespace {

// Auxiliary QNetworkRequest::User slots used to carry async request context.
constexpr auto RequestContextAttribute1 = static_cast<QNetworkRequest::Attribute>(QNetworkRequest::User + 1);
constexpr auto RequestContextAttribute2 = static_cast<QNetworkRequest::Attribute>(QNetworkRequest::User + 2);
constexpr auto RequestContextAttribute3 = static_cast<QNetworkRequest::Attribute>(QNetworkRequest::User + 3);
constexpr auto RequestContextAttribute4 = static_cast<QNetworkRequest::Attribute>(QNetworkRequest::User + 4);

QNetworkRequest githubVersionRequest(const QUrl &url)
{
    QNetworkRequest req;
    req.setRawHeader("User-Agent", "Orion");
    req.setRawHeader("Accept", "application/vnd.github.v3+json");
    req.setUrl(url);
    return req;
}

QString githubTagUrl(const QString &tag)
{
    return QStringLiteral("https://github.com/belagrf/orion/tree/%1")
            .arg(QString::fromLatin1(QUrl::toPercentEncoding(tag)));
}

}

NetworkManager *NetworkManager::singleton = nullptr;

NetworkManager::NetworkManager(QNetworkAccessManager *man) : QObject(man)
{
    operation = man;
    app_access_token = qEnvironmentVariable("ORION_TWITCH_APP_ACCESS_TOKEN").trimmed();
    app_client_id = qEnvironmentVariable("ORION_TWITCH_CLIENT_ID").trimmed();
    app_client_secret = qEnvironmentVariable("ORION_TWITCH_CLIENT_SECRET").trimmed();
    if (!app_access_token.isEmpty() && app_client_id.isEmpty()) {
        app_client_id = getClientId();
    }
    if (app_access_token.isEmpty() && !app_client_secret.isEmpty() && app_client_id.isEmpty()) {
        qWarning() << "ORION_TWITCH_CLIENT_SECRET is set but ORION_TWITCH_CLIENT_ID is missing; cannot request a Twitch app access token";
    }

    connectionOK = false;

    //Set up offline poller
    offlinePoller.setInterval(2000);
    connect(&offlinePoller, &QTimer::timeout, this, &NetworkManager::testNetworkConnection);

    accessTokenValidator.setInterval(60 * 60 * 1000);
    connect(&accessTokenValidator, &QTimer::timeout, this, &NetworkManager::validateAccessToken);

    //SSL errors handle (down the drain)
    connect(operation, &QNetworkAccessManager::sslErrors, this, &NetworkManager::handleSslErrors);

    if (!QSslSocket::supportsSsl()) {
        qWarning().noquote() << "Qt Network SSL support is unavailable; HTTPS requests will fail."
                             << "Build SSL:" << QSslSocket::sslLibraryBuildVersionString()
                             << "Runtime SSL:" << QSslSocket::sslLibraryVersionString();
    }

    //Initial network reachability check
    testNetworkConnection();

    //Handshake
    operation->connectToHostEncrypted(QStringLiteral("api.twitch.tv"));

    //Set up listening to access token changes
    connect(SettingsManager::getInstance(), &SettingsManager::accessTokenChanged, this, &NetworkManager::setAccessToken);
    setAccessToken(SettingsManager::getInstance()->accessToken());
}

void NetworkManager::setAccessToken(const QString &accessToken)
{
    access_token = accessToken.trimmed();
    if (access_token.isEmpty()) {
        accessTokenValidator.stop();
        access_token_validation_pending = false;
        requestAppAccessToken();
        return;
    }

    validateAccessToken();
    if (!accessTokenValidator.isActive())
        accessTokenValidator.start();

    requestAppAccessToken();
}

QString NetworkManager::helixAccessToken(HelixAuthMode mode) const
{
    if (!access_token.isEmpty()) {
        return access_token;
    }
    if (mode == HelixAuthMode::UserOrApp && !app_access_token.isEmpty()) {
        return app_access_token;
    }
    return QString();
}

QString NetworkManager::helixClientId(HelixAuthMode mode) const
{
    if (!access_token.isEmpty()) {
        return getClientId();
    }
    if (mode == HelixAuthMode::UserOrApp && !app_access_token.isEmpty() && !app_client_id.isEmpty()) {
        return app_client_id;
    }
    return getClientId();
}

bool NetworkManager::requireHelixAccessToken(const QString &operation, HelixAuthMode mode)
{
    if (!helixAccessToken(mode).isEmpty()) {
        return true;
    }

    const QString message = mode == HelixAuthMode::UserOnly
            ? operation + " requires Twitch login"
            : operation + " requires Twitch login, ORION_TWITCH_APP_ACCESS_TOKEN, or ORION_TWITCH_CLIENT_ID with ORION_TWITCH_CLIENT_SECRET";
    qWarning().noquote() << message;
    emit error(message);
    return false;
}

void NetworkManager::addHelixHeaders(QNetworkRequest &request, HelixAuthMode mode) const
{
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Client-ID", helixClientId(mode).toUtf8());
    const QString token = helixAccessToken(mode);
    if (!token.isEmpty()) {
        request.setRawHeader("Authorization", ("Bearer " + token).toUtf8());
    }
}

void NetworkManager::requestAppAccessToken()
{
    if (!app_access_token.isEmpty()
            || app_access_token_request_pending
            || !access_token.isEmpty()
            || app_client_id.isEmpty()
            || app_client_secret.isEmpty()) {
        return;
    }

    QNetworkRequest request;
    request.setUrl(QUrl(QStringLiteral("https://id.twitch.tv/oauth2/token")));
    request.setRawHeader("Accept", "application/json");
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/x-www-form-urlencoded"));

    QUrlQuery form;
    form.addQueryItem("client_id", app_client_id);
    form.addQueryItem("client_secret", app_client_secret);
    form.addQueryItem("grant_type", "client_credentials");

    app_access_token_request_pending = true;
    QNetworkReply *reply = operation->post(request, form.toString(QUrl::FullyEncoded).toUtf8());
    connect(reply, &QNetworkReply::finished, this, &NetworkManager::appAccessTokenReply);
}

void NetworkManager::validateAccessToken()
{
    if (access_token.isEmpty() || access_token_validation_pending)
        return;

    QNetworkRequest request;
    request.setUrl(QUrl(QStringLiteral("https://id.twitch.tv/oauth2/validate")));
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", ("OAuth " + access_token).toUtf8());
    request.setAttribute(QNetworkRequest::User, access_token);

    access_token_validation_pending = true;
    QNetworkReply *reply = operation->get(request);
    connect(reply, &QNetworkReply::finished, this, &NetworkManager::accessTokenValidationReply);
}

NetworkManager::~NetworkManager()
{
    offlinePoller.stop();
    accessTokenValidator.stop();
    qDebug() << "Destroyer: NetworkManager";
    //operation->deleteLater();
}

void NetworkManager::initialize(QNetworkAccessManager *mgr)
{
    singleton = new NetworkManager(mgr);
}

void NetworkManager::testNetworkConnection()
{
    if (connectionTestReply) {
        return;
    }

    QEventLoop loop;
    QTimer timeoutTimer;
    timeoutTimer.setSingleShot(true);
    connect(this, &NetworkManager::finishedConnectionTest, &loop, &QEventLoop::quit);
    connect(&timeoutTimer, &QTimer::timeout, this, [this]() {
        if (connectionTestReply) {
            qWarning() << "Network connection test timed out";
            connectionTestReply->abort();
        }
    });

    testConnection();
    timeoutTimer.start(10000);
    loop.exec();

    if (!connectionOK && !offlinePoller.isActive())
        offlinePoller.start();
}

bool NetworkManager::networkAccess() {
    return connectionOK;
}

void NetworkManager::testConnection()
{
    QNetworkRequest request;
    request.setUrl(QUrl("https://www.twitch.tv"));

    QNetworkReply *reply = operation->get(request);
    connectionTestReply = reply;

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::testConnectionReply);
}

void NetworkManager::testConnectionReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        emit finishedConnectionTest();
        return;
    }

    if (reply == connectionTestReply) {
        connectionTestReply = nullptr;
    }

//    if (reply->error() == QNetworkReply::NoError)
//        qDebug() << "Got response: " << reply->readAll();

    handleNetworkError(reply);
    reply->deleteLater();

    emit finishedConnectionTest();
}

void NetworkManager::checkVersion()
{
    QNetworkRequest req = githubVersionRequest(
                QUrl(QStringLiteral("https://api.github.com/repos/belagrf/orion/releases/latest")));

    QNetworkReply *reply = operation->get(req);
    connect(reply, &QNetworkReply::finished, this, [reply, this](){
        if (reply->error() != QNetworkReply::NoError) {
            const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            const QString error = reply->errorString();
            reply->deleteLater();

            if (status == 404) {
                checkVersionTags();
                return;
            }

            qDebug() << "Version check failed:" << error;
            emit versionCheckEnded(QString(), QString());
            return;
        }

        QPair<QString, QString> info = JsonParser::parseVersion(reply->readAll());
        emit versionCheckEnded(info.first, info.second);
        reply->deleteLater();
    });
}

void NetworkManager::checkVersionTags()
{
    QNetworkRequest req = githubVersionRequest(
                QUrl(QStringLiteral("https://api.github.com/repos/belagrf/orion/tags?per_page=100")));

    QNetworkReply *reply = operation->get(req);
    connect(reply, &QNetworkReply::finished, this, [reply, this](){
        if (reply->error() != QNetworkReply::NoError) {
            const QString error = reply->errorString();
            qDebug() << "Version tag check failed:" << error;
            emit versionCheckEnded(QString(), QString());
            reply->deleteLater();
            return;
        }

        QPair<QString, QString> info = JsonParser::parseVersion(reply->readAll());
        if (!info.first.isEmpty() && info.second.isEmpty()) {
            info.second = githubTagUrl(info.first);
        }

        emit versionCheckEnded(info.first, info.second);
        reply->deleteLater();
    });
}

/**
 * @brief NetworkManager::getStream
 * Gets single stream status. Usable for polling a channel's stream
 */
void NetworkManager::getStream(const quint64 channelId)
{
    if (channelId == 0) {
        emit streamGetOperationFinished(channelId, false);
        return;
    }

    if (!requireHelixAccessToken("Stream status")) {
        emit streamGetOperationFinished(channelId, false);
        return;
    }

    QUrl url(QString(HELIX_API) + "/streams");
    QUrlQuery query;
    query.addQueryItem("user_id", QString::number(channelId));
    query.addQueryItem("first", "1");
    url.setQuery(query);

    QNetworkRequest request;
    addHelixHeaders(request);
    request.setUrl(url);
    request.setAttribute(QNetworkRequest::User, channelId);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::streamReply);
}

void NetworkManager::getStreams(const QString &url)
{
    //qDebug() << "GET: " << url;
    const QUrl requestUrl(url);
    const bool isHelix = requestUrl.path().startsWith("/helix/");
    if (!isHelix) {
        qWarning() << "Ignoring legacy stream metadata request" << requestUrl;
        QList<Channel *> empty;
        emit allStreamsOperationFinished(empty);
        return;
    }
    if (!requireHelixAccessToken("Stream metadata")) {
        QList<Channel *> empty;
        emit allStreamsOperationFinished(empty);
        return;
    }

    QNetworkRequest request;
    addHelixHeaders(request);
    request.setUrl(requestUrl);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::allStreamsReply);
}

void NetworkManager::getGames(const quint32 &offset, const quint32 &limit)
{
    if (!requireHelixAccessToken("Top games")) {
        QList<Game *> empty;
        emit gamesOperationFinished(empty);
        return;
    }

    const quint32 pageSize = qMax<quint32>(1, qMin<quint32>(limit, 100));

    if (offset == 0) {
        topGamesPageCursors.clear();
    }
    else if (!topGamesPageCursors.contains(offset)) {
        QList<Game *> empty;
        emit gamesOperationFinished(empty);
        return;
    }

    QNetworkRequest request;
    addHelixHeaders(request);
    request.setAttribute(QNetworkRequest::User, offset);
    request.setAttribute(RequestContextAttribute1, pageSize);

    QUrl url(QString(HELIX_API) + "/games/top");
    QUrlQuery query;
    query.addQueryItem("first", QString::number(pageSize));

    const QString cursor = topGamesPageCursors.value(offset);
    if (!cursor.isEmpty()) {
        query.addQueryItem("after", cursor);
    }
    url.setQuery(query);

    request.setUrl(url);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::gamesReply);
}

void NetworkManager::searchChannels(const QString &query, const quint32 &offset, const quint32 &limit)
{
    const QString normalizedQuery = query.trimmed();
    if (normalizedQuery.isEmpty()) {
        QList<Channel *> empty;
        emit searchChannelsOperationFinished(empty, 0);
        return;
    }

    if (!requireHelixAccessToken("Channel search")) {
        QList<Channel *> empty;
        emit searchChannelsOperationFinished(empty, 0);
        return;
    }

    const quint32 pageSize = qMax<quint32>(1, qMin<quint32>(limit, 100));

    QNetworkRequest request;
    addHelixHeaders(request);
    request.setAttribute(QNetworkRequest::User, offset);
    request.setAttribute(RequestContextAttribute1, pageSize);

    if (offset == 0 || normalizedQuery != lastSearchChannelsQuery) {
        searchChannelsPageCursors.clear();
        lastSearchChannelsQuery = normalizedQuery;
    }

    QUrl url(QString(HELIX_API) + "/search/channels");
    QUrlQuery urlQuery;
    urlQuery.addQueryItem("query", normalizedQuery);
    urlQuery.addQueryItem("first", QString::number(pageSize));

    const QString cursor = searchChannelsPageCursors.value(offset);
    if (!cursor.isEmpty()) {
        urlQuery.addQueryItem("after", cursor);
    }
    url.setQuery(urlQuery);

    qDebug() << "requesting" << url;
    request.setUrl(url);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::searchChannelsReply);
}

void NetworkManager::searchGames(const QString &query)
{
    const QString normalizedQuery = query.trimmed();
    if (normalizedQuery.isEmpty()) {
        QList<Game *> empty;
        emit searchGamesOperationFinished(empty);
        return;
    }

    if (!requireHelixAccessToken("Category search")) {
        QList<Game *> empty;
        emit searchGamesOperationFinished(empty);
        return;
    }

    QNetworkRequest request;
    addHelixHeaders(request);

    QUrl url(QString(HELIX_API) + "/search/categories");
    QUrlQuery urlQuery;
    urlQuery.addQueryItem("query", normalizedQuery);
    url.setQuery(urlQuery);

    request.setUrl(url);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::searchGamesReply);
}

void NetworkManager::getFeaturedStreams()
{
    if (!requireHelixAccessToken("Featured streams")) {
        QList<Channel *> empty;
        emit featuredStreamsOperationFinished(empty, 0);
        return;
    }

    QNetworkRequest request;
    addHelixHeaders(request);

    QUrl url(QString(HELIX_API) + "/streams");
    QUrlQuery query;
    query.addQueryItem("first", "25");
    url.setQuery(query);

    request.setUrl(url);

    //qDebug() << url;

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::featuredStreamsReply);
}

void NetworkManager::getStreamsForLanguage(const QString &language, const quint32 &offset, const quint32 &limit)
{
    const QString normalizedLanguage = language.trimmed().toLower();
    const quint32 pageSize = qMax<quint32>(1, qMin<quint32>(limit, 100));

    if (normalizedLanguage.isEmpty()) {
        QList<Channel *> empty;
        emit gameStreamsOperationFinished(empty, offset);
        return;
    }

    if (!requireHelixAccessToken("Language stream search")) {
        QList<Channel *> empty;
        emit gameStreamsOperationFinished(empty, offset);
        return;
    }

    if (offset == 0 || normalizedLanguage != lastLanguageStreamsQuery) {
        languageStreamsPageCursors.clear();
        lastLanguageStreamsQuery = normalizedLanguage;
    }
    else if (!languageStreamsPageCursors.contains(offset)) {
        QList<Channel *> empty;
        emit gameStreamsOperationFinished(empty, offset);
        return;
    }

    QUrl url(QString(HELIX_API) + "/streams");
    QUrlQuery query;
    query.addQueryItem("language", normalizedLanguage);
    query.addQueryItem("first", QString::number(pageSize));

    const QString cursor = languageStreamsPageCursors.value(offset);
    if (!cursor.isEmpty()) {
        query.addQueryItem("after", cursor);
    }
    url.setQuery(query);

    QNetworkRequest request;
    addHelixHeaders(request);
    request.setUrl(url);
    request.setAttribute(QNetworkRequest::User, offset);
    request.setAttribute(RequestContextAttribute1, pageSize);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::gameStreamsReply);
}

void NetworkManager::getStreamsForGame(const QString &game, const quint32 &offset, const quint32 &limit, const QString &language)
{
    const QString gameName = game.trimmed();
    const QString normalizedLanguage = language.trimmed().toLower();
    const QString queryKey = gameName + "\n" + normalizedLanguage;
    const quint32 pageSize = qMax<quint32>(1, qMin<quint32>(limit, 100));

    if (gameName.isEmpty()) {
        QList<Channel *> empty;
        emit gameStreamsOperationFinished(empty, offset);
        return;
    }

    if (!requireHelixAccessToken("Game stream search")) {
        QList<Channel *> empty;
        emit gameStreamsOperationFinished(empty, offset);
        return;
    }

    if (offset == 0 || queryKey != lastGameStreamsQuery) {
        gameStreamsPageCursors.clear();
        lastGameStreamsQuery = queryKey;
    }
    else if (!gameStreamsPageCursors.contains(offset)) {
        QList<Channel *> empty;
        emit gameStreamsOperationFinished(empty, offset);
        return;
    }

    const QString gameId = gameStreamsGameIds.value(gameName);
    if (!gameId.isEmpty()) {
        getStreamsForGameId(gameId, offset, pageSize, normalizedLanguage);
        return;
    }

    QUrl url(QString(HELIX_API) + "/games");
    QUrlQuery query;
    query.addQueryItem("name", gameName);
    url.setQuery(query);

    QNetworkRequest request;
    addHelixHeaders(request);
    request.setUrl(url);
    request.setAttribute(QNetworkRequest::User, offset);
    request.setAttribute(RequestContextAttribute1, pageSize);
    request.setAttribute(RequestContextAttribute2, gameName);
    request.setAttribute(RequestContextAttribute3, normalizedLanguage);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::gameStreamsGameLookupReply);
}

void NetworkManager::getStreamsForGameId(const QString &gameId, const quint32 offset, const quint32 limit, const QString &language)
{
    const QString normalizedGameId = gameId.trimmed();
    const QString normalizedLanguage = language.trimmed().toLower();
    if (normalizedGameId.isEmpty()) {
        QList<Channel *> empty;
        emit gameStreamsOperationFinished(empty, offset);
        return;
    }

    QUrl url(QString(HELIX_API) + "/streams");
    QUrlQuery query;
    query.addQueryItem("game_id", normalizedGameId);
    if (!normalizedLanguage.isEmpty()) {
        query.addQueryItem("language", normalizedLanguage);
    }
    query.addQueryItem("first", QString::number(limit));

    const QString cursor = gameStreamsPageCursors.value(offset);
    if (!cursor.isEmpty()) {
        query.addQueryItem("after", cursor);
    }
    url.setQuery(query);

    QNetworkRequest request;
    addHelixHeaders(request);
    request.setUrl(url);
    request.setAttribute(QNetworkRequest::User, offset);
    request.setAttribute(RequestContextAttribute1, limit);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::gameStreamsReply);
}

void NetworkManager::getChannelPlaybackStream(const QString &channelName)
{
    const QString normalizedChannelName = channelName.trimmed();
    if (normalizedChannelName.isEmpty()) {
        emit m3u8OperationFinished(QVariantMap());
        return;
    }

    QString url = QString(TWITCH_API)
            + QString("/channels/%1").arg(normalizedChannelName)
            + QString("/access_token");
    QNetworkRequest request;
    request.setRawHeader("Client-ID", getPrivateClientId().toUtf8());
    request.setUrl(QUrl(url));

    request.setAttribute(QNetworkRequest::User, LIVE);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::streamExtractReply);
}

void NetworkManager::getBroadcasts(const quint64 channelId, quint32 offset, quint32 limit, const QString &type)
{
    if (channelId == 0) {
        emit broadcastsOperationFailed();
        return;
    }

    if (!requireHelixAccessToken("VOD listing")) {
        emit broadcastsOperationFailed();
        return;
    }

    const quint32 pageSize = qMax<quint32>(1, qMin<quint32>(limit, 100));

    const QString videoType = type.trimmed();
    if (offset == 0 || channelId != lastBroadcastsChannelId || videoType != lastBroadcastsType) {
        broadcastsPageCursors.clear();
        lastBroadcastsChannelId = channelId;
        lastBroadcastsType = videoType;
    }
    else if (!broadcastsPageCursors.contains(offset)) {
        QList<Vod *> empty;
        emit broadcastsOperationFinished(empty);
        return;
    }

    QUrl url;
    QNetworkRequest request;
    addHelixHeaders(request);
    request.setAttribute(QNetworkRequest::User, offset);
    request.setAttribute(RequestContextAttribute1, pageSize);

    url = QUrl(QString(HELIX_API) + "/videos");
    QUrlQuery query;
    query.addQueryItem("user_id", QString::number(channelId));
    query.addQueryItem("first", QString::number(pageSize));
    if (!videoType.isEmpty()) {
        query.addQueryItem("type", videoType);
    }

    const QString cursor = broadcastsPageCursors.value(offset);
    if (!cursor.isEmpty()) {
        query.addQueryItem("after", cursor);
    }
    url.setQuery(query);

    request.setUrl(url);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::broadcastsReply);
}

void NetworkManager::getBroadcastPlaybackStream(const QString &vod)
{
    const QString normalizedVod = vod.trimmed();
    bool vodOk = false;
    const quint64 vodId = normalizedVod.toULongLong(&vodOk);
    if (!vodOk || vodId == 0) {
        emit m3u8OperationBFinished(QVariantMap());
        return;
    }

    QString url = QString(TWITCH_API)
            + QString("/vods/%1").arg(normalizedVod)
            + QString("/access_token");
    QNetworkRequest request;
    request.setRawHeader("Client-ID", getPrivateClientId().toUtf8());
    request.setUrl(QUrl(url));

    request.setAttribute(QNetworkRequest::User, VOD);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::streamExtractReply);
}

void NetworkManager::getUser()
{
    if (!requireHelixAccessToken("User profile loading", HelixAuthMode::UserOnly)) {
        emit userOperationFinished(QString(), 0);
        return;
    }

    QString url = QString(HELIX_API) + "/users";

    QNetworkRequest request;
    addHelixHeaders(request, HelixAuthMode::UserOnly);
    request.setUrl(QUrl(url));

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::userReply);
}

void NetworkManager::getUserFavourites(const quint64 userId, quint32 offset, quint32 limit)
{
    if (userId == 0) {
        QList<Channel *> empty;
        emit favouritesReplyFinished(empty, offset, offset);
        return;
    }

    if (!requireHelixAccessToken("Followed channel loading", HelixAuthMode::UserOnly)) {
        QList<Channel *> empty;
        emit favouritesReplyFinished(empty, offset, offset);
        return;
    }

    if (offset == 0) {
        userFavouritesPageCursors.clear();
    }
    else if (!userFavouritesPageCursors.contains(offset)) {
        QList<Channel *> empty;
        emit favouritesReplyFinished(empty, offset, offset);
        return;
    }

    const quint32 pageSize = qMax<quint32>(1, qMin<quint32>(limit, 100));
    QUrl url(QString(HELIX_API) + "/channels/followed");
    QUrlQuery query;
    query.addQueryItem("user_id", QString::number(userId));
    query.addQueryItem("first", QString::number(pageSize));

    const QString cursor = userFavouritesPageCursors.value(offset);
    if (!cursor.isEmpty()) {
        query.addQueryItem("after", cursor);
    }
    url.setQuery(query);

    QNetworkRequest request;
    addHelixHeaders(request, HelixAuthMode::UserOnly);
    request.setUrl(url);
    request.setAttribute(QNetworkRequest::User, offset);
    request.setAttribute(RequestContextAttribute1, pageSize);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::favouritesReply);
}

void NetworkManager::getEmoteSets(const QStringList &emoteSetIDs) {
    if (!requireHelixAccessToken("Emote set loading")) {
        QMap<QString, QMap<QString, QString>> empty;
        emit getEmoteSetsOperationFinished(empty);
        return;
    }

    pendingEmoteSets.clear();
    pendingEmoteSetReplies = (emoteSetIDs.size() + 24) / 25;

    for (int pos = 0; pos < emoteSetIDs.size(); pos += 25) {
        const QStringList chunk = emoteSetIDs.mid(pos, 25);

        QUrl url(QString(HELIX_API) + "/chat/emotes/set");
        QUrlQuery query;
        for (const auto &id : chunk) {
            query.addQueryItem("emote_set_id", id);
        }
        url.setQuery(query);

        qDebug() << "Requesting" << url;

        QNetworkRequest request;
        addHelixHeaders(request);
        request.setUrl(url);

        QNetworkReply *reply = operation->get(request);

        connect(reply, &QNetworkReply::finished, this, &NetworkManager::emoteSetsReply);
    }

    if (emoteSetIDs.isEmpty()) {
        emit getEmoteSetsOperationFinished(pendingEmoteSets);
    }
}

void NetworkManager::requestHelixChatterList(const QString &channel, const quint64 broadcasterId, const quint64 moderatorId, const quint64 requestId, const QString &cursor)
{
    QUrl url(QString(HELIX_API) + "/chat/chatters");
    QUrlQuery query;
    query.addQueryItem("broadcaster_id", QString::number(broadcasterId));
    query.addQueryItem("moderator_id", QString::number(moderatorId));
    query.addQueryItem("first", "1000");
    if (!cursor.isEmpty()) {
        query.addQueryItem("after", cursor);
    }
    url.setQuery(query);

    qDebug() << "Request" << url;

    QNetworkRequest request;
    addHelixHeaders(request, HelixAuthMode::UserOnly);
    request.setUrl(url);
    request.setAttribute(QNetworkRequest::User, true);
    request.setAttribute(RequestContextAttribute1, channel);
    request.setAttribute(RequestContextAttribute2, broadcasterId);
    request.setAttribute(RequestContextAttribute3, moderatorId);
    request.setAttribute(RequestContextAttribute4, requestId);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::chatterListReply);
}

void NetworkManager::loadLegacyChatterList(const QString &channel, const quint64 requestId)
{
    qDebug() << "Loading legacy TMI viewer list for" << channel;
    const QString url = QString(TWITCH_TMI_USER_API)
            + QString::fromLatin1(QUrl::toPercentEncoding(channel))
            + QString("/chatters");

    qDebug() << "Request" << url;

    QNetworkRequest request;
    request.setUrl(QUrl(url));
    request.setAttribute(QNetworkRequest::User, false);
    request.setAttribute(RequestContextAttribute1, channel);
    request.setAttribute(RequestContextAttribute4, requestId);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::chatterListReply);
}

void NetworkManager::loadChatterList(const QString channel, const quint64 broadcasterId, const quint64 moderatorId) {
    QString normalizedChannel = channel.trimmed();
    if (normalizedChannel.startsWith("#")) {
        normalizedChannel.remove(0, 1);
    }

    if (normalizedChannel.isEmpty()) {
        chatterListRequestId++;
        pendingHelixChatters.clear();
        pendingHelixChatterChannel.clear();
        pendingHelixChatterBroadcasterId = 0;
        pendingHelixChatterModeratorId = 0;
        QMap<QString, QList<QString>> empty;
        emit chatterListLoadOperationFinished(empty);
        return;
    }

    const quint64 requestId = ++chatterListRequestId;
    qDebug() << "Loading viewer list for" << normalizedChannel;
    if (broadcasterId != 0 && moderatorId != 0 && !access_token.isEmpty()) {
        pendingHelixChatters.clear();
        pendingHelixChatterChannel = normalizedChannel;
        pendingHelixChatterBroadcasterId = broadcasterId;
        pendingHelixChatterModeratorId = moderatorId;
        requestHelixChatterList(normalizedChannel, broadcasterId, moderatorId, requestId);
        return;
    }

    loadLegacyChatterList(normalizedChannel, requestId);
}

void NetworkManager::getBlockedUserList(const quint64 userId, const quint32 offset, const quint32 limit) {
    qDebug() << "Loading blocked user list for user" << userId;
    if (userId == 0 || !requireHelixAccessToken("Blocked user list loading", HelixAuthMode::UserOnly)) {
        QList<QString> empty;
        emit blockedUserListLoadOperationFinished(empty, offset, offset);
        return;
    }

    if (offset == 0) {
        blockedUserListPageCursors.clear();
    }
    else if (!blockedUserListPageCursors.contains(offset)) {
        QList<QString> empty;
        emit blockedUserListLoadOperationFinished(empty, offset, offset);
        return;
    }

    QUrl url(QString(HELIX_API) + "/users/blocks");
    QUrlQuery query;
    query.addQueryItem("broadcaster_id", QString::number(userId));
    const quint32 pageSize = qMax<quint32>(1, qMin<quint32>(limit, 100));
    query.addQueryItem("first", QString::number(pageSize));

    const QString cursor = blockedUserListPageCursors.value(offset);
    if (!cursor.isEmpty()) {
        query.addQueryItem("after", cursor);
    }
    url.setQuery(query);

    qDebug() << "Request" << url;

    QNetworkRequest request;
    addHelixHeaders(request, HelixAuthMode::UserOnly);
    request.setUrl(url);

    request.setAttribute(QNetworkRequest::User, offset);
    request.setAttribute(RequestContextAttribute1, pageSize);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::blockedUserListReply);
}

void NetworkManager::editUserBlock(const quint64 myUserId, const QString & blockUsername, const bool isBlock) {
    const QString normalizedBlockUsername = blockUsername.trimmed();
    if (myUserId == 0 || normalizedBlockUsername.isEmpty()) {
        return;
    }

    if (!requireHelixAccessToken("Blocked user editing", HelixAuthMode::UserOnly)) {
        return;
    }

    QUrl url(QString(HELIX_API) + "/users");
    QUrlQuery query;
    query.addQueryItem("login", normalizedBlockUsername);
    url.setQuery(query);

    QNetworkRequest request;
    addHelixHeaders(request, HelixAuthMode::UserOnly);
    request.setUrl(url);

    request.setAttribute(QNetworkRequest::User, myUserId);
    request.setAttribute(RequestContextAttribute1, normalizedBlockUsername);
    request.setAttribute(RequestContextAttribute2, isBlock);
    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::blockUserLookupReply);
}

void NetworkManager::blockUserLookupReply() {
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        reply->deleteLater();
        return;
    }

    quint64 myUserId = reply->request().attribute(QNetworkRequest::User).toULongLong();
    QString blockUsername = reply->request().attribute(RequestContextAttribute1).toString();
    bool isBlock = reply->request().attribute(RequestContextAttribute2).toBool();

    QByteArray data = reply->readAll();
    const auto & userIds = JsonParser::parseUsers(data);

    if (userIds.length() == 0 || userIds[0] == 0) {
        qWarning() << "userId lookup failed for" << blockUsername;
        reply->deleteLater();
        return;
    }

    quint64 blockUserId = userIds[0];

    editUserBlockWithId(myUserId, blockUsername, blockUserId, isBlock);
    reply->deleteLater();
}

void NetworkManager::editUserBlockWithId(const quint64 myUserId, const QString & blockUsername, const quint64 blockUserId, const bool isBlock) {
    qDebug() << "Setting block for user" << blockUserId << "to" << isBlock << "for user" << myUserId;
    QUrl url(QString(HELIX_API) + "/users/blocks");
    QUrlQuery query;
    query.addQueryItem("target_user_id", QString::number(blockUserId));
    if (isBlock) {
        query.addQueryItem("source_context", "chat");
        query.addQueryItem("reason", "other");
    }
    url.setQuery(query);
    qDebug() << "Request" << url;

    QNetworkRequest request;
    addHelixHeaders(request, HelixAuthMode::UserOnly);
    request.setUrl(url);

    request.setAttribute(QNetworkRequest::User, myUserId);
    request.setAttribute(RequestContextAttribute1, blockUsername);
    request.setAttribute(RequestContextAttribute2, isBlock);

    QNetworkReply *reply;
    if (isBlock) {
        reply = operation->put(request, "");
    }
    else {
        reply = operation->deleteResource(request);
    }

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::blockUserReply);
}

void NetworkManager::blockUserReply() {
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (statusCode == 401) {
            qWarning() << "Warning: Not authorized to edit blocked users list; logout and log in again to update OAuth scopes";
        }
        reply->deleteLater();
        return;
    }

    quint64 myUserId = reply->request().attribute(QNetworkRequest::User).toULongLong();
    QString blockUsername = reply->request().attribute(RequestContextAttribute1).toString();
    bool isBlock = reply->request().attribute(RequestContextAttribute2).toBool();

    if (isBlock) {
        emit userBlocked(myUserId, blockUsername);
    }
    else {
        emit userUnblocked(myUserId, blockUsername);
    }

    reply->deleteLater();
}

void NetworkManager::chatterListReply() {
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    const bool isHelixRequest = reply->request().attribute(QNetworkRequest::User).toBool();
    const QString channel = reply->request().attribute(RequestContextAttribute1).toString();
    const quint64 broadcasterId = reply->request().attribute(RequestContextAttribute2).toULongLong();
    const quint64 moderatorId = reply->request().attribute(RequestContextAttribute3).toULongLong();
    const quint64 requestId = reply->request().attribute(RequestContextAttribute4).toULongLong();

    if (requestId != chatterListRequestId) {
        qDebug() << "Ignoring stale viewer-list reply for" << channel;
        reply->deleteLater();
        return;
    }

    if (isHelixRequest
            && (channel != pendingHelixChatterChannel
                || broadcasterId != pendingHelixChatterBroadcasterId
                || moderatorId != pendingHelixChatterModeratorId)) {
        qDebug() << "Ignoring stale Helix viewer-list reply for" << channel;
        reply->deleteLater();
        return;
    }

    if (!handleNetworkError(reply)) {
        if (isHelixRequest && !channel.isEmpty()) {
            qWarning() << "Helix viewer list failed; falling back to legacy TMI viewer list";
            pendingHelixChatters.clear();
            pendingHelixChatterChannel.clear();
            pendingHelixChatterBroadcasterId = 0;
            pendingHelixChatterModeratorId = 0;
            reply->deleteLater();
            loadLegacyChatterList(channel, requestId);
            return;
        }

        QMap<QString, QList<QString>> empty;
        emit chatterListLoadOperationFinished(empty);
        reply->deleteLater();
        return;
    }

    QByteArray data = reply->readAll();

    //qDebug() << data;

    if (isHelixRequest) {
        const PagedResult<QString> result = JsonParser::parseHelixChatterListPage(data);
        pendingHelixChatters.append(result.items);

        if (!result.cursor.isEmpty()) {
            requestHelixChatterList(channel, broadcasterId, moderatorId, requestId, result.cursor);
            reply->deleteLater();
            return;
        }

        QMap<QString, QList<QString>> ret;
        if (!pendingHelixChatters.isEmpty()) {
            ret.insert("viewers", pendingHelixChatters);
        }
        pendingHelixChatters.clear();
        pendingHelixChatterChannel.clear();
        pendingHelixChatterBroadcasterId = 0;
        pendingHelixChatterModeratorId = 0;
        emit chatterListLoadOperationFinished(ret);
        reply->deleteLater();
        return;
    }

    QMap<QString, QList<QString>> ret = JsonParser::parseChatterList(data);
    emit chatterListLoadOperationFinished(ret);

    reply->deleteLater();
}

void NetworkManager::blockedUserListReply() {
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (statusCode == 401) {
            qWarning() << "Warning: Not authorized to read blocked users list; logout and log in again to update OAuth scopes";
        }
        QList<QString> empty;
        const quint32 offset = reply->request().attribute(QNetworkRequest::User).toUInt();
        emit blockedUserListLoadOperationFinished(empty, offset, offset);
        reply->deleteLater();
        return;
    }

    QByteArray data = reply->readAll();

    auto result = JsonParser::parseBlockList(data);

    const quint32 offset = reply->request().attribute(QNetworkRequest::User).toUInt();
    const quint32 limit = reply->request().attribute(RequestContextAttribute1).toUInt();
    const quint32 nextOffset = offset + limit;
    const quint32 total = result.cursor.isEmpty() ? nextOffset : nextOffset + 1;

    if (!result.cursor.isEmpty()) {
        blockedUserListPageCursors.insert(nextOffset, result.cursor);
    }

    emit blockedUserListLoadOperationFinished(result.items, nextOffset, total);

    reply->deleteLater();
}

const QString NetworkManager::CHANNEL_BADGES_BETA_URL_PREFIX = "https://badges.twitch.tv/v1/badges/channels/";
const QString NetworkManager::CHANNEL_BADGES_BETA_URL_SUFFIX = "/display?language=en";
const QString NetworkManager::GLOBAL_BADGES_BETA_URL = "https://badges.twitch.tv/v1/badges/global/display?language=en";

void NetworkManager::getChannelBadgeUrlsBeta(const quint64 channelID) {
    if (channelID == 0) {
        QMap<QString, QMap<QString, QMap<QString, QString>>> empty;
        emit getChannelBadgeBetaUrlsOperationFinished(channelID, empty);
        return;
    }

    QUrl url;
    const bool useHelix = !helixAccessToken().isEmpty();
    if (useHelix) {
        url = QUrl(QString(HELIX_API) + "/chat/badges");
        QUrlQuery query;
        query.addQueryItem("broadcaster_id", QString::number(channelID));
        url.setQuery(query);
    }
    else {
        url = QUrl(CHANNEL_BADGES_BETA_URL_PREFIX + QString::number(channelID) + CHANNEL_BADGES_BETA_URL_SUFFIX);
    }

    qDebug() << "Requesting" << url;

    QNetworkRequest request;
    if (useHelix) {
        addHelixHeaders(request);
    }
    else {
        request.setRawHeader("Accept", "application/json");
        request.setRawHeader("Client-ID", getClientId().toUtf8());
    }
    request.setUrl(url);
    request.setAttribute(QNetworkRequest::User, channelID);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::channelBadgeUrlsBetaReply);
}

void NetworkManager::getGlobalBadgesUrlsBeta() {
    QUrl url;
    const bool useHelix = !helixAccessToken().isEmpty();
    if (useHelix) {
        url = QUrl(QString(HELIX_API) + "/chat/badges/global");
    }
    else {
        url = QUrl(GLOBAL_BADGES_BETA_URL);
    }

    qDebug() << "Requesting" << url;

    QNetworkRequest request;
    if (useHelix) {
        addHelixHeaders(request);
    }
    else {
        request.setRawHeader("Accept", "application/json");
        request.setRawHeader("Client-ID", getClientId().toUtf8());
    }
    request.setUrl(url);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::globalBadgeUrlsBetaReply);
}

void NetworkManager::getChannelBitsUrls(const qint64 channelID) {
    if (channelID <= 0) {
        BitsQStringsMap emptyUrls;
        BitsQStringsMap emptyColors;
        emit getChannelBitsUrlsOperationFinished(channelID, emptyUrls, emptyColors);
        return;
    }

    if (!requireHelixAccessToken("Channel Cheermote metadata")) {
        BitsQStringsMap emptyUrls;
        BitsQStringsMap emptyColors;
        emit getChannelBitsUrlsOperationFinished(channelID, emptyUrls, emptyColors);
        return;
    }

    QUrl url(QString(HELIX_API) + "/bits/cheermotes");
    QUrlQuery query;
    query.addQueryItem("broadcaster_id", QString::number(channelID));
    url.setQuery(query);

    qDebug() << "Requesting" << url;

    QNetworkRequest request;
    addHelixHeaders(request);
    request.setUrl(url);
    request.setAttribute(QNetworkRequest::User, channelID);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::channelBitsUrlsReply);
}

void NetworkManager::channelBitsUrlsReply() {
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        BitsQStringsMap emptyUrls;
        BitsQStringsMap emptyColors;
        const qint64 channelID = reply->request().attribute(QNetworkRequest::User).toLongLong();
        emit getChannelBitsUrlsOperationFinished(channelID, emptyUrls, emptyColors);
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    const qint64 channelID = reply->request().attribute(QNetworkRequest::User).toLongLong();
    if (channelID > 0) {
        qDebug() << "bits urls for channel" << channelID << "loaded";
        BitsQStringsMap urls;
        BitsQStringsMap colors;
        JsonParser::parseBitsData(data, urls, colors);

        emit getChannelBitsUrlsOperationFinished(channelID, urls, colors);
    }
    else {
        qDebug() << "can't determine channel from Cheermote request context";
    }

    reply->deleteLater();
}

void NetworkManager::getGlobalBitsUrls() {
    if (!requireHelixAccessToken("Global Cheermote metadata")) {
        BitsQStringsMap emptyUrls;
        BitsQStringsMap emptyColors;
        emit getGlobalBitsUrlsOperationFinished(emptyUrls, emptyColors);
        return;
    }

    QUrl url(QString(HELIX_API) + "/bits/cheermotes");

    qDebug() << "Requesting" << url;

    QNetworkRequest request;
    addHelixHeaders(request);
    request.setUrl(url);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::globalBitsUrlsReply);
}

void NetworkManager::globalBitsUrlsReply() {
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        BitsQStringsMap emptyUrls;
        BitsQStringsMap emptyColors;
        emit getGlobalBitsUrlsOperationFinished(emptyUrls, emptyColors);
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    QString urlString = reply->url().toString();


    BitsQStringsMap urls;
    BitsQStringsMap colors;
    JsonParser::parseBitsData(data, urls, colors);

    emit getGlobalBitsUrlsOperationFinished(urls, colors);

    reply->deleteLater();
}

void NetworkManager::getChannelBttvEmotes(const QString channel) {
    const QString normalizedChannel = channel.trimmed();
    if (normalizedChannel.isEmpty()) {
        QMap<QString, QString> empty;
        emit getChannelBttvEmotesOperationFinished(QString(), empty);
        return;
    }

    QString url = QString(BTTV_API) + QString("/channels/") + QUrl::toPercentEncoding(normalizedChannel);

    qDebug() << "Requesting" << url;

    QNetworkRequest request;
    request.setUrl(QUrl(url));
    request.setAttribute(RequestContextAttribute1, normalizedChannel);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::channelBttvEmotesReply);
}

void NetworkManager::channelBttvEmotesReply() {
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        const QString channel = reply->request().attribute(RequestContextAttribute1).toString();
        QMap<QString, QString> empty;
        emit getChannelBttvEmotesOperationFinished(channel, empty);
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    const QString channel = reply->request().attribute(RequestContextAttribute1).toString();

    auto emotes = JsonParser::parseBttvEmotesData(data);

    emit getChannelBttvEmotesOperationFinished(channel, emotes);

    reply->deleteLater();
}

void NetworkManager::getGlobalBttvEmotes() {
    QString url = QString(BTTV_API) + QString("/emotes");

    qDebug() << "Requesting" << url;

    QNetworkRequest request;
    request.setUrl(QUrl(url));

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::globalBttvEmotesReply);
}

void NetworkManager::globalBttvEmotesReply() {
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        QMap<QString, QString> empty;
        emit getGlobalBttvEmotesOperationFinished(empty);
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    auto emotes = JsonParser::parseBttvEmotesData(data);

    emit getGlobalBttvEmotesOperationFinished(emotes);

    reply->deleteLater();
}

void NetworkManager::getChannelFfzEmotes(const QString channel) {
    const QString normalizedChannel = channel.trimmed();
    if (normalizedChannel.isEmpty()) {
        QMap<QString, QString> empty;
        emit getChannelFfzEmotesOperationFinished(QString(), empty);
        return;
    }

    QString url = QString(FFZ_API) + QString("/room/") + QUrl::toPercentEncoding(normalizedChannel);

    qDebug() << "Requesting" << url;

    QNetworkRequest request;
    request.setUrl(QUrl(url));
    request.setAttribute(RequestContextAttribute1, normalizedChannel);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::channelFfzEmotesReply);
}

void NetworkManager::channelFfzEmotesReply() {
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        const QString channel = reply->request().attribute(RequestContextAttribute1).toString();
        QMap<QString, QString> empty;
        emit getChannelFfzEmotesOperationFinished(channel, empty);
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    const QString channel = reply->request().attribute(RequestContextAttribute1).toString();

    auto emotes = JsonParser::parseFfzEmotesData(data);

    emit getChannelFfzEmotesOperationFinished(channel, emotes);

    reply->deleteLater();
}

void NetworkManager::getGlobalFfzEmotes() {
    QString url = QString(FFZ_API) + QString("/set/global");

    qDebug() << "Requesting" << url;

    QNetworkRequest request;
    request.setUrl(QUrl(url));

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::globalFfzEmotesReply);
}

void NetworkManager::globalFfzEmotesReply() {
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        QMap<QString, QString> empty;
        emit getGlobalFfzEmotesOperationFinished(empty);
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    auto emotes = JsonParser::parseFfzEmotesData(data);

    emit getGlobalFfzEmotesOperationFinished(emotes);

    reply->deleteLater();
}

QNetworkAccessManager *NetworkManager::getManager() const
{
    return operation;
}

void NetworkManager::getM3U8Data(const QString &url, M3U8TYPE type)
{
    QNetworkRequest request;
    request.setRawHeader("Client-ID", getClientId().toUtf8());
    request.setUrl(QUrl(url));

    request.setAttribute(QNetworkRequest::User, type);

    QNetworkReply *reply = operation->get(request);

    connect(reply, &QNetworkReply::finished, this, &NetworkManager::m3u8Reply);
}

QNetworkReply *NetworkManager::replyFromSender(const char *context) const
{
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply) {
        qWarning() << context << "finished without a network reply sender";
    }
    return reply;
}

bool NetworkManager::handleNetworkError(QNetworkReply *reply)
{
    if (reply->error() != QNetworkReply::NoError){

        if (reply->error() >= 1 && reply->error() <= 199) {

            if (connectionOK == true) {
                connectionOK = false;
                emit networkAccessChanged(false);
            }

            if (!offlinePoller.isActive())
                offlinePoller.start();
        }

        const QString message = reply->errorString();
        qDebug() << message;
        if (!(reply->error() >= 1 && reply->error() <= 199)) {
            emit error(message);
        }

        return false;
    }

    if (!connectionOK) {
        connectionOK = true;
        image_reload_token++;
        emit imageReloadTokenChanged();
        emit networkAccessChanged(true);
    }

    if (offlinePoller.isActive())
        offlinePoller.stop();

    return true;
}

void NetworkManager::handleSslErrors(QNetworkReply * /*reply*/, const QList<QSslError> &errors)
{
    for (const QSslError &e : errors) {
        qDebug() << "Ssl error: " << e.errorString();
    }

    //reply->ignoreSslErrors(errors);
}

void NetworkManager::appAccessTokenReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    app_access_token_request_pending = false;

    if (!reply) {
        emit error("Twitch app access token request failed");
        return;
    }

    if (!handleNetworkError(reply)) {
        qWarning() << "Could not request Twitch app access token";
        reply->deleteLater();
        return;
    }

    const QByteArray data = reply->readAll();
    QJsonParseError parseError;
    const QJsonDocument jsonDocument = QJsonDocument::fromJson(data, &parseError);
    const QJsonObject json = jsonDocument.object();
    const QString token = json.value("access_token").toString().trimmed();

    if (parseError.error != QJsonParseError::NoError || token.isEmpty()) {
        qWarning() << "Twitch app access token response did not contain an access token";
        emit error("Twitch app access token request failed");
        reply->deleteLater();
        return;
    }

    app_access_token = token;
    qInfo() << "Loaded Twitch app access token from client credentials";
    reply->deleteLater();
}

void NetworkManager::accessTokenValidationReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    access_token_validation_pending = false;

    if (!reply)
        return;

    const QString validatedToken = reply->request().attribute(QNetworkRequest::User).toString();
    if (validatedToken != access_token) {
        reply->deleteLater();
        return;
    }

    const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (statusCode == 401) {
        qWarning() << "Stored Twitch OAuth access token is invalid; logging out";
        emit error(QStringLiteral("Twitch login expired. Please log in again."));
        SettingsManager::getInstance()->setAccessToken(QString());
        reply->deleteLater();
        return;
    }

    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "Could not validate Twitch OAuth access token:" << reply->errorString();
        reply->deleteLater();
        return;
    }

    const QByteArray data = reply->readAll();
    QJsonParseError parseError;
    const QJsonDocument jsonDocument = QJsonDocument::fromJson(data, &parseError);
    const QJsonObject json = jsonDocument.object();
    const QString tokenClientId = json.value("client_id").toString();

    if (parseError.error != QJsonParseError::NoError || tokenClientId.isEmpty()) {
        qWarning() << "Twitch OAuth token validation response was malformed";
        reply->deleteLater();
        return;
    }

    if (tokenClientId != getClientId()) {
        qWarning() << "Stored Twitch OAuth access token belongs to another client; logging out";
        emit error(QStringLiteral("Twitch login belongs to another client. Please log in again."));
        SettingsManager::getInstance()->setAccessToken(QString());
        reply->deleteLater();
        return;
    }

    qInfo() << "Validated Twitch OAuth access token";
    reply->deleteLater();
}

void NetworkManager::streamReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        const quint64 channelId = reply->request().attribute(QNetworkRequest::User).toULongLong();
        emit streamGetOperationFinished(channelId, false);
        reply->deleteLater();
        return;
    }

    QByteArray data = reply->readAll();

    //qDebug() << data;

    Channel *channel = JsonParser::parseStream(data);

    quint64 channelId = reply->request().attribute(QNetworkRequest::User).toULongLong();
    if (channelId == 0) {
        QString channelIdStr = reply->url().toString();
        channelIdStr.remove(0, channelIdStr.lastIndexOf('/') + 1);
        channelId = channelIdStr.toULongLong();
    }

    emit streamGetOperationFinished(channelId, channel->isOnline());

    channel->deleteLater();

    reply->deleteLater();
}

void addOfflineChannels(QList<Channel *> & channels, const QList<quint64> & expectedChannelIds) {
    if (channels.count() < expectedChannelIds.count()) {
        QSet<quint64> unseenChannelIds(expectedChannelIds.constBegin(), expectedChannelIds.constEnd());

        const QList<Channel *> &knownChannels = channels;
        for (const Channel *channel : knownChannels) {
            if (channel && channel->getId() != 0) {
                unseenChannelIds.remove(channel->getId());
            }
        }

        const QSet<quint64> &missingChannelIds = unseenChannelIds;
        for (const quint64 id : missingChannelIds) {
            if (id != 0) {
                channels.append(new Channel(id));
            }
        }
    }
}

template <class U>
void addULongLongStringList(U & modify, const QStringList & newItems) {
    modify.reserve(modify.length() + newItems.length());
    for (const QString & s : newItems) {
        bool ok = false;
        const quint64 value = s.toULongLong(&ok);
        if (ok && value != 0) {
            modify.append(value);
        }
    }
}

void NetworkManager::allStreamsReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        QList<Channel *> empty;
        emit allStreamsOperationFinished(empty);
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    QList<quint64> queriedChannelIds;

    const QUrlQuery query(reply->url().query());
    if (query.hasQueryItem("channel")) {
        addULongLongStringList(queriedChannelIds, query.queryItemValue("channel").split(","));
    }
    if (query.hasQueryItem("user_id")) {
        addULongLongStringList(queriedChannelIds, query.allQueryItemValues("user_id"));
    }

    PagedResult<Channel *> out = JsonParser::parseStreams(data);

    addOfflineChannels(out.items, queriedChannelIds);

    emit allStreamsOperationFinished(out.items);

    reply->deleteLater();
}

void NetworkManager::searchGamesReply()
{

    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        QList<Game *> empty;
        emit searchGamesOperationFinished(empty);
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    auto result = JsonParser::parseGameResults(data);
    emit searchGamesOperationFinished(result.items);

    reply->deleteLater();
}

void NetworkManager::gamesReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        QList<Game *> empty;
        emit gamesOperationFinished(empty);
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    auto result = JsonParser::parseGameResults(data);
    const bool isHelix = reply->url().path() == "/helix/games/top";
    if (isHelix && !result.cursor.isEmpty()) {
        const quint32 offset = reply->request().attribute(QNetworkRequest::User).toUInt();
        const quint32 limit = reply->request().attribute(RequestContextAttribute1).toUInt();
        const quint32 returnedCount = static_cast<quint32>(result.items.size());
        const quint32 nextOffset = offset + (returnedCount > 0 ? returnedCount : limit);
        topGamesPageCursors.insert(nextOffset, result.cursor);
    }

    emit gamesOperationFinished(result.items);

    reply->deleteLater();
}

void NetworkManager::gameStreamsReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        QList<Channel *> empty;
        const int total = reply->request().attribute(QNetworkRequest::User).toInt();
        emit gameStreamsOperationFinished(empty, total);
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    //qDebug() << data;

    QList<quint64> queriedChannelIds;

    const QUrlQuery query(reply->url().query());
    if (query.hasQueryItem("channel")) {
        addULongLongStringList(queriedChannelIds, query.queryItemValue("channel").split(","));
    }

    PagedResult<Channel *> out = JsonParser::parseStreams(data);

    addOfflineChannels(out.items, queriedChannelIds);

    const bool isHelixStreams = reply->url().path() == "/helix/streams";
    const bool isHelixGameStreams = isHelixStreams && query.hasQueryItem("game_id");
    const bool isHelixLanguageStreams = isHelixStreams && query.hasQueryItem("language") && !query.hasQueryItem("game_id");
    if (isHelixGameStreams || isHelixLanguageStreams) {
        const quint32 offset = reply->request().attribute(QNetworkRequest::User).toUInt();
        const quint32 limit = reply->request().attribute(RequestContextAttribute1).toUInt();
        const quint32 returnedCount = static_cast<quint32>(out.items.size());
        const quint32 nextOffset = offset + (returnedCount > 0 ? returnedCount : limit);
        const quint32 total = out.cursor.isEmpty() ? nextOffset : nextOffset + 1;

        if (!out.cursor.isEmpty()) {
            if (isHelixLanguageStreams) {
                languageStreamsPageCursors.insert(nextOffset, out.cursor);
            }
            else {
                gameStreamsPageCursors.insert(nextOffset, out.cursor);
            }
        }

        emit gameStreamsOperationFinished(out.items, total);
    }
    else {
        emit gameStreamsOperationFinished(out.items, out.total);
    }

    reply->deleteLater();
}

void NetworkManager::gameStreamsGameLookupReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        QList<Channel *> empty;
        const quint32 offset = reply->request().attribute(QNetworkRequest::User).toUInt();
        emit gameStreamsOperationFinished(empty, offset);
        reply->deleteLater();
        return;
    }

    const quint32 offset = reply->request().attribute(QNetworkRequest::User).toUInt();
    const quint32 limit = reply->request().attribute(RequestContextAttribute1).toUInt();
    const QString game = reply->request().attribute(RequestContextAttribute2).toString();
    const QString language = reply->request().attribute(RequestContextAttribute3).toString();

    QByteArray data = reply->readAll();
    auto result = JsonParser::parseGameResults(data);

    if (result.items.isEmpty() || result.items.first()->getId().isEmpty()) {
        QList<Channel *> empty;
        emit gameStreamsOperationFinished(empty, offset);
        qDeleteAll(result.items);
        reply->deleteLater();
        return;
    }

    const QString gameId = result.items.first()->getId();
    gameStreamsGameIds.insert(game, gameId);

    qDeleteAll(result.items);
    reply->deleteLater();

    getStreamsForGameId(gameId, offset, limit, language);
}

void NetworkManager::featuredStreamsReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        QList<Channel *> empty;
        emit featuredStreamsOperationFinished(empty, 0);
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    //qDebug() << data;

    QList<Channel *> channels;
    if (reply->url().path() == "/helix/streams") {
        channels = JsonParser::parseStreams(data).items;
    }
    else {
        channels = JsonParser::parseFeatured(data);
    }
    emit featuredStreamsOperationFinished(channels, channels.count());

    reply->deleteLater();
}

void NetworkManager::searchChannelsReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        QList<Channel *> empty;
        const int total = reply->request().attribute(QNetworkRequest::User).toInt();
        emit searchChannelsOperationFinished(empty, total);
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    //qDebug() << data;

    auto result = JsonParser::parseChannels(data);
    const bool isHelix = reply->url().path() == "/helix/search/channels";
    if (isHelix) {
        const quint32 offset = reply->request().attribute(QNetworkRequest::User).toUInt();
        const quint32 limit = reply->request().attribute(RequestContextAttribute1).toUInt();
        const quint32 returnedCount = static_cast<quint32>(result.items.size());
        const quint32 nextOffset = offset + (returnedCount > 0 ? returnedCount : limit);
        const quint32 total = result.cursor.isEmpty() ? nextOffset : nextOffset + 1;

        if (!result.cursor.isEmpty()) {
            searchChannelsPageCursors.insert(nextOffset, result.cursor);
        }

        emit searchChannelsOperationFinished(result.items, total);
    }
    else {
        emit searchChannelsOperationFinished(result.items, result.total);
    }

    reply->deleteLater();
}

void NetworkManager::streamExtractReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        emit error("token_error");
        reply->deleteLater();
        return;
    }

    QByteArray data = reply->readAll();
    //qDebug() << data;

    M3U8TYPE type = static_cast<M3U8TYPE>(reply->request().attribute(QNetworkRequest::User).toInt());

    QString url;

    switch (type) {
    case LIVE:
        url = JsonParser::parseChannelStreamExtractionInfo(data);
        break;

    case VOD:
        url = JsonParser::parseVodExtractionInfo(data);
        break;
    }

    if (url.isEmpty()) {
        qWarning() << "Could not extract Twitch playlist URL";
        emit error("token_error");
        reply->deleteLater();
        return;
    }

    getM3U8Data(url, type);

    reply->deleteLater();
}

void NetworkManager::m3u8Reply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {

        emit error("playlist_error");
        reply->deleteLater();

        return;
    }

    QByteArray data = reply->readAll();

    switch (static_cast<M3U8TYPE>(reply->request().attribute(QNetworkRequest::User).toInt())) {
    case LIVE:
        emit m3u8OperationFinished(m3u8::getUrls(data));
        break;

    case VOD:
        emit m3u8OperationBFinished(m3u8::getUrls(data));
        break;
    }
    //qDebug() << data;

    reply->deleteLater();
}

void NetworkManager::broadcastsReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        emit broadcastsOperationFailed();
        reply->deleteLater();
        return;
    }

    QByteArray data = reply->readAll();

    auto result = JsonParser::parseVodResults(data);
    const bool isHelix = reply->url().path() == "/helix/videos";
    if (isHelix && !result.cursor.isEmpty()) {
        const quint32 offset = reply->request().attribute(QNetworkRequest::User).toUInt();
        const quint32 limit = reply->request().attribute(RequestContextAttribute1).toUInt();
        const quint32 returnedCount = static_cast<quint32>(result.items.size());
        const quint32 nextOffset = offset + (returnedCount > 0 ? returnedCount : limit);
        broadcastsPageCursors.insert(nextOffset, result.cursor);
    }

    emit broadcastsOperationFinished(result.items);

    reply->deleteLater();
}

void NetworkManager::favouritesReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (statusCode == 401) {
            qWarning() << "Warning: Not authorized to read followed channels; logout and log in again to update OAuth scopes";
        }
        QList<Channel *> empty;
        const quint32 offset = reply->request().attribute(QNetworkRequest::User).toUInt();
        emit favouritesReplyFinished(empty, offset, offset);
        reply->deleteLater();
        return;
    }

    QByteArray data = reply->readAll();

    auto result = JsonParser::parseFavourites(data);

    const quint32 offset = reply->request().attribute(QNetworkRequest::User).toUInt();
    const quint32 limit = reply->request().attribute(RequestContextAttribute1).toUInt();
    const quint32 nextOffset = offset + limit;
    const quint32 total = result.cursor.isEmpty() ? nextOffset : qMax<quint32>(static_cast<quint32>(result.total), nextOffset + 1);

    if (!result.cursor.isEmpty()) {
        userFavouritesPageCursors.insert(nextOffset, result.cursor);
    }

    emit favouritesReplyFinished(result.items, nextOffset, total);

    reply->deleteLater();
}

void NetworkManager::userReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        emit userOperationFinished(QString(), 0);
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    auto pair = JsonParser::parseUser(data);
    emit userOperationFinished(pair.first, pair.second);

    reply->deleteLater();
}

void NetworkManager::emoteSetsReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        if (pendingEmoteSetReplies > 0) {
            pendingEmoteSetReplies--;
            if (pendingEmoteSetReplies == 0) {
                emit getEmoteSetsOperationFinished(pendingEmoteSets);
            }
        }
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    auto parsed = JsonParser::parseEmoteSets(data);
    if (pendingEmoteSetReplies > 0) {
        for (auto setEntry = parsed.constBegin(); setEntry != parsed.constEnd(); setEntry++) {
            pendingEmoteSets.insert(setEntry.key(), setEntry.value());
        }

        pendingEmoteSetReplies--;
        if (pendingEmoteSetReplies == 0) {
            emit getEmoteSetsOperationFinished(pendingEmoteSets);
        }
    }
    else {
        emit getEmoteSetsOperationFinished(parsed);
    }

    reply->deleteLater();
}

void NetworkManager::channelBadgeUrlsBetaReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        const quint64 channelID = reply->request().attribute(QNetworkRequest::User).toULongLong();
        QMap<QString, QMap<QString, QMap<QString, QString>>> empty;
        emit getChannelBadgeBetaUrlsOperationFinished(channelID, empty);
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    const quint64 channelID = reply->request().attribute(QNetworkRequest::User).toULongLong();
    if (channelID > 0) {
        qDebug() << "beta badges for channel" << channelID << "loaded";
        auto badges = JsonParser::parseBadgeUrlsBetaFormat(data);

        emit getChannelBadgeBetaUrlsOperationFinished(channelID, badges);
    }
    else {
        qDebug() << "can't determine channel from badge request context";
    }

    reply->deleteLater();
}

void NetworkManager::globalBadgeUrlsBetaReply()
{
    QNetworkReply *reply = replyFromSender(Q_FUNC_INFO);
    if (!reply) {
        return;
    }

    if (!handleNetworkError(reply)) {
        QMap<QString, QMap<QString, QMap<QString, QString>>> empty;
        emit getGlobalBadgeBetaUrlsOperationFinished(empty);
        reply->deleteLater();
        return;
    }
    QByteArray data = reply->readAll();

    QString urlString = reply->url().toString();

    qDebug() << "url was" << urlString;

    qDebug() << "global beta badges loaded";
    auto badges = JsonParser::parseBadgeUrlsBetaFormat(data);

    emit getGlobalBadgeBetaUrlsOperationFinished(badges);

    reply->deleteLater();
}
