# CI scripts

The maintained CI entry point for this fork is `.github/workflows/ci.yml`. It
builds Linux Qt 5/mpv, Qt 5/Qt Multimedia, and combined mpv plus Qt Multimedia
targets on Ubuntu 24.04, builds the macOS Qt 5/mpv source target on the
`macos-15` GitHub-hosted runner with Homebrew `qt@5` and `mpv`, builds the
Windows Qt 5/mpv source target on the `windows-2025-vs2026` runner with MSYS2 UCRT64,
validates
least-privilege workflow permissions and stale-run cancellation,
GitHub issue templates,
GitHub community health files,
desktop/AppStream metadata, checks the install target, validates the Twitch API
surface inventory, runs the Twitch API and emote-ID regression guards, validates
the local OAuth callback parser and stored-token validation,
verifies that preserved legacy release helpers keep their explicit opt-in
guard, validates source-build documentation, validates the release-readiness
matrix, checks that the upstream issue
triage covers every audited open issue,
validates Android package metadata, validates Apple bundle metadata,
validates the QML resource manifest
and Ubuntu runtime module dependencies, validates bundled-font setup, checks
remote-image and notification-image fallback handling, checks window/menu
contracts, validates logging contracts, validates emote-picker selection guards,
validates VOD-view state guards, validates maintained shell scripts with
ShellCheck, validates modern Qt helper code, validates HTML entity helpers,
guards playback recovery behavior, and smoke-tests the HLS master-playlist
parser.

The Ubuntu dependency installer uses bounded apt timeouts plus apt download
retries so a transient package mirror stall fails cleanly instead of hanging a
matrix job. The install timeout is intentionally large enough for the combined
mpv plus Qt Multimedia package set on a slow mirror, and the workflow timeout is
long enough for the bounded retries to finish. The timeout wrapper runs under
`sudo` with a short kill-after grace period so stalled apt child processes do not
survive the wrapper. The
update/install timeouts can be tuned with `ORION_CI_APT_UPDATE_TIMEOUT` and
`ORION_CI_APT_INSTALL_TIMEOUT`.

Qmake invocations go through `ci/run_qmake.sh`, which accepts an explicit
`QMAKE` override and otherwise selects the available Qt 5 `qmake` or
`qmake-qt5` executable.

To reproduce the Linux workflow locally without installing Qt build
dependencies on the host, run `ci/check_ubuntu_container_ci.sh`. It uses Podman
or Docker with an Ubuntu 24.04 image, runs the maintained static checks and HLS
parser smoke test, and builds/installs the mpv, Qt Multimedia, and combined
backend matrix. Set `CONTAINER_ENGINE`, `ORION_CI_CONTAINER_IMAGE`, or
`ORION_CI_CONTAINER_VOLUME_SUFFIX` to override the defaults.

GitHub Actions versions are monitored by Dependabot through
`.github/dependabot.yml`, and the workflow hygiene guard verifies that weekly
GitHub Actions update checks stay enabled. The workflow hygiene guard also
verifies that CI-invoked shell scripts keep their committed executable bit. CI
also runs
`ci/check_patch_whitespace.sh` to check the committed patch for whitespace
errors without rewriting legacy files that predate this fork.

The other scripts in this directory are legacy upstream Travis/AppVeyor release
helpers. They reference old Qt, Android, OpenSSL, mpv, and deployment tooling
and are not used by the current GitHub Actions workflow. They now require an
explicit opt-in so they are not run accidentally:

```sh
ORION_ALLOW_LEGACY_CI=1 ci/prepare_linux.sh
```

The guarded Windows OpenSSL helper no longer downloads obsolete OpenSSL 1.0.x
or NASM installers. If a maintainer intentionally uses it, provide a matching
Windows OpenSSL build output directory with `ORION_WINDOWS_OPENSSL_DIR`.

Use the README source build steps or the GitHub Actions workflow as the
supported automation baseline.
