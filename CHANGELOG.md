# Changelog

## 1.6.3 — 2026-11-06

First independent release maintained by 20suiWXJB, based on gao-sun/eul.

- Improve Apple Silicon sensor decoding and GPU detection, tested on Apple M4 Pro.
- Populate CPU and memory process lists when opening their menus.
- Add a setting to show or hide units in status bar readings.
- Check this fork's releases and use manual DMG updates. Migrate legacy automatic-update preferences to status bar notifications.
- Provide a universal DMG, SHA256 checksum, and CI regression/build workflow.

Requires macOS 12.0 or later. The app uses ad-hoc signing and is not notarized. It retains the original app identifier and replaces an existing eul installation. Hardware verification is limited to Apple M4 Pro; Widget data sharing is disabled in local Debug builds and has not been verified in Release builds.
