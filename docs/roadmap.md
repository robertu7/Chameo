# Roadmap

Chameo is currently a personal daily-selfie tool. The roadmap prioritizes a
reliable daily capture habit before broader library, automation, or distribution
work.

## Now: Validation

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
- Renamed preview `Cancel` to `Retake` and added contextual Return and Escape
  keyboard actions.
- Added a rolling 30-day Library summary derived from local Photos asset dates,
  with captured-day progress, missed dates, and today treated as pending.
- Added optional automatic face alignment with square output and fallback to the
  original photo when alignment fails.
- Automatically recreate the configured Photos album on the next save if it was
  deleted externally.
