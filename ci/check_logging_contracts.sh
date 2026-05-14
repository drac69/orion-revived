#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
main_cpp="$repo_dir/src/main.cpp"
logbuffer_header="$repo_dir/src/model/logbuffer.h"
logbuffer_source="$repo_dir/src/model/logbuffer.cpp"
options_view="$repo_dir/src/qml/OptionsView.qml"
project_file="$repo_dir/orion.pro"
install_deps="$repo_dir/ci/install_ubuntu_ci_deps.sh"
workflow="$repo_dir/.github/workflows/ci.yml"
container_ci="$repo_dir/ci/check_ubuntu_container_ci.sh"
readme="$repo_dir/README.md"

for required in \
    'enum class LogLevel' \
    'struct LogConfig' \
    'LogLevel stdoutLevel = LogLevel::Warning;' \
    'LogLevel stderrLevel = LogLevel::Warning;' \
    'LogLevel fileLevel = LogLevel::Warning;' \
    'LogLevel journalLevel = LogLevel::Off;' \
    'LogLevel bufferLevel = LogLevel::Warning;' \
    'bool parseLogLevel(const QString &value, LogLevel &level)' \
    'bool shouldLogToSink(LogLevel messageLevel, LogLevel sinkLevel)' \
    'QByteArray formatLogLine(QtMsgType type, const QMessageLogContext &context, const QString &msg)' \
    'void msgHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)' \
    'qInstallMessageHandler(&msgHandler);'
do
    if ! rg -q -F "$required" "$main_cpp"; then
        printf 'main.cpp must keep the structured logging core token: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'LogBuffer::getInstance()->appendLine(QString::fromLocal8Bit(line.constData(), line.size()));' \
    'fputs(line.constData(), stdout);' \
    'fflush(stdout);' \
    'fputs(line.constData(), stderr);' \
    'fflush(stderr);' \
    'fputs(line.constData(), logConfig.file);' \
    'fflush(logConfig.file);' \
    'std::atexit(closeLogFile);'
do
    if ! rg -q -F "$required" "$main_cpp"; then
        printf 'Logging sinks must keep buffer/stdout/stderr/file output behavior: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'QCommandLineOption logLevelOption' \
    '"log-level"' \
    'QCommandLineOption stdoutLogLevelOption' \
    '"stdout-log-level"' \
    'QCommandLineOption stderrLogLevelOption' \
    '"stderr-log-level"' \
    'QCommandLineOption logFileOption' \
    '"log-file"' \
    'QCommandLineOption fileLogLevelOption' \
    '"file-log-level"' \
    'parser.isSet(quietOption)' \
    'logConfig.stdoutLevel = LogLevel::Off;' \
    'logConfig.stderrLevel = LogLevel::Off;'
do
    if ! rg -q -F "$required" "$main_cpp"; then
        printf 'Logging command-line controls are missing token: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'QCommandLineOption journalOption' \
    '"journal"' \
    'QCommandLineOption journalLogLevelOption' \
    '"journal-log-level"' \
    'sd_journal_send("MESSAGE=%s", journalMsg.constData(),' \
    '"SYSLOG_IDENTIFIER=orion"' \
    'qWarning() << "--journal requested but this build was compiled without systemd journal support";'
do
    if ! rg -q -F "$required" "$main_cpp"; then
        printf 'Linux journal logging contract is missing token: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'packagesExist(libsystemd)' \
    'PKGCONFIG += libsystemd' \
    'DEFINES += SYSTEMD_JOURNAL'
do
    if ! rg -q -F "$required" "$project_file"; then
        printf 'orion.pro must keep optional libsystemd journal wiring: %s\n' "$required" >&2
        exit 1
    fi
done

if ! rg -q -F 'libsystemd-dev' "$install_deps"; then
    printf 'Ubuntu CI dependencies must include libsystemd-dev for journal-enabled builds.\n' >&2
    exit 1
fi

for required in \
    'Q_PROPERTY(QString text READ text NOTIFY textChanged)' \
    'void appendLine(const QString &line);' \
    'Q_INVOKABLE void clear();' \
    'QMutex mMutex;' \
    'int mMaxLines = 500;'
do
    if ! rg -q -F "$required" "$logbuffer_header"; then
        printf 'LogBuffer must keep bounded QML-visible recent-log state: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'QMutexLocker locker(&mMutex);' \
    'mLines.append(trimmedLine);' \
    'while (mLines.size() > mMaxLines)' \
    'mLines.removeFirst();' \
    'emit textChanged();'
do
    if ! rg -q -F "$required" "$logbuffer_source"; then
        printf 'LogBuffer must keep thread-safe bounded append/clear behavior: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'qmlRegisterSingletonType<LogBuffer>("app.orion", 1, 0, "LogBuffer", &LogBuffer::provider);' \
    'LogBuffer::getInstance()->setParent(parent);'
do
    if ! rg -q -F "$required" "$main_cpp"; then
        printf 'LogBuffer must stay registered for QML use: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'title: "Logs"' \
    'text: LogBuffer.text' \
    'readOnly: true' \
    'selectByMouse: true' \
    'onClicked: Settings.copyToClipboard(LogBuffer.text)' \
    'onClicked: LogBuffer.clear()'
do
    if ! rg -q -F "$required" "$options_view"; then
        printf 'OptionsView must keep the in-app recent-log viewer controls: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'Useful logging options:' \
    'orion --journal' \
    'orion --stdout-log-level info --stderr-log-level warning' \
    'orion --journal-log-level warning' \
    "Valid log levels are \`debug\`, \`info\`, \`warning\`, \`critical\`, \`fatal\`, and \`off\`."
do
    if ! rg -q -F "$required" "$readme"; then
        printf 'README must document maintained logging controls: %s\n' "$required" >&2
        exit 1
    fi
done

for ci_file in "$workflow" "$container_ci"; do
    if ! rg -q -F 'ci/check_logging_contracts.sh' "$ci_file"; then
        printf '%s must run the logging contracts guard.\n' "$ci_file" >&2
        exit 1
    fi
done
