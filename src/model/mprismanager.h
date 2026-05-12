#ifndef MPRISMANAGER_H
#define MPRISMANAGER_H

#include <QObject>
#include <QVariantMap>

#include "singletonprovider.h"

class MprisManager : public QObject
{
    QML_SINGLETON
    Q_OBJECT
    Q_PROPERTY(QString playbackStatus READ playbackStatus WRITE setPlaybackStatus NOTIFY playbackStatusChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(qint64 position READ position WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(QVariantMap metadata READ metadata NOTIFY metadataChanged)

    explicit MprisManager(QObject *parent = nullptr);

public:
    static MprisManager *getInstance();

    QString playbackStatus() const;
    Q_INVOKABLE void setPlaybackStatus(const QString &playbackStatus);

    double volume() const;
    Q_INVOKABLE void setVolume(double volume);

    qint64 position() const;
    Q_INVOKABLE void setPosition(qint64 position);

    QVariantMap metadata() const;
    Q_INVOKABLE void setMetadata(const QString &title, const QString &artist, qint64 length, const QString &artUrl);
    Q_INVOKABLE bool available() const;

signals:
    void playbackStatusChanged();
    void volumeChanged();
    void positionChanged();
    void metadataChanged();

    void playRequested();
    void pauseRequested();
    void playPauseRequested();
    void stopRequested();
    void seekRequested(qint64 offset);
    void setPositionRequested(qint64 position);
    void volumeRequested(double volume);
    void raiseRequested();

private:
    friend class MprisRootAdaptor;
    friend class MprisPlayerAdaptor;

    void requestVolume(double volume);
    void notifyPlayerPropertiesChanged(const QVariantMap &changedProperties);

    QString mPlaybackStatus = "Stopped";
    double mVolume = 1.0;
    qint64 mPosition = 0;
    QVariantMap mMetadata;
    bool mAvailable = false;
};

#endif // MPRISMANAGER_H
