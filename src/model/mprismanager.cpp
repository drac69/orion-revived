#include "mprismanager.h"

#include <QtGlobal>

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
#include <QCoreApplication>
#include <QDBusAbstractAdaptor>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusVariant>
#include <QDebug>
#endif

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
class MprisRootAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    Q_PROPERTY(bool CanQuit READ canQuit CONSTANT)
    Q_PROPERTY(bool CanRaise READ canRaise CONSTANT)
    Q_PROPERTY(bool Fullscreen READ fullscreen WRITE setFullscreen)
    Q_PROPERTY(bool HasTrackList READ hasTrackList CONSTANT)
    Q_PROPERTY(QString Identity READ identity CONSTANT)
    Q_PROPERTY(QString DesktopEntry READ desktopEntry CONSTANT)
    Q_PROPERTY(QStringList SupportedUriSchemes READ supportedUriSchemes CONSTANT)
    Q_PROPERTY(QStringList SupportedMimeTypes READ supportedMimeTypes CONSTANT)

public:
    explicit MprisRootAdaptor(MprisManager *manager)
        : QDBusAbstractAdaptor(manager), mManager(manager)
    {
        setAutoRelaySignals(true);
    }

    bool canQuit() const { return false; }
    bool canRaise() const { return true; }
    bool fullscreen() const { return false; }
    void setFullscreen(bool fullscreen) { Q_UNUSED(fullscreen) }
    bool hasTrackList() const { return false; }
    QString identity() const { return QStringLiteral("Orion"); }
    QString desktopEntry() const { return QStringLiteral("Orion"); }
    QStringList supportedUriSchemes() const { return QStringList(); }
    QStringList supportedMimeTypes() const { return QStringList(); }

public slots:
    void Raise() { emit mManager->raiseRequested(); }
    void Quit() {}

private:
    MprisManager *mManager;
};

class MprisPlayerAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(QString PlaybackStatus READ playbackStatus)
    Q_PROPERTY(QString LoopStatus READ loopStatus WRITE setLoopStatus)
    Q_PROPERTY(double Rate READ rate WRITE setRate)
    Q_PROPERTY(bool Shuffle READ shuffle WRITE setShuffle)
    Q_PROPERTY(QVariantMap Metadata READ metadata)
    Q_PROPERTY(double Volume READ volume WRITE setVolume)
    Q_PROPERTY(qlonglong Position READ position)
    Q_PROPERTY(double MinimumRate READ minimumRate CONSTANT)
    Q_PROPERTY(double MaximumRate READ maximumRate CONSTANT)
    Q_PROPERTY(bool CanGoNext READ canGoNext CONSTANT)
    Q_PROPERTY(bool CanGoPrevious READ canGoPrevious CONSTANT)
    Q_PROPERTY(bool CanPlay READ canPlay CONSTANT)
    Q_PROPERTY(bool CanPause READ canPause CONSTANT)
    Q_PROPERTY(bool CanSeek READ canSeek CONSTANT)
    Q_PROPERTY(bool CanControl READ canControl CONSTANT)

public:
    explicit MprisPlayerAdaptor(MprisManager *manager)
        : QDBusAbstractAdaptor(manager), mManager(manager)
    {
        setAutoRelaySignals(true);
    }

    QString playbackStatus() const { return mManager->playbackStatus(); }
    QString loopStatus() const { return QStringLiteral("None"); }
    void setLoopStatus(const QString &loopStatus) { Q_UNUSED(loopStatus) }
    double rate() const { return 1.0; }
    void setRate(double rate) { Q_UNUSED(rate) }
    bool shuffle() const { return false; }
    void setShuffle(bool shuffle) { Q_UNUSED(shuffle) }
    QVariantMap metadata() const { return mManager->metadata(); }
    double volume() const { return mManager->volume(); }
    void setVolume(double volume) { mManager->requestVolume(volume); }
    qlonglong position() const { return mManager->position(); }
    double minimumRate() const { return 1.0; }
    double maximumRate() const { return 1.0; }
    bool canGoNext() const { return false; }
    bool canGoPrevious() const { return false; }
    bool canPlay() const { return true; }
    bool canPause() const { return true; }
    bool canSeek() const { return true; }
    bool canControl() const { return true; }

public slots:
    void Next() {}
    void Previous() {}
    void Pause() { emit mManager->pauseRequested(); }
    void PlayPause() { emit mManager->playPauseRequested(); }
    void Stop() { emit mManager->stopRequested(); }
    void Play() { emit mManager->playRequested(); }
    void Seek(qlonglong offset) { emit mManager->seekRequested(offset); }
    void SetPosition(const QDBusObjectPath &trackId, qlonglong position)
    {
        Q_UNUSED(trackId)
        emit mManager->setPositionRequested(position);
    }
    void OpenUri(const QString &uri) { Q_UNUSED(uri) }

signals:
    void Seeked(qlonglong Position);

private:
    MprisManager *mManager;
};
#endif

MprisManager::MprisManager(QObject *parent)
    : QObject(parent)
{
#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    new MprisRootAdaptor(this);
    new MprisPlayerAdaptor(this);

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        qWarning() << "MPRIS disabled: no D-Bus session bus";
        return;
    }

    const QString serviceName = QStringLiteral("org.mpris.MediaPlayer2.orion");
    if (!bus.registerService(serviceName)) {
        qWarning() << "MPRIS disabled: could not register" << serviceName;
        return;
    }

    mAvailable = bus.registerObject(QStringLiteral("/org/mpris/MediaPlayer2"),
                                    this,
                                    QDBusConnection::ExportAdaptors);
    if (!mAvailable) {
        bus.unregisterService(serviceName);
        qWarning() << "MPRIS disabled: could not register player object";
    }
#endif
}

MprisManager *MprisManager::getInstance()
{
    static MprisManager instance;
    return &instance;
}

QString MprisManager::playbackStatus() const
{
    return mPlaybackStatus;
}

void MprisManager::setPlaybackStatus(const QString &playbackStatus)
{
    if (mPlaybackStatus != playbackStatus) {
        mPlaybackStatus = playbackStatus;
        emit playbackStatusChanged();
        notifyPlayerPropertiesChanged({{QStringLiteral("PlaybackStatus"), mPlaybackStatus}});
    }
}

double MprisManager::volume() const
{
    return mVolume;
}

void MprisManager::setVolume(double volume)
{
    const double clampedVolume = qBound(0.0, volume, 1.0);
    if (!qFuzzyCompare(mVolume + 1.0, clampedVolume + 1.0)) {
        mVolume = clampedVolume;
        emit volumeChanged();
        notifyPlayerPropertiesChanged({{QStringLiteral("Volume"), mVolume}});
    }
}

void MprisManager::requestVolume(double volume)
{
    setVolume(volume);
    emit volumeRequested(mVolume);
}

qint64 MprisManager::position() const
{
    return mPosition;
}

void MprisManager::setPosition(qint64 position)
{
    const qint64 clampedPosition = qMax<qint64>(0, position);
    if (mPosition != clampedPosition) {
        mPosition = clampedPosition;
        emit positionChanged();
    }
}

QVariantMap MprisManager::metadata() const
{
    return mMetadata;
}

void MprisManager::setMetadata(const QString &title, const QString &artist, qint64 length, const QString &artUrl)
{
    QVariantMap metadata;

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    metadata.insert(QStringLiteral("mpris:trackid"),
                    QVariant::fromValue(QDBusObjectPath(QStringLiteral("/org/orion/current"))));
#endif

    metadata.insert(QStringLiteral("xesam:title"), title.isEmpty() ? QStringLiteral("Orion") : title);
    if (!artist.isEmpty()) {
        metadata.insert(QStringLiteral("xesam:artist"), QStringList({artist}));
    }
    if (length > 0) {
        metadata.insert(QStringLiteral("mpris:length"), length);
    }
    if (!artUrl.isEmpty()) {
        metadata.insert(QStringLiteral("mpris:artUrl"), artUrl);
    }

    if (mMetadata != metadata) {
        mMetadata = metadata;
        emit metadataChanged();
        notifyPlayerPropertiesChanged({{QStringLiteral("Metadata"), mMetadata}});
    }
}

bool MprisManager::available() const
{
    return mAvailable;
}

void MprisManager::notifyPlayerPropertiesChanged(const QVariantMap &changedProperties)
{
#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    if (!mAvailable) {
        return;
    }

    QDBusMessage message = QDBusMessage::createSignal(QStringLiteral("/org/mpris/MediaPlayer2"),
                                                      QStringLiteral("org.freedesktop.DBus.Properties"),
                                                      QStringLiteral("PropertiesChanged"));
    message << QStringLiteral("org.mpris.MediaPlayer2.Player") << changedProperties << QStringList();
    QDBusConnection::sessionBus().send(message);
#else
    Q_UNUSED(changedProperties)
#endif
}

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
#include "mprismanager.moc"
#endif
