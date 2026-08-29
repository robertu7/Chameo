import XCTest
@testable import Chameo

@MainActor
final class DeferredOpenRequestTests: XCTestCase {
    func testRequestMadeBeforeAppUIIsReadyIsDeliveredWhenHandlerIsInstalled() {
        let request = DeferredOpenRequest()
        var destinations: [ReminderNotificationOpenDestination] = []

        request.performOrDefer(.camera)
        XCTAssertTrue(destinations.isEmpty)

        request.installHandler { destination in
            destinations.append(destination)
        }

        XCTAssertEqual(destinations, [.camera])
    }

    func testRequestMadeAfterAppUIIsReadyIsDeliveredImmediately() {
        let request = DeferredOpenRequest()
        var destinations: [ReminderNotificationOpenDestination] = []
        request.installHandler { destination in
            destinations.append(destination)
        }

        request.performOrDefer(.libraryToday)

        XCTAssertEqual(destinations, [.libraryToday])
    }

    func testMultipleStartupRequestsCoalesceIntoLatestDestination() {
        let request = DeferredOpenRequest()
        var destinations: [ReminderNotificationOpenDestination] = []

        request.performOrDefer(.camera)
        request.performOrDefer(.libraryToday)
        request.installHandler { destination in
            destinations.append(destination)
        }

        XCTAssertEqual(destinations, [.libraryToday])
    }
}
