#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ci_dir="$repo_dir/ci"
fail=0

check_guard_reference() {
    local file=$1
    local pattern=$2
    local lines=$3

    if ! head -n "$lines" "$file" | rg -q "$pattern"; then
        printf '%s must call the legacy CI guard before doing work\n' "${file#$repo_dir/}" >&2
        fail=1
    fi
}

while IFS= read -r file; do
    base=${file##*/}
    if [[ "$base" == check_* || "$base" == "install_ubuntu_ci_deps.sh" || "$base" == "legacy_ci_guard.sh" ]]; then
        continue
    fi
    check_guard_reference "$file" 'legacy_ci_guard\.sh' 5
done < <(find "$ci_dir" -maxdepth 1 -type f -name '*.sh' | sort)

while IFS= read -r file; do
    base=${file##*/}
    if [[ "$base" == "legacy_ci_guard.bat" ]]; then
        continue
    fi
    check_guard_reference "$file" 'legacy_ci_guard\.bat' 3
done < <(find "$ci_dir" -maxdepth 1 -type f -name '*.bat' | sort)

if ! rg -q 'ORION_ALLOW_LEGACY_CI' "$ci_dir/legacy_ci_guard.sh" "$ci_dir/legacy_ci_guard.bat"; then
    printf 'legacy CI guard files must document ORION_ALLOW_LEGACY_CI\n' >&2
    fail=1
fi

dependency_installer="$ci_dir/install_ubuntu_ci_deps.sh"
if rg -q 'timeout --foreground' "$dependency_installer"; then
    printf 'install_ubuntu_ci_deps.sh must not use timeout --foreground; CI apt children must stay under timeout control\n' >&2
    fail=1
fi

if ! rg -q 'sudo env DEBIAN_FRONTEND=noninteractive timeout --kill-after=30s "\$command_timeout" "\$@"' "$dependency_installer"; then
    printf 'install_ubuntu_ci_deps.sh must run apt commands through sudo timeout with a kill-after grace period\n' >&2
    fail=1
fi

exit "$fail"
