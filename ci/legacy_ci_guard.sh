#!/usr/bin/env bash

if [[ "${ORION_ALLOW_LEGACY_CI:-}" == "1" ]]; then
    if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
        return 0
    fi
    exit 0
fi

cat >&2 <<'EOF'
This is a legacy upstream Travis/AppVeyor helper and is not part of the
maintained GitHub Actions CI for this fork.

Use the README source build steps or .github/workflows/ci.yml for supported
automation. To run this legacy helper intentionally, set:

  ORION_ALLOW_LEGACY_CI=1
EOF
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    return 1
fi
exit 1
