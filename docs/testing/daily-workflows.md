# Daily Workflow Validation

## Owner-confirmed results (October 3, 2026)

Following the v0.5.1 release, the owner confirmed that both workflows below
have been validated in real use. This records the owner's confirmation;
the agent did not rerun these checks or collect device logs in this pass.

- Photo workflow: capture, Retake/Save, Photos and local copies, local-copy
  restoration and deletion, Timelapse export and playback, including iCloud
  photos, cancellation, retry, and closing/reopening during export.
- Reminders and updates: reminder delivery and clicks after sleep/wake,
  and a real Sparkle update/relaunch with reminder cleanup.

These workflows are no longer pending initial live validation. Repeat relevant
checks when changes affect capture, storage, export, reminder scheduling, or
the updater.

## Remaining checks

- Full keyboard traversal, VoiceOver, and system accessibility settings.
- Each permission denial/recovery path and launch at login.
- Installation, update, relaunch, Gatekeeper, and permission persistence on a
  clean Mac before broader distribution.

The confirmation does not establish that every failure-injection scenario in
the [reminder cleanup checklist](reminder-update-cleanup.md) was exercised,
or that existing orphaned reminders and manual app replacement are repaired.

See the [native UI review](../reviews/liquid-glass-consistency-2026-10-03/review.md)
for the separate visual and accessibility evidence.
