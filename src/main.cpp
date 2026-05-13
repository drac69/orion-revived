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

#include <QQmlApplicationEngine>
#include <QQmlError>
#include <QScreen>
#include <QQmlContext>
#include <QCommandLineParser>
#include <QNetworkProxyFactory>
#include <QFontDatabase>
#include <QIcon>
#include <QQuickWindow>
#include <QLockFile>
#include <QRegularExpression>
#include <QUrl>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>

#include <cstdlib>
#include <cstdio>
#include <iostream>

#include "model/channelmanager.h"
#include "network/networkmanager.h"
#include "model/vodmanager.h"
#include "model/ircchat.h"
#include "model/mprismanager.h"
#include "network/httpserver.h"
#include "model/viewersmodel.h"
#include "model/logbuffer.h"
#include "power/power.h"

#ifndef Q_OS_ANDROID
#include <QApplication>
#include "notification/notificationmanager.h"
#else
#include <QGuiApplication>
#endif

#ifdef MPV_PLAYER
#include "player/mpvobject.h"
#endif

#ifdef SYSTEMD_JOURNAL
#include <systemd/sd-journal.h>
#endif

#ifdef Q_OS_WIN
#include <io.h>
#include <fcntl.h>
#pragma comment(lib, "User32.lib")
#endif

void configureHighDpiScaling()
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    if (!qEnvironmentVariableIsSet("QT_ENABLE_HIGHDPI_SCALING")
            || qEnvironmentVariableIntValue("QT_ENABLE_HIGHDPI_SCALING") != 0) {
        QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    }
    QCoreApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);
#endif
}

void registerBundledFont(const QString &path)
{
    const int fontId = QFontDatabase::addApplicationFont(path);
    if (fontId < 0) {
        qWarning().noquote() << "Could not load bundled font" << path;
    }
}

void registerBundledFonts()
{
    registerBundledFont(":/fonts/MaterialIcons-Regular.ttf");
    registerBundledFont(":/fonts/NotoSans-Regular.ttf");
}

QString singleInstanceLockPath()
{
    QString basePath = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (basePath.isEmpty()) {
        basePath = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    }
    if (basePath.isEmpty()) {
        basePath = QDir::tempPath();
    }

    QDir baseDir(basePath);
    const QString lockDirName = QCoreApplication::organizationName()
            + "/" + QCoreApplication::applicationName();
    if (!baseDir.mkpath(lockDirName)) {
        qWarning().noquote() << "Could not create lock directory under" << basePath
                             << "- using temp directory";
        return QDir::temp().absoluteFilePath("orion.lock");
    }

    return baseDir.absoluteFilePath(lockDirName + "/orion.lock");
}

QString normalizedStartupChannel(QString value)
{
    value = value.trimmed();
    if (value.isEmpty()) {
        return value;
    }

    const QUrl url = QUrl::fromUserInput(value);
    if (url.isValid() && !url.host().isEmpty()) {
        const QString host = url.host().toLower();
        if (host == "twitch.tv" || host == "www.twitch.tv") {
            const QStringList parts = url.path().split('/', Qt::SkipEmptyParts);
            if (!parts.isEmpty()) {
                value = parts.first();
            }
        }
    }

    value.remove(QRegularExpression("^[#@/]+"));
    value.remove(QRegularExpression("[/?#].*$"));
    return value.trimmed();
}

QString normalizedLocalFilePath(QString value)
{
    value = value.trimmed();
    if (value.isEmpty()) {
        return value;
    }
    if (value == "~") {
        value = QDir::homePath();
    } else if (value.startsWith("~/") || value.startsWith("~\\")) {
        value = QDir::homePath() + value.mid(1);
    }

    return QFileInfo(value).absoluteFilePath();
}

#ifdef Q_OS_WIN
void showConsole() {
    if (GetConsoleWindow()) { return; }
    AllocConsole();
    HWND hwnd = GetConsoleWindow();
    LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);
    SetWindowLongPtr(hwnd, GWL_STYLE, style & ~WS_SYSMENU);

    static FILE *instream = nullptr, *outstream = nullptr, *outerrstream = nullptr;
    std::atexit([](){
        if (instream) {
            fclose(instream);
            instream = nullptr;
        }
        if (outstream) {
            fclose(outstream);
            outstream = nullptr;
        }
        if (GetConsoleWindow()) {
            FreeConsole();
        }
    });
    freopen_s(&instream, "CONIN$", "r", stdin);
    freopen_s(&outstream, "CONOUT$", "w+", stdout);
    freopen_s(&outerrstream, "CONOUT$", "w+", stderr);

    std::ios::sync_with_stdio();

    CONSOLE_SCREEN_BUFFER_INFO coninfo = {};
    GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &coninfo);
    static const WORD MAX_CONSOLE_LINES = 8192;
    static const WORD CONSOLE_WIDTH = 256;
    coninfo.dwSize.Y = MAX_CONSOLE_LINES;
    coninfo.dwSize.X = CONSOLE_WIDTH;
    SetConsoleScreenBufferSize(GetStdHandle(STD_OUTPUT_HANDLE), coninfo.dwSize);

    SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE | FOREGROUND_INTENSITY);
    SetConsoleTextAttribute(GetStdHandle(STD_ERROR_HANDLE), FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE | FOREGROUND_INTENSITY);

    CONSOLE_FONT_INFOEX info = {};
    info.cbSize = sizeof(info);
    info.dwFontSize.Y = 14;
    info.FontWeight = FW_NORMAL;
    wcscpy_s(info.FaceName, L"Consolas");
    SetCurrentConsoleFontEx(GetStdHandle(STD_OUTPUT_HANDLE), NULL, &info);
    SetCurrentConsoleFontEx(GetStdHandle(STD_ERROR_HANDLE), NULL, &info);
    SetConsoleOutputCP(CP_UTF8);
}
#endif

enum class LogLevel {
    Debug = 0,
    Info,
    Warning,
    Critical,
    Fatal,
    Off
};

struct LogConfig {
    LogLevel minLevel = LogLevel::Warning;
    bool console = true;
    bool journal = false;
    FILE *file = nullptr;
};

LogConfig logConfig;

LogLevel messageLogLevel(QtMsgType type)
{
    switch (type) {
    case QtDebugMsg:
        return LogLevel::Debug;
    case QtInfoMsg:
        return LogLevel::Info;
    case QtWarningMsg:
        return LogLevel::Warning;
    case QtCriticalMsg:
        return LogLevel::Critical;
    case QtFatalMsg:
        return LogLevel::Fatal;
    }

    return LogLevel::Warning;
}

QString messageLogLevelName(QtMsgType type)
{
    switch (type) {
    case QtDebugMsg:
        return "Debug";
    case QtInfoMsg:
        return "Info";
    case QtWarningMsg:
        return "Warning";
    case QtCriticalMsg:
        return "Critical";
    case QtFatalMsg:
        return "Fatal";
    }

    return "Log";
}

int journalPriority(QtMsgType type)
{
    switch (type) {
    case QtDebugMsg:
        return 7;
    case QtInfoMsg:
        return 6;
    case QtWarningMsg:
        return 4;
    case QtCriticalMsg:
        return 3;
    case QtFatalMsg:
        return 2;
    }

    return 4;
}

bool parseLogLevel(const QString &value, LogLevel &level)
{
    const QString normalized = value.trimmed().toLower();
    if (normalized == "debug") {
        level = LogLevel::Debug;
    } else if (normalized == "info") {
        level = LogLevel::Info;
    } else if (normalized == "warning" || normalized == "warn") {
        level = LogLevel::Warning;
    } else if (normalized == "critical" || normalized == "error") {
        level = LogLevel::Critical;
    } else if (normalized == "fatal") {
        level = LogLevel::Fatal;
    } else if (normalized == "off" || normalized == "none") {
        level = LogLevel::Off;
    } else {
        return false;
    }

    return true;
}

QString logContextText(const QMessageLogContext &context)
{
    if (!context.file) {
        return "";
    }

    return QString(" (%1:%2, %3)")
            .arg(QString::fromLocal8Bit(context.file))
            .arg(context.line)
            .arg(context.function ? QString::fromLocal8Bit(context.function) : QString());
}

QByteArray formatLogLine(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    return QString("%1 %2: %3%4\n")
            .arg(QDateTime::currentDateTime().toString(Qt::ISODate))
            .arg(messageLogLevelName(type))
            .arg(msg)
            .arg(logContextText(context))
            .toLocal8Bit();
}

void closeLogFile()
{
    if (logConfig.file) {
        fclose(logConfig.file);
        logConfig.file = nullptr;
    }
}

void msgHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    if (messageLogLevel(type) < logConfig.minLevel || logConfig.minLevel == LogLevel::Off) {
        return;
    }

    const QByteArray line = formatLogLine(type, context, msg);
    LogBuffer::getInstance()->appendLine(QString::fromLocal8Bit(line.constData(), line.size()));

    if (logConfig.console) {
        FILE *stream = messageLogLevel(type) >= LogLevel::Warning ? stderr : stdout;
        fputs(line.constData(), stream);
        fflush(stream);
    }

    if (logConfig.file) {
        fputs(line.constData(), logConfig.file);
        fflush(logConfig.file);
    }

#ifdef SYSTEMD_JOURNAL
    if (logConfig.journal) {
        const QByteArray journalMsg = msg.toLocal8Bit();
        sd_journal_send("MESSAGE=%s", journalMsg.constData(),
                        "PRIORITY=%i", journalPriority(type),
                        "SYSLOG_IDENTIFIER=orion",
                        "CODE_FILE=%s", context.file ? context.file : "",
                        "CODE_LINE=%i", context.line,
                        "CODE_FUNC=%s", context.function ? context.function : "",
                        NULL);
    }
#endif
}


void registerQmlComponents(QObject *parent)
{
    qmlRegisterSingletonType<ChannelManager>("app.orion", 1, 0, "ChannelManager", &ChannelManager::provider);
    qmlRegisterSingletonType<BadgeContainer>("app.orion", 1, 0, "Emotes", &BadgeContainer::provider);
    qmlRegisterSingletonType<ViewersModel>("app.orion", 1, 0, "Viewers", &ViewersModel::provider);
    qmlRegisterSingletonType<LogBuffer>("app.orion", 1, 0, "LogBuffer", &LogBuffer::provider);
    qmlRegisterSingletonType<VodManager>("app.orion", 1, 0, "VodManager", &VodManager::provider);
    qmlRegisterSingletonType<MprisManager>("app.orion", 1, 0, "MprisManager", &MprisManager::provider);
    qmlRegisterSingletonType<SettingsManager>("app.orion", 1, 0, "Settings", &SettingsManager::provider);
    qmlRegisterSingletonType<HttpServer>("app.orion", 1, 0, "LoginService", &HttpServer::provider);
    qmlRegisterSingletonType<NetworkManager>("app.orion", 1, 0, "Network", &NetworkManager::provider);
    qmlRegisterSingletonType<Power>("app.orion", 1, 0, "PowerManager", &Power::provider);
    qmlRegisterType<IrcChat>("aldrog.twitchtube.ircchat", 1, 0, "IrcChat");

#ifdef MPV_PLAYER
    qmlRegisterType<MpvObject>("mpv", 1, 0, "MpvObject");
#endif

    //Setup obj parents for cleanup
    ChannelManager::getInstance()->setParent(parent);
    BadgeContainer::getInstance()->setParent(parent);
    ViewersModel::getInstance()->setParent(parent);
    LogBuffer::getInstance()->setParent(parent);
    VodManager::getInstance()->setParent(parent);
    MprisManager::getInstance()->setParent(parent);
    SettingsManager::getInstance()->setParent(parent);
    HttpServer::getInstance()->setParent(parent);
}

int main(int argc, char *argv[])
{
    qInstallMessageHandler(&msgHandler);
    QCoreApplication::setApplicationName("Orion");
    QCoreApplication::setOrganizationName("orion.application");
    QCoreApplication::setApplicationVersion(APP_VERSION);

    //Override QT_QUICK_CONTROLS_STYLE environment variable
    qputenv("QT_QUICK_CONTROLS_STYLE", "material");

    configureHighDpiScaling();

    auto opengl = SettingsManager::getInstance()->opengl().toLower();

    // OpenGL implementation used to render app.
    // Need to be set before constructing QGuiApplication
    // http://doc.qt.io/qt-5/qt.html#ApplicationAttribute-enum
    if (opengl.contains("desktop")) {
        QCoreApplication::setAttribute(Qt::AA_UseDesktopOpenGL);
    } else if(opengl.contains("software")) {
        QCoreApplication::setAttribute(Qt::AA_UseSoftwareOpenGL);
    } else {
        QCoreApplication::setAttribute(Qt::AA_UseOpenGLES);
#ifdef QT_OPENGL_DYNAMIC
        qputenv("QT_OPENGL", "angle");
#endif
#ifdef Q_OS_WIN
        if (opengl.contains("d3d11"))
            qputenv("QT_ANGLE_PLATFORM", "d3d11");
        else if (opengl.contains("d3d9"))
            qputenv("QT_ANGLE_PLATFORM", "d3d9");
        else if (opengl.contains("warp"))
            qputenv("QT_ANGLE_PLATFORM", "warp");
#endif
    }

#ifndef Q_OS_ANDROID
    QApplication app(argc, argv);
#else
    QGuiApplication app(argc, argv);
#endif

    const QIcon appIcon = QIcon(":/icon/orion.ico");
    app.setWindowIcon(appIcon);
    registerBundledFonts();

    QString startupChannel;
    QString mpvConfigFile;

#ifndef Q_OS_ANDROID
    QCommandLineParser parser;
    parser.setApplicationDescription("Twitch.tv client");
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption debugOption(QStringList() << "d" << "debug", "show debug output");
    parser.addOption(debugOption);

    QCommandLineOption channelOption(QStringList() << "c" << "channel",
                                     "open a Twitch channel on startup", "channel");
    parser.addOption(channelOption);
    parser.addPositionalArgument("channel", "Twitch channel name or twitch.tv URL to open on startup.");

#ifdef Q_OS_WIN
    QCommandLineOption noConsoleOption(QStringList() << "nc" << "no console", "don't open console in debug mode");
    parser.addOption(noConsoleOption);
#endif

    QCommandLineOption quietOption(QStringList() << "q" << "quiet", "disable console output");
    parser.addOption(quietOption);

    QCommandLineOption logLevelOption(QStringList() << "log-level",
                                      "set log level: debug, info, warning, critical, fatal, off",
                                      "level");
    parser.addOption(logLevelOption);

    QCommandLineOption logFileOption(QStringList() << "log-file",
                                     "append log output to a file",
                                     "path");
    parser.addOption(logFileOption);

#ifdef MPV_PLAYER
    QCommandLineOption mpvConfigOption(QStringList() << "libmpv-config" << "mpv-config",
                                       "load an mpv config file for the libmpv backend",
                                       "path");
    parser.addOption(mpvConfigOption);
#endif

#ifdef Q_OS_LINUX
    QCommandLineOption journalOption(QStringList() << "journal",
                                     "send log output to the systemd journal when supported by this build");
    parser.addOption(journalOption);
#endif

    parser.process(QCoreApplication::arguments());

    if (parser.isSet(channelOption)) {
        startupChannel = normalizedStartupChannel(parser.value(channelOption));
    } else if (!parser.positionalArguments().isEmpty()) {
        startupChannel = normalizedStartupChannel(parser.positionalArguments().first());
    }

#ifdef MPV_PLAYER
    if (parser.isSet(mpvConfigOption)) {
        mpvConfigFile = normalizedLocalFilePath(parser.value(mpvConfigOption));
    }
#endif

    LogLevel minLogLevel = LogLevel::Warning;
    if (parser.isSet(debugOption)) {
        minLogLevel = LogLevel::Debug;
    }
    if (parser.isSet(logLevelOption) && !parseLogLevel(parser.value(logLevelOption), minLogLevel)) {
        qWarning().noquote() << "Invalid log level" << parser.value(logLevelOption) << "- using warning";
        minLogLevel = LogLevel::Warning;
    }

    logConfig.minLevel = minLogLevel;
    logConfig.console = !parser.isSet(quietOption);

#ifdef Q_OS_LINUX
    logConfig.journal = parser.isSet(journalOption);
#ifndef SYSTEMD_JOURNAL
    if (logConfig.journal) {
        qWarning() << "--journal requested but this build was compiled without systemd journal support";
        logConfig.journal = false;
    }
#endif
#endif

    if (parser.isSet(logFileOption)) {
        const QString path = parser.value(logFileOption);
        const QByteArray pathBytes = path.toLocal8Bit();
        logConfig.file = fopen(pathBytes.constData(), "a");
        if (logConfig.file) {
            std::atexit(closeLogFile);
        } else {
            qWarning().noquote() << "Could not open log file" << path;
        }
    }

#ifdef MPV_PLAYER
    if (!mpvConfigFile.isEmpty()) {
        MpvObject::setConfigFile(mpvConfigFile);
    }
#endif

#ifdef Q_OS_WIN
    if (logConfig.console && (parser.isSet(debugOption) || logConfig.minLevel <= LogLevel::Info)) {
        // windows doesn't pass message strings to normal console, so open our own when -d is enabled
        if (!parser.isSet(noConsoleOption)) {
            showConsole();
        }
    }
#endif
#endif

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError> &warnings) {
        for (const QQmlError &warning : warnings) {
            qCritical().noquote() << warning.toString();
        }
    });

    //Prime network manager
    QNetworkProxyFactory::setUseSystemConfiguration(true);
    NetworkManager::initialize(engine.networkAccessManager());

#ifndef Q_OS_ANDROID
    // detect hi dpi screens
    qDebug() << "Screens:";
    int screens = 0;
    qreal maxDevicePixelRatio = QGuiApplication::primaryScreen()->devicePixelRatio();
    for (const auto & screen : QGuiApplication::screens()) {
        qreal curPixelRatio = screen->devicePixelRatio();
        maxDevicePixelRatio = qMax(maxDevicePixelRatio, curPixelRatio);
        screens++;
        qDebug() << "  Screen #" << screens << screen->name() << ": devicePixelRatio" << curPixelRatio;
    }
    qDebug() << "maxDevicePixelRatio" << maxDevicePixelRatio;

    SettingsManager::getInstance()->setHiDpi(maxDevicePixelRatio > 1.0);

    //Set up notifications
    NotificationManager *notificationManager = new NotificationManager(&engine, engine.networkAccessManager(), &app);
    QObject::connect(ChannelManager::getInstance(), &ChannelManager::pushNotification, notificationManager, &NotificationManager::pushNotification);
#endif

    QQmlContext *rootContext = engine.rootContext();
    rootContext->setContextProperty("g_favourites", ChannelManager::getInstance()->getFavouritesProxy());
    rootContext->setContextProperty("g_results", ChannelManager::getInstance()->getResultsModel());
    rootContext->setContextProperty("g_games", ChannelManager::getInstance()->getGamesModel());
    rootContext->setContextProperty("vodsModel", VodManager::getInstance()->getModel());
    rootContext->setContextProperty("g_startupChannel", startupChannel);
    
    
#ifndef Q_OS_ANDROID
    //Single application solution
    const QString lockPath = singleInstanceLockPath();
    QLockFile lockfile(lockPath);
    const bool primaryInstance = lockfile.tryLock(100);
    if (!primaryInstance && !SettingsManager::getInstance()->multipleInstances()) {
        qWarning().noquote() << "Another Orion instance is already running;"
                             << "enable multiple instances in settings to allow this."
                             << "Lock file:" << lockPath;
        return 0;
    }
    rootContext->setContextProperty("g_instance", primaryInstance ? "main" : "child");
#else
    rootContext->setContextProperty("g_instance", "main");
#endif

    // Register qml components
    registerQmlComponents(&app);

    // Load QML content
    engine.load(QUrl("qrc:/main.qml"));
#ifndef Q_OS_ANDROID
    // Get QML root window, add connections
    QQuickWindow *rootWin = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!rootWin) {
#ifdef Q_OS_WIN
        if (GetConsoleWindow())
            std::cin.ignore();
#endif
        qFatal("Main window was not opened. Check the QML errors above for missing modules or startup failures.");
        return -1;
    }
#endif

    // first check
    ChannelManager::getInstance()->checkFavourites();

    // Start
    return app.exec();
}
