import XCTest
@testable import Chameo

@MainActor
final class LibraryStoreTests: XCTestCase {
    func testOlderReloadCannotOverwriteNewerState() async {
        let store = LibraryStore { albumName in
            if albumName == "Old" {
                try await Task.sleep(for: .milliseconds(50))
                throw TestError.staleFailure
            }

            try await Task.sleep(for: .milliseconds(1))
            return []
        }

        let oldReload = Task {
            await store.reload(albumName: "Old")
        }
        await Task.yield()
        await store.reload(albumName: "Current")
        await oldReload.value

        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.errorMessage)
        XCTAssertTrue(store.assets.isEmpty)
    }

    func testDailyStatusIsUnknownUntilInitialLoadCompletes() async throws {
        let store = LibraryStore { _ in [] }
        let today = try date(2026, 7, 18)

        XCTAssertEqual(store.dailyStatus(on: today, today: today, calendar: calendar), .unknown)

        await store.reload(albumName: "Chameo")

        XCTAssertEqual(store.dailyStatus(on: today, today: today, calendar: calendar), .pendingToday)
    }

    func testChangingAlbumInvalidatesThePreviousSnapshot() async throws {
        let gate = AlbumLoadGate()
        let store = LibraryStore { albumName in
            if albumName == "New" {
                await gate.wait()
            }
            return []
        }
        let today = try date(2026, 7, 18)

        await store.reload(albumName: "Old")
        let newReload = Task {
            await store.reload(albumName: "New")
        }
        await Task.yield()

        XCTAssertEqual(store.dailyStatus(on: today, today: today, calendar: calendar), .unknown)

        await gate.open()
        await newReload.value
        XCTAssertEqual(store.dailyStatus(on: today, today: today, calendar: calendar), .pendingToday)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day
        )))
    }
}

private enum TestError: Error {
    case staleFailure
}

private actor AlbumLoadGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}
