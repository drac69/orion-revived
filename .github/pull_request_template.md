## Summary

Describe the user-visible change and the upstream issue, platform, or release
gap it addresses.

## Validation

List the commands, CI jobs, devices, or manual checks you ran.

## Scope checklist

- [ ] I updated documentation or triage notes when behavior, support status, or
      known limitations changed.
- [ ] I added or updated a focused CI guard when the change can be checked
      without private credentials or target hardware.
- [ ] I did not include OAuth tokens, Twitch client secrets, cookies, passwords,
      signing keys, keystore passwords, or private logs.
- [ ] Twitch API changes are backed by current official Twitch documentation, or
      the PR explicitly documents a fallback/product decision.
- [ ] Android changes include the Qt/SDK/NDK/toolchain versions and target-device
      validation results, or keep Android release publishing retired and disabled.
- [ ] Packaging changes do not claim signed Windows installers, signed/notarized
      macOS packages, Play Store packages, F-Droid packages, or APK releases
      unless those artifacts are actually produced and validated.
