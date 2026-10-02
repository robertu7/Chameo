# Timelapse UI/UX review — October 2, 2026

Timelapse needs clearer hierarchy and a different layout for each stage. The
current compact window repeats a large title, promotional subtitle, and photo
strip before the information needed to create, monitor, or open the export.

## Evidence and limits

- The current test app was accessed through native UI automation by bundle ID
  `com.robertu.Chameo.test`, using the launch approach described in the linked
  “Diagnose local build failure” chat. No build fix was needed for this review.
- Step 1 is a live capture. The test album is empty and its Timelapse button is
  disabled, so the live export flow could not be entered.
- Steps 2–4 are fresh native content renders of the current `TimelapseExportView`,
  generated this run by `testExportScreenRendersAtWindowSizeInEveryLanguage`.
  They use three fixture assets, a fake generator, and deliberately unloaded
  thumbnails. The placeholders are fixture artifacts, not evidence of a photo
  loading bug. Composited glass and native window chrome are not reliably drawn.
- Fresh fixture renders cover English, Simplified Chinese, and Traditional
  Chinese at the current 460 × 480 content size. The render test passed.
- This is a live entry review plus a source/fixture screen review, not a verified
  end-to-end Photos/iCloud export audit. Keyboard focus, VoiceOver output,
  actual thumbnail loading, dark appearance, and accessibility settings still
  need live checks with a populated test album.
- Screenshot originals and renders are saved in
  `/tmp/chameo-timelapse-review-20261002/`. Those files are temporary and are not
  product assets or onboarding replacements.

## 1. Library entry — blocked for an empty album

![Live Library entry](/tmp/chameo-timelapse-review-20261002/01-entry.png)

The entry is easy to locate, and sits beside Today. But a disabled Timelapse
button does not explain its prerequisite. Its help text says only “Create
Timelapse.” The empty summary inside the export screen is unreachable through
this button.

Recommendation: allow entry to an explicit empty state: “Take your first Chameo
to create a timelapse,” with a route back to Camera. Alternatively, keep the
button disabled and show its prerequisite beside it. This needs a product
decision before implementation.

## 2. Setup — too much space for repeated information

![Fresh setup fixture render](/tmp/chameo-timelapse-review-20261002/02-summary-english.png)

The export scope, chronology, duration, and format are useful and present.
However, the large icon/header and three-photo strip dominate the window.
“All album photos” and the explanatory sentence repeat the scope. Fixed output
format receives the same visual weight as the photo count and video duration,
although none of these are editable. The main button opens a save dialog, which
its label does not make explicit.

Recommendation:

- Use a modest heading without the promotional subtitle.
- Keep a smaller photo strip on this screen only, with its date range.
- Combine count and duration into one compact summary, with format as secondary
  text; retain one clear sentence that all album photos are included.
- Put “Create Timelapse…” in a fixed bottom action area; the ellipsis signals
  the destination chooser. Preserve the current save-before-generation flow.

## 3. Generation — competing progress signals

![Fresh download/progress fixture render](/tmp/chameo-timelapse-review-20261002/03-progress-english.png)

The fixture reports a photo download at 45%, but also displays a large 0%
export figure and “Photos completed: 0 of 3.” These values refer to different
operations. Their simultaneous prominence can make a working download look
stalled. The top heading still says “Create Timelapse,” while another heading
says “Creating timelapse.” The unchanged photo strip delays the status and
Cancel action in the reading order.

Recommendation:

- Replace the setup content with one status heading and one progress region.
- Show preparing/loading without an estimated overall percentage; show known
  per-photo download progress explicitly as a download percentage.
- When frames are written, show the completed-photo count and a determinate
  encoding bar. During finalization, show “Saving video…” with indeterminate
  activity. Do not present frame completion as elapsed-time completion.
- Keep a short “You can close this window; generation continues” message and a
  visible Cancel action in a fixed bottom area.
- Add an Escape shortcut for cancellation if it fits the app's cancellation
  policy; the current Cancel button has no such shortcut in the source.

Apple distinguishes determinate and indeterminate progress according to what
the app knows about the operation. The phase-specific design above is a
recommendation for Chameo, rather than an Apple requirement to use these exact
layouts. [Apple progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators).

## 4. Completion — the result should lead

![Fresh completion fixture render](/tmp/chameo-timelapse-review-20261002/04-result-english.png)

The success heading and explicit Open Folder/Open Video actions are clear.
However, the source-photo strip remains above the saved file, the promotional
subtitle remains after success, and the full directory path takes two lines.
The same three metrics reappear. The action group is inside the content's
ScrollView, so extra path wrapping or warning text can move it below the visible
area. “Create Another” also has little breathing room at this size.

Recommendation: put a modest success indicator, filename, short folder label,
and compact export summary first. Expose the full path through help and
accessibility. Keep Open Folder primary, Open Video secondary, and Create
Another tertiary in a fixed footer. Preserve background export ownership,
explicit folder opening, and the recently requested absence of completion
notifications.

## Proposed direction

Use a compact native export panel, retaining the current window size. Content
changes by phase; controls stay in a stable bottom region. Use native Liquid
Glass for the action controls, with clear content surfaces for photos, progress,
and file information. This follows Apple's distinction between the content and
control layers. [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).

| Stage | Main content | Bottom actions |
| --- | --- | --- |
| Setup | Small photo strip, date span, count/duration, scope | Create Timelapse… |
| Generating | Phase, one progress indicator, relevant detail | Background-generation reassurance, Cancel |
| Ready | Saved filename, folder, compact export summary | Open Video, Open Folder; Create Another |
| Failed/cancelled | Brief status and useful recovery instruction | Retry or Create Timelapse… |

Before accepting a redesign, verify all primary actions remain visible at
460 × 420, content scrolls independently, long localized text reflows, keyboard
focus remains visible, and status announcements describe the correct phase.
Actual iCloud progress must be checked with real assets. The findings above describe the pre-implementation review. The approved
implementation is recorded below.

Suggested page order after agreeing the Timelapse direction: Camera, Library,
Settings (General, Capture, Reminders, Photos), and onboarding.


## Approved implementation

Implemented the compact export-panel direction, with the photo strip retained
only on setup. The strip uses 72-point square thumbnails so square Chameo images
keep their composition. Progress and completion content are separate from setup;
the action footer is outside the scrolling region.

- Empty Library albums can open Timelapse. Its empty state explains the
  prerequisite and offers Take Chameo; the app-owned window closes before
  routing back to the normal Camera surface.
- Phase headings and accessibility announcements distinguish preparation,
  loading, iCloud download, encoding, and saving. A known download fraction
  drives the download bar; encoded-frame counts drive the encoding bar.
  Preparation, unknown loading, and saving remain indeterminate. Cancel has an
  Escape shortcut and remains disabled while cancellation completes.
- Completion shows the saved filename, short destination, and count/duration.
  Full paths remain in help and accessibility. Open Folder stays primary,
  Open Video secondary, and Create Another tertiary in the fixed footer.
- The 460 × 480 default and 460 × 420 minimum are retained. Background export
  ownership, save-before-generation, cancellation safety, explicit result
  opening, and the absence of completion notifications are preserved.
- New wording is localized in English, Simplified Chinese, and Traditional
  Chinese. No preference keys, photo storage, version, or release publication
  changed.

### Implementation evidence

These are fresh native fixture renders, not live exports. Thumbnail placeholders
come from the fixture, and composited glass/window chrome remain unverified.

| Setup | Downloading | Ready |
| --- | --- | --- |
| ![Setup](/tmp/chameo-timelapse-redesign-20261002/english-summary.png) | ![Downloading](/tmp/chameo-timelapse-redesign-20261002/english-progress-minimum.png) | ![Ready](/tmp/chameo-timelapse-redesign-20261002/english-result-minimum.png) |

### Validation

- Full regression suite: 199 tests, zero failures, one optional render test
  skipped. Subsequent final layout/localization/progress checks: 17 tests,
  zero failures.
- Strict-concurrency compilation passed; existing unrelated warnings remain.
- The expanded fixture covers empty, setup, download, encoding, saving, and
  completion in all three languages, including the minimum window size.
  Rendered action labels fit at 460 × 420. This is visual inspection of fixtures,
  not an automated assertion of all native hit targets or focus frames.
- The isolated ad-hoc-signed test app was rebuilt. Native inspection reached
  onboarding, then lost the running app; the redesigned Timelapse window and its
  Camera route were not verified live. No new permission grants were applied.
- Live Photos/iCloud progress, permission recovery, native glass, keyboard focus,
  VoiceOver behavior, and accessibility settings remain manual checks. Run the
  updated test app with a populated test album to complete them.
