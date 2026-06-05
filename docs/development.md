# Development

## Project Layout

```text
Package.swift
Chameo.entitlements
script/build_and_run.sh
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

Use the project script for app launch:

```bash
./script/build_and_run.sh
```

The script is the preferred run path because SwiftPM GUI executables should launch as an `.app` bundle, not as a raw command-line process.

## App Icon

The app icon is generated from a deterministic AppKit drawing script:

```bash
swift script/generate_app_icon.swift
```

The script writes `Assets/AppIcon.iconset/` and packages `Assets/AppIcon.icns`. The build script copies `Assets/AppIcon.icns` into the app bundle and declares it as `CFBundleIconFile`.

## Run Script Modes

```bash
./script/build_and_run.sh
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --debug
```

- `run`: build, stage, sign, launch.
- `--verify`: launch and confirm the process exists.
- `--logs`: launch and stream logs for the process.
- `--telemetry`: launch and stream logs filtered by bundle ID.
- `--debug`: open the built binary under `lldb`.

## Codex Run Button

`.codex/environments/environment.toml` wires the Codex app Run action to:

```bash
./script/build_and_run.sh
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
- Keep destructive Photos deletion behind inline confirmation unless the behavior changes to non-destructive album removal.
- If reminder settings do not change, saving Settings should not request notification permission.
