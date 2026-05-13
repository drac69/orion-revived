#!/usr/bin/env bash

if [[ "${ORION_ALLOW_LEGACY_CI:-}" == "1" ]]; then
    return 0 2>/dev/null || exit 0
fi

cat >&2 <<'EOF'
This is a legacy upstream Travis/AppVeyor helper and is not part of the
maintained GitHub Actions CI for this fork.

Use the README source build steps or .github/workflows/ci.yml for supported
automation. To run this legacy helper intentionally, set:

  ORION_ALLOW_LEGACY_CI=1
EOF
return 1 2>/dev/null || exit 1
