#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")/legacy_ci_guard.sh" || exit 1
set -e -x

ARTIFACTS=$1

# deploy
make install INSTALL_ROOT=$PWD
$QTDIR/bin/androiddeployqt --output $PWD
mv $PWD/bin/QtApp-debug.apk $ARTIFACTS/orion-$PLATFORM-$TRAVIS_TAG.apk
