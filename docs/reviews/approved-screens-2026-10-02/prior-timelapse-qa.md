# Timelapse photo-stack implementation — 2026-10-02

Archived review: this records the October 2 implementation and is not a current acceptance check. Screenshot links resolve to retained repository evidence.

**Final result: passed** for the approved layout and the native fixture flow. Real Photos/iCloud generation and system accessibility settings retain the manual checks listed below.

## Visual targets and evidence

The user selected the second setup draft, then approved the matching Creating and Created drafts. This implements those three states in the existing native SwiftUI window, not a separate web prototype.

| State | Approved visual | Current native fixture | Combined comparison |
| --- | --- | --- | --- |
| Setup | [Draft](../timelapse-keepsake-2026-10-02/draft-setup.png) | [Capture](../timelapse-keepsake-2026-10-02/native-setup.png) | [Comparison](../timelapse-keepsake-2026-10-02/comparison-setup.png) |
| Creating | [Draft](../timelapse-keepsake-2026-10-02/draft-creating.png) | [Capture](../timelapse-keepsake-2026-10-02/native-creating.png) | [Comparison](../timelapse-keepsake-2026-10-02/comparison-creating.png) |
| Created | [Draft](../timelapse-keepsake-2026-10-02/draft-created.png) | [Capture](../timelapse-keepsake-2026-10-02/native-created.png) | [Comparison](../timelapse-keepsake-2026-10-02/comparison-created.png) |

The comparisons put the source and implementation together in the same image. Native captures use a temporary app-hosted fixture with the production view, an isolated fake generator, and a portrait extracted from the approved mock. The same fixture portrait is repeated; production instead loads the first, middle, and latest available album thumbnails. No camera/Photos permission was requested, and the fixture output is not a playable video. The temporary interactive fixture was removed after capture; the persistent tests cover actual view layout and thumbnail retention.

**Viewport and normalization:** production content is 460 × 480 points, with a 460 × 420 minimum. Native screenshots are 920 × 1024 pixels including the 32-point title bar; their 920 × 960 content crops are compared at 2× density. The generated targets are 1228 × 1281 pixels; their 1128 × 1100 content crops are scaled proportionally to fit the same 920 × 960 comparison region, with neutral padding. There is no CSS viewport. Native chrome and the screen-sharing overlay are excluded. The generated draft's imperfect aspect ratio is not reproduced by stretching the photos or changing the supported window sizes.

## Findings and fixes

- **Resolved P2: destination text clipped at minimum height in Traditional Chinese.** The first fixture retained a 126-point minimum photo size, leaving insufficient room for the file-location line. The stack now shrinks to 110 points at 420-point window height. The post-fix [minimum-size Traditional Chinese capture](../timelapse-keepsake-2026-10-02/fixture-traditional-minimum.png) shows the filename, destination, and all completion actions.
- **Resolved P2: progress detail absent from initial offscreen captures.** The synchronous renderer captured changing view state before it settled. The renderer now awaits view tasks and layout. The post-fix creating capture shows both the phase detail and its bar. Native accessibility inspection also reported “Encoding video · 132 of 184 photos” and a fraction of 0.7173913.
- **No remaining actionable P0/P1/P2 layout findings** in the inspected fixture states. Source imagery differences are fixture data, and system button shapes/chrome are intentional native adaptations.

## Required fidelity surfaces

| Surface | Assessment |
| --- | --- |
| Fonts and typography | Native SF Pro, centered 22-point semibold titles, 17-point summaries, system body/caption styles. Dates, summary, phase, filename and action text remain readable and localized. Small raster/font-rendering differences from the generated mock are expected. |
| Spacing and layout rhythm | The same photo stack and summary stay in place in setup, creating and created. Status changes below the summary. The action footer stays outside scrolling content. The stack adapts to supported height; errors and completion warnings can scroll without pushing actions away. |
| Colors and visual tokens | Clear semantic content background adapts to light/dark. Glass is confined to actions. Native capture verifies a blue Open Video primary action and neutral Open Folder/Cancel controls. Setup's primary action appears muted in its capture but responded to Return and began creation; active/inactive focus colors remain a manual spot check. |
| Image quality and assets | Square images preserve aspect ratio, with two rotated rear thumbnails and a centered front thumbnail. Existing contrast-aware outlines and modest shadows separate photos. Local-only preview requests increase to 360 × 360 for the larger Retina presentation; they do not start iCloud downloads. No generated portraits are bundled with the app. |
| Copy and content | Approved setup/creating/created wording is localized in English, Simplified Chinese and Traditional Chinese. Encoding reports frame counts; downloading reports its photo fraction; unknown work remains indeterminate. Completion provides the real filename, short folder and full path in help/accessibility. |

Full-view comparisons show all relevant text and controls at readable scale, so an additional focused crop is unnecessary. Offscreen [dark](../timelapse-keepsake-2026-10-02/fixture-dark-minimum.png) and [high-contrast](../timelapse-keepsake-2026-10-02/fixture-contrast-minimum.png) captures verify content layout; their cached native glass controls are not compositor evidence for button contrast.

## Interaction and regression evidence

- Native fixture: Return started creation; accessibility inspection verified phase description, fractional progress, Cancel, then Open Folder, Open Video and Create Another in the same window. Native compositor captures verify creating/completion controls. Opening actions were not invoked on the fake video.
- Regression: thumbnail requests remain exactly once per sampled asset across setup, generation and completion. Existing tests cover cancellation, late completion, retries, saved results, window reuse, background ownership and minimum size.
- Localization and fixture rendering cover all three languages, both supported sizes, preparation/download/encoding/saving/completion and empty states.
- No notifications were added; no preferences, photo storage, generation settings, version or publication changed.

## Remaining manual checks

Real Photos/iCloud downloads, playable exported video, full Tab traversal under the user's macOS Keyboard Navigation preference, VoiceOver announcements, active/inactive setup colors, and system Reduce Motion/Reduce Transparency behavior are not established by these fixtures. Native glass follows system accessibility settings; the photo stack adds no custom animation.

## Implementation checklist

- [x] Shared photo-stack composition across setup, creating and created.
- [x] Phase-specific progress, Cancel and background-generation explanation.
- [x] Filename/location and explicit Open Video/Open Folder/Create Another actions.
- [x] Empty, cancellation, retry and warning paths retained.
- [x] Minimum-height adjustment and post-fix captures inspected.
- [x] Three-language catalog checks and full regression suite: 200 tests, one optional preview skip, zero failures.
- [x] Strict-concurrency compilation passed.
- [x] Local release bundle built and passed `script/verify_app_bundle.sh`; isolated test bundle rebuilt and passed deep/strict signature verification. Both bundles require macOS 26.0. These use ad-hoc local signatures and are not distribution/notarization builds.
