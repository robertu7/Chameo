# Changelog

## 0.3.8

### What’s new

- Timelapse exports now include every saved Chameo photo in chronological order,
  including multiple photos captured on the same day.

### Fixes

- None.

### Known testing limitations

- Full-history selection is covered by automated tests, but export with a large
  or iCloud-backed photo library has not been manually validated.
- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.
- Installation, relaunch, Gatekeeper behavior, and permission persistence are
  covered by tester feedback rather than automated end-to-end UI validation.

## 0.3.7

### What’s new

- Added a disk image for first-time installation, with an Applications shortcut
  for drag-and-drop setup.
- Renamed the automatic language option to “Follow System” for clearer behavior
  in English, Simplified Chinese, and Traditional Chinese.

### Fixes

- None.

### Known testing limitations

- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.
- Installation, relaunch, Gatekeeper behavior, and permission persistence are
  covered by tester feedback rather than automated end-to-end UI validation.

## 0.3.6

### What’s new

- Added user-confirmed Sparkle updates with daily automatic checks and a manual
  check in General Settings.
- Added Apple Silicon CI, tagged GitHub prereleases, signed update archives, and
  a signed GitHub Pages appcast.

### Fixes

- None.

### Known testing limitations

- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.
- Installation, relaunch, Gatekeeper behavior, and permission persistence are
  covered by tester feedback rather than automated end-to-end UI validation.
