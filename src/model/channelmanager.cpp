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

#include "channelmanager.h"
#include <QCoreApplication>
#include <QDebug>
#include <QUrl>
#include <QUrlQuery>

ChannelManager::ChannelManager() :
    netman(NetworkManager::getInstance()),
    settingsManager(SettingsManager::getInstance())
{
    user_id = 0;
    tempFavourites = nullptr;

    resultsModel = new ChannelListModel();
    gamesModel = new GameListModel();

    //Setup followed channels model and it's signal chain
    favouritesModel = createFollowedChannelsModel();

    favouritesProxy = new QSortFilterProxyModel();

    favouritesProxy->setSortRole(ChannelListModel::Roles::ViewersRole);
    favouritesProxy->sort(0, Qt::DescendingOrder);
    favouritesProxy->setSourceModel(favouritesModel);

    connect(netman, &NetworkManager::allStreamsOperationFinished, this, &ChannelManager::updateStreams);
    connect(netman, &NetworkManager::featuredStreamsOperationFinished, this, &ChannelManager::addSearchResults);
    connect(netman, &NetworkManager::gamesOperationFinished, this, &ChannelManager::addGames);
    connect(netman, &NetworkManager::gameStreamsOperationFinished, this, &ChannelManager::addSearchResults);
    connect(netman, &NetworkManager::searchChannelsOperationFinished, this, &ChannelManager::addSearchResults);
    connect(netman, &NetworkManager::m3u8OperationFinished, this, &ChannelManager::foundPlaybackStream);
    connect(netman, &NetworkManager::searchGamesOperationFinished, this, &ChannelManager::addGames);

    connect(netman, &NetworkManager::userOperationFinished, this, &ChannelManager::onUserUpdated);

    connect(netman, &NetworkManager::favouritesReplyFinished, this, &ChannelManager::addFollowedResults);

    connect(netman, &NetworkManager::networkAccessChanged, this, &ChannelManager::slotNetworkAccessChanged);
    connect(settingsManager, &SettingsManager::accessTokenChanged, this, &ChannelManager::updateAccessToken);

    load();

    //Start polling timer, setting id as property
    setProperty("pollTimer", startTimer(30000, Qt::VeryCoarseTimer));


    if (SettingsManager::getInstance()->hasAccessToken()) {
        updateAccessToken(SettingsManager::getInstance()->accessToken());
    }
}

ChannelManager *ChannelManager::getInstance() {
    static ChannelManager *instance = new ChannelManager();
    return instance;
}

ChannelManager::~ChannelManager(){
    qDebug() << "Destroyer: ChannelManager";

    save();

    delete favouritesModel;
    delete resultsModel;
    delete gamesModel;
    delete favouritesProxy;
}

void ChannelManager::addToFavourites(const quint64 &id, const QString &serviceName, const QString &title,
                                     const QString &info, const QString &logo, const QString &preview,
                                     const QString &game, const qint32 &viewers, bool online)
{
    if (isAccessTokenAvailable()) {
        qWarning() << "Twitch follow API is no longer available; not editing remote followed channels";
        return;
    }

    if (id == 0) {
        qWarning() << "Ignoring favourite channel with id 0";
        return;
    }

    if (!favouritesModel->find(id)){
        Channel *channel = new Channel();
        channel->setId(id);
        channel->setServiceName(serviceName);
        channel->setName(title);
        channel->setInfo(info);
        channel->setLogourl(logo);
        channel->setPreviewurl(preview);
        channel->setGame(game);
        channel->setOnline(online);
        channel->setViewers(viewers);
        channel->setFavourite(true);

        favouritesModel->addChannel(channel);

        emit addedChannel(channel->getId());

        Channel *chan = resultsModel->find(channel->getId());
        if (chan){
            chan->setFavourite(true);
            resultsModel->updateChannelForView(chan);
        }

        save();
    }
}

void ChannelManager::searchGames(QString q, const quint32 &offset, const quint32 &limit)
{
    const QString query = q.trimmed();

    if (offset == 0 || !query.isEmpty())
        gamesModel->clear();

    //If query is empty, search games by viewercount
    if (query.isEmpty()) {
        emit gamesSearchStarted();
        netman->getGames(offset, limit);
    }

    //Else by queryword
    else if (offset == 0) {
        emit gamesSearchStarted();
        netman->searchGames(query);
    }
}

QString ChannelManager::username() const
{
    return user_name;
}

void ChannelManager::updateAccessToken(QString /*accessToken*/)
{
    if (isAccessTokenAvailable()) {
        //Fetch display name for logged in user
        netman->getUser();

        //move favs to tempfavs
        if (!tempFavourites) {
            tempFavourites = favouritesModel;

            favouritesModel = createFollowedChannelsModel();
            favouritesProxy->setSourceModel(favouritesModel);
        }
    }

    else {
        // if we just logged out there are user settings to clear
        user_id = 0;
        user_name = "";

        //Reload local favourites from memory
        if (tempFavourites) {
            delete favouritesModel;
            favouritesModel = tempFavourites;
            tempFavourites = nullptr;
            favouritesProxy->setSourceModel(favouritesModel);
        }

        emit login("", "");
    }

    emit accessTokenUpdated();
}

void ChannelManager::timerEvent(QTimerEvent *event)
{
    Q_UNUSED(event);
    checkFavourites();
}

ChannelListModel *ChannelManager::getFavouritesModel() const
{
    return favouritesModel;
}

QSortFilterProxyModel *ChannelManager::getFavouritesProxy() const
{
    return favouritesProxy;
}

GameListModel *ChannelManager::getGamesModel() const
{
    return gamesModel;
}

ChannelListModel *ChannelManager::getResultsModel() const
{
    return resultsModel;
}

void ChannelManager::load(){
    QSettings settings(QCoreApplication::organizationName(), QCoreApplication::applicationName());

    int size = settings.beginReadArray("channels");
    if (size > 0) {
        QList<Channel*> _channels;

        for (int i = 0; i < size; i++) {
            settings.setArrayIndex(i);
            Channel * channel = new Channel(settings);
            channel->setFavourite(true);
            _channels.append(channel);
        }

        favouritesModel->addAll(_channels);

        qDeleteAll(_channels);
    }
    settings.endArray();
}

void ChannelManager::save()
{
    QSettings settings(QCoreApplication::organizationName(), QCoreApplication::applicationName());

    if (!settings.isWritable())
        qDebug() << "Error: settings file not writable";

    if (tempFavourites) {
        delete favouritesModel;
        favouritesModel = tempFavourites;
        tempFavourites = nullptr;
    }

    //Write channels
    settings.beginWriteArray("channels");
    for (int i=0; i < favouritesModel->count(); i++){
        settings.setArrayIndex(i);
        favouritesModel->getChannels().at(i)->writeToSettings(settings);
    }
    settings.endArray();
    settings.sync();
    if (settings.status() != QSettings::NoError) {
        qWarning() << "Favourite channel settings sync failed with status" << settings.status();
    }
}


void ChannelManager::addToFavourites(const quint64 &id){
    if (isAccessTokenAvailable()) {
        qWarning() << "Twitch follow API is no longer available; not editing remote followed channels";
        return;
    }

    if (id == 0) {
        qWarning() << "Ignoring favourite channel with id 0";
        return;
    }

    Channel *channel = resultsModel->find(id);

    if (channel){
        channel->setFavourite(true);
        favouritesModel->addChannel(new Channel(*channel));

        emit addedChannel(channel->getId());

        resultsModel->updateChannelForView(channel);

        save();
    }
}

void ChannelManager::removeFromFavourites(const quint64 &id){
    if (isAccessTokenAvailable()) {
        qWarning() << "Twitch unfollow API is no longer available; not editing remote followed channels";
        return;
    }

    if (id == 0) {
        qWarning() << "Ignoring favourite removal with id 0";
        return;
    }

    Channel *chan = favouritesModel->find(id);
    if (!chan)
        return;

    emit deletedChannel(chan->getId());

    favouritesModel->removeChannel(chan);

    chan = nullptr;

    //Update results
    Channel* channel = resultsModel->find(id);
    if (channel){

        channel->setFavourite(false);
        resultsModel->updateChannelForView(channel);
    }

    save();
}

QString commaSeparatedChannelIds(const QList<Channel *> & channels) {
    QStringList channelIdStrs;
    for (Channel *channel : channels) {
        if (channel) {
            channelIdStrs.append(QString::number(channel->getId()));
        }
    }
    return channelIdStrs.join(',');
}

void ChannelManager::checkStreams(const QList<Channel *> &list)
{
    if (!isAccessTokenAvailable()) {
        qWarning() << "Skipping stream metadata refresh because Twitch login is required for Helix streams";
        return;
    }

    //Divide list to sublists for sanity
    int pos = 0;

    while(pos < list.length()) {

        const int batchSize = 100;
        QList<Channel*> sublist = list.mid(pos, batchSize);
        pos += sublist.length();

        QList<Channel*> validChannels;
        validChannels.reserve(sublist.length());
        for (Channel *channel : sublist) {
            if (channel && channel->getId()) {
                validChannels.append(channel);
            }
        }

        if (validChannels.isEmpty()) {
            continue;
        }

        QUrl helixUrl(QString(HELIX_API) + "/streams");
        QUrlQuery query;
        query.addQueryItem("first", QString::number(validChannels.length()));
        for (Channel *channel : validChannels) {
            query.addQueryItem("user_id", QString::number(channel->getId()));
        }
        helixUrl.setQuery(query);
        netman->getStreams(helixUrl.toString(QUrl::FullyEncoded));
    }
}

void ChannelManager::checkFavourites()
{
    checkStreams(favouritesModel->getChannels());
}

void ChannelManager::searchChannels(QString q, const quint32 &offset, const quint32 &limit, bool clear)
{
    const QString query = q.trimmed();

    if (clear)
        resultsModel->clear();

    emit searchingStarted();

    if (query.isEmpty()) {
        netman->getFeaturedStreams();
    }
    else if (query.startsWith("/game ")){
        QString game = query.mid(QString("/game ").length()).trimmed();
        QString language;
        int languageIndex = game.lastIndexOf(" /language ", -1, Qt::CaseInsensitive);
        int languagePrefixLength = QString(" /language ").length();

        if (languageIndex < 0) {
            languageIndex = game.lastIndexOf(" /lang ", -1, Qt::CaseInsensitive);
            languagePrefixLength = QString(" /lang ").length();
        }

        if (languageIndex >= 0) {
            language = game.mid(languageIndex + languagePrefixLength).trimmed();
            game = game.left(languageIndex).trimmed();
        }

        netman->getStreamsForGame(game, offset, limit, language);

    } else if (query.startsWith("/language ") || query.startsWith("/lang ")) {
        const QString language = query.section(' ', 1).trimmed();
        netman->getStreamsForLanguage(language, offset, limit);

    } else {
        netman->searchChannels(query, offset, limit);
    }
}

void ChannelManager::addSearchResults(const QList<Channel*> &list, const int total)
{
    bool needsStreamCheck = false;
    QList<Channel*> validChannels;
    validChannels.reserve(list.size());

    for (Channel *channel : list) {
        if (!channel || !channel->getId()) {
            continue;
        }

        validChannels.append(channel);

        if (favouritesModel->find(channel->getId()))
            channel->setFavourite(true);

        if (!channel->isOnline())
            needsStreamCheck = true;
    }

    int numAdded = resultsModel->addAll(validChannels);

    if (needsStreamCheck)
        checkStreams(validChannels);

    qDeleteAll(list);

    emit resultsUpdated(numAdded, total);
}

void ChannelManager::findPlaybackStream(const QString &serviceName)
{
    netman->getChannelPlaybackStream(serviceName);
}

void ChannelManager::updateFavourites(const QList<Channel*> &list)
{
    QList<Channel*> validChannels;
    validChannels.reserve(list.size());

    for (Channel *c : list) {
        if (!c || !c->getId()) {
            continue;
        }

        validChannels.append(c);
        c->setFavourite(true);
    }

    favouritesModel->updateChannels(validChannels);
    qDeleteAll(list);
}

bool ChannelManager::containsFavourite(const quint64 &q)
{
    return favouritesModel->find(q) != nullptr;
}

//Updates channel streams in all models
void ChannelManager::updateStreams(const QList<Channel*> &list)
{
    favouritesModel->updateStreams(list);
    resultsModel->updateStreams(list);
    qDeleteAll(list);
}

void ChannelManager::addGames(const QList<Game*> &list)
{
    gamesModel->addAll(list);

    qDeleteAll(list);

    emit gamesUpdated();
}

void ChannelManager::notify(Channel *channel)
{
    if (settingsManager->alert() && channel){

        if (!channel->isOnline() && !settingsManager->offlineNotifications())
            //Skip offline notifications if set
            return;

        emit pushNotification(channel->getName() + (channel->isOnline() ? " is now streaming" : " has gone offline"),
                              channel->getInfo(),
                              channel->getLogourl());
    }
}

void ChannelManager::notifyChatMessage(const QString &title, const QString &message, const QString &imgUrl)
{
    if (settingsManager->alert() && settingsManager->chatNotifications()) {
        emit pushNotification(title, message, imgUrl);
    }
}

void ChannelManager::notifyMultipleChannelsOnline(const QList<Channel*> &channels)
{
    if (channels.size() == 1) {
        //Only one channel, send the usual notification
        notify(channels.at(0));
    }

    else if (settingsManager->alert()) {
        //Send multi-notification
        QString str;

        for (Channel *c : channels) {
            if (!c) {
                continue;
            }

            //Omit channels after enough characters in message body
            if (str.size() > 80) {
                str.append("...");
                break;
            }

            str.append(!str.isEmpty() ? ", " : "");
            str.append(c->getName());
        }

        if (!str.isEmpty()) {
            emit pushNotification("Channels are streaming", str, DEFAULT_LOGO_URL);
        }
    }
}

//Login function
void ChannelManager::onUserUpdated(const QString &name, const quint64 userId)
{
    user_name = name;
    user_id = userId;
    emit userNameUpdated(user_name);

    if (isAccessTokenAvailable()) {
        emit login(user_name, settingsManager->accessToken());

        //Start using user followed channels
        getFollowedChannels(FOLLOWED_FETCH_LIMIT, 0);
    }
}

void ChannelManager::getFollowedChannels(const quint32& limit, const quint32& offset)
{
    //if (offset == 0)
    //favouritesModel->clear();

    netman->getUserFavourites(user_id, offset, limit);
}

void ChannelManager::addFollowedResults(const QList<Channel *> &list, const quint32 offset, const quint32 total)
{
    //    qDebug() << "Merging channel data for " << list.size()
    //             << " items with " << offset << " offset.";

    QList<Channel*> validChannels;
    validChannels.reserve(list.size());

    for (Channel *c : list) {
        if (!c || !c->getId()) {
            continue;
        }

        validChannels.append(c);
        c->setFavourite(true);
    }

    favouritesModel->mergeAll(validChannels);

    if (offset < total)
        getFollowedChannels(FOLLOWED_FETCH_LIMIT, offset);

    checkStreams(validChannels);

    qDeleteAll(list);

    emit followedUpdated();
}

void ChannelManager::slotNetworkAccessChanged(bool up)
{
    if (up) {
        if (isAccessTokenAvailable()) {
            //Relogin
            favouritesModel->clear();
            netman->getUser();
        }
    } else {
        qDebug() << "Network went down";
        favouritesModel->setAllChannelsOffline();
        resultsModel->setAllChannelsOffline();
    }
}

quint64 ChannelManager::getUser_id() const
{
    return user_id;
}

ChannelListModel *ChannelManager::createFollowedChannelsModel()
{
    ChannelListModel *model = new ChannelListModel();

    connect(model, &ChannelListModel::channelOnlineStateChanged, this, &ChannelManager::notify);
    connect(model, &ChannelListModel::multipleChannelsChangedOnline, this, &ChannelManager::notifyMultipleChannelsOnline);

    return model;
}
