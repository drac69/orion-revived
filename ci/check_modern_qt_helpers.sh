#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if rg -n '\bforeach\s*\(' "$repo_dir/src"; then
    printf 'src must use range-based loops instead of Qt foreach.\n' >&2
    exit 1
fi

if rg -n '\b(NULL|Q_NULLPTR)\b' "$repo_dir/src"; then
    printf 'src must use nullptr/FALSE instead of legacy null macros.\n' >&2
    exit 1
fi

if rg -n 'Q_ASSERT\((0|false)\)' "$repo_dir/src"; then
    printf 'Unreachable code paths must use Q_UNREACHABLE() instead of release-noop Q_ASSERT constants.\n' >&2
    exit 1
fi

if rg -n '\b(Q_OS_MAC|Q_OS_OSX|Q_WS_MAC)\b' "$repo_dir/src"; then
    printf 'src must use Q_OS_MACOS for macOS-specific code instead of deprecated Qt platform macros.\n' >&2
    exit 1
fi

if rg -n 'QtWebKit|QtWebKitWidgets|QWebView|QWebPage' "$repo_dir/src"; then
    printf 'src must not reintroduce legacy QtWebKit dependencies.\n' >&2
    exit 1
fi

if rg -n '\((MpvObject|QTcpSocket|QRgb)\s*\* ?\)|\((uint64_t|M3U8TYPE)\)' \
    "$repo_dir/src/player/mpvobject.cpp" \
    "$repo_dir/src/network/httpserver.cpp" \
    "$repo_dir/src/network/networkmanager.cpp" \
    "$repo_dir/src/notification/notificationsender.cpp"; then
    printf 'Modernized C++ code must use named casts or qobject_cast instead of legacy C-style casts.\n' >&2
    exit 1
fi

if rg -n '\.toStdString\(\)\.c_str\(\)' "$repo_dir/src"; then
    printf 'src must write Qt strings through explicit Qt byte arrays instead of temporary std::string c_str pointers.\n' >&2
    exit 1
fi

if rg -n '\*\s*[A-Za-z_][A-Za-z0-9_]*\s*=\s*0\s*(;|,|\))|\*\s*parent\s*=\s*0\b' "$repo_dir/src"; then
    printf 'Pointer declarations and default arguments must use nullptr instead of 0.\n' >&2
    exit 1
fi

if rg -n 'QVariant::Type|\.type\(\)' "$repo_dir/src/player/qthelper.hpp"; then
    printf 'qthelper.hpp must use QVariant::userType() for Qt meta-type checks.\n' >&2
    exit 1
fi

if rg -n '\.(setAttribute|attribute)\(static_cast<QNetworkRequest::Attribute>\(QNetworkRequest::User \+' "$repo_dir/src/network"; then
    printf 'Network request context must use named request attributes instead of inline QNetworkRequest::User offsets.\n' >&2
    exit 1
fi

if ! rg -q 'bytesWritten == data\.size\(\) && file\.flush\(\)' "$repo_dir/src/util/fileutils.cpp"; then
    printf 'File write helpers must verify full writes and flush success.\n' >&2
    exit 1
fi

if rg -Uq 'file\.write\(data\);\s*return true;' "$repo_dir/src/util/fileutils.cpp"; then
    printf 'File write helpers must not report success without checking write results.\n' >&2
    exit 1
fi

required_override_lines=(
    "$repo_dir/src/model/channellistmodel.h|Qt::ItemFlags flags(const QModelIndex &index) const override;"
    "$repo_dir/src/model/gamelistmodel.h|Qt::ItemFlags flags(const QModelIndex &index) const override;"
    "$repo_dir/src/model/vodlistmodel.h|Qt::ItemFlags flags(const QModelIndex &index) const override;"
    "$repo_dir/src/model/imageprovider.h|QImage requestImage(const QString &id, QSize * size, const QSize & requestedSize) override;"
    "$repo_dir/src/model/badgeimageprovider.h|QString getCanonicalKey(QString key) override;"
    "$repo_dir/src/player/mpvobject.h|Renderer *createRenderer() const override;"
    "$repo_dir/src/player/mpvobject.h|bool event(QEvent *event) override;"
    "$repo_dir/src/player/mpvobject.cpp|void render() override"
)

for entry in "${required_override_lines[@]}"; do
    file=${entry%%|*}
    line=${entry#*|}
    if ! rg -Fq "$line" "$file"; then
        printf 'Missing expected C++ override annotation in %s: %s\n' "$file" "$line" >&2
        exit 1
    fi
done
