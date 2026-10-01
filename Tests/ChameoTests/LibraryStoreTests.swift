import XCTest
import Photos
@testable import Chameo

@MainActor
final class LibraryStoreTests: XCTestCase {
    func testOlderReloadCannotOverwriteNewerState() async {
        let store = LibraryStore(assetLoader: { albumName in
            if albumName == "Old" {
                try await Task.sleep(for: .milliseconds(50))
                throw TestError.staleFailure
            }

            try await Task.sleep(for: .milliseconds(1))
            return []
        })

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
        let store = LibraryStore(assetLoader: { _ in [] })
        let today = try date(2026, 7, 18)

        XCTAssertEqual(store.dailyStatus(on: today, today: today, calendar: calendar), .unknown)

        await store.reload(albumName: "Chameo")

        XCTAssertEqual(store.dailyStatus(on: today, today: today, calendar: calendar), .pendingToday)
    }

    func testChangingAlbumInvalidatesThePreviousSnapshot() async throws {
        let gate = AlbumLoadGate()
        let store = LibraryStore(assetLoader: { albumName in
            if albumName == "New" {
                await gate.wait()
            }
            return []
        })
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

    func testDefaultDeletionKeepsTheLocalCopy() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let asset = ChameoAsset(asset: LibraryTestPhoto())
        try await fixture.store.saveOriginal(try localTestJPEG(), source: localTestSnapshot(id: asset.id))
        var didDelete = false
        let store = LibraryStore(assetDeleter: { _ in didDelete = true }, assetLoader: { _ in [asset] })
        await store.reload(albumName: "Chameo")
        let deleted = await store.deleteFromLibrary(asset, albumName: "Chameo", localPhotos: fixture.store)
        XCTAssertTrue(deleted)
        XCTAssertTrue(didDelete)
        XCTAssertTrue(store.assets.isEmpty)
        XCTAssertNil(store.deletionWarning)
        XCTAssertEqual(try fixture.photos().count, 1)
    }

    func testLocalTrashFailureKeepsSuccessfulPhotosDeletionAndDailyStatus() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let asset = ChameoAsset(asset: LibraryTestPhoto())
        try await fixture.store.saveOriginal(try localTestJPEG(), source: localTestSnapshot(id: asset.id))
        let file = try XCTUnwrap(fixture.photos().first)
        try Data("user edits".utf8).write(to: file)
        let store = LibraryStore(assetDeleter: { _ in }, assetLoader: { _ in [asset] })
        await store.reload(albumName: "Chameo")
        let deleted = await store.deleteFromLibrary(asset, albumName: "Chameo",
                                                     trashLocalCopy: true, localPhotos: fixture.store)
        XCTAssertTrue(deleted)
        XCTAssertTrue(store.assets.isEmpty)
        XCTAssertNil(store.errorMessage)
        XCTAssertNotNil(store.deletionWarning)
        let today = try date(2026, 7, 18)
        XCTAssertEqual(store.dailyStatus(on: today, today: today, calendar: calendar), .pendingToday)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
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

private final class LibraryTestPhoto: PHAsset, @unchecked Sendable {
    private let fixtureID = UUID().uuidString
    override var localIdentifier: String { fixtureID }
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
