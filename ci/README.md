# CI scripts

The maintained CI entry point for this fork is `.github/workflows/ci.yml`. It
builds the Linux Qt 5/mpv target on Ubuntu 24.04, validates desktop/AppStream
metadata, checks the install target, runs the Twitch API and emote-ID regression
guards, validates Android package metadata, validates the QML resource manifest
and HTML entity helpers, guards playback recovery behavior, and smoke-tests the
HLS master-playlist parser.

The other scripts in this directory are legacy upstream Travis/AppVeyor release
helpers. They reference old Qt, Android, OpenSSL, mpv, and deployment tooling
and are not used by the current GitHub Actions workflow. They now require an
explicit opt-in so they are not run accidentally:

```sh
ORION_ALLOW_LEGACY_CI=1 ci/prepare_linux.sh
```

Use the README source build steps or the GitHub Actions workflow as the
supported automation baseline.
