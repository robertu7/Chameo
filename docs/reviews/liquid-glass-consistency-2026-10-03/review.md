# Chameo UI consistency review — October 3, 2026

**Result: implementation and inspected content layouts align; full native visual/accessibility acceptance remains open.** Native inspection initially returned `timeoutReached` (`-10005`), then recovered after rebuilding the test app. The user completed Camera and Photos authorization personally, enabling live main-window and Settings review.

## Scope and intended experience

Camera, capture review, Library, the four Settings categories, the New Album sheet, local-copy help, all onboarding pages, and Timelapse setup/progress/completion. The goal is a compact daily-photo experience with consistent control roles, legible content, and distinct glass navigation.

The approved fixed geometry remains: Camera/Library 448 × 526 points; Settings/Timelapse 500 × 460; onboarding 500 × 560. Onboarding uses the same utility width with extra height for permissions and illustrations. Windows remain nonresizable.

## Apple guidance used

- Glass belongs to navigation and controls; content should retain a clear hierarchy. Avoid glass on glass, use Regular for adaptable legibility, and reserve tint for emphasis. System glass responds to accessibility settings. [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/).
- Primary actions should be distinct, support Return where appropriate, and avoid making destructive actions the default. [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons).
- Use dynamic system colors consistently across light, dark, and increased-contrast appearances. [Color](https://developer.apple.com/design/human-interface-guidelines/color).
- System fonts support interface legibility and adaptability. [Fonts](https://developer.apple.com/documentation/technologyoverviews/fonts).

## Confirmed strengths and changes

| Area | Review and resulting treatment |
| --- | --- |
| Action hierarchy | Native `.glassProminent` primary actions; `.glass` secondary actions; accent-colored borderless tertiary text actions. The New Album sheet now explicitly distinguishes Create from Cancel and groups its actions. Delete remains destructive with confirmation. |
| Navigation | Camera/Library and Settings share the same SwiftUI selector. Selected segments now use Regular interactive system glass instead of a solid fill and hand-drawn shadow. Settings has a `GlassEffectContainer`; the main navigation already groups its adjacent glass controls. No glass is applied to the selector track. |
| More menus | App and photo menus now use `ChameoMoreMenu`: the same ellipsis, 13-point semibold symbol, 28-point circular target, glass treatment, accessible label, and help. The decorative normal-contrast outline was removed so system glass defines its edge; the accessibility contrast treatment remains. |
| Typography | Settings, onboarding, and Timelapse use 22-point semibold system headings. Settings subtitles now use the same callout style as onboarding and Timelapse. Body, caption, and compact calendar/navigation roles retain their deliberate hierarchy. |
| Color | Primary/secondary text and system backgrounds adapt to appearance. Accent means an action or selection; green means captured/allowed/ready, orange means pending/warning, and red identifies errors/destructive actions. Status descriptions and symbols accompany color. |
| Content surfaces | Photos, calendar dates, grouped settings, and explanations remain content surfaces. Only controls/navigation receive Liquid Glass; camera guidance uses a readable material with an opaque Reduce Transparency fallback. |
| Density and spacing | Shared rounded-rectangle action borders remain at radius 8. Large actions serve Camera/onboarding/Timelapse; compact actions serve Settings and Library. The Today/Timelapse row remains right-aligned and separate from month navigation. Settings heading spacing remains 16 points. |
| Accessibility in source | Icon controls have labels/help. Custom selectors retain selected traits, focus outlines, and arrow-key routing. Custom glass/readable surfaces account for transparency/contrast; camera guidance respects Reduce Motion. Permission warnings now expose full text through help and accessibility labels. |

Live accessibility inspection also found the Album row and picker repeating their label and value. The label/value/help now belong to the picker alone; its redundant visible label is hidden from accessibility while remaining visually unchanged. This correction passed compilation and tests; its final native accessibility tree remains unchecked because rebuilding reset test-app permissions.

Intentional desktop/product choices remain: the explicit category selector preserves the approved appearance and page state after the native tab layout issue; rounded-rectangle actions preserve the approved drafts; fixed utility sizes use scrolling for longer content. These do not imply that every control matches a default system shape or that custom navigation has passed live keyboard testing.

## Fresh evidence and limits

Before and after renders were generated from the current working source in app-hosted XCTest. The fixture uses isolated defaults, synthetic photographs, and permission stubs; it never starts the camera or grants access. There are 168 current main/Settings/onboarding content captures in `/tmp/chameo-consistency-after` and 36 fresh Timelapse captures in `/tmp/chameo-timelapse-previews`. Representative layouts were opened and inspected across all page types, Chinese text, light/dark appearances, and six-row calendar content.

- Library: [before](before-library.png), [after](library.png).
- Settings: [Photos before](before-settings-photos.png), [Photos after](settings-photos.png), [General dark](settings-general-dark.png), [Capture](settings-capture.png), [Reminders in Traditional Chinese](settings-reminders-zh-Hant.png).
- Camera: [review in Simplified Chinese](camera-review-zh-Hans.png).
- Onboarding: [Camera](onboarding-camera.png), [Library in Traditional Chinese](onboarding-library-zh-Hant.png), [permissions in dark Simplified Chinese](onboarding-permissions-dark-zh-Hans.png).
- Timelapse: [creating](timelapse-progress.png), [created in Traditional Chinese](timelapse-created-zh-Hant.png).

`NSView.cacheDisplay` omits native glass backgrounds, tint, and some label adaptation. Missing selection surfaces, missing circular menu surfaces, or black glass labels in these captures cannot establish the installed app's appearance or contrast. Before/after captures therefore support grouping, sizing, typography, and content alignment. Live inspection separately confirmed the navigation and More glass surfaces and the New Album sheet layout; active glass contrast remains open.

The host runs macOS **27.0.1**. Package and bundle deployment requirements remain **26.0**; this review does not establish execution on a macOS 26 device. Light/dark/high-contrast appearance fixtures rendered successfully. Reduce Transparency and Reduce Motion cannot be injected into these fixtures through their read-only SwiftUI environment keys; attempted overrides were removed, leaving those settings for native system checks.

Live follow-up: the accessibility tree exposes labeled Back/Next controls, the current onboarding step, named Camera/Photos Allow actions, and a disabled Continue action while access is missing. The user completed setup for the main-window review. After the final rebuild, all three onboarding pages rendered completely; titles, illustrations, permission rows, and footer actions fit. The [menu-bar guidance](native-onboarding-permissions.png) shows the eye icon highlighted with an upward arrow. Earlier partially obscured onboarding captures are not acceptance evidence.

The live Camera preview subsequently rendered correctly. Its camera selector was readable against a bright scene, and the tab selector and circular More control had native glass surfaces. Camera imagery was not saved into these review artifacts. The empty Library displayed its six-row calendar, selected day, separate right-aligned action row, and date-status descriptions. Opening Settings through More hid the main window. Settings categories and title spacing were inspected natively, and the zoom controls were disabled.

Native evidence: [Library](native-library-zh-Hans.png), [General](native-settings-general-zh-Hans.png), [Photos](native-settings-photos-zh-Hans.png), [Capture](native-settings-capture-zh-Hans.png), [Reminders off](native-settings-reminders-zh-Hans.png), [New Album sheet](native-new-album-zh-Hans.png), and [Traditional Chinese General](native-settings-general-zh-Hant.png). The New Album form was populated only to inspect its enabled action and then cancelled; no album was created. The Local Copies popover opened at its info button, exposed the full explanation to accessibility, and dismissed through its native Cancel action. Its [capture](native-local-copy-help-zh-Hans.png) is cropped to the parent window and does not include the complete outside-window popover.

English and Traditional Chinese labels were selected temporarily and Simplified Chinese was restored. Captures mainly show inactive-window styling, where controls recede; active primary-button contrast remains unverified. Tab did not establish a focused control in the tool's window context, so complete keyboard traversal is not asserted.

The user opened Timelapse from the menu bar for the native follow-up. Its setup screen displayed one photo, date, duration, output details, and the Create action without clipped content at the fixed utility size. Heading and subtitle typography match Settings and onboarding. The zoom control was disabled and the primary action had an accessible label. This screenshot contained the user's real photo and was not saved to the repository. Creating/created states were reviewed with synthetic fixtures; real generation, completion, and active-button contrast were not exercised in this native pass.

## Validation

- Full suite: **201 tests, one optional render test skipped, zero failures** (`/tmp/chameo-consistency-tests.log`). Existing Settings reuse/retention, fixed sizing, camera visibility routing, and export ownership regressions pass.
- Strict-concurrency build command passed (`/tmp/chameo-consistency-strict.log`).
- Updated main/Settings/onboarding render fixture passed separately (`/tmp/chameo-consistency-after.log`); Timelapse state rendering passed with a synthetic photo (`/tmp/chameo-consistency-timelapse.log`).
- Local release bundle built and passed `verify_app_bundle.sh`; local test bundle rebuilt, signature verified, and launch/process verification passed. Both require macOS 26.0. The release build retains an existing reverse-geocoding deprecation warning unrelated to these changes.
- The final ad-hoc test rebuild reset protected-resource permissions, as reported by the build script. The app is running at the onboarding permissions page; no permissions were granted by the agent.
- No preference keys, capture behavior, reminder scheduling, export ownership, version, or publication changed. Timelapse completion notifications remain removed; accessibility announcements remain available.

## Remaining acceptance

Verify on screen: glass contrast over bright/dark video, active/inactive windows, hover/disabled states, full keyboard traversal and VoiceOver, complete outside-window popover presentation, and system Reduce Motion/Reduce Transparency/Increase Contrast. Native capture/retake/save, Photos/iCloud recovery, and real Timelapse generation/completion remain hardware/system checks. Full Apple-guideline or accessibility compliance is not asserted before these checks pass.
