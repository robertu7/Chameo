# Development

## Project Layout

```text
Package.swift
Chameo.entitlements
script/build_app.sh
VERSION
Sources/Chameo/
  App/
  Models/
  Services/
  Stores/
  Support/
  Views/
```

## Build

Use SwiftPM for compilation:

```bash
swift build
```

Use the project script to build and stage the app bundle:

```bash
./script/build_app.sh
```

The script is the preferred build path because SwiftPM GUI executables should be staged as an `.app` bundle, not used as a raw command-line process.

## Versioning

`VERSION` is the app version source of truth. `script/build_app.sh` writes that value to `CFBundleShortVersionString`, writes the git commit count to `CFBundleVersion`, and writes the short git SHA to `ChameoBuildID`. Local builds with uncommitted changes append `-dirty` to the build id.

Release automation can override those values:

```bash
CHAMEO_VERSION=1.2.0 CHAMEO_BUILD_NUMBER=42 CHAMEO_BUILD_ID=ci-42 ./script/build_app.sh --release
```

Settings shows the bundled version number and build id from `Info.plist`.

## App Icon

The app icon is generated from a deterministic AppKit drawing script:

```bash
swift script/generate_app_icon.swift
```

The script writes `Assets/AppIcon.iconset/` and packages `Assets/AppIcon.icns`. The build script copies `Assets/AppIcon.icns` into the app bundle and declares it as `CFBundleIconFile`.

## Build Script Modes

```bash
./script/build_app.sh
./script/build_app.sh --release
```

- `debug`: build, stage, and sign a debug app bundle. This is the default.
- `--release`: build, stage, and sign a release app bundle.

## Codex Run Button

`.codex/environments/environment.toml` wires the Codex app Run action to:

```bash
./script/build_app.sh
```

## Debugging Tips

- If the menu bar icon disappears after a click, check crash reports:

```bash
ls -lt ~/Library/Logs/DiagnosticReports/Chameo-*.ips
```

- Inspect signed entitlements:

```bash
codesign -d --entitlements :- dist/Chameo.app
```

- Inspect generated bundle metadata:

```bash
plutil -p dist/Chameo.app/Contents/Info.plist
```

## Implementation Notes

- Keep AppKit interop narrow. `StatusPopoverController` owns status item and popover behavior; SwiftUI owns feature UI.
- Do not start the camera outside the visible Camera tab.
- Do not write to Photos on `Take`; write only on `Save to Photos`.
- Keep destructive Photos deletion behind inline confirmation.
- If reminder settings do not change, saving Settings should not request notification permission.
