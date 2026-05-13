#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")/legacy_ci_guard.sh" || exit 1

cat << EOM > ci/osx.env
export QTDIR=$(brew --prefix qt)
export PATH=$QTDIR/bin:$PATH
EOM
