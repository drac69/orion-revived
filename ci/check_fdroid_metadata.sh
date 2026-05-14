#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

python3 - "$repo_dir" <<'PY'
import pathlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

repo = pathlib.Path(sys.argv[1])
metadata_path = repo / "metadata" / "app.orion.android.yml"
manifest_path = repo / "android" / "AndroidManifest.xml"
triage_path = repo / "docs" / "upstream-issue-triage.md"
android_doc_path = repo / "docs" / "android.md"

errors = []

if not metadata_path.exists():
    errors.append("F-Droid metadata must exist at metadata/app.orion.android.yml")
    metadata = ""
else:
    metadata = metadata_path.read_text(encoding="utf-8")

root = ET.parse(manifest_path).getroot()
android_ns = "{http://schemas.android.com/apk/res/android}"
package_name = root.get("package", "")
version_name = root.get(android_ns + "versionName", "")
version_code = root.get(android_ns + "versionCode", "")

if metadata_path.name != f"{package_name}.yml":
    errors.append("F-Droid metadata filename must match the Android package name")

def scalar(key):
    match = re.search(rf"^{re.escape(key)}:\s*(.+?)\s*$", metadata, re.MULTILINE)
    return match.group(1) if match else ""

def require(pattern, message, flags=re.MULTILINE):
    if not re.search(pattern, metadata, flags):
        errors.append(message)

require(r"^License:\s*GPL-3\.0-or-later\s*$", "F-Droid metadata must use the GPL-3.0-or-later SPDX license")
require(r"^RepoType:\s*git\s*$", "F-Droid metadata must declare the git repo type")
require(r"^Repo:\s*https://github\.com/belagrf/orion-revived\.git\s*$", "F-Droid metadata must point at the maintained fork repo")
require(r"^SourceCode:\s*https://github\.com/belagrf/orion-revived\s*$", "F-Droid SourceCode must point at the maintained fork")
require(r"^IssueTracker:\s*https://github\.com/belagrf/orion-revived/issues\s*$", "F-Droid IssueTracker must point at the maintained fork")
require(r"(?ms)^AntiFeatures:\n(?:\s+-\s+\S+\n)*\s+-\s+NonFreeNet\s*$", "F-Droid metadata must flag Twitch's non-free network dependency")
require(r"^Disabled:\s*.+reproducibly validated.+$", "F-Droid metadata must stay disabled until Android release builds are reproducibly validated")
require(r"^ArchivePolicy:\s*1 versions\s*$", "F-Droid metadata must keep the current release archive policy")
require(r"(?ms)^Builds:\n\s+-\s+versionName:\s*" + re.escape(version_name) + r"\s*$", "F-Droid build entry must match android:versionName")
require(r"(?m)^\s+versionCode:\s*" + re.escape(version_code) + r"\s*$", "F-Droid build entry must match android:versionCode")
require(r"(?m)^\s+disable:\s*.+reproducibly validated.+$", "The Android build entry must stay disabled until a reproducible recipe is validated")
require(r"^UpdateCheckMode:\s*Tags \^v\[0-9\]\+\\\.\[0-9\]\+\\\.\[0-9\]\+\$\s*$", "F-Droid update checks must use version tags")
require(r"^UpdateCheckData:\s*android/AndroidManifest\.xml\|android:versionCode=\"\(\[0-9\]\+\)\"\|\.\|android:versionName=\"\(\[\^\"\]\+\)\"\s*$", "F-Droid update checks must read the Android manifest version")

if scalar("CurrentVersion") != version_name:
    errors.append("CurrentVersion must match android:versionName")
if scalar("CurrentVersionCode") != version_code:
    errors.append("CurrentVersionCode must match android:versionCode")

commit_match = re.search(r"(?m)^\s+commit:\s*([0-9a-f]{40})\s*$", metadata)
if not commit_match:
    errors.append("F-Droid build entry must pin a full 40-character commit")
else:
    expected_ref = f"v{version_name}^{{}}"
    try:
        expected_commit = subprocess.check_output(
            ["git", "-C", str(repo), "rev-parse", expected_ref],
            text=True,
        ).strip()
    except subprocess.CalledProcessError:
        errors.append(f"Missing release tag v{version_name} for F-Droid build pin")
    else:
        if commit_match.group(1) != expected_commit:
            errors.append(f"F-Droid build commit must match release tag v{version_name}")

triage = triage_path.read_text(encoding="utf-8")
if "disabled F-Droid metadata scaffold" not in triage or "reproducible Android build recipe" not in triage:
    errors.append("Upstream issue triage must document the F-Droid metadata scaffold and remaining recipe work")

android_doc = android_doc_path.read_text(encoding="utf-8")
if "disabled F-Droid metadata scaffold" not in android_doc or "reproducible build recipe" not in android_doc:
    errors.append("Android status docs must document the disabled F-Droid metadata scaffold and remaining recipe work")
if "F-Droid metadata plus a reproducible build recipe" in android_doc:
    errors.append("Android status docs must not claim F-Droid metadata is still entirely missing")

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)
PY
