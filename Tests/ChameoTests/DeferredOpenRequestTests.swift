import XCTest
@testable import Chameo

@MainActor
final class DeferredOpenRequestTests: XCTestCase {
    func testRequestMadeBeforeAppUIIsReadyIsDeliveredWhenHandlerIsInstalled() {
        let request = DeferredOpenRequest()
        var openCount = 0

        request.performOrDefer()
        XCTAssertEqual(openCount, 0)

        request.installHandler {
            openCount += 1
        }

        XCTAssertEqual(openCount, 1)
    }

    func testRequestMadeAfterAppUIIsReadyIsDeliveredImmediately() {
        let request = DeferredOpenRequest()
        var openCount = 0
        request.installHandler {
            openCount += 1
        }

        request.performOrDefer()

        XCTAssertEqual(openCount, 1)
    }

    func testMultipleStartupRequestsCoalesceIntoOneOpen() {
        let request = DeferredOpenRequest()
        var openCount = 0

        request.performOrDefer()
        request.performOrDefer()
        request.installHandler {
            openCount += 1
        }

        XCTAssertEqual(openCount, 1)
    }
}
