# iOS and iPadOS Development

The mobile app is an independent SwiftUI target. It shares domain logic with
the macOS app through the local `ChameoCore` Swift package, but it keeps its own
preferences, reminder schedule, and onboarding state. The two apps can see the
same exact-name Photos albums when iCloud Photos synchronizes them.

## Requirements

- Xcode with an iOS 18 or newer Simulator runtime.
- XcodeGen (`brew install xcodegen`) when regenerating the project.
- An Apple Account added to Xcode for installation on a personal iPhone or
  iPad. Simulator builds do not require signing.

## Generate and build

The checked-in Xcode project is generated from `Mobile/project.yml`. Regenerate
it after changing target files or build settings:

```bash
xcodegen --spec Mobile/project.yml --project Mobile
```

Open `Mobile/ChameoMobile.xcodeproj`, select the `ChameoMobile` scheme, choose an
iPhone or iPad Simulator, and press Run. Camera capture cannot be validated in
Simulator; use its permission/error states for UI work.

The equivalent command-line build is:

```bash
xcodebuild \
  -project Mobile/ChameoMobile.xcodeproj \
  -scheme ChameoMobile \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Install on a personal device

1. Add your Apple Account in Xcode Settings > Accounts.
2. Connect and trust the iPhone or iPad, then enable Developer Mode if the
   device asks for it.
3. Select the `ChameoMobile` target, open Signing & Capabilities, and choose your
   Personal Team. Keep automatic signing enabled.
4. Select the connected device as the run destination and press Run.
5. Complete Chameo onboarding and choose Full Photos Access. Limited Photos
   Access intentionally does not satisfy setup.

Use a physical iPhone and iPad for final camera, orientation, Vision framing,
location, iCloud Photos, notification, deletion, and large-timelapse checks.
The iPad camera intentionally pauses outside a full-screen window.

## Automated verification

```bash
swift test
swift build --target ChameoCore --jobs 1 \
  -Xswiftc -strict-concurrency=complete \
  -Xswiftc -warnings-as-errors
xcodebuild \
  -project Mobile/ChameoMobile.xcodeproj \
  -scheme ChameoMobile \
  -destination 'platform=iOS Simulator,name=<booted simulator name>' \
  test
```

The iOS test action requires a concrete booted Simulator. A generic Simulator
destination can build the app and test bundles, but cannot execute them.
