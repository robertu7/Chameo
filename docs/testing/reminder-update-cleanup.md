# Reminder cleanup across ad-hoc updates

The old running build must remove its own reminders before Sparkle replaces it. A new build cannot be assumed to enumerate notifications belonging to an older ad-hoc identity. This is prevention for updates **from a build containing this code**, not a migration of existing orphaned sources.

## Implemented behavior

Sparkle's installation callbacks mark an update quit, including updates staged for the next quit. Its relaunch check re-arms the marker on a termination retry. AppDelegate delays that quit with `terminateLater`; ordinary quits leave reminders intact. This uses the actual termination boundary instead of relying on Sparkle's optional postponement callback, which documents skipped paths.

The reminder queue drains earlier work, suspends subsequent scheduling, removes reminder pending/delivered identifiers, and verifies both are empty. Unrelated identifiers are preserved. Cleanup retries three times. The termination decision has a ten-second deadline; failure or timeout refuses termination. Cancellation or failure restores scheduling from stored preferences. A late cleanup completion after the deadline restores scheduling and cannot authorize installation. If the notification service never completes, the quit is refused but rollback must wait for that serialized operation to finish.

The new process already refreshes reminders from stored settings during startup. A staged update keeps its marker across a successful update-check cycle, because Sparkle can finish the cycle while installation remains queued. Error aborts clear it. No persisted migration-complete flag is written.

## Automated validation

Run `swift test`. `UpdateReminderBarrierTests` covers ordinary quit, update quit, failure, cancellation during cleanup, a stalled cleanup/late completion, queue suspension/resume, and Objective-C exposure of Sparkle's optional delegate methods. `ReminderNotificationPlannerTests` verifies pending and delivered cleanup, failure when either remains, and preservation of unrelated notifications.

These tests do not validate Notification Center's source identity lookup or an actual Sparkle replacement.

## Native release-validation checklist (not yet performed)

Use a separate test bundle identifier, data container, and private appcast. The existing `script/build_app.sh --test` uses `com.robertu.Chameo.test` but **disables Sparkle**, so it is not an end-to-end updater fixture without a test-only configuration change. Never point a fixture at the production feed or replace `/Applications/Chameo.app` for this test.

1. Produce distinct ad-hoc builds A and B, both containing the barrier, for the test identifier. Verify different designated requirements with `codesign -d -r-` and preserve the exact artifacts.
2. Run A, enable reminders, deliver one and leave another pending. Update via the private Sparkle feed. Confirm `reminder-update` logs show verified cleanup before termination, with no scheduling between cleanup and termination.
3. Run B and verify the obsolete A reminders are gone, the saved schedule is recreated, and a fresh real reminder opens the camera/library. Exercise background, terminated, and sleep/wake cases.
4. Repeat with a staged install-on-quit and an installation retry. An ordinary quit with no update must retain pending reminders.
5. Trigger a settings change and a wake/activation refresh while cleanup is held. Neither may reschedule after cleanup. Cancel/fail installation and confirm reminders resume from the latest preferences.
6. Simulate notification removal failing and a query that never completes. The app must refuse the update quit; a late successful result must restore scheduling rather than terminate it.
7. Control: retain A reminders and manually replace A with B without cleanup. Record the old-source behavior separately; manual replacement and force-kill bypass the barrier and are not covered by this mitigation.

Existing orphaned production reminders, the first upgrade from a build without the barrier, force quits, and manual app replacement remain outside the verified repair scope. Do not label this as a complete fix for all notification clicks until native validation passes.
