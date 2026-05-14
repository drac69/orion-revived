#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$repo_dir/.github/workflows/ci.yml"
dependabot="$repo_dir/.github/dependabot.yml"

if ! rg -q '^permissions:\s*$' "$workflow" || ! rg -q '^\s+contents:\s*read\s*$' "$workflow"; then
    printf 'CI workflow must use least-privilege read-only contents permissions.\n' >&2
    exit 1
fi

if ! rg -q '^concurrency:\s*$' "$workflow" \
        || ! rg -Fq 'group: ${{ github.workflow }}-${{ github.ref }}' "$workflow" \
        || ! rg -q '^\s+cancel-in-progress:\s*true\s*$' "$workflow"; then
    printf 'CI workflow must cancel stale runs for the same workflow/ref.\n' >&2
    exit 1
fi

if ! rg -q 'ci/check_workflow_hygiene\.sh' "$workflow"; then
    printf 'CI workflow must run the workflow hygiene guard.\n' >&2
    exit 1
fi

if ! rg -q 'ci/check_patch_whitespace\.sh' "$workflow"; then
    printf 'CI workflow must reject whitespace errors in the committed patch.\n' >&2
    exit 1
fi

if ! rg -q 'fetch-depth:\s*2' "$workflow"; then
    printf 'CI checkout must fetch the previous commit for patch-only whitespace checks.\n' >&2
    exit 1
fi

if ! rg -q 'fetch-tags:\s*true' "$workflow"; then
    printf 'CI checkout must fetch tags so release-pinned metadata can be validated.\n' >&2
    exit 1
fi

if ! rg -q 'runs-on:\s*macos-15' "$workflow" \
        || ! rg -q 'brew install qt@5 mpv' "$workflow" \
        || ! rg -Fq 'ci/run_qmake.sh orion.pro CONFIG+=mpv "INCLUDEPATH+=$mpv_prefix/include" "LIBS+=-L$mpv_prefix/lib"' "$workflow" \
        || ! rg -q 'orion\.app/Contents/MacOS/orion' "$workflow"; then
    printf 'CI workflow must keep the macOS Qt 5/mpv source-build validation job.\n' >&2
    exit 1
fi

if ! rg -q 'runs-on:\s*windows-2025-vs2026' "$workflow" \
        || ! rg -q 'msys2/setup-msys2@v2' "$workflow" \
        || ! rg -q 'msystem:\s*UCRT64' "$workflow" \
        || ! rg -q 'mingw-w64-ucrt-x86_64-mpv' "$workflow" \
        || ! rg -q 'ci/run_qmake\.sh orion\.pro CONFIG\+=mpv' "$workflow" \
        || ! rg -q 'release/orion\.exe' "$workflow"; then
    printf 'CI workflow must keep the Windows MSYS2 Qt 5/mpv source-build validation job.\n' >&2
    exit 1
fi

if ! rg -q 'ci/check_shell_scripts\.sh' "$workflow"; then
    printf 'CI workflow must run ShellCheck for maintained shell scripts.\n' >&2
    exit 1
fi

if ! rg -q 'ci/check_github_issue_templates\.sh' "$workflow"; then
    printf 'CI workflow must validate GitHub issue templates.\n' >&2
    exit 1
fi

if ! rg -q 'ci/check_github_community_files\.sh' "$workflow"; then
    printf 'CI workflow must validate GitHub community health files.\n' >&2
    exit 1
fi

ci_packages=$(ORION_CI_APT_DRY_RUN=1 "$repo_dir/ci/install_ubuntu_ci_deps.sh")
if ! rg -q '^shellcheck$' <<<"$ci_packages"; then
    printf 'CI dependency installer must include shellcheck for shell-script linting.\n' >&2
    exit 1
fi

if ! rg -Fq 'apt_install_timeout=${ORION_CI_APT_INSTALL_TIMEOUT:-600s}' "$repo_dir/ci/install_ubuntu_ci_deps.sh"; then
    printf 'CI dependency installation must keep a bounded retry timeout for hosted-runner stalls.\n' >&2
    exit 1
fi

if ! rg -q 'ci/check_build_docs\.sh' "$workflow"; then
    printf 'CI workflow must validate source-build documentation.\n' >&2
    exit 1
fi

if ! rg -q 'ci/check_release_readiness\.sh' "$workflow"; then
    printf 'CI workflow must validate release readiness documentation.\n' >&2
    exit 1
fi

if ! rg -q 'ci/check_apple_metadata\.sh' "$workflow"; then
    printf 'CI workflow must validate Apple bundle metadata.\n' >&2
    exit 1
fi

if ! rg -q 'ci/check_fdroid_metadata\.sh' "$workflow"; then
    printf 'CI workflow must validate F-Droid metadata.\n' >&2
    exit 1
fi

while IFS= read -r script; do
    script_path="$repo_dir/$script"
    mode=$(git -C "$repo_dir" ls-files -s -- "$script" | awk '{print $1}')

    if [ "$mode" != "100755" ] || [ ! -x "$script_path" ]; then
        printf 'CI-invoked script %s must be committed executable.\n' "$script" >&2
        exit 1
    fi
done < <(
    git -C "$repo_dir" ls-files 'ci/check_*.sh'
    printf '%s\n' ci/install_ubuntu_ci_deps.sh
    printf '%s\n' ci/run_qmake.sh
)

if ! rg -q 'package-ecosystem:\s*"github-actions"' "$dependabot" \
        || ! rg -q 'directory:\s*"/"' "$dependabot" \
        || ! rg -q 'interval:\s*"weekly"' "$dependabot"; then
    printf 'Dependabot must keep weekly GitHub Actions update checks enabled.\n' >&2
    exit 1
fi
