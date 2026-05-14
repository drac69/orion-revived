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
chat_view_qml = (repo / "src" / "qml" / "irc" / "ChatView.qml").read_text(encoding="utf-8")
chat_message_qml = (repo / "src" / "qml" / "irc" / "ChatMessage.qml").read_text(encoding="utf-8")
chat_messages_view_qml = (repo / "src" / "qml" / "irc" / "ChatMessagesView.qml").read_text(encoding="utf-8")
settings_header = (repo / "src" / "model" / "settingsmanager.h").read_text(encoding="utf-8")
settings_source = (repo / "src" / "model" / "settingsmanager.cpp").read_text(encoding="utf-8")
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
    ("model: Qt.fontFamilies()", "OptionsView.qml must offer installed font families"),
    ("property string fontName: Settings.font || appFont.name", "OptionsView.qml must show the saved or bundled default font"),
    ("Settings.font = model[index]", "OptionsView.qml must persist selected font families"),
):
    if token not in options_qml:
        errors.append(description)

for token, description in (
    ("Q_PROPERTY(double textScaleFactor READ textScaleFactor WRITE setTextScaleFactor NOTIFY textScaleFactorChanged)",
     "SettingsManager must expose the text scale factor setting"),
    ("double mTextScaleFactor = 1.0;", "SettingsManager must keep text scale at 1.0 by default"),
    ('setTextScaleFactor(settings.value("textScaleFactor", mTextScaleFactor).toDouble())',
     "SettingsManager must load the persisted text scale factor"),
    ("void setTextScaleFactor(double textScaleFactor)", "SettingsManager must expose a text scale factor setter"),
    ("void textScaleFactorChanged()", "SettingsManager must notify text scale factor changes"),
):
    if token not in settings_header and token not in settings_source:
        errors.append(description)

for token, description in (
    ("if (textScaleFactor < 0.5 || textScaleFactor > 3.0)", "SettingsManager must clamp text scale to the supported range"),
    ('settings.setValue("textScaleFactor", textScaleFactor)', "SettingsManager must persist text scale changes"),
    ("emit textScaleFactorChanged()", "SettingsManager must notify after text scale changes"),
):
    if token not in settings_source:
        errors.append(description)

for token, description in (
    ("property real fontSize: Settings.textScaleFactor * 12", "Chat messages must scale text from Settings.textScaleFactor"),
    ("* Settings.textScaleFactor", "Chat emote and badge sizes must scale from Settings.textScaleFactor"),
):
    if token not in chat_message_qml:
        errors.append(description)

for token, description in (
    ("font.pointSize: Settings.textScaleFactor * 12", "Chat input text must scale from Settings.textScaleFactor"),
    ("Settings.textScaleFactor += 0.15", "Chat view must keep a text-scale increase control"),
    ("Settings.textScaleFactor -= 0.15", "Chat view must keep a text-scale decrease control"),
):
    haystack = chat_view_qml + "\n" + chat_messages_view_qml
    if token not in haystack:
        errors.append(description)

for token, description in (
    ("Q_PROPERTY(double chatOpacity READ chatOpacity WRITE setChatOpacity NOTIFY chatOpacityChanged)",
     "SettingsManager must expose the chat opacity setting"),
    ("double mChatOpacity = 1.0;", "SettingsManager must keep chat opacity fully opaque by default"),
    ('setChatOpacity(settings.value("chatOpacity", mChatOpacity).toDouble())',
     "SettingsManager must load the persisted chat opacity"),
    ("void setChatOpacity(double chatOpacity)", "SettingsManager must expose a chat opacity setter"),
    ("void chatOpacityChanged()", "SettingsManager must notify chat opacity changes"),
):
    if token not in settings_header and token not in settings_source:
        errors.append(description)

for token, description in (
    ("if (chatOpacity < 0.0 || chatOpacity > 1.0)", "SettingsManager must clamp chat opacity to the supported range"),
    ('settings.setValue("chatOpacity", chatOpacity)', "SettingsManager must persist chat opacity changes"),
    ("emit chatOpacityChanged()", "SettingsManager must notify after chat opacity changes"),
):
    if token not in settings_source:
        errors.append(description)

for token, description in (
    ("opacity: Settings.chatOpacity", "ChatView background must bind to Settings.chatOpacity"),
    ('text: "Chat background opacity"', "OptionsView.qml must label the chat opacity control"),
    ("from: 0.0", "OptionsView.qml chat opacity slider must allow fully transparent chat"),
    ("to: 1.0", "OptionsView.qml chat opacity slider must allow fully opaque chat"),
    ("value: Settings.chatOpacity", "OptionsView.qml chat opacity slider must show the saved value"),
    ("onValueChanged: Settings.chatOpacity = value", "OptionsView.qml chat opacity slider must persist changes"),
):
    haystack = chat_view_qml + "\n" + options_qml
    if token not in haystack:
        errors.append(description)

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
