#include "badgeimageprovider.h"
#include "badgecontainer.h"
#include "settingsmanager.h"
#include <QUrl>

namespace {
QString badgeKeyPart(const QString &value)
{
    return QString::fromLatin1(QUrl::toPercentEncoding(value, QByteArray(), "-"));
}

QString badgeKeyPartValue(const QString &value)
{
    return QUrl::fromPercentEncoding(value.toLatin1());
}

QString badgeCacheKey(const QString &channel, const QString &badge, const QString &version, const QString &imageFormat)
{
    return QList<QString>({ channel, badgeKeyPart(badge), badgeKeyPart(version), imageFormat }).join("-");
}
}

BadgeImageProvider::BadgeImageProvider() : ImageProvider("badge", ".png") {

}

QString BadgeImageProvider::badgeKey(const QString &badgeName, const QString &version)
{
    return QList<QString>({ badgeKeyPart(badgeName), badgeKeyPart(version) }).join("-");
}

QString BadgeImageProvider::getCanonicalKey(QString key) {
    /** Resolve a key with just a badge name and version, specific to the current room, to a globally unique key for an official API or beta API badge */
    QString url;

    const QString betaImageFormat = SettingsManager::getInstance()->hiDpi() ? "image_url_2x" : "image_url_1x";

    const QStringList keyParts = key.split("-");
    if (keyParts.length() == 2) {
        const QString badge = badgeKeyPartValue(keyParts.at(0));
        const QString version = badgeKeyPartValue(keyParts.at(1));
        //qDebug() << "badge hunt: channel name" << _channelName << "channel id" << _channelId << "badge" << badge << "version" << version;

        if (BadgeContainer::getInstance()->getChannelBadgeBetaUrl(_channelId, badge, version, betaImageFormat, url)) {
            return badgeCacheKey(_channelId, badge, version, betaImageFormat);
        }
        if (BadgeContainer::getInstance()->getChannelBadgeBetaUrl("GLOBAL", badge, version, betaImageFormat, url)) {
            return badgeCacheKey("GLOBAL", badge, version, betaImageFormat);
        }
    }

    qDebug() << "getCanonicalKey for badge" << key << "could not find a badge";
    return key;
}

const QUrl BadgeImageProvider::getUrlForKey(QString & key) {
    QString url;

    QList<QString> parts = key.split("-");
    if (parts.length() == 4) {
        const QString badge = badgeKeyPartValue(parts.at(1));
        const QString version = badgeKeyPartValue(parts.at(2));
        if (BadgeContainer::getInstance()->getChannelBadgeBetaUrl(parts.at(0), badge, version, parts.at(3), url)) {
            return url;
        }
    }
    qDebug() << "Invalid badge cache key" << key;
    return QUrl();
}

BitsImageProvider::BitsImageProvider() : ImageProvider("bits", ".gif") {

}

QString BitsImageProvider::getCanonicalKey(QString key) {
    // input key has a prefix and a bits level, separated by a -

    QString globalUrl;
    QString channelUrl;

    const QString theme = "dark";
    const QString type = "animated";
    const QString size = SettingsManager::getInstance()->hiDpi() ? "2" : "1";

    int splitPos = key.indexOf('-');
    if (splitPos != -1) {
        QString prefix = key.left(splitPos);
        QString minBits = key.mid(splitPos + 1);

        bool foundGlobalUrl = BadgeContainer::getInstance()->getChannelBitsUrl(-1, prefix, minBits, globalUrl);

        if (BadgeContainer::getInstance()->getChannelBitsUrl(_channelId, prefix, minBits, channelUrl)) {
            if (!foundGlobalUrl || channelUrl != globalUrl) {
                return QList<QString>({ QString::number(_channelId), theme, type, size, prefix, minBits }).join("-");
            }
        }
        if (foundGlobalUrl) {
            return QList<QString>({ "GLOBAL", theme, type, size, prefix, minBits }).join("-");
        }
    }
    qDebug() << "can't canonicalize" << key << "couldn't find that bits badge";
    return key;
}

const QUrl BitsImageProvider::getUrlForKey(QString & key) {
    return BadgeContainer::getInstance()->getBitsUrlForKey(key);
}
