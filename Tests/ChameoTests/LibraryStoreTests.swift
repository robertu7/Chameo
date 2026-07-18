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
}

private enum TestError: Error {
    case staleFailure
}
