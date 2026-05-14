# CI scripts

The maintained CI entry point for this fork is `.github/workflows/ci.yml`. It
builds Linux Qt 5/mpv, Qt 5/Qt Multimedia, and combined mpv plus Qt Multimedia
targets on Ubuntu 24.04, validates
least-privilege workflow permissions and stale-run cancellation,
desktop/AppStream metadata, checks the install target, runs the Twitch API and emote-ID regression
guards, validates the local OAuth callback parser and stored-token validation,
verifies that preserved legacy release helpers keep their explicit opt-in
guard, validates source-build documentation, checks that the upstream issue
triage covers every audited open issue,
validates Android package metadata, validates the QML resource manifest
and Ubuntu runtime module dependencies, validates bundled-font setup, checks
remote-image and notification-image fallback handling, checks window/menu
contracts, validates emote-picker selection guards, validates modern Qt helper
code, validates HTML entity helpers, guards playback recovery behavior, and
smoke-tests the HLS master-playlist parser.

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

Use the README source build steps or the GitHub Actions workflow as the
supported automation baseline.
