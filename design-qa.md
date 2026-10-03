# Timelapse Dropdown Layout — Design QA

**final result: passed** for the reference-to-render visual comparison.
Live menu clicks, keyboard traversal, VoiceOver, and real Photos/iCloud export
with the new controls remain owner testing; this report does not claim those
were exercised by cached native renders.

## Target and Evidence

The user explicitly supplied the selected option 1 screenshot. That attachment,
rather than the earlier incorrect numbered-option mapping, is the visual truth.

- Source: `docs/reviews/timelapse-options-2026-10-03/draft-setup.png`.
- Implementation: `docs/reviews/timelapse-options-2026-10-03/english-summary.png`.
- Full comparison: `docs/reviews/timelapse-options-2026-10-03/comparison-setup.png`.
- Focused controls: `docs/reviews/timelapse-options-2026-10-03/comparison-controls.png`.
- Expanded state: `docs/reviews/timelapse-options-2026-10-03/english-month.png`.
- Localized state: `docs/reviews/timelapse-options-2026-10-03/traditionalChinese-month.png`.

State: All Photos, 10 photos/sec, 184 synthetic photos, March 1–October 3, 2026,
18.4 seconds, light appearance. The native content viewport is 500 × 430 points,
rendered at 2× as 1000 × 860 pixels. There is no CSS viewport. Source pixels are
1308 × 1203; crop `(4, 75, 1304, 1198)` excludes native title-bar chrome. The crop
is proportionally fitted to 1000 × 860 with a negligible 2-pixel vertical edge
crop. Native window chrome is not recreated in the view. Both artifacts were
opened together in the combined comparison, followed by the enlarged controls
comparison. The fixture renders the production SwiftUI view in an NSHostingView
with synthetic Photos assets and a synthetic portrait. No fixture is bundled
in the app; production loads real selected first/middle/last thumbnails.

## Findings and Comparison History

1. [P1, fixed] Wrong selected design. The previous screen used two segmented
   preset bars and placed options before the summary. The uploaded reference
   requires the summary first and two labelled dropdown rows. The screen now
   follows that order, with native Menu/Picker selection behind each field.
2. [P2, fixed] Initial native popup styling collapsed field widths, added native
   double chevrons, and did not preserve the reference's full rectangular fields.
   Button-style menus with an explicit label surface now retain 170 × 26-point
   fields and a single SF Symbols chevron. The focused comparison confirms both.
3. [P2, fixed] Window proportions and photo-stack geometry drifted. The initial
   500 × 460 viewport was taller than the reference. It is now 500 × 430;
   the center photo is 144 points, smaller rear photos fan behind it, and spacing
   leaves all three dividers and the Create action visible without scrolling in
   the default state. Extra date fields shrink the stack instead of hiding Create.
4. [P2, fixed] Offscreen native glass omitted the blue Create surface. The setup
   action now uses an explicit rounded blue button style with press, disabled,
   and focus treatments. The resulting fill is present in the render.

Each implementation correction was followed by new native renders. The final
full-view and focused comparisons show no remaining actionable P0/P1/P2 visual
mismatches. The earlier report's claim that segmented presets represented the
selected design is superseded by this report and the uploaded reference.

## Required Fidelity Surfaces

| Surface | Evaluation |
| --- | --- |
| Fonts and typography | Native system family, 22-point bold heading, 14-point subtitle, 18-point bold count/duration, 12-point date and controls, and 11-point format preserve the reference hierarchy. Localized fields fit. |
| Spacing and layout rhythm | Heading, large photo stack, date, count/duration, format, divided dropdown rows, and centered wide Create action follow the source. The same window width is retained; its height now matches the source ratio. All default controls fit. |
| Colors and tokens | Adaptive primary/secondary text, pale neutral fields, subtle borders/dividers, and an explicit blue Create surface match the source treatment. The native dark render was inspected. High-contrast interaction and appearance remain manual checks. |
| Image quality | Center/rear photo proportions, rotation, crop, outline, and shadows follow the source. The repeated synthetic portrait differs from the source's three portraits; this is fixture data, not bundled product content. |
| Copy and content | Both setting labels, selection values, date span, count/duration, resolution/format, and Create label match. Calendar dates are locale-formatted and range/speed values update through existing bindings. |

## Validation and Limits

- 18 export/selection tests and 10 localization tests passed after the three-option
  revision, with zero failures.
- Coverage includes selected asset/speed snapshots, retries, background ownership,
  destination cancellation, result actions, window sizing/close behavior, and
  native render states in all three supported languages.
- Default, Month, Year, empty, running, completion,
  dark, and high-contrast states were rendered. Empty periods disable Create.
  Extra feedback remains scrollable.
- Native menus use SwiftUI Picker bindings and retain system menu behavior;
  this pass did not automate opening/selecting them on screen.
- The cached high-contrast fixture omits the heading; that capture does not
  establish high-contrast acceptance. The standard light/dark captures retain
  it. Complete high-contrast appearance requires an on-screen check.
- The corrected isolated test bundle built and launched successfully using the
  supported ad-hoc local signing option; the build/run script verified its process.
- Production Photos thumbnails and the original export pipeline are retained.
  New real-library exports and accessibility interaction remain manual checks.

## Follow-up Polish

[P3] Minor raster/font rendering and gradient differences from the generated
mock remain. The photo subject differs because the fixture uses synthetic data.

## Implementation Checklist

- [x] Use the uploaded screenshot as the selected design.
- [x] Replace preset bars with working dropdown selections.
- [x] Match order, window proportions, photo fan, row surfaces, and Create action.
- [x] Compare full and focused renders after fixes.
- [x] Verify export regression tests and localized expanded states.

## Latest Scope Revision

The user requested only 全部、月份、年份. Custom is removed from the enum,
selection state, UI, localization catalogs, and active test fixtures. English
labels remain All Photos, Month, and Year. The three remaining states were
re-rendered and the Traditional Chinese month selection was inspected;
controls and Create fit the existing 500 × 430 content viewport. Historical
Custom/invalid-range images are superseded and do not represent current UI.
The uploaded reference remains the visual target, with this explicit option
reduction superseding its menu contents.
