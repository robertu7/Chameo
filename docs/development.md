# Development

## Project Layout

```text
Package.swift
Package.resolved
Chameo.entitlements
script/build_app.sh
script/prepare_release.sh
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

Run the automated test suite:

```bash
swift test
```

Run the Swift 6 concurrency migration audit while the package remains in Swift 5 language mode:

```bash
swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warn-concurrency
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

The build rejects malformed version metadata before compilation and marks the build id as dirty for both tracked and untracked changes.

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

The build automatically selects an installed Apple Development identity, then
an installed Developer ID Application identity. Stable signing lets macOS
retain Camera and Photos grants when the app binary is replaced. Override the
selection when needed:

```bash
CHAMEO_CODE_SIGN_IDENTITY="Apple Development: Name (TEAMID)" ./script/build_app.sh
```

If neither identity is available, the script warns and uses ad-hoc signing.
Because an ad-hoc app's identity changes with its code hash, a rebuilt app must
request protected-resource permissions again. Set
`CHAMEO_CODE_SIGN_IDENTITY=-` only when that behavior is intentional.

The staged bundle embeds the pinned Sparkle framework under
`Contents/Frameworks`, signs its installer/downloader helpers inside-out, and
then signs the containing app. Do not replace this sequence with
`codesign --deep`; `--deep` is used only for verification.

## Updates and Test Releases

Sparkle 2.9.4 is pinned in `Package.swift` and `Package.resolved`. Chameo uses:

- `https://robertu7.github.io/Chameo/appcast.xml` as its update feed.
- EdDSA-signed archives, release notes, and appcast XML.
- Pre-extraction archive verification and fail-closed signed-feed validation.
- Sparkle's sandboxed installer and downloader XPC services.
- A 24-hour scheduled check after the user grants permission.
- Standard user-confirmed download, installation, and relaunch UI.

`CHANGELOG.md` is the release-notes source of truth. A release section must
match the three-component version in `VERSION`.

The CI workflow runs on pull requests and pushes to `main`. Push a matching tag
to start a prerelease:

```bash
git tag v0.3.6
git push origin v0.3.6
```

The tag commit must be reachable from `origin/main`. The release workflow:

1. Repeats tests and bundle validation on an Apple Silicon `macos-14` runner.
2. Builds an ad-hoc-signed ZIP.
3. Signs and verifies the ZIP, release notes, and appcast.
4. Creates a public GitHub prerelease.
5. Publishes the signed appcast through GitHub Pages.
6. Verifies the published release and feed URLs.

Before the first release:

1. In the repository's **Settings → Pages**, select **GitHub Actions** as the
   deployment source.
2. Create a GitHub environment named `release`.
3. Export the Chameo Sparkle private key and store it as the
   `SPARKLE_PRIVATE_KEY` secret in that environment.
4. Keep a separate offline backup of the private key.

The private key is stored in the login Keychain under the Sparkle account
`com.robertu.Chameo`. Export it without printing it:

```bash
SPARKLE_TOOLS=".build/artifacts/sparkle/Sparkle/bin"
"$SPARKLE_TOOLS/generate_keys" \
  --account com.robertu.Chameo \
  -x /path/outside/the/repository/chameo-sparkle-private-key
gh secret set SPARKLE_PRIVATE_KEY \
  --env release \
  --repo robertu7/Chameo \
  < /path/outside/the/repository/chameo-sparkle-private-key
```

Treat the exported file like a password. Never commit it or attach it to a
release.

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

- Validate the complete staged bundle:

```bash
./script/verify_app_bundle.sh dist/Chameo.app
```

- Inspect generated bundle metadata:

```bash
plutil -p dist/Chameo.app/Contents/Info.plist
```

## Implementation Notes

- Keep AppKit interop narrow. `StatusPopoverController` owns status item and popover behavior; SwiftUI owns feature UI.
- Do not start the camera outside the visible Camera tab.
- Keep hands-free capture dependent on the visible face guide, cancel its timer
  on Camera lifecycle changes, and route automatic capture through the same
  preview flow as the manual button.
- Do not write to Photos on `Take Chameo`; write only on `Save to Photos`.
- Keep destructive Photos deletion behind inline confirmation.
- If reminder settings do not change, saving Settings should not request notification permission.
- Add durable preference keys through `AppPreferenceKey`; background code should read reminder preferences through `StoredReminderSettings`.
- Keep reminder recurrence rules in `ReminderSchedule` so UI previews and scheduled notifications cannot diverge.
