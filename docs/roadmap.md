# Roadmap

## (Completed) Near-Term Polish

- Added permission recovery actions:
  - Open Camera settings.
  - Open Photos settings.
  - Open Location settings.
  - Open Notifications settings.
- Changed Library deletion to delete the original Photos asset behind inline confirmation.
- Added explicit status for permission-denied states near the action that needs the permission.
- Added lightweight loading states for Library reverse geocoding.
- Added the Library empty-state `Take First Chameo` action.

## Capture Experience

- Add `Retake` in the preview flow.
- Add face alignment guide or ghost overlay from the previous saved selfie.
- Add automatic face-centering or crop suggestions.
- Add optional square crop for consistent daily photos.
- Add keyboard shortcuts for `Take`, `Save to Photos`, and `Cancel`.

## Library

- Add month/year navigation.
- Add search/filter by date and location.
- Add full-size photo preview from Library.
- Add export for a date range.
- Add album repair tools if the configured album is deleted externally.

## Reminders

- Add quick presets:
  - Daily morning.
  - Daily evening.
  - Weekdays.
- Add custom weekday selection.
- Add missed-day indication.
- Add snooze from notification.

## Long-Term Features

- Timelapse video generation.
- Streak tracking and calendar view.
- Multiple selfie projects or albums.
- Widgets or menu bar streak indicator.
- Shortcuts/App Intents:
  - Take Chameo.
  - Open Today.
  - Create Timelapse.
- Optional private local backup cache.

## Distribution

- Replace ad-hoc development signing with a Developer ID or Mac App Store signing flow.
- Add release build configuration.
- Add notarization workflow.
- Add a privacy policy page if distributed publicly.
