# Changelog

## 0.3.13

### What’s new

- Polished image previews and timelapse controls.
- Improved accessibility across the app.

### Fixes

- Improved reminder notification routing and cleanup retry behavior.

### Known testing limitations

- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.
- Installation, relaunch, Gatekeeper behavior, and permission persistence are
  covered by tester feedback rather than automated end-to-end UI validation.

## 0.3.12

### What’s new

- Improved notification-triggered camera opens during app startup by deferring
  requests until the UI is ready and reliably foregrounding the camera window.

### Fixes

- None.

### Known testing limitations

- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.
- Installation, relaunch, Gatekeeper behavior, and permission persistence are
  covered by tester feedback rather than automated end-to-end UI validation.

## 0.3.11

### What’s new

- None.

### Fixes

- None.

### Known testing limitations

- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.
- Installation, relaunch, Gatekeeper behavior, and permission persistence are
  covered by tester feedback rather than automated end-to-end UI validation.

## 0.3.10

### What’s new

- None.

### Fixes

- None.

### Known testing limitations

- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.
- Installation, relaunch, Gatekeeper behavior, and permission persistence are
  covered by tester feedback rather than automated end-to-end UI validation.

## 0.3.9

### What’s new

- Redesigned the permission onboarding experience with clearer setup guidance
  and refreshed camera and library previews.
- Added smoother menu bar handoff and window recovery, and made Settings
  available directly from the Chameo popover.

### Fixes

- Kept the permission onboarding window visible while setup is in progress.

### Known testing limitations

- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.
- Installation, relaunch, Gatekeeper behavior, and permission persistence are
  covered by tester feedback rather than automated end-to-end UI validation.

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
