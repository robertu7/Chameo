# Architecture

Chameo is a SwiftPM macOS app using a small AppKit shell and SwiftUI feature views.

## Runtime Shape

- `ChameoApp.swift` owns app launch, default preference migration, notification response handling, and menu-bar-only activation.
- `StatusPopoverController.swift` creates the `NSStatusItem`, hosts the SwiftUI popover, and exposes `showCamera()` for notification clicks.
- `ContentView.swift` coordinates the Camera, Library, Settings, bottom status area, and camera lifecycle.

The app uses `NSStatusItem` plus `NSPopover` instead of SwiftUI `MenuBarExtra` because notification taps need to open the popover programmatically.

## State

- `AppState` stores popover-level UI state:
  - selected tab
- `@AppStorage` stores durable preferences:
  - album name
  - camera face guide
  - automatic photo alignment
  - save location
  - launch at login
  - reminder date/time
  - reminder repeat mode
  - reminder weekday
  - hourly reminder follow-ups
- `LibraryStore` owns the currently fetched Photos assets and library errors.
- `CameraService` owns the `AVCaptureSession` and still photo capture.
- `CaptureProgress` derives rolling captured and missed days from Photos asset creation dates; it does not persist a separate activity history.

Camera hardware starts only when the Camera tab is visible. It stops when the user switches to Library or closes the popover.

## Services

- `CameraService`
  - Requests camera permission.
  - Configures `AVCaptureSession`.
  - Captures still photos without preview mirroring.

- `FaceAlignmentService`
  - Uses Vision face landmarks after capture.
  - Aligns captured selfies with Core Image before preview/save when enabled.
  - Falls back to the original photo when face or landmark detection fails.

- `PhotoLibraryService`
  - Requests Photos read/write access.
  - Finds the first Photos album with the configured exact name, or creates that album if none exists.
  - Saves images into Photos.app with optional `CLLocation`.
  - Fetches album assets and thumbnails.
  - Deletes selected original assets from Photos.

- `LocationService`
  - Requests when-in-use authorization.
  - Fetches one current location for saved photo metadata.
  - Reverse-geocodes asset locations into `City, Country` for Library rows.

- `ReminderService`
  - Schedules one stable primary notification request plus optional dated hourly follow-ups.
  - Replaces existing reminders when reminder settings change and refreshes follow-ups after a save.

## UI Composition

- `CameraView`
  - Live camera preview.
  - Capture-to-memory preview.
  - `Save to Photos` and `Retake` flow.
  - Contextual Return and Escape keyboard actions.
  - Inline status for capture, location, and save progress.

- `LibraryView`
  - Rolling 30-day captured and missed-day summary.
  - Date-grouped photo list.
  - Thumbnail, local date/time, location name.
  - Inline destructive confirmation before Photos deletion.

- `SettingsView`
  - Grouped settings sections for Album, Camera, Location, Startup, and Reminder.
  - Saves notification changes only when reminder fields changed.

## Bundle and Signing

The project is SwiftPM-based, so `script/build_app.sh` stages the app bundle manually under `dist/Chameo.app`. The script writes bundle metadata and applies an ad-hoc signature with `Chameo.entitlements`.
