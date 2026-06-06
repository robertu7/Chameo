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
  - whether Settings is visible
- `@AppStorage` stores durable preferences:
  - album name
  - camera face guide
  - mirror camera
  - save location
  - launch at login
  - reminder date/time
  - reminder repeat mode
- `LibraryStore` owns the currently fetched Photos assets and library errors.
- `CameraService` owns the `AVCaptureSession` and still photo capture.

Camera hardware starts only when the Camera tab is visible and Settings is closed. It stops when the user switches tabs, opens Settings, or closes the popover.

## Services

- `CameraService`
  - Requests camera permission.
  - Configures `AVCaptureSession`.
  - Captures still photos with optional mirroring.

- `PhotoLibraryService`
  - Requests Photos read/write access.
  - Finds the first Photos album with the configured exact name, or creates that album if none exists.
  - Saves images into Photos.app with optional `CLLocation`.
  - Fetches album assets, thumbnails, and deletes selected assets.

- `LocationService`
  - Requests when-in-use authorization.
  - Fetches one current location for saved photo metadata.
  - Reverse-geocodes asset locations into `City, Country` for Library rows.

- `ReminderService`
  - Schedules one stable notification request.
  - Replaces existing reminders when reminder settings change.

## UI Composition

- `CameraView`
  - Live camera preview.
  - Capture-to-memory preview.
  - `Save to Photos` and `Cancel` flow.
  - Inline status for capture, location, and save progress.

- `LibraryView`
  - Date-grouped photo list.
  - Thumbnail, local date/time, location name.
  - Inline destructive confirmation before Photos deletion.

- `SettingsView`
  - Grouped settings sections for Album, Camera, Location, Startup, and Reminder.
  - Saves notification changes only when reminder fields changed.

## Bundle and Signing

The project is SwiftPM-based, so `script/build_app.sh` stages the app bundle manually under `dist/Chameo.app`. The script writes bundle metadata and signs with `Chameo.entitlements`.
