#ifndef SETTINGSMANAGER_H
#define SETTINGSMANAGER_H

#include <QObject>
#include <QSettings>
#include "singletonprovider.h"

class SettingsManager : public QObject
{
    QML_SINGLETON
    Q_OBJECT

    Q_PROPERTY(bool alert READ alert WRITE setAlert NOTIFY alertChanged)
    Q_PROPERTY(bool multipleInstances READ multipleInstances WRITE setMultipleInstances NOTIFY multipleInstancesChanged)
    Q_PROPERTY(int alertPosition READ alertPosition WRITE setAlertPosition NOTIFY alertPositionChanged)
    Q_PROPERTY(int alertScreen READ alertScreen WRITE setAlertScreen NOTIFY alertScreenChanged)
    Q_PROPERTY(int volumeLevel READ volumeLevel WRITE setVolumeLevel NOTIFY volumeLevelChanged)
    Q_PROPERTY(bool minimizeOnStartup READ minimizeOnStartup WRITE setMinimizeOnStartup NOTIFY minimizeOnStartupChanged)
    Q_PROPERTY(int chatEdge READ chatEdge WRITE setChatEdge NOTIFY chatEdgeChanged)
    Q_PROPERTY(bool offlineNotifications READ offlineNotifications WRITE setOfflineNotifications NOTIFY offlineNotificationsChanged)
    Q_PROPERTY(bool chatNotifications READ chatNotifications WRITE setChatNotifications NOTIFY chatNotificationsChanged)
    Q_PROPERTY(bool autoRaidRedirect READ autoRaidRedirect WRITE setAutoRaidRedirect NOTIFY autoRaidRedirectChanged)
    Q_PROPERTY(double textScaleFactor READ textScaleFactor WRITE setTextScaleFactor NOTIFY textScaleFactorChanged)
    Q_PROPERTY(QString opengl READ opengl WRITE setOpengl NOTIFY openglChanged)
    Q_PROPERTY(QString quality READ quality WRITE setQuality NOTIFY qualityChanged)
    Q_PROPERTY(bool rememberChannelQuality READ rememberChannelQuality WRITE setRememberChannelQuality NOTIFY rememberChannelQualityChanged)
    Q_PROPERTY(bool lowLatencyPlayback READ lowLatencyPlayback WRITE setLowLatencyPlayback NOTIFY lowLatencyPlaybackChanged)
    Q_PROPERTY(int vodCacheMaxAgeHours READ vodCacheMaxAgeHours WRITE setVodCacheMaxAgeHours NOTIFY vodCacheMaxAgeHoursChanged)
    Q_PROPERTY(QString decoder READ decoder WRITE setDecoder NOTIFY decoderChanged)
    Q_PROPERTY(bool audioCompressor READ audioCompressor WRITE setAudioCompressor NOTIFY audioCompressorChanged)
    Q_PROPERTY(QString backend READ backend WRITE setBackend NOTIFY backendChanged)
    Q_PROPERTY(QStringList backends READ backends NOTIFY backendsChanged)
    Q_PROPERTY(QString accessToken READ accessToken WRITE setAccessToken NOTIFY accessTokenChanged)
    Q_PROPERTY(bool hasAccessToken READ hasAccessToken NOTIFY accessTokenChanged)
    Q_PROPERTY(bool lightTheme READ lightTheme WRITE setLightTheme NOTIFY lightThemeChanged)
    Q_PROPERTY(bool pastelColors READ pastelColors WRITE setPastelColors NOTIFY pastelColorsChanged)
    Q_PROPERTY(bool compactNavigation READ compactNavigation WRITE setCompactNavigation NOTIFY compactNavigationChanged)
    Q_PROPERTY(bool sideNavigation READ sideNavigation WRITE setSideNavigation NOTIFY sideNavigationChanged)
    Q_PROPERTY(bool clickTogglePause READ clickTogglePause WRITE setClickTogglePause NOTIFY clickTogglePauseChanged)
    Q_PROPERTY(bool inhibitScreensaver READ inhibitScreensaver WRITE setInhibitScreensaver NOTIFY inhibitScreensaverChanged)
    Q_PROPERTY(bool autoScrollSmoothing READ autoScrollSmoothing WRITE setAutoScrollSmoothing NOTIFY autoScrollSmoothingChanged)
    Q_PROPERTY(QString chatBlacklist READ chatBlacklist WRITE setChatBlacklist NOTIFY chatBlacklistChanged)
    Q_PROPERTY(QString chatHighlightUsers READ chatHighlightUsers WRITE setChatHighlightUsers NOTIFY chatHighlightUsersChanged)
    Q_PROPERTY(double chatOpacity READ chatOpacity WRITE setChatOpacity NOTIFY chatOpacityChanged)
    Q_PROPERTY(QString font READ font WRITE setFont NOTIFY fontChanged)
    Q_PROPERTY(bool versionCheckEnabled READ versionCheckEnabled)
    Q_PROPERTY(bool keepOnTop READ keepOnTop WRITE setKeepOnTop NOTIFY keepOnTopChanged)

    bool mAlert = true;
    bool mMultipleInstances = false;
    int mAlertPosition = 1;
    int mAlertScreen = 0;
    int mVolumeLevel = 100;
    bool mMinimizeOnStartup = false;
    bool mSwapChat = false;
    bool mOfflineNotifications = false;
    bool mChatNotifications = true;
    bool mAutoRaidRedirect = false;
    double mTextScaleFactor = 1.0;
#ifdef Q_OS_WIN
    QString mOpengl = "angle (d3d11)";
#else
    QString mOpengl = "opengl es";
#endif
    QString mQuality = "source";
    bool mRememberChannelQuality = false;
    bool mLowLatencyPlayback = false;
    int mVodCacheMaxAgeHours = 24;
    QString mDecoder = "auto-copy";
    bool mAudioCompressor = false;

#ifdef MPV_PLAYER
    QString mBackend = "mpv";
#elif defined(QTAV_PLAYER)
    QString mBackend = "qtav";
#elif defined(MULTIMEDIA_PLAYER)
    QString mBackend = "multimedia";
#else
    #error unknown backend
#endif
    QStringList mBackends = {
    #ifdef MPV_PLAYER
        "mpv",
    #endif
    #ifdef QTAV_PLAYER
        "qtav",
    #endif
    #ifdef MULTIMEDIA_PLAYER
        "multimedia",
    #endif
    };
    QString mAccessToken = "";
    int mChatEdge = 1;
    bool mLightTheme = false;
    bool mPastelColors = true;
    bool mCompactNavigation = false;
    bool mSideNavigation = false;
    bool mClickTogglePause = true;
    bool mInhibitScreensaver = true;
    bool mAutoScrollSmoothing = true;
    QString mChatBlacklist = "";
    QString mChatHighlightUsers = "";
    double mChatOpacity = 1.0;
    QString mFont = "";

    bool mHiDpi = false;
    bool mKeepOnTop = false;

    explicit SettingsManager(QObject *parent = nullptr);
public:
    static SettingsManager *getInstance();

    bool alert() const;
    void setAlert(bool alert);

    bool multipleInstances() const;
    void setMultipleInstances(bool multipleInstances);

    int alertPosition() const;
    void setAlertPosition(int alertPosition);

    int alertScreen() const;
    void setAlertScreen(int alertScreen);

    int volumeLevel() const;
    void setVolumeLevel(int volumeLevel);

    bool minimizeOnStartup() const;
    void setMinimizeOnStartup(bool minimizeOnStartup);

    int chatEdge() const;
    void setChatEdge(int chatEdge);

    bool offlineNotifications() const;
    void setOfflineNotifications(bool offlineNotifications);

    bool chatNotifications() const;
    void setChatNotifications(bool chatNotifications);

    bool autoRaidRedirect() const;
    void setAutoRaidRedirect(bool autoRaidRedirect);

    double textScaleFactor() const;
    void setTextScaleFactor(double textScaleFactor);

    QString opengl() const;
    void setOpengl(const QString &opengl);

    QString quality() const;
    void setQuality(const QString &quality);

    bool rememberChannelQuality() const;
    void setRememberChannelQuality(bool rememberChannelQuality);

    bool lowLatencyPlayback() const;
    void setLowLatencyPlayback(bool lowLatencyPlayback);

    int vodCacheMaxAgeHours() const;
    void setVodCacheMaxAgeHours(int vodCacheMaxAgeHours);

    QString decoder() const;
    void setDecoder(const QString &decoder);

    bool audioCompressor() const;
    void setAudioCompressor(bool audioCompressor);

    QString accessToken() const;

    void setHiDpi(bool dpi);

    bool lightTheme() const;
    void setLightTheme(bool lightTheme);

    QString font() const;
    void setFont(const QString &font);

    bool versionCheckEnabled();

    bool keepOnTop() const;
    void setKeepOnTop(bool keepOnTop);

    QString backend() const;
    void setBackend(const QString &backend);

    QStringList backends() const;

    bool pastelColors() const;
    void setPastelColors(bool pastelColors);

    bool compactNavigation() const;
    void setCompactNavigation(bool compactNavigation);

    bool sideNavigation() const;
    void setSideNavigation(bool sideNavigation);

    bool clickTogglePause() const;
    void setClickTogglePause(bool clickTogglePause);

    bool inhibitScreensaver() const;
    void setInhibitScreensaver(bool inhibitScreensaver);

    bool autoScrollSmoothing() const;
    void setAutoScrollSmoothing(bool autoScrollSmoothing);

    QString chatBlacklist() const;
    void setChatBlacklist(const QString &chatBlacklist);

    QString chatHighlightUsers() const;
    void setChatHighlightUsers(const QString &chatHighlightUsers);

    double chatOpacity() const;
    void setChatOpacity(double chatOpacity);

    Q_INVOKABLE void copyToClipboard(const QString &text) const;
    Q_INVOKABLE void showVirtualKeyboard() const;
    Q_INVOKABLE QStringList screenNames() const;
    Q_INVOKABLE QString channelQuality(const QString &channel);
    Q_INVOKABLE void setChannelQuality(const QString &channel, const QString &quality);
    Q_INVOKABLE void markBackendUnavailable(const QString &backend);

signals:
    void alertChanged();
    void multipleInstancesChanged();
    void alertPositionChanged();
    void alertScreenChanged();
    void volumeLevelChanged();
    void minimizeOnStartupChanged();
    void chatEdgeChanged();
    void offlineNotificationsChanged();
    void chatNotificationsChanged();
    void autoRaidRedirectChanged();
    void textScaleFactorChanged();
    void openglChanged();
    void qualityChanged();
    void rememberChannelQualityChanged();
    void lowLatencyPlaybackChanged();
    void vodCacheMaxAgeHoursChanged();
    void decoderChanged();
    void audioCompressorChanged();
    void backendChanged();
    void backendsChanged();
    void lightThemeChanged();
    void accessTokenChanged(QString accessToken);
    void fontChanged();
    void keepOnTopChanged();
    void pastelColorsChanged();
    void compactNavigationChanged();
    void sideNavigationChanged();
    void clickTogglePauseChanged();
    void inhibitScreensaverChanged();
    void autoScrollSmoothingChanged();
    void chatBlacklistChanged();
    void chatHighlightUsersChanged();
    void chatOpacityChanged();

public slots:
    void setAccessToken(const QString accessToken);
    bool hasAccessToken() const;
    void load();

    bool hiDpi() const;
    bool isNewerVersion(QString version) const;

private:
    QSettings settings;
};

#endif // SETTINGSMANAGER_H
