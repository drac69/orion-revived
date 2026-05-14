# Security Policy

## Supported versions

Security fixes are accepted for the current `modernize-maintenance` branch and
the latest GitHub Release from this fork. The archived upstream repository and
old binary packages are not maintained here.

Android packages, signed Windows installers, and signed or notarized macOS
packages are not currently published by this fork. Treat reports about those
channels as source-maintenance or packaging-validation work unless a maintained
artifact from this fork exists.

## Reporting a vulnerability

Do not disclose exploitable details, OAuth tokens, Twitch client secrets,
cookies, passwords, signing keys, keystore passwords, or private logs in public
issues or pull requests.

If GitHub private vulnerability reporting is available for this repository, use
it. Otherwise, open a minimal public issue that describes the affected component
without sensitive details and ask for a private contact path.

Useful non-sensitive context:

* Tested Orion version or commit.
* Operating system and package source.
* Qt, mpv, OpenSSL, or GStreamer versions if relevant.
* Whether the issue needs login, app access tokens, or Twitch client
  credentials.
* Redacted logs showing the failing code path.

Public hardening or dependency update pull requests are welcome when they do
not expose secrets or live exploit details.
