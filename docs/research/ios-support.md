# iOS Support Research

Date: 2026-07-31

## Executive recommendation

Supporting iOS is feasible and strategically aligned with Chameo's daily-capture
product, but it is a **medium-to-large platform port**, not a deployment-setting
change. The best first release is an iPhone-first app that supports:

1. foreground daily capture with the existing framing and quality guidance;
2. an explicit in-memory preview followed by **Save to Photos**;
3. the Chameo album, calendar Library, and foreground timelapse export;
4. local reminders that open the Camera screen; and
5. the existing English, Simplified Chinese, and Traditional Chinese
   localizations.

Do not make automatic/background capture, iPad camera multitasking, Center Stage,
cross-device settings synchronization, or fully background timelapse generation
MVP requirements. Apple doesn't allow starting an iOS capture session in the
background, background-task launch time is nondeterministic, and Center Stage
camera behavior is hardware-dependent and currently documented through beta
material. Local notifications already provide the dependable system-owned daily
prompt while the app isn't running.

The recommended technical shape is:

- keep SwiftPM as the home of a new reusable `ChameoCore` library;
- keep the existing macOS AppKit/Sparkle executable as a macOS-specific target;
- add an Xcode iOS app target that links the local package;
- isolate camera, image, Photos, notification, file-export, lifecycle, and
  settings-navigation adapters by platform; and
- share domain rules and tests rather than trying to share the current fixed
  popover UI.

This preserves the tested macOS product while giving iOS the standard signing,
capabilities, asset, Simulator, archive, TestFlight, and App Store workflow.
Apple explicitly recommends local Swift packages for modularity and reuse within
an app repository, while Xcode projects model apps and related products as
targets ([Apple: Organizing code with local
packages](https://developer.apple.com/documentation/Xcode/organizing-your-code-with-local-packages),
[Apple: Configuring a new
target](https://developer.apple.com/documentation/xcode/configuring-a-new-target-in-your-project/)).

## What exists today

Chameo is a macOS 14+ SwiftPM executable. Its only declared platform is macOS,
and the executable target directly depends on Sparkle
([`Package.swift`](../../Package.swift)). The bundle is manually staged, signed,
and updated outside the Mac App Store
([`docs/architecture.md`](../architecture.md),
[`docs/development.md`](../development.md)). The iOS product cannot reuse that
packaging or update path.

The current code has three layers with different reuse potential:

| Area | Examples | iOS reuse |
| --- | --- | --- |
| Domain and planning | `DailyCaptureStatus`, `HandsFreeCountdown`, `LiveFramingGuidance`, `ReminderSchedule`, `ReminderNotificationPlan`, `TimelapseSelection`, preference keys, localization resolution | High after moving into a platform-neutral library |
| Apple-framework services | AVFoundation capture, Vision analysis, PhotoKit persistence, Core Location, UserNotifications, AVAssetWriter timelapse | Medium: frameworks and concepts are available, but several concrete types and lifecycle assumptions differ |
| App shell and UI integration | `NSApplicationDelegate`, `NSStatusItem`, `NSPopover`, `NSWindow`, `NSViewRepresentable`, `NSSavePanel`, `NSWorkspace`, `SMAppService`, Sparkle | Low: replace with iOS scenes, navigation, UIKit bridges, file export/share UI, and App Store delivery |

The macOS architecture intentionally centers on a menu-bar `NSStatusItem` and
programmatically opened `NSPopover`
([`Sources/Chameo/App/ChameoApp.swift`](../../Sources/Chameo/App/ChameoApp.swift),
[`Sources/Chameo/App/StatusPopoverController.swift`](../../Sources/Chameo/App/StatusPopoverController.swift)).
The current fixed popover geometry, AppKit segmented control, settings window,
quit action, and wake/session observers should not be carried into the iPhone
experience. SwiftUI itself is designed to share adaptable views across Apple
platforms, but platform-specific integration can and should remain in UIKit or
AppKit wrappers ([Apple: SwiftUI](https://developer.apple.com/documentation/SwiftUI)).

## Capability findings

### Camera and capture

AVFoundation supports the core iOS flow: request camera permission, configure an
`AVCaptureSession`, present a preview, receive video frames for on-device Vision
analysis, and capture a still image. That maps well to `CameraService`,
`LiveFramingAnalyzer`, `FaceAlignmentService`, and
`FaceCaptureQualityService`. Apple requires explicit camera authorization and a
camera purpose string before capture
([Apple: Requesting authorization to capture and save
media](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media)).

The implementation still needs iOS adapters:

- `CameraPreviewView` is an `NSViewRepresentable` backed by `NSView`; iOS needs a
  `UIViewRepresentable`/`UIView` preview layer
  ([`Sources/Chameo/Views/CameraPreviewView.swift`](../../Sources/Chameo/Views/CameraPreviewView.swift)).
- Captured and processed images currently cross service/UI boundaries as
  `NSImage` or use `NSBitmapImageRep`; use a shared `Data`/`CGImage` boundary and
  small platform image adapters instead
  ([`Sources/Chameo/Services/PhotoLibraryService.swift`](../../Sources/Chameo/Services/PhotoLibraryService.swift),
  [`Sources/Chameo/Services/FaceAlignmentService.swift`](../../Sources/Chameo/Services/FaceAlignmentService.swift)).
- Camera discovery and preference policy must be reworked around the iPhone
  front camera. Continuity/external-camera and system-preferred-camera behavior
  are macOS product choices, whereas lens availability and orientation are
  device-dependent on iOS
  ([`Sources/Chameo/Services/CameraSessionController.swift`](../../Sources/Chameo/Services/CameraSessionController.swift)).
- Camera start/stop must follow `scenePhase` and foreground visibility, not
  popover visibility. iOS interrupts camera use when the app goes into the
  background; Apple explicitly identifies “video device not available in
  background” as a capture-session interruption
  ([Apple: capture-session interruption
  reason](https://developer.apple.com/documentation/AVFoundation/AVCaptureSession/InterruptionReason/videoDeviceNotAvailableInBackground)).

Automatic daily capture while the phone is locked or the app is backgrounded is
therefore not a viable product promise. “Hands-free” can remain a foreground
three-second countdown after Chameo's Ready state.

Center Stage is a future progressive enhancement, not a baseline. Apple's
current iPhone sample requires supported Center Stage front-camera hardware and
is associated with beta software
([Apple: Supporting Center Stage front camera in your iOS
app](https://developer.apple.com/documentation/avfoundation/supporting-center-stage-front-camera-in-your-ios-app)).
Keep the existing Vision guide and post-capture alignment as the portable
baseline; later capability-check Center Stage without changing behavior on
other iPhones.

### Photos and the Library

PhotoKit supports saving, fetching, creating collections, requesting
thumbnails, deleting assets, and loading images for timelapse, so much of
`PhotoLibraryService`, `LibraryStore`, and `ChameoAsset` can keep their behavior
behind a platform-neutral protocol
([Apple: PhotoKit](https://developer.apple.com/documentation/photokit)).

The highest-risk product constraint is **limited Photos access**. The current
code treats `.limited` as sufficient and then finds or creates an exact-name
Chameo album. Apple says an app in limited-library mode cannot create or fetch
user albums, although assets the app creates are automatically added to its
limited selection
([Apple: Delivering an enhanced privacy experience in your Photos
app](https://developer.apple.com/documentation/PhotoKit/delivering-an-enhanced-privacy-experience-in-your-photos-app)).
The iOS UI must therefore make one of these contracts explicit:

- **Recommended for feature parity:** request `.readWrite` only when the user
  enters the save/Library workflow; explain that full access is needed to
  maintain the Chameo album, calendar, deletion, and timelapse. If the user
  chooses limited access, provide a clear reduced state and a system affordance
  to update the selection.
- **Privacy-minimal alternative:** allow capture and add-only saving without a
  managed album, but disable or redesign calendar history, deletion, and
  all-album timelapse. This is a different product contract, not a transparent
  fallback.

Apple recommends requesting only the necessary level at the moment of user
action, and App Review asks apps to prefer out-of-process pickers when full
protected-resource access isn't required
([Apple: Photos privacy](https://developer.apple.com/documentation/PhotoKit/delivering-an-enhanced-privacy-experience-in-your-photos-app),
[Apple: App Review Guidelines, section
5.1.1](https://developer.apple.com/app-store/review/guidelines/)).
Because Chameo's managed history is core functionality, read/write access can be
justified, but onboarding should not imply that limited access provides full
feature parity.

If iCloud Photos is enabled, Photos can supply the same album/assets on the
person's devices. That does not synchronize Chameo's `UserDefaults`, reminder
settings, capture-quality baseline, or transient UI state. Cross-device
preference sync should be a separately designed iCloud feature rather than an
MVP assumption.

### Reminders, notifications, and background execution

The current reminder planner and identifier rules are strong reuse candidates.
UserNotifications uses the same scheduling model on iOS, and the system
delivers a scheduled local notification even if the app isn't running
([Apple: Scheduling a notification locally from your
app](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)).
On a tap, the iOS app should activate and route its navigation state to Camera,
replacing the macOS call that opens the status popover.

The app must continue to request notification authorization contextually and
handle denied settings. Apple ignores attempts to schedule local notifications
when authorization is denied
([Apple: `UNNotificationSettings.authorizationStatus`](https://developer.apple.com/documentation/usernotifications/unnotificationsettings/authorizationstatus)).

Do not rely on background tasks to make reminders exact, start the camera, or
perform daily reconciliation at a chosen wall-clock time. Apple describes
`BGAppRefreshTask` as short, `BGProcessingTask` as longer maintenance work, and
documents that scheduled task launch can be delayed by many hours
([Apple: Background Tasks](https://developer.apple.com/documentation/backgroundtasks),
[Apple: Background-task development
behavior](https://developer.apple.com/documentation/backgroundtasks/starting-and-terminating-tasks-during-development)).
Schedule a rolling set of local notifications whenever the user changes
settings, saves a Chameo, or foregrounds the app. Background refresh is optional
hardening, not correctness infrastructure.

### App Intents and Shortcuts

App Intents is a good second-phase addition shared by both platforms. Apple
allows intent types in an app, extension, framework, or Swift package and uses
them to expose actions to Siri, Shortcuts, and other system experiences
([Apple: `AppIntent`](https://developer.apple.com/documentation/appintents/appintent)).

Recommended semantics:

- **Take Chameo:** foreground/open the app directly to Camera. It should not
  promise a headless capture because camera use requires a visible foreground
  experience and user awareness.
- **Create Timelapse:** open the Library's export flow with all available
  Chameos selected. A later intent may produce a result without opening the app
  only after destination, permission, cancellation, memory, and runtime
  behavior are proven.

This is more honest and reliable than making automation bypass Chameo's
preview/save and export-destination contracts. It also matches the existing
roadmap, which places App Intents after capture and timelapse stability
([`docs/roadmap.md`](../roadmap.md)).

### Timelapse and file output

The current selection rule and most AVAssetWriter composition logic can be
shared. The AppKit dependency is concentrated in image loading/rendering and the
macOS `NSSavePanel` workflow
([`Sources/Chameo/Models/TimelapseSelection.swift`](../../Sources/Chameo/Models/TimelapseSelection.swift),
[`Sources/Chameo/Services/TimelapseService.swift`](../../Sources/Chameo/Services/TimelapseService.swift),
[`Sources/Chameo/Views/LibraryView.swift`](../../Sources/Chameo/Views/LibraryView.swift)).

For iOS MVP:

- generate the video in the foreground with visible progress and cancellation;
- stage output in the app's temporary/container directory;
- offer **Save to Photos** and a SwiftUI file exporter/share sheet; and
- test interruption, low storage, iCloud-backed source assets, thermal pressure,
  and memory on physical devices.

SwiftUI's file dialogs, including `fileExporter`, have iOS-specific behavior
([Apple: SwiftUI file-dialog browser
options](https://developer.apple.com/documentation/swiftui/filedialogbrowseroptions/displayfileextensions)).
Do not port the macOS security-scoped save-panel implementation literally.
Background Tasks can support long work, but background execution is a
separately constrained enhancement; foreground export has the fewest failure
states for the first release.

### Location

Core Location and `PHAsset.location` are portable, and the current opt-in,
one-shot, timeout-bounded design should remain. Request when-in-use permission
only when the user enables location and saves. Keep save-without-location as the
fallback. The macOS `NSWorkspace` route to privacy settings needs an iOS
settings URL adapter. App Review specifically recommends an alternative when a
person declines Location
([Apple: App Review Guidelines, section
5.1.1](https://developer.apple.com/app-store/review/guidelines/),
[`Sources/Chameo/Services/LocationService.swift`](../../Sources/Chameo/Services/LocationService.swift),
[`Sources/Chameo/Services/PermissionRecoveryService.swift`](../../Sources/Chameo/Services/PermissionRecoveryService.swift)).

## Recommended architecture

### Target structure

Use an Xcode project/workspace for products and a local Swift package for shared
code:

```text
Chameo.xcodeproj
Package.swift
Sources/
  ChameoCore/          # platform-neutral models, planning, policies
  ChameoShared/        # carefully selected cross-platform Apple framework code
  ChameoMac/           # current AppKit shell, Mac UI, Sparkle integration
  ChameoiOS/           # optional only if Xcode target uses synchronized folders
Tests/
  ChameoCoreTests/
  ChameoMacTests/
  ChameoiOSTests/
```

Exact names can change, but dependency direction should be:

```text
ChameoCore
  ↑             ↑
ChameoMac     ChameoiOS
```

`ChameoCore` must not import AppKit, UIKit, Sparkle, PhotoKit UI, or app
lifecycle APIs. Xcode supports linking a local package's library product into an
app target, and keeps that package in the same repository
([Apple: Organizing code with local
packages](https://developer.apple.com/documentation/Xcode/organizing-your-code-with-local-packages)).

### Extract first

Move these units first, keeping their tests:

- reminder recurrence, planning, identifiers, and stored-settings decoding;
- daily capture history/status;
- timelapse selection and chronology;
- hands-free countdown and live-framing guidance state;
- capture-quality baseline policy;
- localization keys/resolution and date policies; and
- small value types and errors that don't expose platform image/view types.

Then introduce narrow service interfaces for camera, photo library, location,
notifications, and timelapse output. Avoid a single cross-platform service full
of `#if os(...)` branches. Share an implementation only when its public types
and lifecycle are genuinely the same.

### UI shape

Build the iPhone UI for the platform:

- a full-screen camera as the primary destination;
- a Library destination with calendar and day detail;
- Settings in normal iOS navigation/forms;
- scene/deep-link state that can route notification and App Intent launches;
- safe-area, orientation, Dynamic Type, VoiceOver, and compact/regular-size
  adaptations; and
- no Quit, launch-at-login, status-item, popover, Sparkle-update, or Finder
  reveal controls.

Share visual subviews only after the interaction model is stable. The existing
calendar domain, copy, colors, and icons are better reuse candidates than the
current fixed-size view composition.

## Packaging, privacy, and distribution

The iOS target should use Xcode automatic signing during development. Apple
notes that adding capabilities through the target's Signing & Capabilities pane
updates entitlements, Info.plist values, and signing assets where needed
([Apple: Adding capabilities to your
app](https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app)).
Choose the App ID/bundle-ID and whether the future Mac App Store build shares an
App Store record before uploading the first build; App Store Connect requires
the uploaded bundle ID to match the project and it can't be changed after a
build is uploaded
([Apple: App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)).

The iOS product needs:

- iOS purpose strings for Camera, Photos, and optional Location;
- notification authorization copy in the app;
- a valid `PrivacyInfo.xcprivacy` covering the app's required-reason API use and
  declared data practices
  ([Apple: Adding a privacy
  manifest](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk));
- App Store privacy answers and a public privacy-policy URL
  ([Apple: Manage app
  privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy));
- App Store screenshots/metadata and an App Review explanation of the
  managed-album/full-Photos-access workflow; and
- no Sparkle framework or self-update code in the iOS target.

TestFlight is the correct beta channel. Apple supports internal and external
groups, feedback and crash collection, and 90-day beta builds; the first
external build may require beta review
([Apple: TestFlight
overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)).

## Verification strategy

Keep the existing SwiftPM unit suite as the fast shared-logic gate, then add:

1. **Core matrix:** `swift test` plus strict-concurrency checks for the shared
   package on every change.
2. **iOS build/tests:** `xcodebuild` for the iOS app and unit/UI-test schemes on
   at least one current iPhone Simulator.
3. **Physical-device camera matrix:** front-camera preview/capture, orientation,
   mirroring, interruption/background/foreground, hands-free countdown, Vision
   performance, memory, and thermal behavior.
4. **Physical-device Photos matrix:** not determined, denied, limited, full,
   Settings changes, existing exact-name album, iCloud-only assets, deletion,
   and save without Location.
5. **Notification matrix:** permission states, scheduled delivery with the app
   foreground/background/terminated, tap routing, completion-day cancellation,
   timezone/daylight-saving changes, and device restart.
6. **Timelapse matrix:** short and large albums, cancellation, destination
   replacement, low storage, backgrounding, iCloud download, Save to Photos,
   Files export, playback, duration, frame order, and visual crop.
7. **Release matrix:** archive/validate, TestFlight install/update, clean-device
   onboarding, privacy report, crash/feedback visibility, and App Review
   metadata.

Apple warns that Simulator doesn't reproduce every physical-device feature, so
camera, performance, permission, and final release behavior require real-device
testing
([Apple: Running on simulated or physical
devices](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices)).
Also test an optimized Release build without the debugger; Apple notes that the
debugger can mask watchdog termination behavior
([Apple: Testing a release
build](https://developer.apple.com/documentation/xcode/testing-a-release-build)).

## Principal risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Limited Photos access cannot fetch/create the Chameo album | Core Library/timelapse contract breaks | Make full-access rationale explicit; design and test a reduced limited-access state |
| macOS types leak into shared modules | Conditional-compilation sprawl and fragile reuse | Extract pure core first; use `CGImage`/`Data` and narrow protocols at boundaries |
| iOS app lifecycle interrupts camera/export | Capture or export failure | Bind camera to visible foreground scene; foreground MVP export; cancellation-safe staging |
| Fixed popover UI is mechanically ported | Poor iPhone usability/accessibility | Build native iOS navigation and layout, sharing domain/copy rather than geometry |
| Background execution is treated as deterministic | Missed reminders or incomplete work | Let UserNotifications own delivery; reconcile on user actions and foreground |
| Photos content is mistaken for app-state sync | Different settings/reminders across devices | Document MVP as device-local settings; design iCloud sync separately |
| Timelapse stresses memory/thermal/storage on phones | Crashes or unusable export | Stream frames, bound memory, expose progress/cancel, test large iCloud-backed libraries on device |
| Distribution work is underestimated | TestFlight/App Review delay | Establish App ID, signing, privacy manifest/policy, metadata, and archive validation early |
| New iOS work regresses the proven Mac app | Existing product instability | Preserve Mac target and tests; migrate in small seam-first steps; run both platform gates |

## Phased plan

### Phase 0 — Product contract and spike

- Decide whether full Photos access is required for the iOS Library. The
  recommendation is yes, with an honest reduced state for limited/denied access.
- Confirm iPhone-first scope, minimum iOS version, supported orientations, and
  whether iPad runs as a compatible layout or is excluded initially.
- Create a disposable device spike for front-camera preview → capture → in-memory
  preview → PhotoKit save. Validate real hardware before restructuring the repo.
- Establish bundle-ID/App Store record strategy and create no public promise yet.

Exit: one physical iPhone proves permission, foreground capture, mirroring,
orientation, and PhotoKit save behavior.

### Phase 1 — Shared-core extraction

- Add the reusable library product and split the macOS executable/Sparkle shell.
- Move pure models/planners/policies plus their current tests.
- Introduce narrow platform service interfaces.
- Keep the macOS bundle, tests, and release scripts green after every step.

Exit: macOS behavior is unchanged; shared core builds/tests for macOS and iOS.

### Phase 2 — iOS daily-capture MVP

- Add the Xcode iOS target, native app/scene lifecycle, adaptive Camera UI, iOS
  preview bridge, permission recovery, localization, and Save to Photos.
- Add physical-device and Simulator CI coverage.
- Do not include Library deletion, timelapse, App Intents, background tasks, or
  Center Stage yet.

Exit: TestFlight internal build reliably completes one daily capture on a clean
device and after permission-state changes.

### Phase 3 — Library, reminders, and timelapse

- Add the calendar Library and explicit limited-Photos state.
- Port reminder scheduling and notification-tap routing.
- Add foreground timelapse export to Photos/Files with progress and cancellation.
- Run large, iCloud-backed, low-storage, timezone, and terminated-app tests.

Exit: a small external TestFlight cohort can use the full daily loop for several
weeks without capture loss, reminder failure, or export loss.

### Phase 4 — Automation and enhancements

- Add `Take Chameo` and `Create Timelapse` App Intents with foreground/deep-link
  semantics.
- Evaluate iCloud preference synchronization only with an explicit conflict and
  migration model.
- Capability-gate Center Stage and iPad multitasking camera behavior.
- Consider background continued processing for already-started timelapses only
  after foreground reliability is established.

Exit: enhancements are additive and cannot weaken the foreground daily-capture
contract.

## Decision

Proceed, but treat iOS as a native second product surface over a shared domain,
not as a compilation target for the existing Mac executable. The first concrete
investment should be the Phase 0 physical-device capture/Photos spike followed
by seam-first `ChameoCore` extraction. The limited-Photos product decision is
the gating question because it determines whether Chameo can preserve its
album-backed Library and timelapse identity on iOS.
