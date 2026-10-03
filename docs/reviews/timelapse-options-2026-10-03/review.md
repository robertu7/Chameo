# Timelapse Options — October 3, 2026

The user's uploaded screenshot is the visual target for option 1. It supersedes
our earlier incorrect identification of that option as visible segmented presets.

The corrected native screen places the heading and larger photo stack above the
date span, photo-count/duration summary, and format. Two separated rows show
Date range and Playback speed as dropdown fields with a single downward chevron.
A wide blue Create Timelapse button completes the screen. The shared 500-point
utility-window width is retained; Timelapse's content height is 430 points to
match the uploaded window's proportions.

[Uploaded reference](draft-setup.png) · [Full comparison](comparison-setup.png) ·
[Controls comparison](comparison-controls.png) · [Month](english-month.png) ·
[Traditional Chinese Month](traditionalChinese-month.png).

Native menu pickers retain the existing range/speed bindings, calendar filtering,
and frozen export selection. Date range now offers only All Photos, Month,
and Year, per the latest request. In both Chinese languages these are 全部、月份、年份.
Month and Year reveal a period dropdown. Custom date entry and its model state
are removed. All Photos and 10 photos/sec remain the defaults.
Save dialog, retry, cancellation, background export, and result actions remain.

Validation for the three-option revision: 18 export/selection tests and 10 localization tests passed, including native renders
in English, Simplified Chinese, and Traditional Chinese, dark/high-contrast
appearance, empty periods, and window lifecycle checks. The prior feature pass
also exercised date boundaries and actual encoder timing. These renders use
synthetic photos; they are not evidence of new real-library or live menu-click
coverage. See [design QA](../../../design-qa.md) for comparison details.

The corrected test app was rebuilt with local ad-hoc signing and launched;
`build_and_run.sh --verify` confirmed the running process. Changes are uncommitted.

Earlier Custom/invalid-range images in this folder are superseded historical
artifacts and are not current UI states.
