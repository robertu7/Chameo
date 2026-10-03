# Changelog

Testing limitations below describe the status at each release. The owner
subsequently confirmed the complete photo workflow and reminders/Sparkle
update workflow as validated on October 3, 2026; see the current
[manual validation record](docs/testing/daily-workflows.md).

## 0.5.2

### What’s new

- Added Timelapse date filters for All Photos, Month, and Year, plus 5, 10, or
  15 photos-per-second playback speeds. The selected photos and estimated
  duration update together; defaults remain All Photos and 10 photos/sec.

### Fixes

- Kept the expanded Timelapse options and Create action visible in the revised
  export window, with controls localized in English and both Chinese variants.

### Known testing limitations

- Interactive menu selection and exports using the new date and speed options
  with a populated Photos/iCloud library still need live validation; the new
  states have automated tests and fixture renders.
- VoiceOver, full keyboard traversal, system accessibility settings, and
  permission denial/recovery need live validation.
- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.

## 0.5.1

### What’s new

- Release appcast feeds are now re-signed and verified after final version
  edits. A guarded workflow can repair an existing feed signature without
  changing release tags or downloads.

### Fixes

- Preserved the More menu’s full circular control as its click target.

### Known testing limitations

- Camera capture and switching, local-copy restoration and deletion, real
  Photos/iCloud handling, and Timelapse generation and playback still need live
  device and library checks.
- VoiceOver, full keyboard traversal, system accessibility settings, and
  permission recovery need live validation.
- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.

## 0.5.0

### What’s new

- Added **Save Local Copy** to Photo Actions to restore a missing original, and
  an option to move its local copy to Trash when deleting the Photos asset.
- Refreshed Camera, Library, Settings, Timelapse, and onboarding with clearer
  navigation, fixed-size layouts, localized illustrations, and help for local
  copies.
- Reworked Timelapse export as a dedicated in-app flow with phase-specific
  status, completed-photo progress, and explicit Open Folder and Open Video
  actions.
- Requires macOS 26 or newer.

### Fixes

- Improved window fit, album-selection guidance, selector and menu accessibility,
  and progress reporting during iCloud downloads.

### Known testing limitations

- Camera capture and switching, local-copy restoration and deletion, real
  Photos/iCloud handling, and Timelapse generation and playback still need live
  device and library checks.
- VoiceOver, full keyboard traversal, system accessibility settings, and
  permission recovery need live validation.
- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.

## 0.5.0-rc.6

### What’s new

- Timelapse progress now tracks completed photos consistently across loading,
  iCloud downloads, encoding, and saving, with separate text for the current
  phase.

### Fixes

- Prevented iCloud download progress from changing the meaning of the main
  completed-photo progress bar.

### Known testing limitations

- Real Photos/iCloud handling and Timelapse generation and playback still need
  validation with a populated test library.
- VoiceOver, full keyboard traversal, and system accessibility settings need
  live checks; automated tests do not prove native announcements and controls.
- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.

## 0.5.0-rc.5

### What’s new

- Unified Camera/Library and Settings selectors plus app and photo menus with
  consistent glass controls, arrow-key navigation, and clearer labels.
- Added a compact Local Copies help popover explaining storage behavior and
  improved album-selection guidance.

### Fixes

- Removed duplicated album-picker accessibility announcements and improved
  Settings content fit in the fixed-size window.

### Known testing limitations

- Bright/dark glass contrast, hover and disabled states, full keyboard traversal,
  VoiceOver, and system accessibility settings still need live validation.
- Real camera capture/save, permission recovery, real Photos/iCloud handling,
  and Timelapse generation and playback need hardware/library checks.
- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.

## 0.5.0-rc.4

### What’s new

- Refreshed the Camera, Library, Settings, Timelapse, and onboarding screens
  with consistent fixed-size layouts and clearer navigation.
- Added onboarding portrait and story illustrations, with updated copy localized
  in English, Simplified Chinese, and Traditional Chinese.

### Fixes

- Adjusted Settings spacing, album selection layout, and onboarding illustration
  sizing to keep content visible in the fixed-size windows.

### Known testing limitations

- Live inspection of native glass, Settings tabs, switch appearance, and keyboard
  focus is still needed; fixture captures do not establish compositor behavior.
- Camera capture and switching, real Photos/iCloud handling, permission recovery,
  Timelapse playback, VoiceOver, and system accessibility settings need live
  validation.
- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.

## 0.5.0-rc.3

### What’s new

- Redesigned the Timelapse export flow around a shared photo stack and video
  summary, with phase-specific progress and clear completion actions.
- Localized the updated setup, creating, and created states in English,
  Simplified Chinese, and Traditional Chinese.

### Fixes

- None.

### Known testing limitations

- Real Photos/iCloud downloads, playable exported video, and Open Video/Open
  Folder actions still need validation with a populated test library.
- Keyboard focus, VoiceOver, permission recovery, and system accessibility
  settings need live checks; fixture renders do not verify all native behavior.
- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.

## 0.5.0-rc.2

### What’s new

- Refined the compact Timelapse panel with phase-specific progress, a clear
  empty-album path back to Camera, and a fixed footer for cancel, retry, and
  result actions.

### Fixes

- None.

### Known testing limitations

- Native Timelapse routing, live thumbnails, Photos/iCloud progress, and result
  actions still need validation with a populated test library.
- Keyboard focus, VoiceOver, native glass, and permission recovery need live
  checks; fixture renders do not verify native hit targets or chrome.
- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.

## 0.5.0-rc.1

### What’s new

- Timelapse completion now stays in Chameo with explicit Open Folder and Open
  Video actions. Exports no longer request notification permission or send
  completion notifications.
- Reduced the default Settings and Timelapse window sizes and refined Library
  header alignment.

### Fixes

- None.

### Known testing limitations

- Timelapse photo/iCloud handling, the Open Folder/Open Video actions, and
  remembered export behavior after relaunch still need live validation.
- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.

## 0.5.0-rc.0

### What’s new

- Added **Save Local Copy** to Photo Actions to restore a missing original, and
  an option to move an intact local copy to Trash when deleting its Photos asset.
- Added a dedicated Settings window with General, Capture, Reminders, and Photos
  categories, plus macOS 26 Liquid Glass controls and accessibility support.
- Requires macOS 26 or newer.

### Fixes

- None.

### Known testing limitations

- Local-copy restoration, Photos/iCloud deletion, and optional local-copy
  trashing still need live-library and permission-persistence validation.
- Timelapse photo and iCloud handling, notification actions, and remembered-file
  behavior after relaunch are not covered by automated end-to-end validation.
- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.

## 0.4.3

### What’s new

- Original photo copies now save to `Pictures/Chameo` by default, with an Open
  Folder action in Photos settings.

### Fixes

- None.

### Known testing limitations

- Local photo folder access, permission persistence, and offline export still
  need manual validation.
- Timelapse photo and iCloud handling, notification actions, and remembered-file
  behavior after relaunch are not covered by automated end-to-end validation.
- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.

## 0.4.2

### What’s new

- Added optional local copies of original photos, with folder selection and
  reuse during timelapse export.

### Fixes

- Improved utility-window sizing and timelapse-window reopening behavior.

### Known testing limitations

- Local photo folder access, permission persistence, and offline export still
  require manual validation.
- Timelapse photo and iCloud handling, notification actions, and remembered-file
  behavior after relaunch are not covered by automated end-to-end validation.
- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.

## 0.4.1

### What’s new

- Moved timelapse creation into a dedicated resizable window, with local photo
  previews and clearer export progress and completion details.

### Fixes

- None.

### Known testing limitations

- Timelapse photo and iCloud handling, notification actions, and remembered-file
  behavior after relaunch are not covered by automated end-to-end validation.
- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.

## 0.4.0

### What’s new

- Added a persistent timelapse export experience with progress, iCloud download
  status, cancellation, retry, and a completion notification with Open Folder.

### Fixes

- None.

### Known testing limitations

- Timelapse photo and iCloud handling, notification actions, and remembered-file
  behavior after relaunch are not covered by automated end-to-end validation.
- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.

## 0.3.15

### What’s new

- None.

### Fixes

- Clear Chameo reminder notifications before Sparkle replaces an ad-hoc build.
- Suspend reminder scheduling during update cleanup and refuse replacement when
  cleanup cannot be verified.

### Known testing limitations

- Existing notifications created by prior ad-hoc builds are not repaired by
  this update.
- Native Sparkle installation, relaunch, Notification Center click routing,
  Gatekeeper behavior, and permission persistence remain covered by tester
  feedback rather than automated end-to-end UI validation.

## 0.3.14

### What’s new

- None.

### Fixes

- Retained framing guidance’s ready state during transient camera movement.

### Known testing limitations

- Stage 1 builds are ad-hoc signed and are not notarized by Apple.
- macOS may request Camera, Photos, Location, or Notification permission again
  after an update.
- Installation, relaunch, Gatekeeper behavior, and permission persistence are
  covered by tester feedback rather than automated end-to-end UI validation.

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
