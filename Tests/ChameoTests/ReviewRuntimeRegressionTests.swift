import AppKit
import Photos
import ServiceManagement
import XCTest
@testable import Chameo

@MainActor
final class CaptureReviewStoreTests: XCTestCase {
    func testDraftAndInFlightWorkSurviveNavigationAndRejectDuplicates() async {
        let state = AppState()
        let store = state.captureReview
        let gate = ReviewTestGate()
        let started = expectation(description: "Preparing capture")
        let preview = CapturedPreview(data: Data([1]), qualityEvaluation: .noFace, qualitySuggestion: nil)
        store.capture {
            started.fulfill()
            await gate.wait()
            return preview
        }
        await fulfillment(of: [started], timeout: 2)
        state.selectedTab = .library
        state.prepareForMenuBarOpen(status: .captured)
        XCTAssertEqual(state.selectedTab, .camera)
        XCTAssertTrue(store.isSaving)
        store.capture { XCTFail("Duplicate capture"); return preview }
        await gate.open()
        while store.isSaving { await Task.yield() }
        XCTAssertEqual(store.capturedPreview?.id, preview.id)
        state.selectedTab = .library
        state.selectedTab = .camera
        XCTAssertEqual(state.captureReview.capturedPreview?.id, preview.id)
        store.retake()
        XCTAssertNil(store.capturedPreview)
    }

    func testFailedSaveRetainsDraftAndSuccessfulSaveClearsItOnce() async {
        let store = CaptureReviewStore()
        let preview = CapturedPreview(data: Data([1]), qualityEvaluation: .noFace, qualitySuggestion: nil)
        store.capture { preview }
        while store.isSaving { await Task.yield() }
        store.save { _ in throw ReviewTestError.failed }
        while store.isSaving { await Task.yield() }
        XCTAssertEqual(store.capturedPreview?.id, preview.id)
        var saves = 0
        let gate = ReviewTestGate()
        store.save { savedPreview in
            saves += 1
            XCTAssertEqual(savedPreview.id, preview.id)
            await gate.wait()
            return .localized("Saved")
        }
        store.retake()
        store.save { _ in XCTFail("Duplicate save"); return .localized("Saved") }
        await gate.open()
        while store.isSaving { await Task.yield() }
        XCTAssertEqual(saves, 1)
        XCTAssertNil(store.capturedPreview)
    }
}

final class PhotoAlbumCoordinatorTests: XCTestCase {
    func testConcurrentSameNameUsesOneCreationWhileOtherNamesProceed() async throws {
        let gate = ReviewTestGate()
        let created = ReviewAlbumCreationRecorder(gate: gate)
        let catalog = ReviewAlbumCatalog()
        let coordinator = PhotoAlbumCoordinator(find: catalog.album, create: { name in
            let album = try await created.create(name)
            catalog.insert(album, named: name)
            return album
        })
        let first = Task { try await coordinator.album(named: "Shared") }
        await created.waitUntilStarted()
        let second = Task { try await coordinator.album(named: "Shared") }
        let other = try await coordinator.album(named: "Other")
        await gate.open()
        let firstAlbum = try await first.value
        let secondAlbum = try await second.value
        XCTAssertTrue(firstAlbum === secondAlbum)
        XCTAssertFalse(other === firstAlbum)
        let counts = await created.counts
        XCTAssertEqual(counts["Shared"], 1)
        XCTAssertEqual(counts["Other"], 1)
    }

    func testFailureDoesNotPoisonNextCreation() async throws {
        let attempts = ReviewAlbumAttempts()
        let coordinator = PhotoAlbumCoordinator(find: { _ in nil }, create: { _ in try await attempts.create() })
        do { _ = try await coordinator.album(named: "Retry"); XCTFail("Expected failure") }
        catch { XCTAssertTrue(error is ReviewTestError) }
        _ = try await coordinator.album(named: "Retry")
        let count = await attempts.count
        XCTAssertEqual(count, 2)
    }
}

final class PhotoThumbnailRequestStateTests: XCTestCase {
    func testCancellationBeforeInstallResumesWithoutStartingRequest() async {
        let state = PhotoThumbnailRequestState { _ in XCTFail("No request started") }
        state.cancel()
        let image = await withCheckedContinuation { continuation in
            XCTAssertFalse(state.install(continuation))
        }
        XCTAssertNil(image)
    }

    func testCancellationBeforeRequestIDCancelsLateIDAndIgnoresCallback() async {
        let cancelled = expectation(description: "Late request cancelled")
        let state = PhotoThumbnailRequestState { id in XCTAssertEqual(id, 42); cancelled.fulfill() }
        let image: NSImage? = await withCheckedContinuation { continuation in
            XCTAssertTrue(state.install(continuation))
            state.cancel()
            state.cancel()
            state.setRequestID(42)
            state.finish(NSImage(size: CGSize(width: 1, height: 1)))
        }
        XCTAssertNil(image)
        await fulfillment(of: [cancelled], timeout: 2)
    }

    func testCompletedRequestIsResumedOnceAndDoesNotCancel() async {
        let state = PhotoThumbnailRequestState { _ in XCTFail("Completed request") }
        let expected = NSImage(size: CGSize(width: 1, height: 1))
        let image = await withCheckedContinuation { continuation in
            XCTAssertTrue(state.install(continuation))
            state.finish(expected)
            state.setRequestID(42)
            state.finish(nil)
            state.cancel()
        }
        XCTAssertTrue(image === expected)
    }
}

final class LaunchAtLoginRegistrationTests: XCTestCase {
    func testPendingApprovalIsRegisteredAndCanBeUnregistered() throws {
        let registration = LaunchAtLoginRegistration(status: .requiresApproval)
        XCTAssertTrue(registration.isRegistered)
        XCTAssertTrue(registration.requiresApproval)
        var unregisters = 0
        try registration.setEnabled(true, register: { XCTFail("Already registered") }, unregister: { XCTFail() })
        try registration.setEnabled(false, register: { XCTFail() }, unregister: { unregisters += 1 })
        XCTAssertEqual(unregisters, 1)
    }

    func testEnabledRegistrationSkipsRegisterAndCanBeDisabled() throws {
        let registration = LaunchAtLoginRegistration(status: .enabled)
        XCTAssertTrue(registration.isRegistered)
        XCTAssertFalse(registration.requiresApproval)
        var unregisters = 0
        try registration.setEnabled(true, register: { XCTFail("Already enabled") }, unregister: { XCTFail() })
        try registration.setEnabled(false, register: { XCTFail() }, unregister: { unregisters += 1 })
        XCTAssertEqual(unregisters, 1)
    }

    func testUnregisteredStateRegistersOnlyWhenEnabled() throws {
        for status in [SMAppService.Status.notRegistered, .notFound] {
            let registration = LaunchAtLoginRegistration(status: status)
            XCTAssertFalse(registration.isRegistered)
            var registers = 0
            try registration.setEnabled(false, register: { XCTFail() }, unregister: { XCTFail() })
            try registration.setEnabled(true, register: { registers += 1 }, unregister: { XCTFail() })
            XCTAssertEqual(registers, 1)
        }
    }
}

private enum ReviewTestError: Error { case failed }
private actor ReviewTestGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}
private actor ReviewAlbumCreationRecorder {
    let gate: ReviewTestGate
    var counts: [String: Int] = [:]
    init(gate: ReviewTestGate) { self.gate = gate }
    func create(_ name: String) async throws -> PHAssetCollection {
        counts[name, default: 0] += 1
        if name == "Shared" { await gate.wait() }
        return PHAssetCollection()
    }
    func waitUntilStarted() async {
        while counts["Shared"] == nil { await Task.yield() }
    }
}
private actor ReviewAlbumAttempts {
    var count = 0
    func create() throws -> PHAssetCollection {
        count += 1
        if count == 1 { throw ReviewTestError.failed }
        return PHAssetCollection()
    }
}

// Match PhotoKit's visibility after a successful create, so a caller that starts
// after the gate opens finds the same album rather than causing a timing failure.
private final class ReviewAlbumCatalog: @unchecked Sendable {
    private let lock = NSLock()
    private var albums: [String: PHAssetCollection] = [:]
    func album(named name: String) -> PHAssetCollection? {
        lock.lock()
        defer { lock.unlock() }
        return albums[name]
    }
    func insert(_ album: PHAssetCollection, named name: String) {
        lock.lock()
        albums[name] = album
        lock.unlock()
    }
}
