
# Orion

[![CI](https://github.com/belagrf/orion/actions/workflows/ci.yml/badge.svg)](https://github.com/belagrf/orion/actions/workflows/ci.yml)

Maintained fork of [alamminsalo/orion](https://github.com/alamminsalo/orion), which was archived by its original author in May 2020.

QML/C++-written desktop client for Twitch.tv

## Fork status

This fork starts from the final upstream `master` state and focuses on keeping the desktop build usable on current Linux/Qt5 systems. It includes the unmerged upstream crash fix from PR #303, safer mpv hardware decoding defaults, dynamic search pagination for large windows, VOD resume persistence fixes, modern high-DPI setup, and GitHub Actions CI.

Some old upstream issues are broad feature requests or depend on Twitch API behavior that has changed since the original project was archived. See `docs/upstream-issue-triage.md` for the current issue audit.

## Downloads

This fork currently validates source builds on Linux through GitHub Actions. Revalidated Windows, macOS, Android, and F-Droid packages are not published yet; check the GitHub Releases page for any available builds, otherwise use the source build steps below. Android source status is tracked in `docs/android.md`. Twitch directory, search, and VOD metadata use Helix and require either logging in, providing an app access token, or allowing Orion to request one with user-supplied Twitch app credentials; followed-channel and account actions still require logging in.

The maintained automation entry point is `.github/workflows/ci.yml`. Older release helper scripts under `ci/` are preserved for reference only, require an explicit legacy opt-in before running, and should not be treated as current build instructions.

## Features: 

* Login by twitch credentials
* Desktop notifications
* Integrated player
* Chat support
* Support for live streams and vods

## Screencaptures

<img src="https://user-images.githubusercontent.com/5585454/27839943-cc1834ae-60fd-11e7-9b87-d3aaf5f7483c.png" width="128">	<img src="https://user-images.githubusercontent.com/5585454/27839974-fb7a6d3e-60fd-11e7-8638-9214fe5a1355.png" width="128">	<img src="https://user-images.githubusercontent.com/5585454/27840060-adef907a-60fe-11e7-88c5-72c83ec60d1d.png" width="128">	<img src="https://user-images.githubusercontent.com/5585454/27840062-b2f14eba-60fe-11e7-9e04-7d12477519d7.png" width="128">	<img src="https://user-images.githubusercontent.com/5585454/27840063-b6429fce-60fe-11e7-9e96-54d6d0657953.png" width="128">

## Dependencies

* Qt 5.15 development tools and QML modules
* `mpv` and `libmpv` development headers
* `pkg-config`
* Optional Linux journal logging: `libsystemd` development headers
* Optional legacy backends: `qtav` or `qt5-multimedia`

## Building on Linux and FreeBSD

The first command uses Arch Linux package names; distro-specific notes follow.

Run the commands in this section from a terminal application, such as Terminal, Konsole, GNOME Terminal, or another shell.

#### Install needed libraries and software

```
sudo pacman -S git gcc qt5-base qt5-svg qt5-quickcontrols2 qt5-graphicaleffects mpv
```

Ubuntu/Linux Mint:

```
sudo apt install build-essential libmpv-dev libsystemd-dev pkg-config qt5-qmake qtbase5-dev qtdeclarative5-dev qtquickcontrols2-5-dev qml-module-qtquick2 qml-module-qtquick-controls2 qml-module-qtquick-layouts qml-module-qtquick-window2 qml-module-qtgraphicaleffects qml-module-qt-labs-settings
```

If the app builds but the window does not appear, run `orion --debug` from a terminal and look for missing QML module messages.

Fedora:

```
sudo dnf install git gcc-c++ make mpv mpv-libs-devel pkgconf-pkg-config qt5-qtbase-devel qt5-qtdeclarative-devel qt5-qtgraphicaleffects qt5-qtquickcontrols2-devel qt5-qtsvg-devel systemd-devel
```

Fedora packages should prefer the mpv backend. The Qt Multimedia backend uses
GStreamer and needs `qt5-qtmultimedia-devel` plus working GStreamer H.264/AAC
plugins from Fedora or RPM Fusion; missing or incompatible GStreamer plugins can
produce audio-only playback or immediate playback failures.

FreeBSD:

```
pkg install qt5-buildtools qt5-qmake qt5-core qt5-declarative qt5-graphicaleffects \
  qt5-gui qt5-network qt5-quickcontrols2 qt5-widgets mpv
```

On FreeBSD, the default install prefix is `/usr/local`.

If using backend other than mpv, install those packages instead. Packagers can build multiple backends into one binary by passing more than one backend flag, for example `CONFIG+=mpv CONFIG+=multimedia`. The GitHub Actions workflow validates separate mpv and Qt Multimedia builds as well as a combined mpv plus Qt Multimedia build. At startup, Orion removes a compiled backend from the in-app selector if its QML module cannot load and falls back to another compiled backend when one is available.

If a FreeBSD build fails at runtime with unresolved `QSslSocket` or OpenSSL
symbols, check that the runtime Qt Network package and OpenSSL libraries come
from the same package set. Orion logs the Qt build/runtime SSL library versions
when Qt reports SSL support is unavailable. Old FreeBSD 11-era reports of
`SSL_CTX_set1_groups` failures were consistent with an SSL runtime mismatch
rather than an Orion-only crash.

#### Choosing player backend (optional)
To select one or more backends, pass suitable CONFIG variables to the Qt 5 qmake wrapper (alternatively edit straight to `.pro` file):

* MPV: `CONFIG+=mpv`
* QtAV: `CONFIG+=qtav`
* Qt5 Multimedia: `CONFIG+=multimedia`

As default, mpv is used if nothing is passed. When more than one backend is built, the player setting becomes visible and Orion can fall back to another compiled backend if the selected backend cannot load at runtime.

On Ubuntu/Linux Mint, the Qt Multimedia backend also needs `qtmultimedia5-dev` at build time and `qml-module-qtmultimedia` at runtime.

#### Get orion from github and install

```
git clone https://github.com/belagrf/orion
cd orion
mkdir build && cd build
../ci/run_qmake.sh ../
make -j"$(nproc)"
```

To try the build before installing it system-wide:

```
./orion --debug
```

To install it into the default prefix (`/usr` on Linux, `/usr/local` on FreeBSD):

```
sudo make install
```

Open a channel directly from a launcher or shell:

```
orion --channel channelname
orion https://www.twitch.tv/channelname
```

Search commands:

```
/game Just Chatting
/language en
```

Optional logged-out Twitch metadata:

```
ORION_TWITCH_CLIENT_ID=your_client_id ORION_TWITCH_APP_ACCESS_TOKEN=your_app_access_token orion
```

The app access token must belong to the same Twitch app as the client ID, and it expires according to Twitch's OAuth response. This is only used for public Helix metadata such as streams, categories, VOD listings, badges, emote sets, and Cheermotes; user-specific follows, chat login, chatters, and block-list actions still need the in-app Twitch login.

Alternatively, Orion can request and refresh a short-lived app access token when both values are present:

```
ORION_TWITCH_CLIENT_ID=your_client_id ORION_TWITCH_CLIENT_SECRET=your_client_secret orion
```

Only use the client-secret form for local/private runs where you can protect that secret. Do not ship a Twitch client secret in a public package or launcher.

Useful logging options:

```
orion --debug
orion --log-level debug --log-file /tmp/orion.log
orion --journal
orion --stdout-log-level info --stderr-log-level warning
orion --log-file /tmp/orion.log --file-log-level debug
orion --journal-log-level warning
```

Valid log levels are `debug`, `info`, `warning`, `critical`, `fatal`, and `off`.
`--stdout-log-level` controls debug/info messages, while `--stderr-log-level` controls
warning/fatal messages. `--quiet` disables stdout and stderr without disabling the
in-app log viewer, file logging, or journal logging.

Load an mpv config file when using the mpv backend:

```
orion --libmpv-config ~/.config/orion/mpv.conf
```

## Building on MacOS

macOS packaging has not been revalidated in this fork. The bundle metadata is
kept current for local source builds, but no signed or notarized `.app` package
is published yet.

#### Install needed libraries and software

```
brew install qt@5 mpv
```
Make sure the Qt 5 `qmake` is on `PATH`.

#### Get orion from github and install

```
git clone https://github.com/belagrf/orion
cd orion
mkdir build && cd build
../ci/run_qmake.sh ../
make
```

There will now be an orion.app application in the build directory.

## Qt version

Minimum supported Qt version for this fork is currently 5.15.


## Misc

Supports environment variables such as `QT_QUICK_CONTROLS_MATERIAL_ACCENT`, to customize UI colors. 

### Example

```
# linux example, but similar in other OSes
QT_QUICK_CONTROLS_MATERIAL_BACKGROUND="#00101f" QT_QUICK_CONTROLS_MATERIAL_ACCENT="#FF5722" orion
```

And this looks like:

<img src="https://user-images.githubusercontent.com/5585454/42691905-8438a3fe-86b2-11e8-821e-c4a6bbb8ff08.png" width="256">

See more on [qt material docs](https://doc.qt.io/qt-5/qtquickcontrols2-material.html).


## Windows troubleshooting

Revalidated Windows installers are not published from this fork yet. If you are
testing an older Windows build or a local Windows build and it fails to start
because the MSVC runtime is missing, install Microsoft's latest supported Visual
C++ Redistributable for Visual Studio 2015, 2017, 2019, and 2022:
<https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist>

If a Windows build starts but every content tab stays empty or only shows a
connection error after login, run it with `--debug` and check the Qt Network SSL
messages. Older Orion Windows builds could silently load OpenSSL DLLs from the
wrong architecture; local Windows packages must ship SSL libraries that match
the executable and Qt build. The qmake project stages modern
`libs/libssl*.dll` and `libs/libcrypto*.dll` files when present, while still
recognizing the old `ssleay32.dll` / `libeay32.dll` names used by older Qt
packages.

## Known limitations

* Native live and VOD playback still depends on Twitch playlist-token endpoints that are not documented as a supported Helix API. If Orion cannot load a playable playlist, use the player header action to open the channel or VOD on twitch.tv.
* Twitch's Helix viewer-list API requires the logged-in user to be the broadcaster or one of the broadcaster's moderators with the `moderator:read:chatters` scope. Orion falls back to Twitch's legacy TMI chatters endpoint when Helix chatters are unavailable, but that fallback is best-effort.
* VOD replay chat is not available through Twitch's current supported APIs. Orion shows a chat notice for VOD playback and links users to the Twitch VOD fallback at the current playback time.
