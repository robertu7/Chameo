# macOS 26 UI Validation

The modernization requires macOS 26+, keeps the 448 × 526 capture popover, and
moves Settings into a reusable native window with General, Capture, Reminders,
and Photos categories. Existing preference keys and photo/export services remain
compatible with stored data.

## Automated Results (October 2, 2026)

- Full suite: 196 tests, zero failures; the optional layout-preview export is skipped.
- Strict-concurrency compilation: passed. Existing concurrency and reverse-geocoding deprecation warnings are outside this UI change.
- Test and release apps: rebuilt and signed. The release app passed `script/verify_app_bundle.sh`.
- Bundle metadata and executable both require macOS 26.0.
- Native content-layout fixture: passed, generating 84 previews at the compact sizes across three languages and four native appearances. The existing offscreen tab/glass rendering limitation remains; these verify content layout, not native chrome.
- Regression coverage includes Settings window reuse and minimum sizing, retained category/tab/day selection, camera routing, and visibility belonging only to the active hosting surface.

## Initial Live Review Limitation (October 2, 2026)

At the time of the initial review, the signed test app was built, but macOS could
not launch it in the execution environment (`RBSRequestErrorDomain Code=5`,
underlying spawn error 163). The UI
inspection surface could not locate that bundle. Cached AppKit previews omit or
misrender native tab controls and composited Liquid Glass; they do not verify
actual glass contrast, pointer behavior, keyboard focus, or hardware operation.

Native launch and inspection subsequently recovered. The
[October 3 UI review](../reviews/liquid-glass-consistency-2026-10-03/review.md)
records live Camera, Library, Settings, onboarding, and Timelapse setup
inspection. The owner also confirmed the complete photo workflow and
reminders/Sparkle update workflow as validated on October 3; see the
[workflow validation record](daily-workflows.md).

## Current Geometry and Regression Checklist

Camera/Library remains 448 × 526 points. Settings and Timelapse are both fixed
at 500 × 460; onboarding is fixed at 500 × 560. These windows are nonresizable,
with zoom disabled. Longer Settings and Timelapse content uses scrolling
within the fixed layout.

Use the existing Run action or `./script/build_and_run.sh` on a Mac with a working
desktop session. Check the test build, which uses separate preferences and a
separate album/local folder:

- Camera and Library navigation, app-menu Settings, Command-comma, Command-Q, and text-field copy/paste work with pointer and keyboard.
- Settings retains its selected category after closing/reopening; all controls remain reachable by scrolling at 500 × 460. New Album supports Return and Escape.
- Closing, minimizing, hiding, or opening Settings stops the camera. Returning restores the appropriate tab/day; only the visible hosting surface can capture or count down.
- Camera controls and framing guidance remain readable over bright/dark scenes. Verify switching cameras, preview mirroring, manual/hands-free capture, retake, save, and permission-recovery states.
- Library aligns Today and Timelapse to the right with extra vertical spacing, and keeps six-row months, focus/selection, multiple thumbnails, local-copy actions, and deletion confirmation usable. The popover app-menu icon is 18 points.
- Settings and Timelapse open at the fixed 500 × 460 content size; both support scrolling for longer content.
- Timelapse never requests notification permission or sends a completion notification.
- Timelapse continues while its window is closed; reopening shows current progress and completion offers explicit Open Folder/Open Video actions.
- Repeat in English, Simplified Chinese, Traditional Chinese, light/dark appearance, Increase Contrast, Reduce Transparency, Reduce Motion, and VoiceOver.

Capture/Retake/Save and real Photos/iCloud/Timelapse operation are validated
through the owner's confirmation. The checklist remains a regression reference;
full keyboard traversal, VoiceOver, system accessibility settings, permission
denial/recovery, and launch at login still need acceptance checks.

## Onboarding Evidence

The October 3 UI review records the updated onboarding illustrations, rendered
content, and native inspection. Use its linked captures for current evidence.
Content-layout previews verify layout but do not establish native glass
contrast or full accessibility acceptance.
