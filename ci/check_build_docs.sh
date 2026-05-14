#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readme="$repo_dir/README.md"
appdata="$repo_dir/distfiles/Orion.appdata.xml"

if ! rg -q 'https://github\.com/belagrf/orion-revived/actions/workflows/ci\.yml' "$readme" \
    || ! rg -q 'git clone https://github\.com/belagrf/orion-revived' "$readme" \
    || ! rg -q '^cd orion-revived$' "$readme"; then
    printf 'README must point users at the formal maintained fork and its passing CI workflow.\n' >&2
    exit 1
fi

if rg -q '^cd orion$' "$readme"; then
    printf 'README clone examples must cd into the formal fork checkout directory.\n' >&2
    exit 1
fi

if ! rg -q '<url type="homepage">https://github\.com/belagrf/orion-revived</url>' "$appdata" \
    || ! rg -q '<url type="bugtracker">https://github\.com/belagrf/orion-revived/issues</url>' "$appdata"; then
    printf 'AppStream metadata must point at the formal maintained fork and issue tracker.\n' >&2
    exit 1
fi

if ! rg -q '\.\./ci/run_qmake\.sh \.\./' "$readme"; then
    printf 'README build commands must use the Qt 5 qmake wrapper from the build directory.\n' >&2
    exit 1
fi

if rg -q '^\s*qmake \.\./\s*$' "$readme"; then
    printf 'README build commands must not use ambiguous bare qmake.\n' >&2
    exit 1
fi

if ! rg -q 'Qt 5 qmake wrapper' "$readme"; then
    printf 'README backend instructions must mention the Qt 5 qmake wrapper.\n' >&2
    exit 1
fi

if ! rg -q 'validates source builds on Linux and macOS through GitHub Actions' "$readme" \
    || ! rg -q 'macOS source builds are validated in GitHub Actions' "$readme" \
    || ! rg -q 'Homebrew `qt@5` and' "$readme" \
    || ! rg -q '`macos-15` runner' "$readme"; then
    printf 'README must document macOS source-build CI validation without claiming signed packages.\n' >&2
    exit 1
fi

if rg -q "I'll|next version|Visual C\+\+ 2015-runtime" "$readme"; then
    printf 'README must not keep stale upstream Windows installer/runtime wording.\n' >&2
    exit 1
fi

if ! rg -q 'latest-supported-vc-redist' "$readme"; then
    printf 'README Windows troubleshooting must point to the current Microsoft VC++ redistributable page.\n' >&2
    exit 1
fi

if ! rg -q 'every content tab stays empty' "$readme" \
    || ! rg -q 'Qt Network SSL' "$readme" \
    || ! rg -q 'wrong architecture' "$readme" \
    || ! rg -q 'libs/libssl\*\.dll' "$readme" \
    || ! rg -q 'libs/libcrypto\*\.dll' "$readme"; then
    printf 'README Windows troubleshooting must document the old empty-tabs/SSL DLL architecture failure path.\n' >&2
    exit 1
fi

if ! rg -q 'OPENSSL_BINFILES = \$\$files\(\$\$PWD/libs/libssl\*\.dll\)' "$repo_dir/orion.pro" \
    || ! rg -q '\$\$files\(\$\$PWD/libs/libcrypto\*\.dll\)' "$repo_dir/orion.pro" \
    || ! rg -q '\$\$files\(\$\$PWD/libs/ssleay32\.dll\)' "$repo_dir/orion.pro" \
    || ! rg -q '\$\$files\(\$\$PWD/libs/libeay32\.dll\)' "$repo_dir/orion.pro" \
    || rg -q 'EXTRA_BINFILES = \$\$PWD/libs/ssleay32\.dll' "$repo_dir/orion.pro"; then
    printf 'orion.pro Windows packaging must discover modern OpenSSL DLL names while preserving old-name compatibility.\n' >&2
    exit 1
fi

if ! rg -q 'pkg install .*qt5-qmake' "$readme"; then
    printf 'README FreeBSD dependencies must include qt5-qmake for the Qt 5 qmake wrapper.\n' >&2
    exit 1
fi

if ! rg -q 'sudo dnf install .*mpv-libs-devel' "$readme" \
    || ! rg -q 'Fedora packages should prefer the mpv backend' "$readme" \
    || ! rg -q 'GStreamer H\.264/AAC' "$readme"; then
    printf 'README Fedora notes must document mpv build dependencies and the Qt Multimedia/GStreamer playback caveat.\n' >&2
    exit 1
fi

if ! rg -q 'default install prefix is `/usr/local`' "$readme"; then
    printf 'README FreeBSD build notes must document the /usr/local default install prefix.\n' >&2
    exit 1
fi

if ! rg -q 'freebsd: PREFIX = /usr/local' "$repo_dir/orion.pro"; then
    printf 'orion.pro must default FreeBSD installs to /usr/local.\n' >&2
    exit 1
fi

if ! rg -q 'unix:!macx:!android: \{' "$repo_dir/orion.pro"; then
    printf 'orion.pro install target must cover Unix desktop builds, including FreeBSD.\n' >&2
    exit 1
fi
