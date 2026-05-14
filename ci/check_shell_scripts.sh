#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"

shellcheck \
    ci/check_*.sh \
    ci/install_ubuntu_ci_deps.sh \
    ci/run_qmake.sh
