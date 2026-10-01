import Photos
import XCTest
@testable import Chameo

@MainActor
final class LocalPhotoSettingsTests: XCTestCase {
    func testDefaultSettingsShowFixedFolderWithoutCreatingIt() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.folder)
        let controller = LocalPhotoSettingsController(store: fixture.store)
        await controller.refresh()
        XCTAssertTrue(controller.configuration.isEnabled)
        XCTAssertEqual(controller.configuration.activeFolder?.displayPath, fixture.folder.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.folder.path))
        XCTAssertNil(controller.errorMessage)
        XCTAssertFalse(controller.isBusy)
    }

    func testEnableFailureKeepsSettingOffAndRetryClearsError() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let controller = LocalPhotoSettingsController(store: fixture.store)
        await controller.setEnabled(false)
        let previous = controller.configuration
        try FileManager.default.removeItem(at: fixture.folder)
        try Data("blocked".utf8).write(to: fixture.folder)
        await controller.setEnabled(true)
        XCTAssertEqual(controller.configuration, previous)
        XCTAssertNotNil(controller.errorMessage)
        XCTAssertFalse(controller.isBusy)
        try FileManager.default.removeItem(at: fixture.folder)
        await controller.setEnabled(true)
        XCTAssertTrue(controller.configuration.isEnabled)
        XCTAssertNil(controller.errorMessage)
    }

    func testSettingsRecreationRemembersFolderAndEnabledState() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let first = LocalPhotoSettingsController(store: fixture.store)
        await first.setEnabled(true)
        XCTAssertTrue(first.configuration.isEnabled)
        let next = LocalPhotoSettingsController(store: fixture.recreateStore())
        await next.refresh()
        XCTAssertEqual(next.configuration, first.configuration)
        await next.setEnabled(false)
        XCTAssertFalse(next.configuration.isEnabled)
        XCTAssertNotNil(next.configuration.activeFolder)
    }

    func testPhotosFailureDoesNotAttemptLocalSave() async throws {
        var localCalls = 0
        do {
            let _: CapturePhotoSaveResult<String> = try await CapturePhotoSaveService.save(
                data: Data("original".utf8),
                saveToPhotos: { _ in throw PhotoLibraryError.changeFailed },
                saveLocally: { _, _ in localCalls += 1 }
            )
            XCTFail("Expected Photos failure")
        } catch {}
        XCTAssertEqual(localCalls, 0)
    }

    func testLocalFailurePreservesSuccessfulCaptureAndDoesNotRepeatPhotosSave() async throws {
        let data = try localTestJPEG()
        var photosCalls = 0
        var localCalls = 0
        let result = try await CapturePhotoSaveService.save(
            data: data,
            saveToPhotos: { received in
                XCTAssertEqual(received, data)
                photosCalls += 1
                return "saved-asset"
            },
            saveLocally: { received, asset in
                XCTAssertEqual(received, data)
                XCTAssertEqual(asset, "saved-asset")
                localCalls += 1
                throw LocalPhotoError.folderUnavailable
            }
        )
        XCTAssertEqual(result.asset, "saved-asset")
        XCTAssertTrue(result.localCopyFailed)
        XCTAssertEqual(photosCalls, 1)
        XCTAssertEqual(localCalls, 1)
    }

    func testSuccessfulCaptureSavesIdenticalBytesOnce() async throws {
        let fixture = try LocalPhotoFixture()
        defer { fixture.remove() }
        let data = try localTestJPEG()
        var photosCalls = 0
        let result = try await CapturePhotoSaveService.save(
            data: data,
            saveToPhotos: { _ in photosCalls += 1; return localTestSnapshot() },
            saveLocally: { bytes, snapshot in try await fixture.store.saveOriginal(bytes, source: snapshot) }
        )
        XCTAssertFalse(result.localCopyFailed)
        XCTAssertEqual(photosCalls, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(fixture.photos().first)), data)
    }

    func testPhotoResourceChunksFinishOnceAndRejectLateData() async throws {
        let state = PhotoOriginalRequestState()
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            XCTAssertTrue(state.install(continuation))
            state.append(Data("first".utf8))
            state.append(Data("second".utf8))
            state.finish(error: nil)
            state.append(Data("late".utf8))
            state.finish(error: LocalPhotoError.invalidImage)
        }
        XCTAssertEqual(data, Data("firstsecond".utf8))
        XCTAssertFalse(state.shouldReportProgress())
    }

    func testPhotoResourceCancellationRejectsLateCompletion() async {
        let state = PhotoOriginalRequestState()
        do {
            let _: Data = try await withCheckedThrowingContinuation { continuation in
                XCTAssertTrue(state.install(continuation))
                state.append(Data("partial".utf8))
                state.cancel(manager: .default())
                state.finish(error: nil)
            }
            XCTFail("Expected cancellation")
        } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertFalse(state.shouldReportProgress())
    }
}
