# macOS 26 UI Validation

The modernization requires macOS 26+, keeps the 448 × 526 capture popover, and
moves Settings into a reusable native window with General, Capture, Reminders,
and Photos categories. Existing preference keys and photo/export services remain
compatible with stored data.

## Automated Results

- Full suite: 198 tests, zero failures; the optional layout-preview export is skipped.
- Strict-concurrency compilation: passed. Existing concurrency and reverse-geocoding deprecation warnings are outside this UI change.
- Release app: built, signed, and passed `script/verify_app_bundle.sh`.
- Bundle metadata and executable both require macOS 26.0.
- Native content-layout fixture: passed, generating 84 previews across three languages and four native appearances.
- Regression coverage includes Settings window reuse and minimum sizing, retained category/tab/day selection, camera routing, and visibility belonging only to the active hosting surface.

## Live Review Still Required

The signed test app was built, but macOS could not launch it in the execution
environment (`RBSRequestErrorDomain Code=5`, underlying spawn error 163). The UI
inspection surface could not locate that bundle. Cached AppKit previews omit or
misrender native tab controls and composited Liquid Glass; they do not verify
actual glass contrast, pointer behavior, keyboard focus, or hardware operation.

Use the existing Run action or `./script/build_and_run.sh` on a Mac with a working
desktop session. Check the test build, which uses separate preferences and a
separate album/local folder:

- Camera and Library navigation, app-menu Settings, Command-comma, Command-Q, and text-field copy/paste work with pointer and keyboard.
- Settings retains its selected category after closing/reopening; all controls remain reachable by scrolling at 560 × 480. New Album supports Return and Escape.
- Closing, minimizing, hiding, or opening Settings stops the camera. Returning restores the appropriate tab/day; only the visible hosting surface can capture or count down.
- Camera controls and framing guidance remain readable over bright/dark scenes. Verify switching cameras, preview mirroring, manual/hands-free capture, retake, save, and permission-recovery states.
- Library handles six-row months, focus/selection, multiple thumbnails, local-copy actions, and deletion confirmation.
- Timelapse continues while its window is closed; reopening shows current progress and completion offers explicit Open Folder/Open Video actions.
- Repeat in English, Simplified Chinese, Traditional Chinese, light/dark appearance, Increase Contrast, Reduce Transparency, Reduce Motion, and VoiceOver.

## Onboarding Captures

The existing Camera and Library onboarding images are retained pending live
review. Replace them with accurate captures of the verified screens; the
content-layout previews are unsuitable because native chrome and glass are not
reliably captured. No fabricated replacement screenshots are included.
