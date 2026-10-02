# Architecture

Chameo is a SwiftPM macOS app using a small AppKit shell and SwiftUI feature views.

## Runtime Shape

- `ChameoApp.swift` owns app launch, default preference migration, notification response handling, and menu-bar-only activation.
- `StatusPopoverController.swift` creates the `NSStatusItem` and hosts both the SwiftUI popover and the standalone recovery window. Direct menu-bar clicks use the popover; programmatic entry points such as notification clicks and app reopen use the window so they remain reachable when the menu bar is full.
  It also maps the shared daily capture status onto the menu-bar symbol and
  routes status-item clicks to Camera or today's Library entry.
- `ContentView.swift` coordinates Camera, Library, the app menu, and the feedback footer.
- `SettingsWindowController.swift` owns one reusable Settings window. `SettingsView.swift` presents native General, Capture, Reminders, and Photos tabs with grouped forms.

The app uses `NSStatusItem` plus `NSPopover` instead of SwiftUI `MenuBarExtra` because it needs AppKit-controlled presentation. Direct status-item clicks open the popover, while notification taps and Finder or Spotlight reopen events open a standalone window that does not depend on the status item being visible.

## State

- `AppState` stores popover-level UI state:
  - selected tab
  - selected Library day
  - visible main surface (popover or standalone window)
- `SettingsState` retains the selected Settings category across window closure.
- `@AppStorage` stores durable preferences:
  - album name
  - camera face guide
  - hands-free capture countdown
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
- `CameraService` owns main-actor camera UI state, transient live-framing
  guidance, and still photo capture.
- `CameraSessionController` serializes blocking `AVCaptureSession` configuration and lifecycle work.
- `LocationService` coalesces overlapping authorization/location requests and bounds both with a timeout.

`MainCameraLifecycle` is the single owner of camera visibility intent. Camera hardware starts only when a main surface is visible and Camera is selected. Opening Settings, closing the main surface, or minimizing the standalone window stops it. A late close callback from a different surface cannot stop the active one. Permission callbacks re-check lifecycle intent before starting hardware.

## Services

- `CameraService`
  - Requests camera permission.
  - Configures `AVCaptureSession` with the system-preferred camera.
  - Supports built-in, Continuity, and external cameras with automatic fallback
    and defers preferred-camera changes until an active capture completes.
  - Publishes the live camera list and persists explicit user selections through
    AVFoundation's user-preferred camera.
  - Logs available cameras, active-camera changes, and selection failures.
  - Mirrors built-in and external camera previews while leaving Continuity
    Camera previews unmirrored.
  - Throttles transient video frames to approximately five on-device Vision
    analyses per second for advisory framing guidance.
  - Publishes only derived guidance state; camera frames and face geometry are
    not persisted or logged.
  - Captures still photos without preview mirroring.

- `FaceAlignmentService`
  - Uses Vision face landmarks after capture.
  - Aligns captured selfies with Core Image before preview/save when enabled.
  - Falls back to the original photo when face or landmark detection fails.

- `FaceCaptureQualityService`
  - Evaluates the largest detected face with Vision capture-quality revision 3.
  - Scores each single capture before preview and logs local diagnostics.

- `CaptureQualityHistoryStore`
  - Retains the 30 most recent scores for successfully saved photos.
  - Establishes a per-user baseline after 10 accepted captures.
  - Recommends a retake for no-face captures or scores clearly below that
    baseline, while always allowing the user to keep the photo.

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

- `TimelapseSelection` orders every dated photo in the Chameo album chronologically.
- `TimelapseService`
  - Loads the selected Photos assets without blocking the main actor.
  - Writes frames to a staged square H.264 MP4 and replaces the selected destination only after a successful export.
  - Emits ordered frame counts and per-photo iCloud download progress; finalization remains cancellable.
  - Cancels Photos requests and video writing when its task is cancelled.
- `TimelapseExportController`
  - Owns one export independently of Library view, tab, popover, and standalone-window lifetimes.
  - Presents an all-album summary, progress/cancellation, retry, and explicit result actions.
- `TimelapseNotificationService` / `TimelapseResultStore`
  - Sends silent completion notifications with an Open Folder action, separate from reminders.
  - Persists the latest completed export and a read-only security-scoped file bookmark for notification clicks after relaunch.

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
  - Advisory live framing based on face size, position, eye-line, and stability,
    with one short hint and a green Ready state.
  - Optional silent 3-second hands-free capture after Ready, cancelled whenever
    framing or Camera lifecycle state changes.
  - Compact active-camera badge and a camera menu when multiple devices exist.
  - On-device single-photo quality evaluation with advisory retake guidance.
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
  - Dedicated timelapse summary/progress/result screen, standard Save panel, and persistent export footer.

- `SettingsView`
  - Opens in a reusable native window from the app menu or Command-comma.
  - General, Capture, Reminders, and Photos categories retain their preference keys.
  - Opening Settings stops capture and preserves the main tab/day selection for return.
  - Saves notification changes only when reminder fields changed.

## Bundle and Signing

The project is SwiftPM-based, so `script/build_app.sh` stages the app bundle manually under `dist/Chameo.app`. The script writes bundle metadata, applies `Chameo.entitlements`, and prefers an installed Apple Development or Developer ID Application identity. It warns before falling back to ad-hoc signing because that identity changes with every rebuilt binary and causes macOS protected-resource grants to reset.

## macOS Design

Chameo requires macOS 26 and Swift tools 6.2 or newer. Native glass button styles
carry primary and secondary actions; the custom camera selector uses regular
interactive Liquid Glass. Photos, calendar cells, and informational overlays stay
in the content layer. Custom surfaces honor Reduce Transparency and Increase
Contrast, and framing/countdown transitions honor Reduce Motion.
