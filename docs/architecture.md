# Architecture

Chameo is a SwiftPM macOS app using a small AppKit shell and SwiftUI feature views.

## Runtime Shape

- `ChameoApp.swift` owns app launch, default preference migration, notification response handling, and menu-bar-only activation.
- `StatusPopoverController.swift` creates the `NSStatusItem`, hosts the SwiftUI popover, and exposes `showCamera()` for notification clicks.
  It also maps the shared daily capture status onto the menu-bar symbol and
  routes status-item clicks to Camera or today's Library entry.
- `ContentView.swift` coordinates the Camera, Library, Settings, bottom status area, and camera lifecycle.
- `SettingsView.swift` composes independent General and Reminder settings tabs; each tab owns only its feature state and operations.

The app uses `NSStatusItem` plus `NSPopover` instead of SwiftUI `MenuBarExtra` because notification taps need to open the popover programmatically.

## State

- `AppState` stores popover-level UI state:
  - selected tab
  - selected Library day
- `@AppStorage` stores durable preferences:
  - album name
  - camera face guide
  - automatic photo alignment
  - save location
  - launch at login
  - reminder date/time
  - reminder repeat mode
  - reminder weekday
- `AppPreferenceKey` is the canonical key namespace for those preferences.
- `StoredReminderSettings` is the typed read boundary used by background reminder reconciliation.
- `LibraryStore` owns the currently fetched Photos assets, snapshot validity,
  library errors, and the Photos-backed daily completion status.
- `CameraService` owns main-actor camera UI state and still photo capture.
- `CameraSessionController` serializes blocking `AVCaptureSession` configuration and lifecycle work.
- `LocationService` coalesces overlapping authorization/location requests and bounds both with a timeout.

Camera hardware starts only when the Camera tab is visible. It stops when the user switches to Library or closes the popover. Permission callbacks re-check that lifecycle intent before starting hardware.

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
  - Serializes find-or-create album operations so overlapping saves/settings actions cannot create duplicate exact-name albums.

- `LocationService`
  - Requests when-in-use authorization.
  - Fetches one current location for saved photo metadata.
  - Reverse-geocodes asset locations into `City, Country` for Library rows.

- `TimelapseSelection` chooses the latest photo from each of the most recent 30 captured days.
- `TimelapseService`
  - Loads the selected Photos assets without blocking the main actor.
  - Writes frames to a staged square H.264 MP4 and replaces the selected destination only after a successful export.
  - Cancels Photos requests and video writing when its task is cancelled.

- `ReminderService`
  - Schedules dated primary notifications.
  - Reconciles pending notifications when settings change and after a save, skipping completed days and clearing delivered reminders for completed days.
- `ReminderSchedule`
  - Validates persisted weekday values.
  - Provides the canonical next-occurrence calculation for both Settings previews and notification planning.
- `ReminderNotificationCenter`
  - Isolates the UserNotifications framework boundary and serializes reminder reconciliation operations.

## UI Composition

- `CameraView`
  - Live camera preview.
  - Capture-to-memory preview.
  - `Save to Photos` and `Retake` flow.
  - Contextual Return and Escape keyboard actions.
  - Inline status for capture, location, and save progress.

- `LibraryView`
  - Month calendar with captured, pending, missed, future, and pre-tracking
    states.
  - Hover, focus, and selected-day previews with thumbnails, local date/time,
    location name, and multiple-photo access.
  - Inline destructive confirmation before Photos deletion.
  - Standard Save panel and progress/error state for timelapse export.

- `SettingsView`
  - Grouped settings sections for Album, Camera, Location, Startup, and Reminder.
  - Saves notification changes only when reminder fields changed.

## Bundle and Signing

The project is SwiftPM-based, so `script/build_app.sh` stages the app bundle manually under `dist/Chameo.app`. The script writes bundle metadata and applies an ad-hoc signature with `Chameo.entitlements`.
