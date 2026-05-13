
# Orion

[![CI](https://github.com/belagrf/orion/actions/workflows/ci.yml/badge.svg)](https://github.com/belagrf/orion/actions/workflows/ci.yml)

Maintained fork of [alamminsalo/orion](https://github.com/alamminsalo/orion), which was archived by its original author in May 2020.

QML/C++-written desktop client for Twitch.tv

## Fork status

This fork starts from the final upstream `master` state and focuses on keeping the desktop build usable on current Linux/Qt5 systems. It includes the unmerged upstream crash fix from PR #303, safer mpv hardware decoding defaults, dynamic search pagination for large windows, VOD resume persistence fixes, modern high-DPI setup, and GitHub Actions CI.

Some old upstream issues are broad feature requests or depend on Twitch API behavior that has changed since the original project was archived. See `docs/upstream-issue-triage.md` for the current issue audit.

## Downloads

This fork currently validates source builds on Linux through GitHub Actions. Revalidated Windows and macOS installers are not published yet; check the GitHub Releases page for any available builds, otherwise use the source build steps below.

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

## Building on linux

(Using arch linux examples, but can be applied to other distros as well)

Run the commands in this section from a terminal application, such as Terminal, Konsole, GNOME Terminal, or another shell.

#### Install needed libraries and software

```
sudo pacman -S git gcc qt5-base qt5-quickcontrols qt5-svg qt5-quickcontrols2 qt5-graphicaleffects mpv
```

Ubuntu/Linux Mint:

```
sudo apt install build-essential libmpv-dev libsystemd-dev pkg-config qt5-qmake qtbase5-dev qtdeclarative5-dev qtquickcontrols2-5-dev qml-module-qtquick2 qml-module-qtquick-controls qml-module-qtquick-controls2 qml-module-qtquick-layouts qml-module-qtquick-window2 qml-module-qtgraphicaleffects
```

If the app builds but the window does not appear, run `orion --debug` from a terminal and look for missing QML module messages. On Ubuntu-style distributions, the bundled QML imports also need `qml-module-qt-labs-settings`.

FreeBSD:

```
pkg install qt5-buildtools qt5-core qt5-declarative qt5-graphicaleffects qt5-gui \
  qt5-network qt5-quickcontrols2 qt5-widgets mpv
```

If using backend other than mpv, install those packages instead.

#### Choosing player backend (optional)
To select a backend used, pass CONFIG-variable a suitable backend for qmake (alternatively edit straight to .pro file):

* MPV: `CONFIG+=mpv`
* QtAV: `CONFIG+=qtav`
* Qt5 Multimedia: `CONFIG+=multimedia`

As default, mpv is used (if nothing is passed)

#### Get orion from github and install

```
git clone https://github.com/belagrf/orion
cd orion
mkdir build && cd build
qmake ../
make -j"$(nproc)"
```

To try the build before installing it system-wide:

```
./orion --debug
```

To install it into the default prefix:

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

Useful logging options:

```
orion --debug
orion --log-level debug --log-file /tmp/orion.log
orion --journal
```

Load an mpv config file when using the mpv backend:

```
orion --libmpv-config ~/.config/orion/mpv.conf
```

## Building on MacOS

macOS packaging has not been revalidated in this fork.

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
qmake ../
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

You need Visual C++ 2015-runtime installed. 

Installer can be found in the application's install directory (I'll make it install automatically in the next version)

## Known issues

* If network goes down while Orion is running, the images stop loading until application restart. Otherwise the application should work fine after network is back up
* Sometimes the stream hangs and doesn't load on start. Restarting the stream should work
* Vods are sometimes having issues, skipping some parts of the video. Needs further investigating
