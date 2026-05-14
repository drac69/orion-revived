#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

python3 - "$repo_dir" <<'PY'
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
main_cpp = (repo / "src" / "main.cpp").read_text(encoding="utf-8")
main_qml = (repo / "src" / "qml" / "main.qml").read_text(encoding="utf-8")
options_qml = (repo / "src" / "qml" / "OptionsView.qml").read_text(encoding="utf-8")
info_drawer_qml = (repo / "src" / "qml" / "components" / "InfoDrawer.qml").read_text(encoding="utf-8")
util_js = (repo / "src" / "qml" / "util.js").read_text(encoding="utf-8")
qrc = (repo / "src" / "qml" / "qml.qrc").read_text(encoding="utf-8")

errors = []

for token, description in (
    ('#include <QFont>', "main.cpp must include QFont for process default font setup"),
    ('ORION_DEFAULT_FONT_FAMILY = "Noto Sans"', "main.cpp must keep bundled Noto Sans as the default UI font"),
    ("QFontDatabase::addApplicationFont", "main.cpp must register bundled fonts with Qt"),
    ("QFontDatabase::applicationFontFamilies", "main.cpp must verify bundled font family names"),
    ("QGuiApplication::setFont", "main.cpp must set the process default font before QML loads"),
    ('setFont("");', "main.cpp must clear stale saved font families"),
):
    if token not in main_cpp:
        errors.append(description)

try:
    register_index = main_cpp.index("registerBundledFonts();")
    configure_index = main_cpp.index("configureApplicationFont();")
    load_index = main_cpp.index('engine.load(QUrl("qrc:/main.qml"))')
    if not (register_index < configure_index < load_index):
        errors.append("Bundled fonts must be registered and selected before QML loads")
except ValueError:
    errors.append("Could not find font setup or QML load order tokens in main.cpp")

for font_file in ("fonts/NotoSans-Regular.ttf", "fonts/MaterialIcons-Regular.ttf"):
    if f"<file>{font_file}</file>" not in qrc:
        errors.append(f"qml.qrc must include {font_file}")
    if font_file not in main_qml:
        errors.append(f"main.qml must keep a FontLoader for {font_file}")

if 'font.family: Settings.font || appFont.name' not in main_qml:
    errors.append("main.qml must fall back to the bundled app font when no user font is set")

if 'Settings.font = ""' not in options_qml:
    errors.append("OptionsView.qml must reset to the bundled default font through an empty saved font")

for token, description in (
    ('function needsPlainTextStyle(value)', "util.js must expose the styled-text emoji crash guard"),
    (r'/[^\x00-\x7F]/', "util.js must detect non-ASCII text before styled rendering"),
):
    if token not in util_js:
        errors.append(description)

for token, description in (
    ('property bool plainTextStyle: false', "InfoDrawer must track when styled text should be disabled"),
    ('plainTextStyle = Util.needsPlainTextStyle(item.title)', "InfoDrawer must inspect channel titles before styled rendering"),
    ('|| Util.needsPlainTextStyle(item.game)', "InfoDrawer must inspect game names before styled rendering"),
    ('|| Util.needsPlainTextStyle(item.info)', "InfoDrawer must inspect channel descriptions before styled rendering"),
    ('style: root.plainTextStyle ? Text.Normal : textStyle', "InfoDrawer labels must disable text style for risky Unicode text"),
):
    if token not in info_drawer_qml:
        errors.append(description)

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)
PY
