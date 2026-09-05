import XCTest
@testable import Chameo

@MainActor
final class UpdateReminderBarrierTests: XCTestCase {
    func testSparkleOptionalDelegateMethodsAreExposedToObjectiveC() {
        let controller = UpdateController(isEnabled: false)
        for name in [
            "updaterShouldRelaunchApplication:",
            "updater:willInstallUpdate:",
            "updater:willInstallUpdateOnQuit:immediateInstallationBlock:",
            "updater:didAbortWithError:"
        ] {
            XCTAssertTrue(controller.responds(to: NSSelectorFromString(name)), name)
        }
    }

    func testOrdinaryQuitKeepsReminders() async {
        var cleaned = false
        let barrier = UpdateReminderBarrier(cleanup: { cleaned = true }, restore: {})
        let allowed = await barrier.prepareForTermination()
        XCTAssertTrue(allowed)
        XCTAssertFalse(cleaned)
    }

    func testUpdateQuitWaitsForCleanupAndKeepsSchedulingSuspended() async {
        var events: [String] = []
        let barrier = UpdateReminderBarrier(cleanup: { events.append("clean") }, restore: { events.append("restore") })
        barrier.updateWillInstall()
        let allowed = await barrier.prepareForTermination()
        XCTAssertTrue(allowed)
        XCTAssertEqual(events, ["clean"])
    }

    func testFailedCleanupRefusesQuitAndRestoresScheduling() async {
        var restored = false
        let barrier = UpdateReminderBarrier(cleanup: { throw ReminderError.updateTimedOut }, restore: { restored = true })
        barrier.updateWillInstall()
        let allowed = await barrier.prepareForTermination()
        XCTAssertFalse(allowed)
        XCTAssertTrue(restored)
    }

    func testCancellationDuringCleanupWaitsThenRestores() async {
        var finish: CheckedContinuation<Void, Never>?
        var restored = false
        let barrier = UpdateReminderBarrier(cleanup: {
            await withCheckedContinuation { finish = $0 }
        }, restore: { restored = true })
        barrier.updateWillInstall()
        let task = Task { await barrier.prepareForTermination() }
        while finish == nil { await Task.yield() }
        await barrier.cancelUpdate()
        XCTAssertFalse(restored)
        finish?.resume()
        let allowed = await task.value
        XCTAssertFalse(allowed)
        XCTAssertTrue(restored)
    }

    func testTimeoutRefusesQuitAndLateCleanupRestoresInsteadOfInstalling() async {
        var finish: CheckedContinuation<Void, Never>?
        var restored = false
        let barrier = UpdateReminderBarrier(timeout: .milliseconds(20), cleanup: {
            await withCheckedContinuation { finish = $0 }
        }, restore: { restored = true })
        barrier.updateWillInstall()
        let allowed = await barrier.prepareForTermination()
        XCTAssertFalse(allowed)
        XCTAssertFalse(restored)
        finish?.resume()
        while !restored { await Task.yield() }
        XCTAssertTrue(restored)
    }

    func testQueueSuspensionDrainsWorkAndBlocksRefreshUntilResume() async throws {
        let queue = ReminderOperationQueue()
        let recorder = BarrierRecorder()
        try await queue.perform { await recorder.append("scheduled") }
        try await queue.suspend { await recorder.append("cleaned") }
        try await queue.perform { await recorder.append("unexpected refresh") }
        await queue.resume()
        try await queue.perform { await recorder.append("restored") }
        let events = await recorder.events
        XCTAssertEqual(events, ["scheduled", "cleaned", "restored"])
    }
}

private actor BarrierRecorder {
    var events: [String] = []
    func append(_ event: String) { events.append(event) }
}
