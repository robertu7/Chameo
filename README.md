<p align="center">
  <img src="Assets/AppIconSource.png" alt="Chameo app icon" width="128">
</p>

# Chameo

Chameo is a macOS menu bar app for taking quick daily selfies and storing the photos in a dedicated Photos.app album. The name leans into the idea of seeing how your face, mood, style, and life change over time.

The app is intentionally small: click the camera icon in the menu bar, take a photo, preview it, then save it or retake it.

## Features

- Menu bar completion indicator with a compact popover UI. It opens Camera while
  today's Chameo is pending and today's Library entry after capture.
- Camera tab with mirrored live preview, optional live framing guidance, and an
  opt-in silent hands-free countdown.
- Capture preview flow:
  - `Take Chameo` captures into memory only.
  - `Save to Photos` writes the image to Photos.app.
  - `Retake` discards the in-memory preview without touching Photos.
  - Return performs the primary action; Escape retakes from preview.
- Optional automatic face alignment produces consistent square photos and falls back to the original when alignment is unavailable.
- Calendar-first Library showing captured, pending, missed, future, and
  pre-tracking days.
- Hover, keyboard focus, and selection preview a day's thumbnails, local
  date/time, and location name when available.
- Library exports the latest photo from each of the most recent 30 captured days as a square H.264 MP4.
- Dedicated Photos.app album name configurable in Settings. If Photos already has an album with the same name, Chameo uses that album instead of creating another one. If the album is deleted externally, the next save recreates it.
- Optional location metadata on saved photos, off by default.
- Reminder scheduling with none, daily, and weekly repeat modes.
- Clicking a reminder notification opens the app directly to the Camera tab.
- Permission-denied states include direct System Settings recovery actions.
- Library deletion removes the original photo from Photos.
- Optional launch-at-login support.
- Daily user-approved update checks through Sparkle, with a manual check in
  General Settings.
- Menu-bar-only app with no Dock icon.

## Quick Start

Requirements:

- macOS 14 or newer.
- Apple Silicon Mac.
- Xcode command line tools or Xcode with SwiftPM support.

Build app bundle:

```bash
./script/build_app.sh
```

Build a release app bundle:

```bash
./script/build_app.sh --release
```

The script builds the SwiftPM executable, stages a local `.app` bundle in `dist/`, writes the required `Info.plist`, applies the development entitlements, signs the app, and prints the bundle path. It automatically uses an installed Apple Development or Developer ID Application certificate so macOS can retain protected-resource permissions across rebuilds. Without one, it warns and falls back to ad-hoc signing.

Set the app version in `VERSION`. The build script also writes a build number and build id into the bundle so Settings can display the exact build.

## Test Releases

GitHub prereleases are built for Apple Silicon, ad-hoc signed, and not
notarized by Apple.

Install a test release:

1. Download `Chameo-X.Y.Z-arm64.zip` from
   [GitHub Releases](https://github.com/robertu7/Chameo/releases).
2. Unzip it and move `Chameo.app` to `/Applications`.
3. Control-click Chameo and choose **Open** for the first launch.
4. Approve the Camera and Photos permissions used by the app.

Because these test builds do not have a stable Developer ID signature, macOS
may request Camera, Photos, Location, or Notification permission again after an
update. Existing photos remain in Photos.app and are not part of the replaced
app bundle.

Chameo asks once before enabling daily update checks. The preference can be
changed in General Settings. When an update is found, Sparkle shows its standard
release-notes window; Chameo downloads, installs, and relaunches only after the
user chooses **Install Update**.

The release automation validates bundle metadata, architecture, signatures,
archive contents, appcast XML, and published URLs. It does not perform an
installed-app end-to-end update or Gatekeeper test.

## Permissions

Chameo asks for permissions only when needed:

- Camera: required for live preview and capture.
- Photos: required to create/use the album, save photos, list library items, and delete photos from Photos.
- Location: optional, only when `Save photo location` is enabled.
- Notifications: requested when reminder settings are scheduled.
- User-selected files: used only for the timelapse destination chosen in the standard Save dialog.

Library deletion removes the original photo from Photos. Photos may move deleted items to Recently Deleted according to the system Photos behavior.

## Documentation

- [Architecture](docs/architecture.md)
- [Development](docs/development.md)
- [Permissions & Privacy](docs/permissions.md)
- [Production Readiness](docs/production-readiness.md)
- [Roadmap](docs/roadmap.md)
- [Changelog](CHANGELOG.md)
