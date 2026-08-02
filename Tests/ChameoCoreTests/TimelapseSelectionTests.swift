import XCTest
@testable import ChameoCore

final class CoreTimelapseSelectionTests: XCTestCase {
    private struct Item: Equatable {
        let id: String
        let date: Date?
    }

    func testSelectsOnlyDatedItemsWithDeterministicTieBreaking() {
        let sharedDate = Date(timeIntervalSinceReferenceDate: 100)
        let olderDate = Date(timeIntervalSinceReferenceDate: 50)
        let items = [
            Item(id: "b", date: sharedDate),
            Item(id: "undated", date: nil),
            Item(id: "a", date: sharedDate),
            Item(id: "older", date: olderDate),
        ]

        let selected = TimelapseSelection.datedItemsChronologically(
            from: items,
            date: \.date,
            identifier: \.id
        )

        XCTAssertEqual(selected.map(\.id), ["older", "a", "b"])
    }
}
