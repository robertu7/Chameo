# Roadmap

Chameo is a validated personal daily-selfie tool. The roadmap prioritizes
reliable daily capture and timelapse creation before broader library, automation,
or distribution work.

## Now: Daily Use

Use the capture, reminder, and timelapse workflows regularly. Prioritize fixes
for capture loss, inability to save or export, and reminder failures before
expanding the feature set.

## Later

- Add a calendar history view for browsing captured and missed days.
- Add a menu-bar indicator showing whether today's Chameo has been captured.
- Add Shortcuts/App Intents for `Take Chameo` and `Create Timelapse` after those
  workflows are stable.
- Reconsider a previous-selfie ghost overlay only if the 30-day trial shows that
  the current face guide and automatic alignment produce insufficient results.

## Conditional Distribution

Do this work only after an explicit decision to distribute Chameo beyond the
owner's own Macs:

- Replace ad-hoc development signing with Developer ID or Mac App Store signing.
- Add production release packaging.
- Add notarization.
- Publish a privacy policy for public distribution.

## Completed

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
