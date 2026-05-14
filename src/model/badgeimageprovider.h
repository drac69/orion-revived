#pragma once

#include "imageprovider.h"

class ChannelManager;

class BadgeImageProvider : public ImageProvider {
    Q_OBJECT
public:
    BadgeImageProvider();
    void setChannelName(QString channelName) { _channelName = channelName; }
    void setChannelId(QString channelId) { _channelId = channelId; }
    QString getCanonicalKey(QString key) override;
protected:
    const QUrl getUrlForKey(QString & key) override;
private:
    QString _channelName;
    QString _channelId;
};

class BitsImageProvider : public ImageProvider {
    Q_OBJECT

public:
    BitsImageProvider();
    void setChannelId(qint64 channelId) { _channelId = channelId; }
    QString getCanonicalKey(QString key) override;
protected:
    const QUrl getUrlForKey(QString & key) override;
private:
    qint64 _channelId;
};
