#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

python3 - "$repo_dir" <<'PY'
import pathlib
import plistlib
import re
import sys

repo = pathlib.Path(sys.argv[1])
info_plist_path = repo / "distfiles" / "Info.plist"
project_path = repo / "orion.pro"

errors = []

project = project_path.read_text(encoding="utf-8")
version_match = re.search(r"^VERSION\s*=\s*([0-9]+(?:\.[0-9]+)*)\s*$", project, re.MULTILINE)
project_version = version_match.group(1) if version_match else ""
if not project_version:
    errors.append("orion.pro does not define VERSION")

if "QMAKE_INFO_PLIST = distfiles/Info.plist" not in project:
    errors.append("orion.pro must keep using distfiles/Info.plist for macOS bundles")

try:
    info_text = info_plist_path.read_text(encoding="utf-8")
    info = plistlib.loads(info_text.encode("utf-8"))
except Exception as exc:
    errors.append(f"distfiles/Info.plist is not valid XML plist: {exc}")
    info_text = ""
    info = {}

expected_values = {
    "CFBundleIdentifier": "app.orion.orion",
    "CFBundleName": "Orion",
    "CFBundleDisplayName": "Orion",
    "CFBundleExecutable": "orion",
    "CFBundleIconFile": "orion.icns",
    "LSApplicationCategoryType": "public.app-category.entertainment",
}
for key, expected in expected_values.items():
    if info.get(key) != expected:
        errors.append(f"Info.plist {key} must be {expected}")

for key in ("CFBundleShortVersionString", "CFBundleVersion"):
    if info.get(key) != project_version:
        errors.append(f"Info.plist {key} must match orion.pro VERSION ({project_version})")

if info.get("NSHighResolutionCapable") is not True:
    errors.append("Info.plist must declare NSHighResolutionCapable=true")

if "alamminsalo" in info_text:
    errors.append("Info.plist must not keep the archived upstream bundle identifier")

def contains_key(value, key):
    if isinstance(value, dict):
        return key in value or any(contains_key(child, key) for child in value.values())
    if isinstance(value, list):
        return any(contains_key(child, key) for child in value)
    return False

for insecure_key in (
    "NSAllowsArbitraryLoads",
    "NSTemporaryExceptionAllowsInsecureHTTPLoads",
    "NSExceptionMinimumTLSVersion",
):
    if contains_key(info, insecure_key):
        errors.append(f"Info.plist must not allow insecure App Transport Security key {insecure_key}")

if "TLSv1.0" in info_text:
    errors.append("Info.plist must not keep obsolete TLSv1.0 transport exceptions")

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)
PY
