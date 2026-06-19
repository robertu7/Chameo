# Roadmap

Chameo is currently a personal daily-selfie tool. The roadmap prioritizes a
reliable daily capture habit before broader library, automation, or distribution
work.

## Now

- Rename preview `Cancel` to `Retake`. Retaking discards the in-memory preview
  and returns to the live camera.
- Add contextual keyboard actions:
  - Return takes a photo from the live camera.
  - Return saves the captured preview to Photos.
  - Escape discards the preview and returns to the live camera.
- Add a compact rolling 30-day summary at the top of Library:
  - Count at most one captured day per local calendar day.
  - Treat completed local days without a photo as missed; today is pending.
  - Start tracking on the date of the album's first Chameo.
  - Before 30 days have elapsed, show captured days against elapsed days.
  - Show the missed dates alongside the captured-day count.

## Validation Gate

Run a 30-day personal trial before expanding the feature set.

The trial passes when:

- At least 27 of 30 local calendar days contain a Chameo in the configured
  album.
- Every counted photo is visually usable when the trial set is reviewed
  manually.
- There is no recurring critical failure. A critical failure is capture loss,
  inability to save, or reminder failure; recurring means the same underlying
  cause occurs more than once.

One-off recoverable external failures and cosmetic defects should be recorded,
but do not automatically fail the trial. If the gate is missed, classify each
miss as behavior, reminder, capture UX, or reliability, fix the dominant causes,
and repeat the trial before adding new features.

## Next: Timelapse

After the validation gate passes, add timelapse generation:

- Use the most recent 30 captured days in chronological order.
- Use the latest saved Chameo when a day contains multiple photos.
- Skip missed days rather than inserting blank or duplicated frames.
- Export a square 1080 x 1080 H.264 MP4 at 10 photos per second.
- Use the standard Save dialog to choose a file destination.
- Do not automatically add the video to Photos or keep an internal video
  library.

## Later

- Add a calendar history view for browsing captured and missed days beyond the
  rolling 30-day summary.
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

- Added Camera, Photos, Location, and Notifications permission recovery actions.
- Added permission-denied status near the action requiring permission.
- Changed Library deletion to remove the original Photos asset behind inline
  confirmation.
- Added loading state for Library reverse geocoding.
- Added the Library empty-state `Take First Chameo` action.
- Added optional automatic face alignment with square output and fallback to the
  original photo when alignment fails.
- Automatically recreate the configured Photos album on the next save if it was
  deleted externally.
