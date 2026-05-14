# Release readiness

This document records what the maintained fork can currently ship, what CI
validates, and which blocker issues remain open.

## Current policy

Official maintained releases are source-only. The current public release is the
source-only release `v1.6.9`:

* <https://github.com/belagrf/orion-revived/releases/tag/v1.6.9>

GitHub Actions validates the maintained source-build matrix:

* Linux Qt5/mpv on Ubuntu 24.04.
* Linux Qt5/Qt Multimedia on Ubuntu 24.04.
* Linux Qt5/mpv plus Qt Multimedia on Ubuntu 24.04.
* macOS Qt5/mpv on the `macos-15` GitHub-hosted runner.
* Windows Qt5/mpv on the `windows-2025-vs2026` runner with MSYS2 UCRT64.

CI build outputs prove source-build compatibility for those environments. They
are validation evidence, not release artifacts, and do not by themselves prove
signed installers, notarized `.app` bundles, Android packages, Play Store
packages, F-Droid packages, or target-device runtime behavior.

The desktop release-channel decision is source-only for this maintained fork.
That decision is recorded in [issue #3](https://github.com/belagrf/orion-revived/issues/3).

## Matrix

| Area | Current status | Evidence | Remaining blocker |
| --- | --- | --- | --- |
| Source release | Ready for source-only publication | `v1.6.9`, `README.md`, `.github/workflows/ci.yml` | None for source-only releases |
| Linux source build | Validated in CI | Ubuntu 24.04 Linux Qt5/mpv, multimedia, and combined jobs | Distro package publication remains maintainer/distribution work |
| macOS source build | Validated in CI | `macos-15` Qt5/mpv job | None for the source-only release policy; signed or notarized macOS packages are not published |
| Windows source build | Validated in CI | `windows-2025-vs2026` MSYS2 UCRT64 Qt5/mpv job | None for the source-only release policy; signed Windows installers are not published |
| Android/F-Droid | Retired release channel, source-level metadata retained | `docs/android.md`, `metadata/app.orion.android.yml`, Android/F-Droid metadata guards | None for source-only releases; Android/F-Droid metadata must stay disabled unless a future maintainer supplies a reproducible build recipe and target-device or emulator validation. Decision recorded in [issue #2](https://github.com/belagrf/orion-revived/issues/2) |
| Twitch Helix metadata | Maintained where official APIs exist | `ci/check_twitch_api_guard.sh`, `ci/check_twitch_api_surface.sh`, `docs/twitch-api-surface.md`, `docs/upstream-issue-triage.md` | Reports need official Twitch documentation or a documented fallback |
| Native Twitch HLS, replay chat, rewards-credit behavior | Fallback-supported, not a supported native API claim | `docs/twitch-api-surface.md`, player header twitch.tv fallback, replay-chat notice, Twitch API guards | None for source-only releases; unsupported Twitch playlist-token, replay-chat, and rewards behavior are documented fallback decisions with validation evidence in [issue #1](https://github.com/belagrf/orion-revived/issues/1) |

## Closure criteria

Issue #1 is closed for the source-only release after every remaining Twitch
playback/replay/rewards path either uses current official Twitch documentation
or has an intentional product decision that keeps users on the twitch.tv
fallback instead of claiming native support. The current product decision and
source inventory live in `docs/twitch-api-surface.md`.
Do not ship a Twitch client secret in a public package or launcher.

Issue #2 is closed by retiring Android/F-Droid publishing as a maintained release
channel for this fork. Future restoration requires reproducible Android build
commands plus target-device or emulator evidence covering playback,
phone-call/audio-focus behavior, lifecycle/backgrounding behavior, chat, emote
resolution, settings persistence, and install/update behavior. Until then,
Android/F-Droid metadata must stay disabled.

Issue #3 is closed by documenting source-only releases as the intentional
desktop release policy. Future signed/notarized desktop artifacts would need a
new release-channel decision plus checksums, signing/notarization evidence, and
install/run validation on clean target systems.
