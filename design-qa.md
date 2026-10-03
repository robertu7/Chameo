# Approved screens implementation — 2026-10-02

**Final result: blocked.** Implementation, regression checks, offscreen layout review and local bundle verification are complete. Live compositor and keyboard inspection remain unavailable: computer use reported that the Mac was locked, and subsequent native inspection timed out. Offscreen captures omit native glass and category-tab rendering; they cannot establish appearance, contrast or focus behavior.

The previous Timelapse review is preserved in [prior-timelapse-qa.md](docs/reviews/approved-screens-2026-10-02/prior-timelapse-qa.md). Its resizable-window sizes are superseded by this pass.

## Targets and window contract

The user approved all three design boards, then requested fixed sizing and consistency. Production remains native SwiftUI/AppKit.

| Surface | Fixed content size |
| --- | --- |
| Camera / Library popover and standalone window | 448 × 526 points |
| Settings / Timelapse | 500 × 460 points |
| Onboarding | 500 × 560 points |

Native title bars add chrome outside these dimensions. Onboarding shares the utility width, with extra height for illustrations and permissions. Windows omit the resizable style, have equal content minimum/maximum sizes, disable zoom and opt out of full screen. Settings and Timelapse use one size constant and reapply it after saved-frame restoration. Longer content scrolls within the fixed window; system save panels retain native behavior.

| Approved source | Inspected combined comparisons |
| --- | --- |
| [Main board](docs/reviews/approved-screens-2026-10-02/draft-main.png) | [Review](docs/reviews/approved-screens-2026-10-02/comparison-camera-review.png), [captured day](docs/reviews/approved-screens-2026-10-02/comparison-library-captured.png), [Today](docs/reviews/approved-screens-2026-10-02/comparison-library-today.png) |
| [Settings board](docs/reviews/approved-screens-2026-10-02/draft-settings.png) | [General](docs/reviews/approved-screens-2026-10-02/comparison-general.png), [Capture](docs/reviews/approved-screens-2026-10-02/comparison-capture.png), [Reminders](docs/reviews/approved-screens-2026-10-02/comparison-reminders.png), [Photos](docs/reviews/approved-screens-2026-10-02/comparison-photos.png) |
| [Onboarding board](docs/reviews/approved-screens-2026-10-02/draft-onboarding.png) | [Capture introduction](docs/reviews/approved-screens-2026-10-02/comparison-onboarding-capture.png), [story](docs/reviews/approved-screens-2026-10-02/comparison-onboarding-story.png), [permissions](docs/reviews/approved-screens-2026-10-02/comparison-onboarding-permissions.png) |

Source boards measure 1159 × 1358, 1216 × 1294 and 1889 × 832 pixels respectively. App-owned regions are cropped and proportionally fitted beside native content in a 2040 × 1180 comparison canvas. [make-comparisons.swift](docs/reviews/approved-screens-2026-10-02/make-comparisons.swift) records crop coordinates and scaling. Images are never stretched. Native content is captured at 2× density: 896 × 1052, 1000 × 920 and 1000 × 1120 pixels respectively. There is no CSS viewport. Decorative reference chrome and imperfect generated aspect ratios do not override the requested sizes.

Production views render in an app-hosted XCTest fixture with isolated defaults, temporary folders, synthetic album assets and generated portraits. Camera hardware, permission grants, network update checks and real user photographs are not involved. General's login row is absent in the fixture/test distribution and remains present in production. Album, folder, reminder times and build information reflect fixture data.

## Findings and fixes

- **Resolved P2: switch alignment and Photos clipping.** Full-width labels push switches right. Compact group spacing keeps Location visible at the fixed height. Post-fix [English](docs/reviews/approved-screens-2026-10-02/english-light-settings-photos.png) and [Traditional Chinese](docs/reviews/approved-screens-2026-10-02/traditionalChinese-light-settings-photos.png) captures show complete content.
- **Resolved P2: album text lacked room.** An explicit label/picker row and fixed-size native picker restore the visible selected album.
- **Resolved P2: undersized onboarding story illustration.** The transparent photo stack now uses a 440-point presentation area. Subtitle wrapping and stable footer placement follow the approved hierarchy; the post-fix story comparison is linked above.
- **Open P2 verification: native glass, tabs and focus.** Cached captures omit button backgrounds and switch tint, and fail to compose native category tabs correctly. A native layout warning accompanies cached tab rendering. Inspect the signed test app on an unlocked Mac to distinguish capture limitations from production defects. Do not classify these surfaces as passed from cached images.
- **Resolved P2, control fidelity follow-up:** The user reported that tabs and More differed from the draft. Camera/Library now use SwiftUI buttons with explicit icon-and-text labels, a neutral raised selection, visible keyboard-focus rings and left/right navigation. More uses a 28-point circular glass surface with an outline applied to the menu itself, since macOS ignores effects inside the menu icon. Settings explicitly use native grouped tabs; native action borders are rounded rectangles. The latest cached comparison verifies the main tab icons, selection and More outline. Native glass and focus still require live inspection; the computer-use attempt timed out. Fixed sizes remain unchanged.

## Required fidelity surfaces

| Surface | Assessment |
| --- | --- |
| Fonts / typography | Native SF text; 22-point semibold Settings/onboarding headings and secondary subtitles/captions. Three-language content renders are available. The compact calendar retains its existing headline to fit six rows. |
| Spacing / rhythm | Shared Settings page/group spacing and trailing controls; separate right-aligned Today/Timelapse row with more vertical space; clearer 32-point thumbnails. Onboarding progress/navigation stay outside scrolling content. |
| Colors / tokens | Semantic clear content groups adapt to light/dark. Selection/calendar semantics remain. Glass stays on controls and framing feedback keeps its readable surface. Actual glass and system accessibility settings remain unverified. |
| Images / quality | New portrait and transparent stack illustrations are bundled for onboarding. Production Camera, Library and Timelapse use real camera/album data; fixture imagery is synthetic. Aspect ratios are preserved; scaled-to-fit capture review can retain narrow pillarboxing. |
| Copy / content | Approved headings and supporting text are localized in English, Simplified Chinese and Traditional Chinese. Local-copy explanations remain in a disclosure group, with preservation guidance always visible. Recovery, reminder previews, progress and explicit Open Folder actions remain. |

Full-view combined inputs show text and alignment at readable scale; additional crops cannot resolve missing compositor surfaces. Dark content and Chinese Photos/permissions captures were inspected separately. Cached dark glass labels cannot establish button contrast.

## Validation evidence

- Final suite: **200 tests, one optional preview skipped, zero failures**. Fixed sizing, category/window reuse, onboarding placement, camera visibility routing and background export ownership remain covered.
- Native render fixture passed separately in all three languages and light/dark/high-contrast appearances. Export-state rendering passed at the new shared size. [Setup](docs/reviews/approved-screens-2026-10-02/timelapse-fixed-setup.png) and [Traditional Chinese completion](docs/reviews/approved-screens-2026-10-02/timelapse-fixed-created-zh-Hant.png) were inspected.
- Strict-concurrency compilation passed with complete checking and concurrency warnings enabled. Whitespace validation passed.
- Local release and isolated test bundles built with ad-hoc signatures. Release bundle verification and both deep/strict signature checks passed. The bundle verifier now checks both new onboarding assets. Both bundles require macOS **26.0**; Swift tools remain **6.2** with the existing Swift language mode. These are local builds, without notarization/publication.
- Capture, alignment, save, storage preference keys, reminder scheduling and export ownership are preserved. Timelapse completion notifications remain removed. No version change, commit, push or publication was performed.

## Remaining native acceptance

Inspect native category tabs, glass buttons, switch tint, active/inactive focus, Tab traversal and disabled states on the unlocked Mac. Check bright/dark real video, camera switching, countdown/capture/retake/save, permission recovery, expanded explanations, weekly/one-time reminder fields, all languages, and Timelapse progress/completion. Confirm fixed sizing and no camera activity while the main surface is hidden. VoiceOver, Reduce Motion, Reduce Transparency, Increase Contrast and real Photos/iCloud export remain system/hardware checks, separate from automated success.

## Implementation checklist

- [x] Approved layouts and onboarding illustrations implemented.
- [x] Shared fixed sizing and resize/zoom/full-screen restrictions applied.
- [x] Category retention and existing capture/export behavior preserved.
- [x] Localization, native content captures and combined comparisons reviewed.
- [x] Tests, strict compilation, bundle building and signature verification passed.
- [ ] Live compositor, keyboard and hardware acceptance completed; visual QA passed.
