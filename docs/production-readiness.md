# Production Readiness

Chameo is production-ready for its documented scope: a locally built, sandboxed,
menu-bar app for personal use on macOS 14 or newer.

## Automated Gates

- `swift test` covers reminder recurrence and reconciliation, typed preference
  loading, daily capture status and calendar boundaries, timelapse day
  selection, and face-alignment geometry.
- A complete strict-concurrency compiler audit passes while the package remains
  in Swift 5 language mode.
- `script/build_app.sh --release` builds the release executable, stages the app
  bundle, embeds and signs Sparkle's nested updater components, validates its
  property list, applies the declared sandbox entitlements, and verifies the
  resulting signature.
- Build metadata is validated before it is embedded in XML.
- GitHub Actions validates the arm64 release bundle on pull requests and
  `main`, and tagged release jobs fail unless versions and changelog notes
  match.
- Tagged prereleases provide a DMG with an Applications shortcut for first
  installation. Sparkle updates use signed ZIP archives, signed release notes,
  and a signed GitHub Pages appcast. Chameo verifies archives before extraction
  and does not expire signed-feed validation failures.

## Reliability and Data Safety

- Camera startup is gated by current popover/tab lifecycle intent, including
  after asynchronous permission responses.
- Location authorization and one-shot location requests are coalesced and
  bounded by a timeout; photo saving falls back to no location.
- Photos album creation is serialized and saving checks for a valid album
  mutation before creating the asset.
- Timelapse export writes to an item-replacement directory and changes the
  selected destination only after successful generation.
- Reminder mutations are serialized, persisted values are parsed through a
  typed boundary, and invalid weekly values fall back to the schedule date.

## Security and Privacy

- The app sandbox grants only camera, Photos, location, and user-selected-file
  access required by documented features.
- Location is disabled by default and requested only during an explicit save
  when enabled.
- Timelapse export uses a standard save panel and holds security-scoped access
  only for the export.
- Chameo has no analytics SDK or credential store. Its only direct distribution
  network path is the sandboxed Sparkle updater, which checks the configured
  GitHub Pages feed and downloads user-approved releases. Photos and geocoding
  frameworks may also use Apple services.

## Remaining Validation Boundaries

Automated tests cannot replace manual checks involving real protected system
resources. Before a release used for daily capture, smoke-test camera capture,
each permission denial/recovery path, Photos save/delete, an iCloud-backed
timelapse export, reminders across sleep/wake, and launch at login.

Stage 1 distribution is limited to public GitHub prereleases for the owner and
selected testers. These builds are ad-hoc signed and not notarized, so
Gatekeeper intervention and protected-resource permission prompts may recur
after updates. Automated gates validate release artifacts and URLs but do not
perform an installed-app update/relaunch test.

Developer ID signing, notarization, a public privacy policy, and manual
installed-update validation remain required before presenting Chameo as a
polished public distribution.
