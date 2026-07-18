# Roadmap

Chameo is a validated personal daily-selfie tool. The roadmap prioritizes
reliable daily capture and timelapse creation before broader library, automation,
or distribution work.

## Now: Daily Use

Use the capture, reminder, and timelapse workflows regularly. Prioritize fixes
for capture loss, inability to save or export, and reminder failures before
expanding the feature set.

## Later

### Capture Experience

- Support the system- and user-preferred cameras, including Continuity Camera,
  while preserving a reliable built-in-camera fallback. Offer camera selection
  only if automatic selection proves insufficient.
- Use Vision face-capture quality to identify captures affected by blur,
  lighting, focus, occlusion, pose, or expression. Prototype a short burst that
  selects the best frame instead of rejecting a single photo against an
  arbitrary quality threshold.
- Explore subtle live framing guidance based on face position, size, eye-line,
  and stability. Consider an optional hands-free countdown after the face
  remains well framed and stable.
- Reconsider a previous-selfie ghost overlay if the current face guide and
  automatic alignment still produce inconsistent timelapses.
- If an iPhone capture companion is pursued, evaluate AVFoundation smart
  framing on supported Center Stage front cameras as a progressive enhancement,
  not a baseline requirement.
- Keep generative photo extension out of the normal capture and alignment
  pipeline. If explored, make it an explicitly labeled, opt-in post-capture
  action, preserve the original photo, and complete a privacy review before
  sending selfies to a cloud service. Evaluate Image Playground for its
  system-provided creative workflow; do not depend on the Photos Spatial
  Reframe feature unless Apple publishes a developer API.

### Automation

- Add Shortcuts/App Intents for `Take Chameo` and `Create Timelapse` after those
  workflows are stable.

## Conditional Distribution

Do this work only after an explicit decision to distribute Chameo beyond the
owner's own Macs:

- Replace ad-hoc development signing with Developer ID or Mac App Store signing.
- Add production release packaging.
- Add notarization.
- Publish a privacy policy for public distribution.

## Completed

- Replaced the scrolling Library list with a month calendar showing captured,
  pending, missed, future, and pre-tracking days.
- Added hover and keyboard-focus day previews with thumbnails, capture time,
  location, multiple-photo selection, and inline deletion.
- Added a shared Photos-backed daily-status model used by both Library and the
  menu bar.
- Added a menu-bar completion indicator that opens Camera while today's Chameo
  is pending and today's Library entry after capture.
- Refreshed the daily completion state after saves, deletion, album changes,
  Library reloads, app activation, wake, and calendar-day changes.
- Completed the 30-day personal validation trial.
- Added timelapse generation using the latest saved Chameo from each of the most
  recent 30 captured days, exported chronologically as a square 1080 x 1080
  H.264 MP4 at 10 photos per second through the standard Save dialog.
- Removed the rolling 30-day Library summary after the validation trial.
- Added Camera, Photos, Location, and Notifications permission recovery actions.
- Added permission-denied status near the action requiring permission.
- Changed Library deletion to remove the original Photos asset behind inline
  confirmation.
- Added loading state for Library reverse geocoding.
- Added the Library empty-state `Take First Chameo` action.
- Renamed preview `Cancel` to `Retake` and added contextual Return and Escape
  keyboard actions.
- Added optional automatic face alignment with square output and fallback to the
  original photo when alignment fails.
- Automatically recreate the configured Photos album on the next save if it was
  deleted externally.
