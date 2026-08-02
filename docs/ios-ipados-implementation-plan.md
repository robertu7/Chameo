# Chameo iOS/iPadOS implementation plan

Status: awaiting final shared-understanding confirmation

## Outcome

Build a universal SwiftUI Chameo app for iOS and iPadOS 18 or later. The mobile and Mac apps are independent, full-featured peers. Either app supports the complete daily practice without the other; their only shared state is the configured Photos album, which may propagate through iCloud Photos.

The work is delivered in four installable engineering checkpoints. These are development checkpoints, not public releases. Full product acceptance still requires the complete daily loop to pass on a physical iPhone and iPad.

## Product decisions

- Use `com.robertu.Chameo` for the Mac, iPhone, and iPad product identity.
- Keep preferences, reminders, permission state, onboarding state, quality history, album selection, and language selection device-local.
- Allow multiple Chameos per practice day. A day is complete when it has at least one eligible Chameo.
- Derive a practice day from the Photos creation time interpreted in the viewing device's current time zone. A photo near midnight may move to another day when the viewing time zone changes.
- Count any dated photo in the configured logical Chameo album, including photos added outside the app. Ignore undated photos and all non-photo assets everywhere without modifying them.
- Use tabs for Camera, Library, and Settings on both iPhone and iPad. iPad content adapts to its larger canvas, but there is no sidebar.
- Support iPhone in portrait. Support iPad in portrait and landscape.
- Use only the front camera in the first mobile release.
- Keep English, Simplified Chinese, and Traditional Chinese in-app language choices. Initialize from the device language, apply changes immediately, and store the selection locally.
- Use a checked-in mobile `.xcconfig` for `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. Continue using the root `VERSION` file for Mac releases.

## Architecture and project setup

- Extend the root `Package.swift` to declare macOS 14 and iOS 18 and add a platform-neutral `ChameoCore` library product and target.
- Move reusable domain models and rules into `ChameoCore`: practice-day calculation, calendar status, album selection policy, reminder planning, countdown state, framing evaluation, quality-baseline rules, capture metadata, route state, and timelapse selection/order.
- Make the existing `Chameo` Mac executable depend on `ChameoCore`. Preserve its Sparkle dependency, SwiftPM entry point, bundle-staging scripts, entitlements, and release workflow.
- Add a separate Xcode project containing only the universal mobile app target. It references the root local package and depends on `ChameoCore`; no nested Swift package is introduced.
- Keep platform UI and adapters outside the core. Camera, Photos, Location, Notifications, and video-writing implementations expose narrow interfaces using identifiers, dates, domain structs, `Data`, and image values. AppKit, UIKit, `PHAsset`, and view types do not cross into shared domain APIs.
- Isolate mutable capture/export services appropriately for strict concurrency. Do not force a wholesale Swift-language migration of the existing Mac app merely to create the mobile target.
- Add mobile assets, English/zh-Hans/zh-Hant resources, required Camera/Photos/Location usage descriptions, and `PrivacyInfo.xcprivacy` entries justified by the APIs actually used.

## Permissions, onboarding, lifecycle, and routing

- Present the same product-teaching onboarding pattern as Mac, then block first-run completion until Camera and Full Photos read/write access are granted.
- Represent Photos authorization as not determined, full, limited, denied, or restricted. Limited access is insufficient and receives retry/Open Settings recovery.
- If Camera or Photos access is revoked later, open the normal app and show contextual recovery instead of restarting onboarding.
- Keep reminders off by default. Ask for notification permission only when reminders are first enabled in Settings. Denial never blocks capture or Library.
- Ask for when-in-use Location permission only when “Save Location” is enabled. Denial never blocks capture or saving.
- Launch into Camera. Notification taps set a shared route that selects Camera, even if another device may already have completed that day; the user decides whether to take another photo.
- Start capture only while Camera is visible and the scene is active. Stop it immediately when hidden, interrupted, or backgrounded.
- On iPad, do not start Camera while the app is in Split View or Stage Manager. Show a full-screen requirement; Library and Settings remain usable in multitasking.

## Capture and pending preview

- Use AVFoundation with the front camera, a correctly oriented mirrored preview, and an unmirrored saved image.
- Run on-device Vision framing guidance at the established throttled rate. “Ready” remains advice and never gates capture.
- Preserve the optional silent three-second hands-free countdown.
- After capture, show Preview with explicit Save and Retake actions.
- Persist at most one pending Chameo in the protected app container, excluded from backup, so relaunch restores the preview. A pending Chameo is not in Photos and does not complete a day.
- While a pending preview exists, Library and Settings remain accessible; Camera returns to Preview and cannot capture another image until Save or Retake.
- Preserve original capture time and optional capture-time location with the pending image. Retake deletes it. Save writes to the album configured at Save time and then deletes the pending file.
- Set the saved Photos asset creation date to the shutter time, not the later Save time.
- Automatically produce the existing square face alignment when possible and fall back to the correctly oriented original image when alignment cannot be produced.
- Provide advisory capture-quality feedback using a mobile-device-local baseline.

## Photos album and Library

- Treat every Photos asset collection whose title exactly matches the configured name as one logical Chameo album.
- Deduplicate an asset that appears in multiple matching collections by its Photos local identifier.
- Save to the matching physical album containing the most eligible Chameos; break ties by collection local identifier and remember that identifier locally. If it disappears, select again. Never create another album while any exact-name match exists.
- If no match exists, create the exact configured album. Album configuration stays in Settings and is not part of onboarding.
- Load iCloud-backed thumbnails and originals with visible progress/error handling.
- Show the existing six-week calendar and captured, pending, and missed states. A captured day may contain multiple photos.
- Show day details, capture times, optional location, every photo for the day, and Google Maps links.
- Reflect external Photos additions, edits, and deletion on the next read.
- After explicit confirmation, deletion removes the original Photos asset globally: from all albums, synced devices, and the app's Library. Explain that recovery, when available, is through Photos Recently Deleted.

## Location semantics

- When “Save Location” is enabled, sample optional location at capture time on both Mac and mobile.
- If location is unavailable or times out, retain no location and allow Save. Never substitute the device's location at Save time.
- This intentionally changes the Mac behavior so both apps attach the location of capture rather than the location of a later save.

## Reminders

- Preserve the Mac one-time, daily, and weekly planning rules in shared core logic.
- Reconcile scheduled notifications after reminder-setting changes, a successful save, and foreground activation.
- After capture, clear today's pending and delivered reminder on that device.
- Notification taps always route to Camera. Cross-device reminder state is not synchronized, so a stale local reminder is accepted.
- Do not use background tasks for reminder correctness.

## Timelapse

- Select every eligible dated Chameo across all matching physical albums, deduplicate it, and order it chronologically. Use a stable asset-identifier tie-breaker for identical creation times.
- Require every selected source to be available. If an iCloud original cannot be downloaded, fail the export and remove partial output rather than silently skipping a frame.
- Generate square 1080×1080 H.264 video at 10 photos per second with foreground progress and cancellation.
- If the app backgrounds during generation, cancel, remove partial staged output, and report the cancellation when the app returns. Do not resume or generate in the background.
- Stage output cancellation-safely. Offer Save to the general Photos library plus Files/share export. Never add a generated video to the Chameo album or count it as a Chameo.

## Mac behavior retained or deliberately changed

Retain without regression:

- SwiftPM build and test entry points.
- Sparkle, update settings, menu-bar experience, bundle scripts, entitlements, and release workflow.
- Mac-only concepts such as launch at login, popover geometry, Quit, Finder reveal, and save panels remain Mac-only.

Deliberate cross-platform domain changes:

- Aggregate duplicate exact-name albums.
- Ignore undated photos and non-photo assets, including in timelapse generation.
- Sample location at capture time.
- Share extracted domain policies through `ChameoCore` without sharing device state.

## Delivery checkpoints

### 1. Shared core with Mac unchanged

- Add `ChameoCore` and split shared-core and Mac-specific tests.
- Move pure rules behind compatibility-preserving interfaces.
- Adopt duplicate-album, dated-asset, and capture-location semantics on Mac.
- Keep the existing Mac app, packaging, and release validation passing.

### 2. Mobile onboarding, capture, and save

- Add the universal Xcode target, resources, privacy configuration, tabs, and route model.
- Implement permission onboarding and recovery states.
- Implement front-camera lifecycle, guidance, countdown, preview, pending recovery, alignment, quality advice, location capture, and explicit Photos save.

### 3. Library, deletion, and reminders

- Implement logical-album loading, iCloud-backed assets, six-week calendar, multiple-photo details, locations, links, and global deletion confirmation.
- Implement Settings, language/album controls, local notification planning, reconciliation, and notification routing.

### 4. Timelapse, iPad adaptation, and parity hardening

- Implement all-or-nothing foreground timelapse export, cancellation, Photos save, and Files/share export.
- Complete iPad portrait/landscape layouts and multitasking Camera warning.
- Finish accessibility, localization, interruption handling, performance validation, and full parity regression work.

## Automated verification

- Preserve the current 101-test SwiftPM baseline measured immediately before implementation while separating shared-core and Mac-specific coverage.
- Add unit coverage for Photos full/limited/denied states; onboarding and revocation; routes; front-camera mirroring/orientation; pending recovery; local defaults; album aggregation and deterministic save choice; current-time-zone calendar behavior; reminder parity; location timing; dated-asset filtering; and timelapse order, failure, cancellation, and staging.
- Run shared and Mac `swift test`, a complete strict-concurrency build for new shared/mobile code, and the existing macOS release bundle validation.
- Add iOS Simulator unit/UI coverage for tab navigation on phone/tablet, localization, calendar layout, Settings, permission error states, pending preview, Dynamic Type, and VoiceOver labels/order.
- Build and run the mobile app in Simulator throughout implementation. Simulator results do not prove camera, real PhotoKit/iCloud, permissions, location, notifications, orientation, performance, or export behavior.
- Before paid Apple Developer Program enrollment, use a free Personal Team for direct Xcode installs on registered personal devices. App Store/TestFlight/ad-hoc distribution and App Store signed-archive validation are deferred until enrollment.

## Physical-device acceptance

- Validate the complete daily loop on at least one iPhone and one iPad before calling the mobile product release-ready.
- Cover iPhone portrait; iPad portrait/landscape; iPad multitasking warning; camera interruptions and foreground/background transitions; mirroring; saved orientation; alignment/fallback; hands-free capture; Vision performance; and pending-preview relaunch.
- Cover Full, Limited, denied, and revoked Photos states; exact-name album creation/aggregation; iCloud-only assets; capture-time metadata; save; external additions; multiple same-day photos; and global deletion.
- Cover reminders while foregrounded, backgrounded, terminated, and after restart.
- Cover short and large timelapses, unavailable iCloud originals, user cancellation, background cancellation, low storage, playback, duration, crop, frame order, Files/share export, and Photos save.
- Use a uniquely named temporary album for device QA, delete only assets created by the test, and restore the original album setting afterward.

## Handoff and release boundary

- Implementation handoff requires automated gates to pass and a precise list of device-only checks still outstanding.
- Intended source changes remain uncommitted for review unless commit authorization is given separately. The handoff must contain no accidental generated artifacts or unrelated edits.
- Physical-device acceptance is not claimed from Simulator or build evidence. Paid-program archive validation, TestFlight, App Store metadata, a public privacy policy, and App Review remain deferred.
- App Intents, Locked Camera capture, Center Stage, iPad multitasking camera access, background timelapse processing, preference/reminder synchronization, and public distribution are out of scope.
