import XCTest
@testable import ChameoCore

final class HandsFreeCountdownTests: XCTestCase {
    func testCountdownIsInactiveByDefault() {
        var machine = HandsFreeCountdownMachine()

        XCTAssertEqual(machine.phase, .inactive)
        XCTAssertEqual(machine.handle(.setVisible(true)), [])
        XCTAssertEqual(machine.handle(.guidanceChanged(.ready)), [])
        XCTAssertEqual(machine.phase, .inactive)
    }

    func testReadyStartsThreeSecondCountdownAndCapturesOnce() {
        var machine = enabledVisibleMachine()

        XCTAssertEqual(
            machine.handle(.guidanceChanged(.ready)),
            [.startTimer]
        )
        XCTAssertEqual(machine.phase, .counting(3))
        XCTAssertEqual(machine.handle(.tick), [])
        XCTAssertEqual(machine.phase, .counting(2))
        XCTAssertEqual(machine.handle(.tick), [])
        XCTAssertEqual(machine.phase, .counting(1))
        XCTAssertEqual(machine.handle(.tick), [.capture])
        XCTAssertEqual(machine.phase, .locked)
        XCTAssertEqual(machine.handle(.tick), [])
    }

    func testRepeatedReadyDoesNotStartOverlappingTimers() {
        var machine = enabledVisibleMachine()

        XCTAssertEqual(machine.handle(.guidanceChanged(.ready)), [.startTimer])
        XCTAssertEqual(machine.handle(.guidanceChanged(.ready)), [])
        XCTAssertEqual(machine.handle(.guidanceChanged(.ready)), [])
        XCTAssertEqual(machine.phase, .counting(3))
    }

    func testBriefCorrectiveGuidanceDoesNotCancelCountdown() {
        var machine = enabledVisibleMachine()
        _ = machine.handle(.guidanceChanged(.ready))

        XCTAssertEqual(machine.handle(.guidanceChanged(.adjusting(.holdStill))), [])
        XCTAssertEqual(machine.handle(.guidanceChanged(.adjusting(.holdStill))), [])
        XCTAssertEqual(machine.phase, .counting(3))
        XCTAssertEqual(machine.handle(.guidanceChanged(.ready)), [])
        XCTAssertEqual(machine.phase, .counting(3))
    }

    func testSustainedFramingLossCancelsAndReadyRestartsCountdown() {
        var machine = enabledVisibleMachine()
        _ = machine.handle(.guidanceChanged(.ready))

        XCTAssertEqual(machine.handle(.guidanceChanged(.adjusting(.moveTowardCenter))), [])
        XCTAssertEqual(machine.handle(.guidanceChanged(.adjusting(.moveTowardCenter))), [])
        XCTAssertEqual(
            machine.handle(.guidanceChanged(.adjusting(.moveTowardCenter))),
            [.cancelTimer]
        )
        XCTAssertEqual(machine.phase, .armed)
        XCTAssertEqual(
            machine.handle(.guidanceChanged(.ready)),
            [.startTimer]
        )
    }

    func testMissingOrMultipleFacesCancelImmediately() {
        for hint in [LiveFramingHint.centerFace, .onePerson] {
            var machine = enabledVisibleMachine()
            _ = machine.handle(.guidanceChanged(.ready))

            XCTAssertEqual(
                machine.handle(.guidanceChanged(.adjusting(hint))),
                [.cancelTimer]
            )
            XCTAssertEqual(machine.phase, .armed)
        }
    }

    func testAutomaticCaptureRequiresReadyAtFinalTick() {
        var machine = enabledVisibleMachine()
        _ = machine.handle(.guidanceChanged(.ready))
        _ = machine.handle(.tick)
        _ = machine.handle(.tick)
        _ = machine.handle(.guidanceChanged(.adjusting(.holdStill)))

        XCTAssertEqual(machine.handle(.tick), [.cancelTimer])
        XCTAssertEqual(machine.phase, .armed)
    }

    func testNeutralCancelsWithoutUnlockingPostCaptureCycle() {
        var machine = enabledVisibleMachine()
        _ = machine.handle(.guidanceChanged(.ready))
        _ = machine.handle(.tick)
        _ = machine.handle(.tick)
        _ = machine.handle(.tick)

        XCTAssertEqual(machine.phase, .locked)
        XCTAssertEqual(machine.handle(.guidanceChanged(.neutral)), [])
        XCTAssertEqual(machine.handle(.guidanceChanged(.ready)), [])
        XCTAssertEqual(machine.phase, .locked)
    }

    func testCorrectiveGuidanceUnlocksPostCaptureCycle() {
        var machine = capturedMachine()

        XCTAssertEqual(
            machine.handle(.guidanceChanged(.adjusting(.holdStill))),
            []
        )
        XCTAssertEqual(machine.phase, .armed)
        XCTAssertEqual(
            machine.handle(.guidanceChanged(.ready)),
            [.startTimer]
        )
    }

    func testManualCaptureCancelsCountdownAndLocksCycle() {
        var machine = enabledVisibleMachine()
        _ = machine.handle(.guidanceChanged(.ready))

        XCTAssertEqual(machine.handle(.manualCapture), [.cancelTimer])
        XCTAssertEqual(machine.phase, .locked)
        XCTAssertEqual(machine.handle(.guidanceChanged(.ready)), [])
    }

    func testHidingCameraCancelsButPreservesLockout() {
        var machine = capturedMachine()

        XCTAssertEqual(machine.handle(.setVisible(false)), [])
        XCTAssertEqual(machine.phase, .inactive)
        XCTAssertEqual(machine.handle(.setVisible(true)), [])
        XCTAssertEqual(machine.phase, .locked)
        XCTAssertEqual(machine.handle(.guidanceChanged(.ready)), [])
    }

    func testDisablingFeatureCancelsAndResetsLockout() {
        var machine = capturedMachine()

        XCTAssertEqual(machine.handle(.setEnabled(false)), [])
        XCTAssertEqual(machine.phase, .inactive)
        XCTAssertEqual(machine.handle(.setEnabled(true)), [])
        XCTAssertEqual(machine.phase, .armed)
        XCTAssertEqual(
            machine.handle(.guidanceChanged(.ready)),
            [.startTimer]
        )
    }

    func testHidingCameraCancelsActiveTimer() {
        var machine = enabledVisibleMachine()
        _ = machine.handle(.guidanceChanged(.ready))

        XCTAssertEqual(machine.handle(.setVisible(false)), [.cancelTimer])
        XCTAssertEqual(machine.phase, .inactive)
    }

    private func enabledVisibleMachine() -> HandsFreeCountdownMachine {
        var machine = HandsFreeCountdownMachine()
        _ = machine.handle(.setVisible(true))
        _ = machine.handle(.setEnabled(true))
        return machine
    }

    private func capturedMachine() -> HandsFreeCountdownMachine {
        var machine = enabledVisibleMachine()
        _ = machine.handle(.guidanceChanged(.ready))
        _ = machine.handle(.tick)
        _ = machine.handle(.tick)
        _ = machine.handle(.tick)
        return machine
    }
}
