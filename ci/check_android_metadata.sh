#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

python3 - "$repo_dir" <<'PY'
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

repo = pathlib.Path(sys.argv[1])
manifest_path = repo / "android" / "AndroidManifest.xml"
project_path = repo / "orion.pro"
main_activity_path = repo / "android" / "src" / "com" / "orion" / "MainActivity.java"
views_path = repo / "src" / "qml" / "Views.qml"

errors = []

project = project_path.read_text(encoding="utf-8")
version_match = re.search(r"^VERSION\s*=\s*([0-9]+(?:\.[0-9]+)*)\s*$", project, re.MULTILINE)
if not version_match:
    errors.append("orion.pro does not define VERSION")
    project_version = ""
else:
    project_version = version_match.group(1)

expected_version_code = "".join(project_version.split("."))
if not expected_version_code:
    expected_version_code = "0"

try:
    root = ET.parse(manifest_path).getroot()
except ET.ParseError as exc:
    errors.append(f"AndroidManifest.xml is not valid XML: {exc}")
    root = None

android_ns = "{http://schemas.android.com/apk/res/android}"

def attr(element, name):
    return element.get(android_ns + name) if element is not None else None

if root is not None:
    if root.get("package") != "app.orion.android":
        errors.append("Android package must stay app.orion.android")

    if attr(root, "versionName") != project_version:
        errors.append(f"android:versionName must match orion.pro VERSION ({project_version})")

    if attr(root, "versionCode") != expected_version_code:
        errors.append(f"android:versionCode must be {expected_version_code} for VERSION {project_version}")

    uses_sdk = root.find("uses-sdk")
    if uses_sdk is None:
        errors.append("AndroidManifest.xml must declare uses-sdk")
    else:
        min_sdk = attr(uses_sdk, "minSdkVersion")
        target_sdk = attr(uses_sdk, "targetSdkVersion")
        if not (min_sdk and min_sdk.isdigit()):
            errors.append("android:minSdkVersion must be numeric")
        if not (target_sdk and target_sdk.isdigit()):
            errors.append("android:targetSdkVersion must be numeric")
        if min_sdk and target_sdk and min_sdk.isdigit() and target_sdk.isdigit() and int(target_sdk) < int(min_sdk):
            errors.append("android:targetSdkVersion must not be lower than minSdkVersion")

    permissions = {attr(permission, "name") for permission in root.findall("uses-permission")}
    for required_permission in ("android.permission.INTERNET", "android.permission.ACCESS_NETWORK_STATE"):
        if required_permission not in permissions:
            errors.append(f"Android manifest must request {required_permission}")

    if "android.permission.WAKE_LOCK" in permissions:
        errors.append("Android manifest must not request WAKE_LOCK; MainActivity uses FLAG_KEEP_SCREEN_ON")

    metadata = {
        attr(item, "name"): attr(item, "value")
        for item in root.findall(".//meta-data")
        if attr(item, "name")
    }
    expected_metadata = {
        "android.app.background_running": "false",
        "android.app.auto_screen_scale_factor": "true",
        "android.app.extract_android_style": "minimal",
    }
    for key, value in expected_metadata.items():
        if metadata.get(key) != value:
            errors.append(f"{key} must be {value}")

if "ANDROID_PACKAGE_SOURCE_DIR = $$PWD/android" not in project:
    errors.append("orion.pro must keep ANDROID_PACKAGE_SOURCE_DIR pointed at $$PWD/android")

main_activity = main_activity_path.read_text(encoding="utf-8")
if "FLAG_KEEP_SCREEN_ON" not in main_activity:
    errors.append("MainActivity must keep using FLAG_KEEP_SCREEN_ON for playback screen inhibition")

if re.search(r"\bWakeLock\b", main_activity):
    errors.append("MainActivity must not use deprecated WakeLock APIs")

for stale_method in ("acquireWakeLock", "releaseWakeLock"):
    if stale_method in main_activity or stale_method in (repo / "src" / "power" / "power.cpp").read_text(encoding="utf-8"):
        errors.append(f"Android screen inhibition must not use stale {stale_method} bridge names")

if "setPlaybackScreenOn" not in main_activity or "clearPlaybackScreenOn" not in main_activity:
    errors.append("MainActivity must expose playback screen-on bridge methods")

player_view_qml = (repo / "src" / "qml" / "PlayerView.qml").read_text(encoding="utf-8")
if "Settings.clickTogglePause && !isMobile()" not in player_view_qml:
    errors.append("Mobile player taps must only reveal controls; they must not toggle pause")

options_view_qml = (repo / "src" / "qml" / "OptionsView.qml").read_text(encoding="utf-8")
if not re.search(r'text:\s*"Toggle pause by clicking"\s+visible:\s*!isMobile\(\)', options_view_qml):
    errors.append("Click-to-pause setting must stay hidden on mobile where surface taps reveal controls")

views_qml = views_path.read_text(encoding="utf-8")
for required_text, description in (
    ("property int lastNonPlayerIndex", "Views.qml must remember the last non-player tab for Android Back navigation"),
    ("function navigateBack()", "Views.qml must keep a shared Back navigation helper"),
    ("Keys.onBackPressed", "Views.qml must handle the Android Back key"),
    ("event.accepted = navigateBack()", "Android Back handling must consume the event when it leaves the player view"),
):
    if required_text not in views_qml:
        errors.append(description)

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)
PY
