#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/m3u8_parser_smoke.cpp" <<'CPP'
#include <QByteArray>
#include <QDebug>
#include <QString>
#include <QVariantMap>

#include "src/util/m3u8parser.h"

static bool requireUrl(const QVariantMap &streams, const QString &name, const QString &url)
{
    if (streams.value(name).toString() == url) {
        return true;
    }

    qWarning() << "Unexpected stream URL for" << name << "got" << streams.value(name).toString() << "wanted" << url;
    return false;
}

int main()
{
    const QByteArray playlist =
        "#EXTM3U\n"
        "#EXT-X-STREAM-INF:BANDWIDTH=9000000,VIDEO=\"chunked\",CODECS=\"avc1.64002A,mp4a.40.2\"\n"
        "https://example.test/source.m3u8\n"
        "#EXT-X-STREAM-INF:PROGRAM-ID=1,CODECS=\"avc1.4d401f,mp4a.40.2\",VIDEO=\"720p60\",BANDWIDTH=4500000\n"
        "https://example.test/720.m3u8\n"
        "#EXT-X-STREAM-INF:BANDWIDTH=160000,NAME=\"Audio Only\"\n"
        "https://example.test/audio.m3u8\n"
        "#EXT-X-STREAM-INF:BANDWIDTH=1200000,NAME=\"480p30\"\n"
        "https://example.test/480.m3u8\n"
        "#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,FRAME-RATE=59.940\n"
        "https://example.test/resolution-1080.m3u8\n";

    const QVariantMap streams = m3u8::getUrls(playlist);

    bool ok = true;
    ok = requireUrl(streams, QStringLiteral("source"), QStringLiteral("https://example.test/source.m3u8")) && ok;
    ok = requireUrl(streams, QStringLiteral("720p60"), QStringLiteral("https://example.test/720.m3u8")) && ok;
    ok = requireUrl(streams, QStringLiteral("audio_only"), QStringLiteral("https://example.test/audio.m3u8")) && ok;
    ok = requireUrl(streams, QStringLiteral("480p30"), QStringLiteral("https://example.test/480.m3u8")) && ok;
    ok = requireUrl(streams, QStringLiteral("1080p60"), QStringLiteral("https://example.test/resolution-1080.m3u8")) && ok;

    if (streams.contains(QStringLiteral("chunked"))) {
        qWarning() << "chunked quality was not normalized to source";
        ok = false;
    }

    return ok ? 0 : 1;
}
CPP

cat > "$tmpdir/m3u8_parser_smoke.pro" <<EOF
QT += core
CONFIG += console c++11
CONFIG -= app_bundle
TEMPLATE = app
INCLUDEPATH += $repo_dir
SOURCES += m3u8_parser_smoke.cpp
EOF

"$repo_dir/ci/run_qmake.sh" "$tmpdir/m3u8_parser_smoke.pro" -o "$tmpdir/Makefile"
make -C "$tmpdir"
"$tmpdir/m3u8_parser_smoke"
