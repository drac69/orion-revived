/*
 * Copyright © 2015-2016 Andrew Penkrat
 *
 * This file is part of TwitchTube.
 *
 * TwitchTube is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * TwitchTube is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with TwitchTube.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "ircchat.h"

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QUrl>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDir>
#include <QStandardPaths>
#include <QImage>
#include <QRandomGenerator>
#include <qqml.h>
#include "../util/jsonparser.h"
#include "badgecontainer.h"
#include "vodmanager.h"

const QString IrcChat::IMAGE_PROVIDER_EMOTE = "emote";
const QString IrcChat::IMAGE_PROVIDER_BITS = "bits";
const QString IrcChat::EMOTICONS_URL_FORMAT_LODPI = "https://static-cdn.jtvnw.net/emoticons/v2/%1/static/dark/1.0";
const QString IrcChat::EMOTICONS_URL_FORMAT_HIDPI = "https://static-cdn.jtvnw.net/emoticons/v2/%1/static/dark/2.0";
const QString IrcChat::IMAGE_PROVIDER_BTTV_EMOTE = "bttvemote";
const QString IrcChat::BTTV_EMOTES_URL_FORMAT_LODPI = "https://cdn.betterttv.net/emote/%1/1x";
const QString IrcChat::BTTV_EMOTES_URL_FORMAT_HIDPI = "https://cdn.betterttv.net/emote/%1/2x";
const QString IrcChat::IMAGE_PROVIDER_FFZ_EMOTE = "ffzemote";
const QString IrcChat::FFZ_EMOTES_URL_FORMAT_LODPI = "https://cdn.frankerfacez.com/emote/%1/1";
const QString IrcChat::FFZ_EMOTES_URL_FORMAT_HIDPI = "https://cdn.frankerfacez.com/emote/%1/2";

const qint16 IrcChat::PORT = 6697;
const QString IrcChat::HOST = "irc.chat.twitch.tv";

IrcChat::IrcChat(QObject *parent) :
    QObject(parent),
    settings(SettingsManager::getInstance()),
    _emoteProvider(IMAGE_PROVIDER_EMOTE, settings->hiDpi() ? EMOTICONS_URL_FORMAT_HIDPI : EMOTICONS_URL_FORMAT_LODPI, ".png", settings->hiDpi() ? "emotes_2x" : "emotes"),
    _bttvEmoteProvider(IMAGE_PROVIDER_BTTV_EMOTE, settings->hiDpi() ? BTTV_EMOTES_URL_FORMAT_HIDPI : BTTV_EMOTES_URL_FORMAT_LODPI, ".png", settings->hiDpi() ? "bttv_emotes_2x" : "bttv_emotes"),
    _ffzEmoteProvider(IMAGE_PROVIDER_FFZ_EMOTE, settings->hiDpi() ? FFZ_EMOTES_URL_FORMAT_HIDPI : FFZ_EMOTES_URL_FORMAT_LODPI, ".png", settings->hiDpi() ? "ffz_emotes_2x" : "ffz_emotes"),
    _bitsProvider(nullptr),
    _badgeProvider(nullptr),
    sock(nullptr),
    netman(NetworkManager::getInstance())
    {

    logged_in = false;


    for (const auto provider : { &_emoteProvider, &_bttvEmoteProvider, &_ffzEmoteProvider }) {
        connect(provider, &ImageProvider::downloadComplete, this, &IrcChat::handleDownloadComplete);
        connect(provider, &ImageProvider::bulkDownloadComplete, this, &IrcChat::bulkDownloadComplete);
    }

    room = "";

	emoteDirPathImpl = _emoteProvider.getBaseUrl();

    connect(netman, &NetworkManager::blockedUserListLoadOperationFinished, this, &IrcChat::addBlockedUserResults);
    connect(netman, &NetworkManager::userBlocked, this, &IrcChat::innerUserBlocked);
    connect(netman, &NetworkManager::userUnblocked, this, &IrcChat::innerUserUnblocked);

    connect(netman, &NetworkManager::userOperationFinished, this, [this](const QString &/*name*/, const quint64 id){
        user_id = id;
        getBlockedUserList();
    });
}

void IrcChat::initSocket() {
    // Open socket
    sock = new QSslSocket(this);
    if(!sock) {
        emit errorOccured("Error creating socket");
    }
    else {
        sock->setPeerVerifyMode(QSslSocket::VerifyPeer);
        connect(sock, &QSslSocket::readyRead, this, &IrcChat::receive);
        connect(sock, &QAbstractSocket::errorOccurred, this, &IrcChat::processError);
        connect(sock, static_cast<void (QSslSocket::*)(const QList<QSslError> &errors)>(&QSslSocket::sslErrors), this, &IrcChat::processSslErrors);
        connect(sock, &QSslSocket::encrypted, this, &IrcChat::login);
        connect(sock, &QSslSocket::encrypted, this, &IrcChat::onSockStateChanged);
        connect(sock, &QSslSocket::disconnected, this, &IrcChat::onSockStateChanged);
    }
}

void IrcChat::initProviders() {
    initSocket();
	auto engine = qmlEngine(this);
	RegisterEngineProviders(*engine);
}

void IrcChat::RegisterEngineProviders(QQmlEngine & engine) {
	engine.addImageProvider(IMAGE_PROVIDER_EMOTE, _emoteProvider.getQMLImageProvider());
    engine.addImageProvider(IMAGE_PROVIDER_BTTV_EMOTE, _bttvEmoteProvider.getQMLImageProvider());
    engine.addImageProvider(IMAGE_PROVIDER_FFZ_EMOTE, _ffzEmoteProvider.getQMLImageProvider());
    if (_badgeProvider) {
        engine.addImageProvider(_badgeProvider->getImageProviderName(), _badgeProvider->getQMLImageProvider());
    }
    if (_bitsProvider) {
        engine.addImageProvider(_bitsProvider->getImageProviderName(), _bitsProvider->getQMLImageProvider());
    }
    else {
        qDebug() << "couldn't hook up badge provider as it was not available";
    }
}

void IrcChat::hookupChannelProviders() {
    _badgeProvider = BadgeContainer::getInstance()->getBadgeImageProvider();
    _bitsProvider = BadgeContainer::getInstance()->getBitsImageProvider();
    connect(_badgeProvider, &ImageProvider::downloadComplete, this, &IrcChat::handleDownloadComplete);
    connect(_bitsProvider, &ImageProvider::downloadComplete, this, &IrcChat::handleDownloadComplete);
    connect(BadgeContainer::getInstance(), &BadgeContainer::channelBitsUrlsLoaded, this, &IrcChat::handleChannelBitsUrlsLoaded);
    connect(BadgeContainer::getInstance(), &BadgeContainer::channelBttvEmotesLoaded, this, &IrcChat::handleChannelBttvEmotesLoaded);
    connect(BadgeContainer::getInstance(), &BadgeContainer::channelFfzEmotesLoaded, this, &IrcChat::handleChannelFfzEmotesLoaded);
    //connect(BadgeContainer::getInstance(), &BadgeContainer::blockedUsersLoaded, this, &IrcChat::blockedUsersLoaded);
    connect(NetworkManager::getInstance(), &NetworkManager::userBlocked, this, &IrcChat::userBlockedSlot);
    connect(NetworkManager::getInstance(), &NetworkManager::userUnblocked, this, &IrcChat::userUnblockedSlot);
}

bool IrcChat::allDownloadsComplete() {
    return !_emoteProvider.downloadsInProgress() &&
        !_bttvEmoteProvider.downloadsInProgress() &&
        !_ffzEmoteProvider.downloadsInProgress() &&
        _badgeProvider != nullptr && !_badgeProvider->downloadsInProgress() &&
        _bitsProvider != nullptr && !_bitsProvider->downloadsInProgress();
}

IrcChat::~IrcChat() {
    disconnect();
}

void IrcChat::roomInitCommon(const QString channel, const QString channelId) {
    if (inRoom())
        leave();

    // Save channel name and numerical id for later use
    room = channel;
    roomChannelId = channelId;


    if (_badgeProvider) {
        _badgeProvider->setChannelName(channel);
        _badgeProvider->setChannelId(channelId);
    }

    lastCurChannelBitsRegexes.clear();
    if (_bitsProvider) {
        _bitsProvider->setChannelId(channelId.toInt());
    }

    lastCurChannelBttvEmoteFixedStrings.clear();
    lastCurChannelFfzEmoteFixedStrings.clear();
}

void IrcChat::join(const QString channel, const QString channelId) {
    replayMode = false;

    roomInitCommon(channel, channelId);
    if (!connected()) {
        if (sock && sock->state() == QAbstractSocket::UnconnectedState) {
            reopenSocket();
        }
        qDebug() << "Queued channel join" << channel;
        return;
    }

    sendJoinCurrentRoom();
}

void IrcChat::sendJoinCurrentRoom()
{
    if (!sock || room.isEmpty() || replayMode || joinedRoom || !logged_in || !connected()) {
        return;
    }

    sock->write(("JOIN #" + room + "\r\n").toStdString().c_str());
    joinedRoom = true;

    qDebug() << "Joined channel" << room;
}

void IrcChat::replay(const QString channel, const QString channelId, const quint64 /*vodId*/, double /*vodStartEpochTime*/, double /*playbackOffset*/) {
    replayMode = true;
    roomInitCommon(channel, channelId);
    qWarning() << "Twitch no longer exposes VOD replay chat through a supported public API";
}

void IrcChat::replaySeek(double /*newOffset*/) {
}

void IrcChat::replayUpdate(double /*newOffset*/) {
}

QList<QPair<QString, QString>> parseBadges(const QString badgesStr);

void IrcChat::replayStop() {
    replayMode = false;
}

void IrcChat::leave()
{
    msgQueue.clear();
    if (sock && joinedRoom && !room.isEmpty() && connected()) {
        sock->write(("PART #" + room + "\r\n").toStdString().c_str());
    }
    joinedRoom = false;
    room = "";
}

void IrcChat::disconnect() {
    leave();
    if (sock) {
        sock->close();
    }
    logged_in = false;
    joinedRoom = false;
}

void IrcChat::reopenSocket() {
    if (sock) {
        qDebug() << "Reopening socket";
        logged_in = false;
        joinedRoom = false;
        if (sock->isOpen())
            sock->close();
        sock->open(QIODevice::ReadWrite);
        sock->connectToHostEncrypted(HOST, PORT);
        if (!sock->isOpen()) {
            emit errorOccured("Error opening socket");
        }
    }
}

void IrcChat::setAnonymous(bool newAnonymous) {
    if(newAnonymous != anonym) {
        if(newAnonymous) {
            username = "";
            const int anonymousId = QRandomGenerator::global()->bounded(100000, 1000000);
            username = QStringLiteral("justinfan%1").arg(anonymousId, 6, 10, QLatin1Char('0'));
            userpass = "blah";
        }
        anonym = newAnonymous;

        //login();

        emit anonymousChanged();
    }
}

bool IrcChat::connected() {
    if (sock) {
        return sock->state() == QAbstractSocket::ConnectedState && sock->isEncrypted();
    }
    else {
        return false;
    }
}

QVariantMap createImageEntry(QString imageProvider, QString imageId, QString originalText, QString sourceUrl = QString()) {
    QVariantMap imageObj;
    imageObj.insert("imageProvider", imageProvider);
    imageObj.insert("imageId", imageId);
    imageObj.insert("originalText", originalText);
    if (!sourceUrl.isEmpty()) {
        imageObj.insert("sourceUrl", sourceUrl);
    }
    return imageObj;
}

QString IrcChat::bttvEmoteUrl(const QString &id) const
{
    return (settings->hiDpi() ? BTTV_EMOTES_URL_FORMAT_HIDPI : BTTV_EMOTES_URL_FORMAT_LODPI).arg(id);
}

QVariantList IrcChat::substituteEmotesInMessage(const QVariantList & message, const QVariantMap &relevantEmotes) {
    QVariantList output;

    for (auto word = message.begin(); word != message.end(); word++) {
        bool spacePrefix = word != message.begin();
        QString possibleEmoteText = spacePrefix ? word->toString().mid(1) : word->toString();
        bool isEmote = false;

        auto entry = relevantEmotes.constFind(possibleEmoteText);
        if (entry != relevantEmotes.constEnd()) {
            QString emoteId = entry.value().toString();
            _emoteProvider.makeAvailable(emoteId);
            if (spacePrefix) {
                output.append(" ");
            }
            output.append(createImageEntry(_emoteProvider.getImageProviderName(), emoteId, possibleEmoteText));
            isEmote = true;
        }

        for (const auto & emoteIndex : { lastCurChannelBttvEmoteFixedStrings, lastGlobalBttvEmoteFixedStrings }) {
            auto entry = emoteIndex.constFind(possibleEmoteText);
            if (entry != emoteIndex.constEnd()) {
                QString emoteId = entry.value();
                _bttvEmoteProvider.makeAvailable(emoteId);
                if (spacePrefix) {
                    output.append(" ");
                }
                output.append(createImageEntry(_bttvEmoteProvider.getImageProviderName(),
                                               emoteId,
                                               possibleEmoteText,
                                               bttvEmoteUrl(emoteId)));
                isEmote = true;
                break;
            }
        }

        for (const auto & emoteIndex : { lastCurChannelFfzEmoteFixedStrings, lastGlobalFfzEmoteFixedStrings }) {
            auto entry = emoteIndex.constFind(possibleEmoteText);
            if (!isEmote && entry != emoteIndex.constEnd()) {
                QString emoteId = entry.value();
                _ffzEmoteProvider.makeAvailable(emoteId);
                if (spacePrefix) {
                    output.append(" ");
                }
                output.append(createImageEntry(_ffzEmoteProvider.getImageProviderName(), emoteId, possibleEmoteText));
                isEmote = true;
                break;
            }
        }

        if (!isEmote) {
            output.append(*word);
        }
    }
    return output;
}

void removeVariantListPairByFirstValue(QVariantList list, const QVariant value) {
    for (auto it = list.begin(); it != list.end();) {

        if (!it->canConvert<QVariantList>() || it->toList().length() < 1) {
            ++it;
            continue;
        }

        if (it->toList()[0] == value) {
            it = list.erase(it);
        }
        else {
            ++it;
        }
    }
}

void IrcChat::makeBadgeAvailable(const QString badgeName, const QString version) {
    if (_badgeProvider) {
        _badgeProvider->makeAvailable(badgeName + "-" + version);
    }
    else {
        qDebug() << "can't make badge" << badgeName << version << "available because there is no _badgeProvider";
    }
}

QString IrcChat::getBadgeLocalUrl(QString key) {
    if (_badgeProvider) {
        return _badgeProvider->getBaseUrl() + "/" + _badgeProvider->getCanonicalKey(key);
    }
    else {
        qDebug() << "can't get badge url because there is no _badgeProvider";
        return "";
    }
}

bool IrcChat::addBadges(QVariantList &badges, QString channel) {
    qDebug() << "addBadges" << channel;
    auto channelEntry = badgesByChannel.find(channel);
    if (channelEntry != badgesByChannel.end()) {
        auto curBadges = channelEntry.value();
        for (auto badge = curBadges.constBegin(); badge != curBadges.constEnd(); badge++) {
            qDebug() << "badge" << channel << badge->first << badge->second;
            removeVariantListPairByFirstValue(badges, badge->first);
            const QString badgeName = badge->first;
            const QString badgeVersion = badge->second;
            makeBadgeAvailable(badgeName, badgeVersion);
            badges.push_back(QVariantList({ badgeName, badgeVersion }));
        }
        return true;
    }
    else {
        return false;
    }
}

void IrcChat::sendMessage(const QString &msg, const QVariantMap &relevantEmotes) {
    if (inRoom() && connected()) {
		bool isAction = false;
        bool isWhisper = false;
        QString recipient = "";
		QVariantList message;
		const QString ME_PREFIX = "/me ";
		QString displayMessage = msg;
		if (displayMessage.toLower().startsWith(ME_PREFIX)) {
			isAction = true;
			displayMessage = displayMessage.mid(ME_PREFIX.length());
		}
        const QStringList whisperPrefixes = { QStringLiteral("/msg "), QStringLiteral("/w ") };
        for (const QString &prefix : whisperPrefixes) {
            if (displayMessage.toLower().startsWith(prefix)) {
                displayMessage = displayMessage.mid(prefix.length());
                isWhisper = true;
                int spacePos = displayMessage.indexOf(' ');
                if (spacePos == -1 || spacePos == displayMessage.length() - 1) {
                    emit noticeReceived("Ignoring whisper with empty message");
                    return;
                }
                recipient = displayMessage.left(spacePos);
                displayMessage = displayMessage.mid(spacePos + 1);
                break;
            }
        }
        
        const QStringList userBlockPrefixes = {
            QStringLiteral("/block "),
            QStringLiteral("/ignore "),
            QStringLiteral("/unblock "),
            QStringLiteral("/unignore ")
        };
        for (const QString &prefix : userBlockPrefixes) {
            if (displayMessage.toLower().startsWith(prefix)) {
                bool isBlock = (prefix == "/block ") || (prefix == "/ignore ");
                QString username = displayMessage.mid(prefix.length());
                setUserBlock(username, isBlock);
                return;
            }
        }

        if (sock) {
            QString ircCmd;
            if (isWhisper) {
                ircCmd = "PRIVMSG #" + room + " :/w " + recipient + " " + displayMessage + "\r\n";
            }
            else {
                ircCmd = "PRIVMSG #" + room + " :" + msg + "\r\n";
            }
            sock->write(ircCmd.toStdString().c_str());
        }

		addWordSplit(displayMessage, ' ', message);
        message = substituteEmotesInMessage(message, relevantEmotes);

        const QString channelName = "#" + room;

        QVariantList userBadges;
        if (!addBadges(userBadges, channelName)) {
            addBadges(userBadges, "GLOBAL");
        }

        qDebug() << "Looking up color for #" << room;

        QString color = "";
        bool subscriber = false;
        bool turbo = false; // tag?
        bool mod = false;


        auto colorEntry = userChannelColors.find(channelName);
        if (colorEntry != userChannelColors.end()) {
            color = colorEntry.value();
            qDebug() << "using user room color" << color;
        }
        else {
            color = userGlobalColor;
            qDebug() << "using user global color" << color;
        }

        auto subscriberEntry = userChannelSubscriber.find(channelName);
        if (subscriberEntry != userChannelSubscriber.end()) {
            subscriber = subscriberEntry.value();
        }

        auto modEntry = userChannelMod.find(channelName);
        if (modEntry != userChannelMod.end()) {
            mod = modEntry.value();
        }

        QString displayName = username;
        
        auto displayNameEntry = userChannelDisplayName.find(channelName);
        if (displayNameEntry != userChannelDisplayName.end() && displayNameEntry.value() != "") {
            displayName = displayNameEntry.value();
        } else if (userGlobalDisplayName != "") {
            displayName = userGlobalDisplayName;
        }

        bool isChannelMessage = isWhisper;
        QString systemMessage = isWhisper ? ("Whispered to " + recipient + ":") : "";
        disposeOfMessage({ displayName, message, color, subscriber, turbo, mod, isAction, userBadges, isChannelMessage, systemMessage, isWhisper, "" });
    }
}

void IrcChat::onSockStateChanged() {
    // We don't check if connected property actually changed because this slot should only be awaken when it did
    if (!connected()) {
        logged_in = false;
        joinedRoom = false;
    }
    emit connectedChanged();
}

void IrcChat::login()
{
    if (userpass.isEmpty() || username.isEmpty())
        setAnonymous(true);
    else
        setAnonymous(false);

    if (sock) {
        // Tell server that we support twitch-specific commands
        sock->write("CAP REQ :twitch.tv/commands\r\n");
        sock->write("CAP REQ :twitch.tv/tags\r\n");

        // Login
        sock->write(("PASS " + userpass + "\r\n").toStdString().c_str());
        sock->write(("NICK " + username + "\r\n").toStdString().c_str());
    }

    logged_in = true;

    sendJoinCurrentRoom();
}

void IrcChat::receive() {
    QString msg;
    while (sock && sock->canReadLine()) {
        msg = sock->readLine();
        msg = msg.remove('\n').remove('\r');
        parseCommand(msg);
    }
}

void IrcChat::processError(QAbstractSocket::SocketError socketError) {
    QString err;
    switch (socketError) {
    case QAbstractSocket::RemoteHostClosedError:
        err = "Server closed connection.";
        break;
    case QAbstractSocket::HostNotFoundError:
        err = "Host not found.";
        break;
    case QAbstractSocket::ConnectionRefusedError:
        err = "Connection refused.";
        break;
    default:
        err = "Unknown error.";
    }

    emit errorOccured(err);
}

void IrcChat::processSslErrors(const QList<QSslError> &errors) {
    qDebug() << "SSL errors:";
    for (const auto & error : errors) {
        qDebug() << error.errorString();
    }

    emit errorOccured("SSL Error");
}

void IrcChat::addWordSplit(const QString & s, const QChar & sep, QVariantList & l) {
	bool first = true;
    const QStringList & parts = s.split(sep);
	for (const auto & part : parts) {
		if (first) {
			first = false;
			l.append(part);
		}
		else {
			l.append(QString(sep) + part);
		}
	}
}

void IrcChat::disposeOfMessage(ChatMessage m) {
    if (allDownloadsComplete()) {
        emit messageReceived(m.name, m.messageList, m.color, m.subscriber, m.turbo, m.mod, m.isAction, m.badges, m.isChannelNotice, m.systemMessage, m.isWhisper);
    }
    else {
        // queue message to be shown when downloads are complete
        msgQueue.push_back(m);
    }
}

QList<QString> getTags(const QString cmd) {
    if (cmd.at(0) == QChar('@')) {
        // tags are present
        int tagsEnd = cmd.indexOf(" ");
        QString tags = cmd.mid(1, tagsEnd - 1);
        return tags.split(";");
    }
    else {
        return QList<QString>();
    }
}

class Tag {
public:
    Tag(const QString tag) {
        int assignPos = tag.indexOf("=");
        if (assignPos == -1) {
            valid = false;
        }
        else {
            valid = true;
            key = tag.left(assignPos);
            value = tag.mid(assignPos + 1);
        }
    }
public:
    QString key;
    QString value;
    bool valid;
};

QList<QPair<QString, QString>> parseBadges(const QString badgesStr) {
    QList<QPair<QString, QString>> badges;
    for (const QString &badgeStr : badgesStr.split(",")) {
        int splitPos = badgeStr.indexOf('/');
        if (splitPos == -1) continue;
        badges.append(QPair<QString, QString>(badgeStr.left(splitPos), badgeStr.mid(splitPos + 1)));
    }
    return badges;
}

QMap<int, QPair<int, QString>> IrcChat::parseEmotesTag(const QString emotes) {
    QMap<int, QPair<int, QString>> emotePositionsMap;
    if (emotes != "") {
        auto emoteList = emotes.split('/');

        for (auto emote : emoteList) {
            auto key = emote.left(emote.indexOf(':'));
            auto positions = emote.remove(0, emote.indexOf(':') + 1);
            //qDebug() << "key " << key;

            _emoteProvider.makeAvailable(key);

            const QStringList & emotePlcs = positions.split(',');
            for (const auto & emotePlc : emotePlcs) {
                auto firstAndLast = emotePlc.split('-');
                int first = firstAndLast[0].toInt();
                int last = firstAndLast.length() > 1 ? firstAndLast[1].toInt() : first;

                emotePositionsMap.insert(first, qMakePair(last, key));
            }
        }
    }
    return emotePositionsMap;
}

class UnicodeCharacterCounter {
public:
    UnicodeCharacterCounter(const QString s) : s(s) { }
    int toUtf16Offset(int unicodeOffset) {
        if (unicodeOffset < curUnicodeOffset) {
            curUnicodeOffset = 0;
            curQStringOffset = 0;
        }
        
        while (curUnicodeOffset < unicodeOffset) {
            if (curQStringOffset >= s.length()) return s.length();
            const QChar ch = s.at(curQStringOffset++);
            if ((0xd800 <= ch) && (ch <= 0xdbff)) {
                if (curQStringOffset >= s.length()) return s.length();
                curQStringOffset++; // consume another QString char
            }
            curUnicodeOffset++;
        }

        return curQStringOffset;
    }
private:
    int curUnicodeOffset = 0;
    int curQStringOffset = 0;
    const QString s;
};

QRegularExpression createBitsRegex(const QString bitsPrefix) {
    const QString lowerPrefix = bitsPrefix.toLower();
    const QString BITS_REGEX_FORMAT = "(^|\\s)(%1)(\\d+)(\\s|$)";
    const QString regexStr = BITS_REGEX_FORMAT.arg(QRegularExpression::escape(lowerPrefix));
    qDebug() << "creating bits regex for" << bitsPrefix << ":" << regexStr;

    return QRegularExpression(regexStr);
}

const int BITS_LEVELS[] = {10000, 5000, 1000, 100};

QString minBitsForBits(QString bitsStr) {
    int bits = bitsStr.toInt();
    for (int curMinBits : BITS_LEVELS) {
        if (bits >= curMinBits) {
            return QString::number(curMinBits);
        }
    }
    return "1";
}

void IrcChat::checkBitsRegex(const QRegularExpression & regex, const QString & prefix, const QString & message, ImagePositionsMap & mapToUpdate) {
    int pos = 0;
    while (true) {
        const QRegularExpressionMatch match = regex.match(message, pos);
        if (!match.hasMatch()) break;

        int prefixStart = match.capturedStart(2);

        QString bitsCount = match.captured(3);
        int bitsCountEnd = match.capturedEnd(3);
        QString minBits = minBitsForBits(bitsCount);

        qDebug() << "found bits prefix" << prefix << "with count" << bitsCount << "; using minBits" << minBits << "start" << prefixStart << "end" << bitsCountEnd << "resuming at" << bitsCountEnd;

        QString key = prefix + "-" + minBits;
        if (_bitsProvider) {
            InlineImageInfo info;
            info.kind = ImageEntryKind::bits;
            info.key = _bitsProvider->getCanonicalKey(key);
            info.textSuffix = bitsCount;
            BadgeContainer::getInstance()->getChannelBitsColor(roomChannelId.toInt(), prefix, minBits, info.textSuffixColor);
            mapToUpdate.insert(prefixStart, qMakePair(bitsCountEnd, info));
            _bitsProvider->makeAvailable(key);
        }

        pos = bitsCountEnd;
    }
}

void IrcChat::handleBttvEmote(const QString & id, ImagePositionsMap & mapToUpdate, int pos, int end) {
    InlineImageInfo info;
    info.kind = ImageEntryKind::bttvEmote;

    info.key = _bttvEmoteProvider.getCanonicalKey(id);
    mapToUpdate.insert(pos, qMakePair(end, info));
    _bttvEmoteProvider.makeAvailable(id);
}

void IrcChat::handleFfzEmote(const QString & id, ImagePositionsMap & mapToUpdate, int pos, int end) {
    InlineImageInfo info;
    info.kind = ImageEntryKind::ffzEmote;

    info.key = _ffzEmoteProvider.getCanonicalKey(id);
    mapToUpdate.insert(pos, qMakePair(end, info));
    _ffzEmoteProvider.makeAvailable(id);
}

void updateBitsRegexes(const BitsQStringsMap & bitsUrls, QMap<QString, QRegularExpression> & mapToUpdate) {
    mapToUpdate.clear();
    
    for (auto actionEntry = bitsUrls.constBegin(); actionEntry != bitsUrls.constEnd(); actionEntry++) {
        const QString & prefix = actionEntry.key();
        mapToUpdate.insert(prefix, createBitsRegex(prefix));
    }
}

void IrcChat::handleChannelBitsUrlsLoaded(const int channelID, BitsQStringsMap bitsUrls) {
    if (channelID == -1) {
        updateBitsRegexes(bitsUrls, lastGlobalBitsRegexes);
    }
    else if (QString::number(channelID) == roomChannelId) {
        updateBitsRegexes(bitsUrls, lastCurChannelBitsRegexes);
    }
}

void IrcChat::createMessageList(const QMap<int, QPair<int, QString>> & emotePositionsMap, QString bitsNumber, QVariantList & messageList, const QString message) {
    // cut up message into an ordered list of text fragments and images

    // put together all kinds of image entries so we can go through them in order
    ImagePositionsMap imagePositionsMap; // map of start unicode pos -> (end unicode pos, (image kind, key))

    UnicodeCharacterCounter counter(message);

    for (auto emoteEntry = emotePositionsMap.constBegin(); emoteEntry != emotePositionsMap.constEnd(); emoteEntry++) {
        // also convert positions to utf-16 domain at this time
        int start = counter.toUtf16Offset(emoteEntry.key());
        int end = counter.toUtf16Offset(emoteEntry.value().first + 1);
        QString key = emoteEntry.value().second;

        InlineImageInfo info;
        info.kind = ImageEntryKind::emote;
        info.key = key;
        info.textSuffixColor = "#ffffff";
        
        imagePositionsMap.insert(start, qMakePair(end, info));
    }

    if (bitsNumber.length() > 0) {
        for (const QMap<QString, QRegularExpression> & map : { lastCurChannelBitsRegexes, lastGlobalBitsRegexes }) {
            for (auto mapEntry = map.constBegin(); mapEntry != map.constEnd(); mapEntry++) {
                const auto & prefix = mapEntry.key();
                const auto & regex = mapEntry.value();
                checkBitsRegex(regex, prefix, message, imagePositionsMap);
            }
        }
    }

    // check for space-separated fixed string tokens
    int cur = 0;
    while (cur < message.length()) {
        int wordEnd = message.indexOf(' ', cur);
        if (wordEnd == -1) {
            wordEnd = message.length();
        }

        if (wordEnd > cur) {
            const auto word = message.mid(cur, wordEnd - cur);
            
            bool foundThirdPartyEmote = false;
            for (const QMap<QString, QString> & bttvIndex : { lastCurChannelBttvEmoteFixedStrings, lastGlobalBttvEmoteFixedStrings }) {
                const auto matchEntry = bttvIndex.constFind(word);
                if (matchEntry != bttvIndex.constEnd()) {
                    handleBttvEmote(matchEntry.value(), imagePositionsMap, cur, wordEnd);
                    foundThirdPartyEmote = true;
                    break;
                }
            }
            for (const QMap<QString, QString> & ffzIndex : { lastCurChannelFfzEmoteFixedStrings, lastGlobalFfzEmoteFixedStrings }) {
                const auto matchEntry = ffzIndex.constFind(word);
                if (!foundThirdPartyEmote && matchEntry != ffzIndex.constEnd()) {
                    handleFfzEmote(matchEntry.value(), imagePositionsMap, cur, wordEnd);
                    break;
                }
            }
        }

        cur = wordEnd + 1;
    }

    // go through all text replacement image entries and cut up the input message
    cur = 0;
    for (auto i = imagePositionsMap.constBegin(); i != imagePositionsMap.constEnd(); i++) {
        auto emoteStart = i.key();
        if (emoteStart > cur) {
            addWordSplit(message.mid(cur, emoteStart - cur), ' ', messageList);
        }
        auto emoteAfterEnd = i.value().first;

        auto imageInfo = i.value().second;
        auto imageKind = imageInfo.kind;
        auto imageId = imageInfo.key;
        QString originalText = message.mid(emoteStart, emoteAfterEnd - emoteStart);

        QVariantMap imgEntry;
        bool doInsert = true;

        switch (imageKind) {
        case ImageEntryKind::emote:
            imgEntry = createImageEntry(_emoteProvider.getImageProviderName(), imageId, originalText);
            break;
        case ImageEntryKind::bttvEmote:
            imgEntry = createImageEntry(_bttvEmoteProvider.getImageProviderName(),
                                        imageId,
                                        originalText,
                                        bttvEmoteUrl(imageId));
            break;
        case ImageEntryKind::ffzEmote:
            imgEntry = createImageEntry(_ffzEmoteProvider.getImageProviderName(), imageId, originalText);
            break;
        case ImageEntryKind::bits:
            if (_bitsProvider) {
                imgEntry = createImageEntry(_bitsProvider->getImageProviderName(), imageId, originalText);
                // currently QML AnimatedImage doesn't support using images from a QQuickImageProvider
                imgEntry.insert("sourceUrl", BadgeContainer::getInstance()->getBitsUrlForKey(imageId).toString());
            }
            else {
                doInsert = false;
            }
            break;
        }
        if (doInsert) {
            imgEntry.insert("textSuffix", imageInfo.textSuffix);
            imgEntry.insert("textSuffixColor", imageInfo.textSuffixColor);
            messageList.append(imgEntry);
        }
        cur = emoteAfterEnd;
    }
    if (cur < message.length()) {
        addWordSplit(message.mid(cur, message.length() - cur), ' ', messageList);
    }
}

void IrcChat::parseMessageCommand(const QString cmd, const QString cmdKeyword, CommandParse & commandParse) {
    QString displayName = "";

    QString & emotesStr = commandParse.emotesStr;
    emotesStr = "";

    commandParse.tags = getTags(cmd);

    ChatMessage & chatMessage = commandParse.chatMessage;

    chatMessage.isAction = false;
    chatMessage.isChannelNotice = false;
    chatMessage.isWhisper = false;

    for (const QString &tagStr : commandParse.tags) {
        Tag tag(tagStr);
        if (!tag.valid) continue;
        if (tag.key == "display-name") {
            displayName = tag.value;
        }
        else if (tag.key == "color") {
            chatMessage.color = tag.value;
        }
        else if (tag.key == "subscriber") {
            chatMessage.subscriber = (tag.value == "1");
        }
        else if (tag.key == "turbo") {
            chatMessage.turbo = (tag.value == "1");
        }
        else if (tag.key == "mod") {
            chatMessage.mod = (tag.value == "1");
        }
        else if (tag.key == "badges") {
            QList<QPair<QString, QString>> badgesMap = parseBadges(tag.value);

            for (auto entry = badgesMap.constBegin(); entry != badgesMap.constEnd(); entry++) {
                makeBadgeAvailable(entry->first, entry->second);
                chatMessage.badges.push_back(QVariantList({ entry->first, entry->second }));
            }
        }
        else if (tag.key == "emotes") {
            emotesStr = tag.value;
        }
        else if (tag.key == "bits") {
            chatMessage.bitsNumber = tag.value;
        }
        else {
            //qDebug() << "Unused " << cmdKeyword << " tag" << tag.key;
        }
    }

    int cmdKeywordPos = cmd.indexOf(cmdKeyword);

    commandParse.params = cmd.left(cmdKeywordPos);
    QString nickname = commandParse.params.left(commandParse.params.lastIndexOf('!')).remove(0, commandParse.params.lastIndexOf(':') + 1);
    commandParse.haveMessage = false;

    commandParse.message = "";
    int messageSepPos = cmd.indexOf(':', cmdKeywordPos + cmdKeyword.length());
    if (messageSepPos != -1) {
        commandParse.haveMessage = true;
        commandParse.message = cmd.mid(messageSepPos + 1);
    }

    int channelEnd = messageSepPos == -1 ? cmd.length() : messageSepPos - 1;
    int channelStart = cmdKeywordPos + cmdKeyword.length() + 1;
    commandParse.channel = cmd.mid(channelStart, channelEnd - channelStart);

    bool isHashChannel = (commandParse.channel.length() > 0) && (commandParse.channel.at(0) == '#');
    commandParse.wrongChannel = isHashChannel && inRoom() && ((QString("#") + room) != commandParse.channel);
    if (commandParse.wrongChannel) {
        qDebug() << "message is for" << commandParse.channel.mid(1) << "and we are in" << room;
    }

    if (displayName.length() > 0) {
        chatMessage.name = displayName;
    }
    else {
        chatMessage.name = nickname;
    }

    //qDebug() << "emotes " << emotes;
}

static QString ircCommandKeyword(const QString &cmd)
{
    QString message = cmd;
    if (message.startsWith('@')) {
        const int tagEnd = message.indexOf(' ');
        if (tagEnd == -1) {
            return QString();
        }
        message = message.mid(tagEnd + 1);
    }

    const QStringList parts = message.split(' ', Qt::SkipEmptyParts);
    const int commandIndex = !parts.isEmpty() && parts.first().startsWith(':') ? 1 : 0;
    return commandIndex < parts.length() ? parts.at(commandIndex) : QString();
}

static QString ircTrailingMessage(const QString &cmd, int afterPos)
{
    const int messageStart = cmd.indexOf(':', afterPos);
    return messageStart == -1 ? QString() : cmd.mid(messageStart + 1);
}

void IrcChat::parseCommand(QString cmd) {
    const QString commandKeyword = ircCommandKeyword(cmd);

    if (commandKeyword == "RECONNECT") {
        qDebug() << "Twitch IRC requested reconnect";
        reopenSocket();
        return;
    }

    if(commandKeyword == "PING" && cmd.startsWith("PING ")) {
        sock->write(("PONG " + cmd.mid(5) + "\r\n").toStdString().c_str());
        return;
    }

    if (commandKeyword == "HOSTTARGET") {
        const QString hostTarget = ircTrailingMessage(cmd, cmd.indexOf("HOSTTARGET")).section(' ', 0, 0);
        if (hostTarget == "-") {
            emit noticeReceived("No longer hosting another channel.");
        }
        else if (!hostTarget.isEmpty()) {
            emit noticeReceived(QString("Now hosting %1.").arg(hostTarget));
        }
        return;
    }

    if(cmd.contains("PRIVMSG")) {

        // Structure of message: '@color=#HEX;display-name=NicK;emotes=id:start-end,start-end/id:start-end;subscriber=0or1;turbo=0or1;user-type=type :nick!nick@nick.tmi.twitch.tv PRIVMSG #channel :message'

        CommandParse parse;

        parseMessageCommand(cmd, "PRIVMSG", parse);

        if (parse.wrongChannel) {
            return;
        }

        if (blockedUsers.contains(parse.chatMessage.name.toLower())) {
            qDebug() << "Dropping blocked user" << parse.chatMessage.name << "message";
            return;
        }

		// parse IRC action before applying emotes, as emote indices are relative to the content of the action
		const QString ACTION_PREFIX = QString(QChar(1)) + "ACTION ";
		const QString ACTION_SUFFIX = QString(QChar(1));
		if (parse.message.startsWith(ACTION_PREFIX) && parse.message.endsWith(ACTION_SUFFIX)) {
			parse.chatMessage.isAction = true;
            parse.message = parse.message.mid(ACTION_PREFIX.length(), parse.message.length() - ACTION_SUFFIX.length() - ACTION_PREFIX.length());
		}

        createMessageList(parseEmotesTag(parse.emotesStr), parse.chatMessage.bitsNumber, parse.chatMessage.messageList, parse.message);

        //qDebug() << "messageList " << messageList;

        disposeOfMessage(parse.chatMessage);
        return;
    }
    if (cmd.contains("USERNOTICE")) {
        // Structure of message: 
        // @badges=staff/1,broadcaster/1,turbo/1;color=#008000;display-name=TWITCH_UserName;emotes=;mod=0;msg-id=resub;msg-param-months=6;room-id=1337;subscriber=1;system-msg=TWITCH_UserName\shas\ssubscribed\sfor\s6\smonths!;login=twitch_username;turbo=1;user-id=1337;user-type=staff :tmi.twitch.tv USERNOTICE #channel :Great stream -- keep it up!
        // when there is no message, last part is omitted
        // @badges=staff/1,broadcaster/1,turbo/1;color=#008000;display-name=TWITCH_UserName;emotes=;mod=0;msg-id=resub;msg-param-months=6;room-id=1337;subscriber=1;system-msg=TWITCH_UserName\shas\ssubscribed\sfor\s6\smonths!;login=twitch_username;turbo=1;user-id=1337;user-type=staff :tmi.twitch.tv USERNOTICE #channel

        CommandParse parse;

        parseMessageCommand(cmd, "USERNOTICE", parse);

        if (parse.wrongChannel) {
            return;
        }

        parse.chatMessage.isChannelNotice = true;

        QString noticeId;
        QString raidChannel;

        for (const QString &tagStr : parse.tags) {
            Tag tag(tagStr);
            if (tag.key == "msg-id") {
                noticeId = tag.value;
            }
            else if (tag.key == "msg-param-login") {
                raidChannel = tag.value;
            }
            else if (tag.key == "system-msg") {
                QString systemMessage = tag.value;

                // \s -> space
                systemMessage.replace("\\s", " ");
                // double backslash -> single backslash
                systemMessage.replace("\\\\", "\\");

                parse.chatMessage.systemMessage = systemMessage;
            }
        }

        const bool isRaidNotice = noticeId == "raid" && !raidChannel.isEmpty();
        if (isRaidNotice) {
            parse.chatMessage.systemMessage += QString(" https://www.twitch.tv/%1").arg(raidChannel);
        }

        createMessageList(parseEmotesTag(parse.emotesStr), parse.chatMessage.bitsNumber, parse.chatMessage.messageList, parse.message);

        //qDebug() << "messageList " << messageList;

        disposeOfMessage(parse.chatMessage);
        if (isRaidNotice) {
            emit raidReceived(raidChannel);
        }
        return;
    }
    if (cmd.contains("WHISPER")) {
        // Structure of message: 
        // @badges=;color=;display-name=TWitch_UserName;emotes=;message-id=2;thread-id=56781234_142000000;turbo=0;user-id=123456789;user-type= :twitch_username!twitch_username@twitch_username.tmi.twitch.tv WHISPER other_twitch_user :hi
        CommandParse parse;

        parseMessageCommand(cmd, "WHISPER", parse);

        if (parse.wrongChannel) {
            return;
        }

        if (blockedUsers.contains(parse.chatMessage.name.toLower())) {
            qDebug() << "Dropping blocked user" << parse.chatMessage.name << "whisper";
            return;
        }

        parse.chatMessage.isChannelNotice = true;
        parse.chatMessage.isWhisper = true;

        parse.chatMessage.systemMessage = QString("Whisper from");

        createMessageList(parseEmotesTag(parse.emotesStr), parse.chatMessage.bitsNumber, parse.chatMessage.messageList, parse.message);

        //qDebug() << "messageList " << messageList;

        qDebug() << "whisper isWhisper" << parse.chatMessage.isWhisper;
        disposeOfMessage(parse.chatMessage);
        return;

    }
    if(cmd.contains("NOTICE") && !cmd.contains(QRegularExpression(QStringLiteral("\\bban_success")))
        && !cmd.contains(QRegularExpression(QStringLiteral("\\btimeout_success"))))
    {
        QString text = cmd.remove(0, cmd.indexOf(':', cmd.indexOf("NOTICE")) + 1);
        emit noticeReceived(text);
        return;
    }
    if(cmd.contains("GLOBALUSERSTATE")) {
		// Structure of message: @badges=turbo/1;color=#4100CC;display-name=user_name;emote-sets=0,1,22,345;user-id=12345678;user-type= :tmi.twitch.tv GLOBALUSERSTATE
		// We want this for the emote ids
        const QList<QString> tags = getTags(cmd);
        for (const QString &tagStr : tags) {
            Tag tag(tagStr);
            if (!tag.valid) continue;
			if (tag.key == "badges") {
                badgesByChannel.remove("GLOBAL");
                auto badges = parseBadges(tag.value);

                qDebug() << "Updating user global badges from GLOBALUSERSTATE:";
                for (auto entry = badges.constBegin(); entry != badges.constEnd(); entry++) {
                    qDebug() << "  " << entry->first << ":" << entry->second;
                }

                badgesByChannel.insert("GLOBAL", badges);
                emit myBadgesForChannel("GLOBAL", badges);
			}
			else if (tag.key == "emote-sets") {
                qDebug() << "GLOBALUSERSTATE emote-sets" << tag.value;
                const QStringList entries = tag.value.split(',', Qt::SkipEmptyParts);
                _emoteSetIDs = entries;
                emit emoteSetIDsChanged();
            }
            else if (tag.key == "color") {
                qDebug() << "Setting user global color to" << tag.value;
                userGlobalColor = tag.value;
            }
            else if (tag.key == "display-name") {
                userGlobalDisplayName = tag.value;
            }
            else {
                qDebug() << "Unused GLOBALUSERSTATE tag" << tag.key;
            }

		}
        return;
    }
    const QString USERSTATE_CMD = " USERSTATE ";
    if (cmd.contains(USERSTATE_CMD)) {
        //@badges=global_mod/1,turbo/1;color=#0D4200;display-name=TWITCH_UserNaME :tmi.twitch.tv USERSTATE #channel
        QString channel = cmd.mid(cmd.indexOf(USERSTATE_CMD) + USERSTATE_CMD.length());
        userChannelColors.remove(channel);
        badgesByChannel.remove(channel);
        userChannelMod.remove(channel);
        userChannelSubscriber.remove(channel);
        userChannelDisplayName.remove(channel);
        const QList<QString> tags = getTags(cmd);
        for (const QString &tagStr : tags) {
            Tag tag(tagStr);
            if (!tag.valid) continue;
            if (tag.key == "badges") {
                auto badges = parseBadges(tag.value);

                qDebug() << "Updating user badges for" << channel << "from USERSTATE:";
                for (auto entry = badges.constBegin(); entry != badges.constEnd(); entry++) {
                    qDebug() << "  " << entry->first << ":" << entry->second;
                }

                badgesByChannel.insert(channel, badges);
                emit myBadgesForChannel(channel, badges);
            }
            else if (tag.key == "color") {
                qDebug() << "Setting user color for channel" << channel << "to" << tag.value;
                userChannelColors.insert(channel, tag.value);
            }
            else if (tag.key == "mod") {
                userChannelMod.insert(channel, tag.value == "1");
            }
            else if (tag.key == "subscriber") {
                userChannelSubscriber.insert(channel, tag.value == "1");
            }
            else if (tag.key == "display-name") {
                userChannelDisplayName.insert(channel, tag.value);
            }
            else {
                qDebug() << "Unused USERSTATE tag" << tag.key;
            }
        }
        return;
    }

    if (commandKeyword == "CLEARMSG") {
        emit noticeReceived("A chat message was deleted by a moderator.");
        return;
    }

    if(cmd.contains("CLEARCHAT")) {
        //@ban-duration=<ban-duration>;ban-reason=<ban-reason> :tmi.twitch.tv CLEARCHAT #<channel> :<user>
        QString user = cmd.mid(cmd.lastIndexOf(":")+1);
        QString banText = "ban-reason";
        int banIndex = cmd.indexOf(banText) + banText.count();
        QString banReason = cmd.mid( banIndex + 1,
            cmd.indexOf(";", banIndex) - banIndex - 1);
        banReason.replace(QString("\\s"), QString(" "));

        QString durationText = "ban-duration";
        if(cmd.contains(durationText)) {
          int durationIndex = cmd.indexOf(durationText)+durationText.count();
          QString banDuration = cmd.mid(durationIndex + 1,
              cmd.indexOf(";") - durationIndex - 1);
          QString banText = QString("%1 has been timed out for %2 seconds. %3")
                             .arg(user).arg(banDuration).arg(banReason);
          emit noticeReceived(banText);
        }
        else {
          QString banText = QString("%1 is now banned from this room. %2")
                             .arg(user).arg(banReason);
          emit noticeReceived(banText);
        }
        return;
    }

    if (commandKeyword == "CAP" || commandKeyword == "JOIN" || commandKeyword == "PART" ||
        commandKeyword == "ROOMSTATE" || commandKeyword == "001" || commandKeyword == "002" ||
        commandKeyword == "003" || commandKeyword == "004" || commandKeyword == "353" ||
        commandKeyword == "366" || commandKeyword == "372" || commandKeyword == "375" ||
        commandKeyword == "376") {
        return;
    }

    qDebug() << "Unrecognized chat command:" << cmd;
}

QString IrcChat::getParamValue(QString params, QString param) {
    QString paramValue = params.remove(0, params.indexOf(param + "="));
    paramValue = paramValue.left(paramValue.indexOf(';')).remove(0, paramValue.indexOf('=') + 1);
    return paramValue;
}

QStringList IrcChat::emoteSetIDs() {
    return _emoteSetIDs;
}

void IrcChat::handleDownloadComplete() {
    if (allDownloadsComplete()) {
        emit downloadComplete();

        //qDebug() << "Download queue complete; posting pending messages";
        while (!msgQueue.empty()) {
            ChatMessage tmpMsg = msgQueue.first();
            emit messageReceived(tmpMsg.name, tmpMsg.messageList, tmpMsg.color, tmpMsg.subscriber, tmpMsg.turbo, tmpMsg.mod, tmpMsg.isAction, tmpMsg.badges, tmpMsg.isChannelNotice, tmpMsg.systemMessage, tmpMsg.isWhisper);
            msgQueue.pop_front();
        }
    }
}

void IrcChat::bulkDownloadEmotes(QList<QString> keys) {
    _emoteProvider.bulkDownload(keys);
}

QList<QString> valuesList(const QMap<QString, QString> & map) {
    QList<QString> out;
    for (auto entry = map.constBegin(); entry != map.constEnd(); entry++) {
        out.append(entry.value());
    }
    return out;
}

void IrcChat::downloadBttvEmotesGlobal() {
    _bttvEmoteProvider.bulkDownload(valuesList(lastGlobalBttvEmoteFixedStrings));
}

void IrcChat::downloadBttvEmotesChannel() {
    _bttvEmoteProvider.bulkDownload(valuesList(lastCurChannelBttvEmoteFixedStrings));
}

void IrcChat::downloadFfzEmotesGlobal() {
    _ffzEmoteProvider.bulkDownload(valuesList(lastGlobalFfzEmoteFixedStrings));
}

void IrcChat::downloadFfzEmotesChannel() {
    _ffzEmoteProvider.bulkDownload(valuesList(lastCurChannelFfzEmoteFixedStrings));
}

void IrcChat::blockedUsersLoaded(const QSet<QString> & newBlockedUsers) {
    blockedUsers = newBlockedUsers;
}

void IrcChat::setUserBlock(const QString & username, const bool blocked) {
    editUserBlock(username, blocked);
}

void IrcChat::userBlockedSlot(quint64 /*myUserId*/, const QString & blockedUsername) {
    QString newBlockedUsername = blockedUsername.toLower();
    emit noticeReceived("User " + blockedUsername + " successfully ignored");
    if (!blockedUsers.contains(newBlockedUsername)) {
        blockedUsers.insert(newBlockedUsername);
    }
}

void IrcChat::userUnblockedSlot(quint64 /*myUserId*/, const QString & unblockedUsername) {
    QString newUnblockedUsername = unblockedUsername.toLower();
    emit noticeReceived("User " + newUnblockedUsername + " successfully unignored");
    if (blockedUsers.contains(newUnblockedUsername)) {
        blockedUsers.remove(newUnblockedUsername);
    }
}

template <typename U>
QVariantMap toVariantMap(const QMap<QString, U> & map) {
    QVariantMap out;
    for (auto entry = map.constBegin(); entry != map.constEnd(); entry++) {
        out.insert(entry.key(), entry.value());
    }
    return out;
}

void IrcChat::handleChannelBttvEmotesLoaded(const QString & channelName, QMap<QString, QString> emotesByCode) {
    const QString GLOBAL_EMOTES_ID = "GLOBAL";
    if (channelName == GLOBAL_EMOTES_ID) {
        lastGlobalBttvEmoteFixedStrings = emotesByCode;
    }
    else if (channelName == room) {
        lastCurChannelBttvEmoteFixedStrings = emotesByCode;
    }

    emit bttvEmotesLoaded(channelName, toVariantMap(emotesByCode));
}

void IrcChat::handleChannelFfzEmotesLoaded(const QString & channelName, QMap<QString, QString> emotesByCode) {
    const QString GLOBAL_EMOTES_ID = "GLOBAL";
    if (channelName == GLOBAL_EMOTES_ID) {
        lastGlobalFfzEmoteFixedStrings = emotesByCode;
    }
    else if (channelName == room) {
        lastCurChannelFfzEmoteFixedStrings = emotesByCode;
    }

    emit ffzEmotesLoaded(channelName, toVariantMap(emotesByCode));
}

void IrcChat::innerUserBlocked(quint64 myUserId, const QString & blockedUsername) {
    if (user_id == myUserId) {
        emit userBlocked(blockedUsername);
    }
}

void IrcChat::innerUserUnblocked(quint64 myUserId, const QString & unblockedUsername) {
    if (user_id == myUserId) {
        emit userUnblocked(unblockedUsername);
    }
}

void IrcChat::getBlockedUserList()
{
    blockedUserListLoading.clear();
    netman->getBlockedUserList(user_id, 0, BLOCKED_USER_LIST_FETCH_LIMIT);
}

void IrcChat::addBlockedUserResults(const QList<QString> & list, const quint32 nextOffset, const quint32 total)
{
    if (!user_id || !settings->hasAccessToken()) return;

    blockedUserListLoading.append(list);

    if (nextOffset < total) {
        netman->getBlockedUserList(user_id, nextOffset, BLOCKED_USER_LIST_FETCH_LIMIT);
    }
    else {
        blockedUsersLoaded(QSet<QString>(blockedUserListLoading.constBegin(), blockedUserListLoading.constEnd()));
    }
}

void IrcChat::editUserBlock(const QString & blockUserName, const bool isBlock) {
    if (settings->hasAccessToken()) {
        netman->editUserBlock(user_id, blockUserName, isBlock);
    }
}
