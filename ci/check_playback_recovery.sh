#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
player_view="$repo_dir/src/qml/PlayerView.qml"
main_qml="$repo_dir/src/qml/main.qml"
options_view="$repo_dir/src/qml/OptionsView.qml"
status_changed_block=$(sed -n '/onStatusChanged:/,/^        }/p' "$player_view")
seek_preview="$repo_dir/src/qml/components/SeekPreview.qml"
multimedia_backend="$repo_dir/src/qml/MultimediaBackend.qml"
qtav_backend="$repo_dir/src/qml/QtAVBackend.qml"
mpv_backend="$repo_dir/src/qml/MpvBackend.qml"
mpv_object_header="$repo_dir/src/player/mpvobject.h"
mpv_object_source="$repo_dir/src/player/mpvobject.cpp"
mpv_qt_helper="$repo_dir/src/player/qthelper.hpp"
m3u8_parser="$repo_dir/src/util/m3u8parser.h"
vod_manager="$repo_dir/src/model/vodmanager.cpp"
settings_manager="$repo_dir/src/model/settingsmanager.cpp"
settings_manager_header="$repo_dir/src/model/settingsmanager.h"
power_manager="$repo_dir/src/power/power.cpp"
power_manager_header="$repo_dir/src/power/power.h"
network_manager="$repo_dir/src/network/networkmanager.cpp"
test_connection_reply_block=$(sed -n '/void NetworkManager::testConnectionReply()/,/^}/p' "$network_manager")
click_timer_block=$(sed -n '/id: clickTimer/,/id: hideTimer/p' "$player_view")

if ! printf '%s\n' "$status_changed_block" | rg -q 'renderer\.status === "BUFFERING"'; then
    printf 'PlayerView must restart stall recovery when active playback returns to BUFFERING.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$status_changed_block" | rg -q 'startupRetryTimer\.restart\(\)'; then
    printf 'PlayerView must restart the buffering retry timer from status changes.\n' >&2
    exit 1
fi

if ! rg -q 'Playback startup stalled; retrying' "$player_view"; then
    printf 'PlayerView must retain bounded buffering retry diagnostics.\n' >&2
    exit 1
fi

if ! rg -q 'unexpectedStopRecoveryTimer' "$player_view"; then
    printf 'PlayerView must retain unexpected STOPPED-state recovery.\n' >&2
    exit 1
fi

for required in \
    'function rendererStatus()' \
    'function rendererPosition()' \
    'Player backend is not available' \
    'running: rendererStatus() === "BUFFERING"' \
    'show(rendererStatus() !== "PLAYING" ?' \
    'text: rendererStatus() !== "PLAYING" && rendererStatus() !== "BUFFERING"' \
    'if (!renderer) {' \
    'return 0' \
    'if (renderer) {' \
    'renderer.setVolume(value)'
do
    if ! rg -q -F "$required" "$player_view"; then
        printf 'PlayerView must guard UI controls when the renderer item is unavailable: %s\n' "$required" >&2
        exit 1
    fi
done

if rg -q 'running: renderer\.status|show\(renderer\.status|text: renderer\.status|if \(renderer\.status === "PAUSED" \|\| renderer\.status === "STOPPED"\)' "$player_view"; then
    printf 'PlayerView controls must use guarded rendererStatus() bindings outside renderer Connections.\n' >&2
    exit 1
fi

for required in \
    'visible: rendererReady() && model.length > 1' \
    'function rendererReady()' \
    'typeof renderer.getDecoder === "function"' \
    'typeof renderer.setDecoder === "function"' \
    'if (!rendererReady() || currentIndex < 0 || currentIndex >= model.length)' \
    'model = []' \
    'currentIndex = -1' \
    'model = decoder || []' \
    'if (model.length <= 0)'
do
    if ! rg -q -F "$required" "$options_view"; then
        printf 'OptionsView must guard backend decoder settings when the renderer item is unavailable: %s\n' "$required" >&2
        exit 1
    fi
done

if rg -q -F 'visible: model.length > 1' "$options_view"; then
    printf 'OptionsView hardware-acceleration control must not depend on model length without checking renderer readiness.\n' >&2
    exit 1
fi

for required in \
    'Q_PROPERTY(bool clickTogglePause READ clickTogglePause WRITE setClickTogglePause NOTIFY clickTogglePauseChanged)' \
    'bool mClickTogglePause = true;' \
    'void setClickTogglePause(bool clickTogglePause)' \
    'void clickTogglePauseChanged()'
do
    if ! rg -q -F "$required" "$settings_manager_header"; then
        printf 'SettingsManager must expose the click-to-pause preference: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'setClickTogglePause(settings.value("clickTogglePause", mClickTogglePause).toBool())' \
    'settings.setValue("clickTogglePause", clickTogglePause)' \
    'emit clickTogglePauseChanged()'
do
    if ! rg -q -F "$required" "$settings_manager"; then
        printf 'SettingsManager must persist the click-to-pause preference: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'text: "Toggle pause by clicking"' \
    'visible: !isMobile()' \
    'checked: Settings.clickTogglePause' \
    'onClicked: Settings.clickTogglePause = checked'
do
    if ! rg -q -F "$required" "$options_view"; then
        printf 'OptionsView must expose the click-to-pause toggle without enabling it on mobile: %s\n' "$required" >&2
        exit 1
    fi
done

if ! rg -q -F 'if (Settings.clickTogglePause && !isMobile()) {' "$player_view"; then
    printf 'PlayerView must gate video-click pause toggling behind the setting and desktop mode.\n' >&2
    exit 1
fi

if ! awk '
    /if \(Settings\.clickTogglePause && !isMobile\(\)\) \{/ {
        in_click_toggle_block = 1
    }
    in_click_toggle_block && /clickTimer\.restart\(\)/ {
        found_restart = 1
    }
    in_click_toggle_block && /^[[:space:]]*\}/ {
        in_click_toggle_block = 0
    }
    END {
        exit(found_restart ? 0 : 1)
    }
' "$player_view"; then
    printf 'PlayerView must only restart the click-to-pause timer from the guarded click-toggle block.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$click_timer_block" | rg -q -F 'onTriggered: {' \
    || ! printf '%s\n' "$click_timer_block" | rg -q -F 'togglePlayback();'; then
    printf 'PlayerView must keep the click timer connected to playback toggling when the preference allows it.\n' >&2
    exit 1
fi

for required in \
    'Q_PROPERTY(bool inhibitScreensaver READ inhibitScreensaver WRITE setInhibitScreensaver NOTIFY inhibitScreensaverChanged)' \
    'bool mInhibitScreensaver = true;' \
    'bool inhibitScreensaver() const;' \
    'void setInhibitScreensaver(bool inhibitScreensaver);' \
    'void inhibitScreensaverChanged();'
do
    if ! rg -q -F "$required" "$settings_manager_header"; then
        printf 'SettingsManager must expose the screensaver-inhibition preference: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'setInhibitScreensaver(settings.value("inhibitScreensaver", mInhibitScreensaver).toBool())' \
    'settings.setValue("inhibitScreensaver", inhibitScreensaver)' \
    'emit inhibitScreensaverChanged()'
do
    if ! rg -q -F "$required" "$settings_manager"; then
        printf 'SettingsManager must persist the screensaver-inhibition preference: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'Q_PROPERTY(bool screensaver READ screensaver WRITE setScreensaver)' \
    'bool screensaverEnabled;' \
    'Q_INVOKABLE void setScreensaver(bool);'
do
    if ! rg -q -F "$required" "$power_manager_header"; then
        printf 'Power manager must expose screensaver control to QML: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'screensaverEnabled(true)' \
    'setScreensaver(true);' \
    'screensaverEnabled = enabled;' \
    'dbus.call("Inhibit", APP_NAME, "Playing video")' \
    'dbus.call("UnInhibit", QVariant(cookie))' \
    'SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED)' \
    'QAndroidJniObject::callStaticMethod<void>("com/orion/MainActivity", "setPlaybackScreenOn")' \
    'QAndroidJniObject::callStaticMethod<void>("com/orion/MainActivity", "clearPlaybackScreenOn")' \
    'QProcess::startDetached(QStringLiteral("xdg-screensaver"), QStringList() << QStringLiteral("reset"))'
do
    if ! rg -q -F "$required" "$power_manager"; then
        printf 'Power manager must keep platform screensaver inhibition behavior: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'text: "Prevent screensaver while playing"' \
    'checked: Settings.inhibitScreensaver' \
    'onClicked: Settings.inhibitScreensaver = checked'
do
    if ! rg -q -F "$required" "$options_view"; then
        printf 'OptionsView must expose the screensaver-inhibition toggle: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'function updateScreensaverState()' \
    'PowerManager.screensaver = !Settings.inhibitScreensaver || (renderer.status !== "PLAYING")' \
    'onInhibitScreensaverChanged: root.updateScreensaverState()' \
    'root.updateScreensaverState()'
do
    if ! rg -q -F "$required" "$player_view"; then
        printf 'PlayerView must update screensaver inhibition from playback state and settings: %s\n' "$required" >&2
        exit 1
    fi
done

if ! awk '
    /void Power::timerEvent\(QTimerEvent \*event\)/ {
        in_timer = 1
    }
    in_timer && /if \(screensaverEnabled\) \{/ {
        saw_guard = 1
    }
    in_timer && saw_guard && /return;/ {
        saw_return = 1
    }
    in_timer && /QProcess::startDetached\(QStringLiteral\("xdg-screensaver"\), QStringList\(\) << QStringLiteral\("reset"\)\)/ {
        saw_reset = 1
        if (!saw_return) {
            exit 2
        }
    }
    END {
        exit(saw_guard && saw_return && saw_reset ? 0 : 1)
    }
' "$power_manager"; then
    printf 'Power::timerEvent must return before xdg-screensaver reset while screensaver inhibition is inactive.\n' >&2
    exit 1
fi

for required in \
    'Q_PROPERTY(bool audioCompressor READ audioCompressor WRITE setAudioCompressor NOTIFY audioCompressorChanged)' \
    'bool mAudioCompressor = false;' \
    'void setAudioCompressor(bool audioCompressor)' \
    'void audioCompressorChanged()'
do
    if ! rg -q -F "$required" "$settings_manager_header"; then
        printf 'SettingsManager must expose the mpv audio-compressor preference: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'setAudioCompressor(settings.value("audioCompressor", mAudioCompressor).toBool())' \
    'settings.setValue("audioCompressor", audioCompressor)' \
    'emit audioCompressorChanged()'
do
    if ! rg -q -F "$required" "$settings_manager"; then
        printf 'SettingsManager must persist the mpv audio-compressor preference: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'text: "Audio compressor"' \
    'visible: Settings.backend === "mpv"' \
    'checked: Settings.audioCompressor' \
    'onClicked: Settings.audioCompressor = checked'
do
    if ! rg -q -F "$required" "$options_view"; then
        printf 'OptionsView must expose the audio-compressor toggle only for mpv builds: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'function audioCompressorFilter()' \
    'acompressor=threshold=0.125:ratio=4:attack=5:release=80:makeup=2' \
    'renderer.setProperty("af", Settings.audioCompressor ? audioCompressorFilter() : "")' \
    'updateAudioFilters()' \
    'onAudioCompressorChanged: updateAudioFilters()'
do
    if ! rg -q -F "$required" "$mpv_backend"; then
        printf 'MpvBackend must apply or clear the configured audio-compressor filter: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'property bool showPlaybackStats: false' \
    'function playbackStatsAvailable()' \
    'typeof renderer.getPlaybackStats === "function"' \
    'if (root.showPlaybackStats) {' \
    'statsPanel.refresh()' \
    'id: statsPanel' \
    'visible: root.showPlaybackStats && root.playbackStatsAvailable()' \
    'statsText.text = renderer.getPlaybackStats()' \
    'running: statsPanel.visible' \
    'font.family: "monospace"' \
    'textFormat: Text.PlainText' \
    'wrapMode: Text.NoWrap' \
    'id: statsBtn' \
    'visible: !isMobile() && root.playbackStatsAvailable()' \
    'highlighted: root.showPlaybackStats' \
    'root.showPlaybackStats = !root.showPlaybackStats'
do
    if ! rg -q -F "$required" "$player_view"; then
        printf 'PlayerView must keep the mpv playback-stats overlay guarded and refreshable: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'function getPlaybackStats()' \
    'renderer.getProperty("width") || renderer.getProperty("dwidth")' \
    'renderer.getProperty("height") || renderer.getProperty("dheight")' \
    'renderer.getProperty("estimated-vf-fps") || renderer.getProperty("container-fps")' \
    'renderer.getProperty("estimated-display-fps") || renderer.getProperty("display-fps")' \
    'renderer.getProperty("packet-video-bitrate") || renderer.getProperty("video-bitrate")' \
    'renderer.getProperty("packet-audio-bitrate") || renderer.getProperty("audio-bitrate")' \
    'renderer.getProperty("demuxer-cache-duration")' \
    'renderer.getProperty("avsync")' \
    'renderer.getProperty("video-codec")' \
    'renderer.getProperty("audio-codec")' \
    'renderer.getProperty("frame-drop-count")' \
    'renderer.getProperty("decoder-frame-drop-count")' \
    'renderer.getProperty("hwdec-current")' \
    '"Video: "' \
    '"Audio: "' \
    '"FPS: "' \
    '"Bitrate: V "' \
    '"Dropped: "' \
    '"A/V sync: "' \
    '"Cache: "' \
    '"HW decode: "'
do
    if ! rg -q -F "$required" "$mpv_backend"; then
        printf 'MpvBackend must report the full playback-stats overlay data set: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'function currentSeekPreviewSource()' \
    'return currentChannel && currentChannel.seekPreviews ? currentChannel.seekPreviews : ""' \
    'onCurrentChannelChanged: preview.source = currentSeekPreviewSource()' \
    'onCurrentChannelChanged: seekPreview.source = currentSeekPreviewSource()' \
    'root.lastSetPosition = startPos' \
    'root.currentChannel && root.curVodId && Math.abs' \
    'Math.abs(newPos - root.lastSetPosition) > 10' \
    'root.lastSetPosition = newPos;' \
    'VodManager.setVodLastPlaybackPosition(root.currentChannel.name, root.curVodId, newPos);' \
    'seekBar.value = startPos'
do
    if ! rg -q -F "$required" "$player_view"; then
        printf 'PlayerView must guard VOD seek-preview and position-save state: %s\n' "$required" >&2
        exit 1
    fi
done

if rg -q 'onCurrentChannelChanged: .*currentChannel\.seekPreviews' "$player_view"; then
    printf 'PlayerView must not dereference currentChannel.seekPreviews directly from seek-preview handlers.\n' >&2
    exit 1
fi

for required in \
    'property bool appFullScreen: isMobile() ? (view.playerVisible && !isPortraitMode) : false' \
    'property bool sideNavigationVisible: Settings.sideNavigation && !appFullScreen && !isMobile()' \
    'visible: !root.sideNavigationVisible && !appFullScreen'
do
    if ! rg -q -F "$required" "$main_qml"; then
        printf 'main.qml must hide app navigation while playback is fullscreen: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'function refreshHeaders()' \
    'if (!hideTimer.running && !root.headersVisible)' \
    'root.headersVisible = true' \
    'hideTimer.restart()' \
    'onPositionChanged: refreshHeaders()' \
    'cursorShape: headersVisible ? Qt.ArrowCursor : Qt.BlankCursor' \
    'if (!root.headersVisible || headerBarArea.containsMouse || bottomBarArea.containsMouse) return' \
    'root.headersVisible = false' \
    'id: headerBar' \
    'height: root.headersVisible ? 55 : 0' \
    'id: fsBtn' \
    'onClicked: appFullScreen = !appFullScreen'
do
    if ! rg -q -F "$required" "$player_view"; then
        printf 'PlayerView must keep fullscreen navigation separate from in-player header hover state: %s\n' "$required" >&2
        exit 1
    fi
done

if rg -n 'onPositionChanged:.*appFullScreen|mouse[XY].*appFullScreen|appFullScreen.*mouse[XY]' "$player_view"; then
    printf 'PlayerView mouse movement must not toggle application fullscreen or app navigation state.\n' >&2
    exit 1
fi

for required in \
    'function resetInfo()' \
    'if (count <= 0 || isNaN(root.from) || isNaN(root.to) || root.to <= root.from)' \
    'var requestedSource = root.source' \
    'if (requestedSource !== root.source || !resp || resp.length <= 0)' \
    'if (!info || !info.count || !info.interval || !info.width || !info.height'
do
    if ! rg -q -F "$required" "$seek_preview"; then
        printf 'SeekPreview must ignore stale or malformed preview metadata: %s\n' "$required" >&2
        exit 1
    fi
done

if ! rg -q 'function showPlaybackError' "$player_view"; then
    printf 'PlayerView must centralize playback error handling.\n' >&2
    exit 1
fi

if ! rg -q 'headersVisible = true' "$player_view" || ! rg -q 'hideTimer\.stop\(\)' "$player_view"; then
    printf 'Playback errors must force the Twitch fallback control to remain visible.\n' >&2
    exit 1
fi

if ! rg -q 'Open VOD on Twitch' "$player_view" || ! rg -q 'Open channel on Twitch' "$player_view"; then
    printf 'Playback errors must keep explicit Twitch fallback labels.\n' >&2
    exit 1
fi

for required in \
    'function currentVodFallbackPosition()' \
    'Util.twitchVodTimestamp(currentVodFallbackPosition())'
do
    if ! rg -q -F "$required" "$player_view"; then
        printf 'VOD Twitch fallback links must preserve the current playback timestamp: %s\n' "$required" >&2
        exit 1
    fi
done

for required in \
    'id: videoPositionLabel' \
    'function updateText()' \
    'if (!isVod || duration <= 0) {' \
    'text = ""' \
    'Util.formatTime(seekBar.value) + "/" + Util.formatTime(duration)' \
    'onIsVodChanged: videoPositionLabel.updateText()' \
    'onDurationChanged: videoPositionLabel.updateText()' \
    'onValueChanged: videoPositionLabel.updateText()' \
    'onPlayingStopped: videoPositionLabel.text = ""'
do
    if ! rg -q -F "$required" "$player_view"; then
        printf 'PlayerView must keep VOD timestamp display current and clear stale non-VOD text: %s\n' "$required" >&2
        exit 1
    fi
done

if ! rg -q 'onBackendError' "$player_view" || ! rg -q 'backend_error' "$player_view"; then
    printf 'PlayerView must surface backend playback errors through the common playback error UI.\n' >&2
    exit 1
fi

if ! rg -q 'if \(playbackError\)' "$player_view"; then
    printf 'PlayerView must not overwrite visible playback errors with stopped-state text.\n' >&2
    exit 1
fi

for backend in "$multimedia_backend" "$qtav_backend" "$mpv_backend"; do
    if ! rg -q 'signal backendError\(string message\)' "$backend"; then
        printf 'Backend %s must expose backendError(message).\n' "$backend" >&2
        exit 1
    fi
done

if ! rg -q 'onError:' "$multimedia_backend" || ! rg -q 'backendError\(detail\)' "$multimedia_backend"; then
    printf 'Qt Multimedia backend must forward MediaPlayer errors to PlayerView.\n' >&2
    exit 1
fi

if ! rg -q 'root\.status = "STOPPED"' "$multimedia_backend"; then
    printf 'Qt Multimedia backend errors must leave BUFFERING state after surfacing the error.\n' >&2
    exit 1
fi

if ! rg -q 'onError:' "$qtav_backend" || ! rg -q 'backendError\(detail\)' "$qtav_backend"; then
    printf 'QtAV backend must forward MediaPlayer errors to PlayerView.\n' >&2
    exit 1
fi

if ! rg -q 'root\.status = "STOPPED"' "$qtav_backend"; then
    printf 'QtAV backend errors must leave BUFFERING state after surfacing the error.\n' >&2
    exit 1
fi

if ! rg -q 'void playbackError\(const QString &message\)' "$mpv_object_header"; then
    printf 'MpvObject must expose mpv playback errors to QML.\n' >&2
    exit 1
fi

if ! rg -q 'MPV_EVENT_END_FILE' "$mpv_object_source" \
    || ! rg -q 'MPV_END_FILE_REASON_ERROR' "$mpv_object_source" \
    || ! rg -q 'mpv_error_string\(endFile->error\)' "$mpv_object_source"; then
    printf 'MpvObject must turn MPV_EVENT_END_FILE error reasons into readable playback errors.\n' >&2
    exit 1
fi

if ! rg -q 'onPlaybackError: root\.backendError' "$mpv_backend"; then
    printf 'MpvBackend.qml must forward libmpv playback errors through backendError.\n' >&2
    exit 1
fi

if rg -q 'command_variant|set_property_variant|set_option_variant|get_property_variant' "$mpv_object_source"; then
    printf 'MpvObject must use the non-deprecated mpv Qt helper calls.\n' >&2
    exit 1
fi

hwdec_default_line=$(rg -n 'mpv_set_option_string\(mpv, "hwdec", "auto-copy"\)' "$mpv_object_source" | head -n1 | cut -d: -f1 || true)
mpv_initialize_line=$(rg -n 'mpv_initialize\(mpv\)' "$mpv_object_source" | head -n1 | cut -d: -f1 || true)
if [[ -z "$hwdec_default_line" || -z "$mpv_initialize_line" || "$hwdec_default_line" -ge "$mpv_initialize_line" ]]; then
    printf 'MpvObject must set the safe auto-copy hwdec default before mpv_initialize().\n' >&2
    exit 1
fi

if ! rg -q 'mpv_error_string\(hwdecResult\)' "$mpv_object_source"; then
    printf 'MpvObject must log failures when applying the safe hwdec default.\n' >&2
    exit 1
fi

if rg -q '#error "This helper is deprecated' "$mpv_qt_helper"; then
    printf 'The bundled mpv Qt helper must not require deprecated libmpv APIs to compile.\n' >&2
    exit 1
fi

if ! rg -q 'static inline int set_option' "$mpv_qt_helper"; then
    printf 'The bundled mpv Qt helper must expose a non-deprecated set_option helper.\n' >&2
    exit 1
fi

if rg -q 'USE_OPENGL_CB|mpv_opengl_cb|MPV_SUB_API_OPENGL_CB|opengl-cb' "$mpv_object_header" "$mpv_object_source"; then
    printf 'MpvObject must use the modern libmpv render API instead of the deprecated OpenGL callback API.\n' >&2
    exit 1
fi

if ! rg -q 'bytesWritten != snapshotData\.size\(\)' "$vod_manager"; then
    printf 'VodManager must treat short playback-position snapshot writes as failed saves.\n' >&2
    exit 1
fi

if ! rg -q 'file\.cancelWriting\(\)' "$vod_manager"; then
    printf 'VodManager must cancel partial playback-position snapshots before returning.\n' >&2
    exit 1
fi

if ! rg -q 'warnSettingsSyncFailure\(settings, "VOD cache settings"\)' "$vod_manager"; then
    printf 'VodManager must warn when cached VOD settings fail to sync.\n' >&2
    exit 1
fi

if ! rg -q 'warnSettingsSyncFailure\(settings, "VOD position settings"\)' "$vod_manager"; then
    printf 'VodManager must warn when VOD position settings fail to sync.\n' >&2
    exit 1
fi

for required in \
    '#include <cmath>' \
    'void VodManager::setVodLastPlaybackPosition' \
    'const auto previousPosition = vodEntry.value().lastPosition;' \
    'vodEntry.value().lastPosition = position;' \
    'vodEntry.value().modified = true;' \
    'std::fabs(static_cast<double>(previousPosition) - static_cast<double>(position)) >= 10' \
    'vodMap.insert(vod, {position, true, -1});' \
    'emit vodLastPositionUpdated(channel, vod, position);'
do
    if ! rg -q -F "$required" "$vod_manager"; then
        printf 'VodManager must compare VOD playback-position changes before syncing settings: %s\n' "$required" >&2
        exit 1
    fi
done

if ! awk '
    /if \(std::fabs\(static_cast<double>\(previousPosition\) - static_cast<double>\(position\)\) >= 10\) \{/ {
        in_threshold_block = 1
    }
    in_threshold_block && /saveSettings\(\);/ {
        found_threshold_save = 1
    }
    in_threshold_block && /^[[:space:]]*\}/ {
        in_threshold_block = 0
    }
    /vodMap\.insert\(vod, \{position, true, -1\}\);/ {
        in_new_position_block = 1
    }
    in_new_position_block && /saveSettings\(\);/ {
        found_new_position_save = 1
    }
    in_new_position_block && /^[[:space:]]*\}/ {
        in_new_position_block = 0
    }
    END {
        exit(found_threshold_save && found_new_position_save ? 0 : 1)
    }
' "$vod_manager"; then
    printf 'VodManager must sync existing VOD positions only after a meaningful change and sync new positions immediately.\n' >&2
    exit 1
fi

if ! rg -q 'syncSettings\("channel quality"\)' "$settings_manager"; then
    printf 'SettingsManager must immediately sync per-channel stream quality changes.\n' >&2
    exit 1
fi

if ! rg -q 'syncSettings\("stream quality"\)' "$settings_manager"; then
    printf 'SettingsManager must immediately sync default stream quality changes.\n' >&2
    exit 1
fi

if ! rg -q 'syncSettings\("remember channel quality"\)' "$settings_manager"; then
    printf 'SettingsManager must immediately sync the per-channel quality memory toggle.\n' >&2
    exit 1
fi

for required in \
    'static QString streamNameFromResolution' \
    'static QString playlistUrl(const QString &line, const QUrl &baseUrl)' \
    'attributeValue(str, QStringLiteral("RESOLUTION"))' \
    'attributeValue(str, QStringLiteral("FRAME-RATE"))' \
    'streamName += QString::number(roundedFrameRate)' \
    'baseUrl.resolved(url).toString()'
do
    if ! rg -q -F "$required" "$m3u8_parser"; then
        printf 'M3U8 parser must derive quality names from RESOLUTION/FRAME-RATE when VIDEO/NAME are absent: %s\n' "$required" >&2
        exit 1
    fi
done

if ! rg -q 'm3u8::getUrls\(data, reply->url\(\)\)' "$network_manager"; then
    printf 'NetworkManager must pass the playlist URL to the M3U8 parser so relative variants can be resolved.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$test_connection_reply_block" | rg -q 'if \(!reply\)'; then
    printf 'Network connection test replies must guard missing reply senders.\n' >&2
    exit 1
fi

if ! printf '%s\n' "$test_connection_reply_block" | rg -q 'reply->deleteLater\(\)'; then
    printf 'Network connection test replies must release QNetworkReply objects.\n' >&2
    exit 1
fi
