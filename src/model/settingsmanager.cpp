#include "settingsmanager.h"
#include "../network/httpserver.h"
#include <QClipboard>
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QGuiApplication>
#include <QInputMethod>
#include <QProcess>
#include <QScreen>
#include <QStandardPaths>

#ifdef Q_OS_WIN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#ifndef SM_TABLETPC
#define ORION_SM_TABLETPC 86
#else
#define ORION_SM_TABLETPC SM_TABLETPC
#endif
#ifndef SM_CONVERTIBLESLATEMODE
#define ORION_SM_CONVERTIBLESLATEMODE 0x2003
#else
#define ORION_SM_CONVERTIBLESLATEMODE SM_CONVERTIBLESLATEMODE
#endif
#endif

namespace {
QString channelQualityKey(const QString &channel)
{
    return channel.trimmed().toLower();
}

#ifdef Q_OS_WIN
bool shouldLaunchWindowsTouchKeyboard()
{
    return GetSystemMetrics(ORION_SM_TABLETPC) != 0 || GetSystemMetrics(ORION_SM_CONVERTIBLESLATEMODE) == 0;
}

QString windowsTouchKeyboardPath()
{
    QStringList searchPaths;
    const QString commonProgramFiles = qEnvironmentVariable("CommonProgramFiles");
    const QString commonProgramFilesX86 = qEnvironmentVariable("CommonProgramFiles(x86)");

    if (!commonProgramFiles.isEmpty())
        searchPaths << QDir(commonProgramFiles).filePath("microsoft shared/ink");
    if (!commonProgramFilesX86.isEmpty())
        searchPaths << QDir(commonProgramFilesX86).filePath("microsoft shared/ink");

    searchPaths << QStringLiteral("C:/Program Files/Common Files/microsoft shared/ink")
                << QStringLiteral("C:/Program Files (x86)/Common Files/microsoft shared/ink");

    const QString tabTip = QStandardPaths::findExecutable(QStringLiteral("TabTip.exe"), searchPaths);
    if (!tabTip.isEmpty())
        return tabTip;

    return QStandardPaths::findExecutable(QStringLiteral("osk.exe"));
}
#endif
}

SettingsManager::SettingsManager(QObject *parent) :
    QObject(parent), settings(QCoreApplication::organizationName(), QCoreApplication::applicationName(), this)
{
    load();
    //Connections
    connect(HttpServer::getInstance(), &HttpServer::codeReceived, this, &SettingsManager::setAccessToken);
}

SettingsManager *SettingsManager::getInstance()
{
    static SettingsManager instance;
    return &instance;
}

void SettingsManager::syncSettings(const char *context)
{
    settings.sync();
    if (settings.status() != QSettings::NoError) {
        qWarning() << context << "settings sync failed with status" << settings.status();
    }
}

void SettingsManager::load()
{
    //Load values from settings, notifying changes as needed
    setAlert(settings.value("alert", mAlert).toBool());
    setAlertPosition(settings.value("alertPosition", mAlertPosition).toInt());
    setAlertScreen(settings.value("alertScreen", mAlertScreen).toInt());
    setMultipleInstances(settings.value("multipleInstances", mMultipleInstances).toBool());
    setMinimizeOnStartup(settings.value("minimizeOnStartup", mMinimizeOnStartup).toBool());
    QString savedOpengl = settings.value("opengl", mOpengl).toString();
#ifdef Q_OS_WIN
    if (savedOpengl == "angle (d3d9)") {
        savedOpengl = mOpengl;
        settings.setValue("opengl", savedOpengl);
    }
#endif
    setOpengl(savedOpengl);
    setQuality(settings.value("quality", mQuality).toString());
    setRememberChannelQuality(settings.value("rememberChannelQuality", mRememberChannelQuality).toBool());
    setLowLatencyPlayback(settings.value("lowLatencyPlayback", mLowLatencyPlayback).toBool());
    setVodCacheMaxAgeHours(settings.value("vodCacheMaxAgeHours", mVodCacheMaxAgeHours).toInt());
    const QString savedDecoder = settings.value("decoder", mDecoder).toString();
    setDecoder(savedDecoder == "auto" ? mDecoder : savedDecoder);
    setAudioCompressor(settings.value("audioCompressor", mAudioCompressor).toBool());
    setBackend(settings.value("backend", mBackend).toString());
    setVolumeLevel(settings.value("volumeLevel", mVolumeLevel).toInt());
    setChatEdge(settings.value("chatEdge", mChatEdge).toInt());
    setTextScaleFactor(settings.value("textScaleFactor", mTextScaleFactor).toDouble());
    setOfflineNotifications(settings.value("offlineNotifications", mOfflineNotifications).toBool());
    setChatNotifications(settings.value("chatNotifications", mChatNotifications).toBool());
    setAutoRaidRedirect(settings.value("autoRaidRedirect", mAutoRaidRedirect).toBool());
    setLightTheme(settings.value("lightTheme", mLightTheme).toBool());
    setAccessToken(settings.value("accessToken", mAccessToken).toString());
    setFont(settings.value("font", mFont).toString());
    setKeepOnTop(settings.value("keepOnTop", mKeepOnTop).toBool());
    setPastelColors(settings.value("pastelColors", mPastelColors).toBool());
    setCompactNavigation(settings.value("compactNavigation", mCompactNavigation).toBool());
    setSideNavigation(settings.value("sideNavigation", mSideNavigation).toBool());
    setClickTogglePause(settings.value("clickTogglePause", mClickTogglePause).toBool());
    setInhibitScreensaver(settings.value("inhibitScreensaver", mInhibitScreensaver).toBool());
    setChatBlacklist(settings.value("chatBlacklist", mChatBlacklist).toString());
    setChatHighlightUsers(settings.value("chatHighlightUsers", mChatHighlightUsers).toString());
    setChatOpacity(settings.value("chatOpacity", mChatOpacity).toDouble());
}

bool SettingsManager::alert() const
{
    return mAlert;
}

void SettingsManager::setAlert(bool alert)
{
    if (mAlert != alert) {
        mAlert = alert;
        settings.setValue("alert", alert);
        emit alertChanged();
        qDebug() << "alert changed to" << alert;
    }
}

bool SettingsManager::multipleInstances() const
{
    return mMultipleInstances;
}

void SettingsManager::setMultipleInstances(bool multipleInstances)
{
    if (mMultipleInstances != multipleInstances) {
        mMultipleInstances = multipleInstances;
        settings.setValue("multipleInstances", multipleInstances);
        emit multipleInstancesChanged();
        qDebug() << "multipleInstances changed to" << multipleInstances;
    }
}

int SettingsManager::alertPosition() const
{
    return mAlertPosition;
}

void SettingsManager::setAlertPosition(int alertPosition)
{
    const int normalizedPosition = qMax(0, qMin(alertPosition, 3));
    if (normalizedPosition != mAlertPosition) {
        mAlertPosition = normalizedPosition;
        settings.setValue("alertPosition", normalizedPosition);
        emit alertPositionChanged();
        qDebug() << "alertPosition changed to" << normalizedPosition;
    }
}

int SettingsManager::alertScreen() const
{
    return mAlertScreen;
}

void SettingsManager::setAlertScreen(int alertScreen)
{
    const int screenCount = QGuiApplication::screens().count();
    const int maxScreen = screenCount > 0 ? screenCount - 1 : 0;
    const int normalizedScreen = qMax(0, qMin(alertScreen, maxScreen));

    if (normalizedScreen != mAlertScreen) {
        mAlertScreen = normalizedScreen;
        settings.setValue("alertScreen", normalizedScreen);
        emit alertScreenChanged();
        qDebug() << "alertScreen changed to" << normalizedScreen;
    }
}

int SettingsManager::volumeLevel() const
{
    return mVolumeLevel;
}

void SettingsManager::setVolumeLevel(int volumeLevel)
{
    if (mVolumeLevel != volumeLevel) {
        mVolumeLevel = volumeLevel;
        settings.setValue("volumeLevel", volumeLevel);
        emit volumeLevelChanged();
        qDebug() << "volumeLevel changed to" << volumeLevel;
    }
}

bool SettingsManager::minimizeOnStartup() const
{
#ifdef Q_OS_ANDROID
    return false;
#else
    return mMinimizeOnStartup;
#endif
}

void SettingsManager::setMinimizeOnStartup(bool minimizeOnStartup)
{
    if (mMinimizeOnStartup != minimizeOnStartup) {
        mMinimizeOnStartup = minimizeOnStartup;
        settings.setValue("minimizeOnStartup", minimizeOnStartup);
        emit minimizeOnStartupChanged();
        qDebug() << "minimizeOnStartup changed to" << minimizeOnStartup;
    }
}

int SettingsManager::chatEdge() const
{
#ifdef Q_OS_ANDROID
    return 2; // bottom
#else
    return mChatEdge;
#endif
}

void SettingsManager::setChatEdge(int chatEdge)
{
    if (mChatEdge != chatEdge) {
        mChatEdge = chatEdge;
        settings.setValue("chatEdge", chatEdge);
        emit chatEdgeChanged();
        qDebug() << "chatEdge changed to" << chatEdge;
    }
}

bool SettingsManager::offlineNotifications() const
{
    return mOfflineNotifications;
}

void SettingsManager::setOfflineNotifications(bool offlineNotifications)
{
    if (mOfflineNotifications != offlineNotifications) {
        mOfflineNotifications = offlineNotifications;
        settings.setValue("offlineNotifications", offlineNotifications);
        emit offlineNotificationsChanged();
        qDebug() << "offlineNotifications changed to" << offlineNotifications;
    }
}

bool SettingsManager::chatNotifications() const
{
    return mChatNotifications;
}

void SettingsManager::setChatNotifications(bool chatNotifications)
{
    if (mChatNotifications != chatNotifications) {
        mChatNotifications = chatNotifications;
        settings.setValue("chatNotifications", chatNotifications);
        emit chatNotificationsChanged();
        qDebug() << "chatNotifications changed to" << chatNotifications;
    }
}

bool SettingsManager::autoRaidRedirect() const
{
    return mAutoRaidRedirect;
}

void SettingsManager::setAutoRaidRedirect(bool autoRaidRedirect)
{
    if (mAutoRaidRedirect != autoRaidRedirect) {
        mAutoRaidRedirect = autoRaidRedirect;
        settings.setValue("autoRaidRedirect", autoRaidRedirect);
        emit autoRaidRedirectChanged();
    }
}

double SettingsManager::textScaleFactor() const
{
    return mTextScaleFactor;
}

void SettingsManager::setTextScaleFactor(double textScaleFactor)
{
    //Validate min/max
    if (textScaleFactor < 0.5 || textScaleFactor > 3.0)
        return;

    if (mTextScaleFactor != textScaleFactor) {
        mTextScaleFactor = textScaleFactor;
        settings.setValue("textScaleFactor", textScaleFactor);
        emit textScaleFactorChanged();
        qDebug() << "textScaleFactor changed to" << textScaleFactor;
    }
}

QString SettingsManager::opengl() const
{
    return mOpengl;
}

void SettingsManager::setOpengl(const QString &opengl)
{
    if (mOpengl != opengl) {
        mOpengl = opengl;
        settings.setValue("opengl", opengl);
        emit openglChanged();
        qDebug() << "opengl changed to" << opengl;
    }
}

QString SettingsManager::quality() const
{
    return mQuality;
}

void SettingsManager::setQuality(const QString &quality)
{
    if (mQuality != quality) {
        mQuality = quality;
        settings.setValue("quality", quality);
        syncSettings("stream quality");
        emit qualityChanged();
    }
}

bool SettingsManager::rememberChannelQuality() const
{
    return mRememberChannelQuality;
}

void SettingsManager::setRememberChannelQuality(bool rememberChannelQuality)
{
    if (mRememberChannelQuality != rememberChannelQuality) {
        mRememberChannelQuality = rememberChannelQuality;
        settings.setValue("rememberChannelQuality", rememberChannelQuality);
        syncSettings("remember channel quality");
        emit rememberChannelQualityChanged();
    }
}

bool SettingsManager::lowLatencyPlayback() const
{
    return mLowLatencyPlayback;
}

void SettingsManager::setLowLatencyPlayback(bool lowLatencyPlayback)
{
    if (mLowLatencyPlayback != lowLatencyPlayback) {
        mLowLatencyPlayback = lowLatencyPlayback;
        settings.setValue("lowLatencyPlayback", lowLatencyPlayback);
        emit lowLatencyPlaybackChanged();
    }
}

int SettingsManager::vodCacheMaxAgeHours() const
{
    return mVodCacheMaxAgeHours;
}

void SettingsManager::setVodCacheMaxAgeHours(int vodCacheMaxAgeHours)
{
    const int normalizedHours = qMax(0, qMin(vodCacheMaxAgeHours, 24 * 30));
    if (mVodCacheMaxAgeHours != normalizedHours) {
        mVodCacheMaxAgeHours = normalizedHours;
        settings.setValue("vodCacheMaxAgeHours", normalizedHours);
        emit vodCacheMaxAgeHoursChanged();
    }
}

QString SettingsManager::channelQuality(const QString &channel)
{
    const QString key = channelQualityKey(channel);
    if (key.isEmpty()) {
        return "";
    }

    settings.beginGroup("channelQualities");
    const QString quality = settings.value(key).toString();
    settings.endGroup();
    return quality;
}

void SettingsManager::setChannelQuality(const QString &channel, const QString &quality)
{
    const QString key = channelQualityKey(channel);
    if (key.isEmpty()) {
        return;
    }

    settings.beginGroup("channelQualities");
    settings.setValue(key, quality);
    settings.endGroup();
    syncSettings("channel quality");
}

QString SettingsManager::decoder() const
{
    return mDecoder;
}

void SettingsManager::setDecoder(const QString &decoder)
{
    if (mDecoder != decoder) {
        mDecoder = decoder;
        settings.setValue("decoder", decoder);
        emit decoderChanged();
    }
}

bool SettingsManager::audioCompressor() const
{
    return mAudioCompressor;
}

void SettingsManager::setAudioCompressor(bool audioCompressor)
{
    if (mAudioCompressor != audioCompressor) {
        mAudioCompressor = audioCompressor;
        settings.setValue("audioCompressor", audioCompressor);
        emit audioCompressorChanged();
    }
}

QString SettingsManager::backend() const
{
    return mBackend;
}

void SettingsManager::setBackend(const QString &backend)
{
    const bool validBackend = mBackends.contains(backend);
    const QString selectedBackend = validBackend ? backend : mBackends.first();

    if (mBackend != selectedBackend || !validBackend) {
        const bool changed = mBackend != selectedBackend;
        mBackend = selectedBackend;
        settings.setValue("backend", selectedBackend);
        if (!validBackend) {
            qWarning() << "Ignoring unavailable player backend" << backend << "and using" << selectedBackend;
        }
        if (changed) {
            emit backendChanged();
        }
    }
}

QStringList SettingsManager::backends() const
{
    return mBackends;
}

void SettingsManager::markBackendUnavailable(const QString &backend)
{
    if (!mBackends.contains(backend)) {
        return;
    }

    if (mBackends.size() <= 1) {
        qWarning() << "Player backend" << backend << "failed to load and no fallback backend is available";
        return;
    }

    mBackends.removeAll(backend);
    qWarning() << "Player backend" << backend << "failed to load; falling back to available backend list" << mBackends;

    if (mBackend == backend) {
        setBackend(mBackends.first());
    }
    emit backendsChanged();
}

QString SettingsManager::accessToken() const
{
    return mAccessToken;
}

void SettingsManager::setAccessToken(const QString accessToken)
{
    if (mAccessToken != accessToken) {
        mAccessToken = accessToken;
        settings.setValue("accessToken", accessToken);
        syncSettings("access token");
        emit accessTokenChanged(accessToken);
        qDebug() << "accessToken changed!";
    }
}

bool SettingsManager::hasAccessToken() const
{
    return !mAccessToken.isEmpty();
}

bool SettingsManager::hiDpi() const {
    return mHiDpi;
}

void SettingsManager::setHiDpi(bool dpi)
{
    mHiDpi = dpi;
    qDebug() << "hiDpi" << mHiDpi;
}

bool SettingsManager::lightTheme() const
{
    return mLightTheme;
}

void SettingsManager::setLightTheme(bool lightTheme)
{
    if (mLightTheme != lightTheme) {
        mLightTheme = lightTheme;
        settings.setValue("lightTheme", lightTheme);
        emit lightThemeChanged();
        qDebug() << "theme changed!";
    }
}

bool SettingsManager::pastelColors() const
{
    return mPastelColors;
}

void SettingsManager::setPastelColors(bool pastelColors)
{
    if (mPastelColors != pastelColors) {
        mPastelColors = pastelColors;
        settings.setValue("pastelColors", pastelColors);
        emit pastelColorsChanged();
    }
}

bool SettingsManager::compactNavigation() const
{
    return mCompactNavigation;
}

void SettingsManager::setCompactNavigation(bool compactNavigation)
{
    if (mCompactNavigation != compactNavigation) {
        mCompactNavigation = compactNavigation;
        settings.setValue("compactNavigation", compactNavigation);
        emit compactNavigationChanged();
    }
}

bool SettingsManager::sideNavigation() const
{
    return mSideNavigation;
}

void SettingsManager::setSideNavigation(bool sideNavigation)
{
    if (mSideNavigation != sideNavigation) {
        mSideNavigation = sideNavigation;
        settings.setValue("sideNavigation", sideNavigation);
        emit sideNavigationChanged();
    }
}

bool SettingsManager::clickTogglePause() const
{
    return mClickTogglePause;
}

void SettingsManager::setClickTogglePause(bool clickTogglePause)
{
    if (mClickTogglePause != clickTogglePause) {
        mClickTogglePause = clickTogglePause;
        settings.setValue("clickTogglePause", clickTogglePause);
        emit clickTogglePauseChanged();
    }
}

bool SettingsManager::inhibitScreensaver() const
{
    return mInhibitScreensaver;
}

void SettingsManager::setInhibitScreensaver(bool inhibitScreensaver)
{
    if (mInhibitScreensaver != inhibitScreensaver) {
        mInhibitScreensaver = inhibitScreensaver;
        settings.setValue("inhibitScreensaver", inhibitScreensaver);
        emit inhibitScreensaverChanged();
    }
}

bool SettingsManager::autoScrollSmoothing() const
{
    return mAutoScrollSmoothing;
}

void SettingsManager::setAutoScrollSmoothing(bool autoScrollSmoothing)
{
    if (mAutoScrollSmoothing != autoScrollSmoothing) {
        mAutoScrollSmoothing = autoScrollSmoothing;
        settings.setValue("autoScrollSmoothing", autoScrollSmoothing);
        emit autoScrollSmoothingChanged();
    }
}

QString SettingsManager::chatBlacklist() const
{
    return mChatBlacklist;
}

void SettingsManager::setChatBlacklist(const QString &chatBlacklist)
{
    if (mChatBlacklist != chatBlacklist) {
        mChatBlacklist = chatBlacklist;
        settings.setValue("chatBlacklist", chatBlacklist);
        syncSettings("chat blacklist");
        emit chatBlacklistChanged();
    }
}

QString SettingsManager::chatHighlightUsers() const
{
    return mChatHighlightUsers;
}

void SettingsManager::setChatHighlightUsers(const QString &chatHighlightUsers)
{
    if (mChatHighlightUsers != chatHighlightUsers) {
        mChatHighlightUsers = chatHighlightUsers;
        settings.setValue("chatHighlightUsers", chatHighlightUsers);
        syncSettings("chat highlight users");
        emit chatHighlightUsersChanged();
    }
}

double SettingsManager::chatOpacity() const
{
    return mChatOpacity;
}

void SettingsManager::setChatOpacity(double chatOpacity)
{
    if (chatOpacity < 0.0 || chatOpacity > 1.0) {
        return;
    }

    if (mChatOpacity != chatOpacity) {
        mChatOpacity = chatOpacity;
        settings.setValue("chatOpacity", chatOpacity);
        emit chatOpacityChanged();
    }
}

void SettingsManager::copyToClipboard(const QString &text) const
{
    QClipboard *clipboard = QGuiApplication::clipboard();
    if (clipboard) {
        clipboard->setText(text);
    }
}

void SettingsManager::showVirtualKeyboard() const
{
    if (QGuiApplication::inputMethod())
        QGuiApplication::inputMethod()->show();

#ifdef Q_OS_WIN
    if (!shouldLaunchWindowsTouchKeyboard())
        return;

    const QString keyboard = windowsTouchKeyboardPath();
    if (!keyboard.isEmpty() && !QProcess::startDetached(keyboard, QStringList()))
        qWarning().noquote() << "Could not start Windows touch keyboard" << keyboard;
#endif
}

QStringList SettingsManager::screenNames() const
{
    QStringList names;
    const QList<QScreen *> screens = QGuiApplication::screens();

    for (int i = 0; i < screens.count(); ++i) {
        const QString name = screens.at(i)->name();
        names.append(name.isEmpty() ? QString("Screen %1").arg(i + 1) : name);
    }

    if (names.isEmpty())
        names.append("Primary screen");

    return names;
}

#include <QVersionNumber>
bool SettingsManager::isNewerVersion(QString version) const
{
    return QVersionNumber::fromString(version.replace('v',"")) > QVersionNumber::fromString(QString(APP_VERSION).replace('v', ""));
}

QString SettingsManager::font() const
{
    return mFont;
}

void SettingsManager::setFont(const QString &font)
{
    if (mFont != font) {
        mFont = font;
        settings.setValue("font", font);
        emit fontChanged();
    }
}

bool SettingsManager::versionCheckEnabled()
{
#ifdef VERSION_CHECK_ENABLED
    return true;
#else
    return false;
#endif
}

bool SettingsManager::keepOnTop() const
{
    return mKeepOnTop;
}

void SettingsManager::setKeepOnTop(bool keepOnTop)
{
    if (mKeepOnTop != keepOnTop) {
        mKeepOnTop = keepOnTop;
        settings.setValue("keepOnTop", keepOnTop);
        emit keepOnTopChanged();
    }
}
