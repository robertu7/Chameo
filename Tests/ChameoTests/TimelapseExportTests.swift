import AppKit
import Photos
import SwiftUI
import XCTest
@testable import Chameo

@MainActor
final class TimelapseExportTests: XCTestCase {
    func testSummaryDurationAndDestinationCancellation() {
        let controller = makeController()
        controller.prepare(assets: [asset()])
        XCTAssertEqual(controller.duration, 0.1, accuracy: 0.0001)
        controller.destinationChosen(nil)
        XCTAssertEqual(controller.state, .summary)
        XCTAssertFalse(controller.isBusy)
    }

    func testEmptySelectionCannotStart() {
        let controller = makeController()
        controller.destinationChosen(URL(fileURLWithPath: "/private/tmp/unused.mp4"))
        XCTAssertEqual(controller.state, .summary)
        XCTAssertFalse(controller.isBusy)
    }

    func testSnapshotDuplicateStartsProgressAndLateCallbacks() async throws {
        let probe = ExportProbe()
        let controller = makeController(probe: probe)
        controller.prepare(assets: [asset(), asset()])
        let url = try temporaryVideo()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        controller.destinationChosen(url)
        controller.destinationChosen(url)
        controller.prepare(assets: [])
        await waitUntil { probe.callback != nil }
        XCTAssertEqual(probe.calls, 1)
        XCTAssertEqual(probe.selectionCount, 2)
        XCTAssertEqual(controller.assets.count, 2)
        await probe.send(.loadingPhoto(0))
        await probe.send(.downloadingPhoto(0, 0.8))
        await probe.send(.downloadingPhoto(0, 0.2))
        XCTAssertEqual(controller.progress, .downloadingPhoto(0, 0.8))
        XCTAssertEqual(controller.completedPhotos, 0)
        await probe.send(.framesWritten(1))
        await probe.send(.downloadingPhoto(0, 1))
        XCTAssertEqual(controller.completedPhotos, 1)
        XCTAssertEqual(controller.progress, .framesWritten(1))
        controller.receive(.saving, runID: UUID())
        XCTAssertEqual(controller.progress, .framesWritten(1))
        await probe.send(.saving)
        await probe.send(.framesWritten(2))
        XCTAssertEqual(controller.progress, .saving)
        probe.finish()
        await waitUntil { !controller.isBusy }
        guard case .succeeded = controller.state else { return XCTFail("Expected successful export") }
        await probe.send(.preparing)
        XCTAssertEqual(controller.progress, .saving)
    }

    func testCancellationHasNoCompletionAndIgnoresProgress() async throws {
        let probe = ExportProbe()
        let controller = makeController(probe: probe)
        controller.prepare(assets: [asset()])
        let url = try temporaryVideo()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        controller.destinationChosen(url)
        await waitUntil { probe.callback != nil }
        controller.cancel()
        XCTAssertEqual(controller.state, .cancelling)
        await probe.send(.framesWritten(1))
        XCTAssertEqual(controller.completedPhotos, 0)
        await controller.cancelAndWait()
        XCTAssertEqual(controller.state, .cancelled)
    }

    func testFailedExportRetainsSelectionForRetry() async throws {
        let probe = ExportProbe()
        probe.failure = TimelapseError.imageUnavailable
        let controller = makeController(probe: probe)
        controller.prepare(assets: [asset()])
        let url = try temporaryVideo()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        controller.destinationChosen(url)
        await waitUntil { probe.callback != nil }
        probe.finish()
        await waitUntil { !controller.isBusy }
        guard case .failed(let message) = controller.state else { return XCTFail("Expected failure") }
        XCTAssertTrue(message.contains("connection"))
        XCTAssertEqual(controller.assets.count, 1)
        probe.failure = nil
        controller.destinationChosen(url)
        await waitUntil { probe.calls == 2 }
        probe.finish()
        await waitUntil { !controller.isBusy }
        guard case .succeeded = controller.state else { return XCTFail("Expected retry to succeed") }
    }

    func testLateCancellationAfterCommitStillReportsSuccess() async throws {
        let controller = TimelapseExportController(
            results: testResultStore(),
            generator: { _, url, _ in
                try Data("video".utf8).write(to: url)
                withUnsafeCurrentTask { $0?.cancel() }
            }, announce: { _ in }
        )
        controller.prepare(assets: [asset()])
        let url = try temporaryVideo()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        controller.destinationChosen(url)
        await waitUntil { !controller.isBusy }
        guard case .succeeded = controller.state else { return XCTFail("Committed video must be successful") }
        XCTAssertEqual(try Data(contentsOf: url), Data("video".utf8))
    }

    func testSuccessPersistsResultAndAnnouncesReadyInApp() async throws {
        let probe = ExportProbe()
        let results = testResultStore()
        var announcements: [String] = []
        let controller = TimelapseExportController(
            results: results,
            generator: { assets, url, callback in try await probe.generate(assets, url, callback) },
            announce: { announcements.append($0) }
        )
        controller.prepare(assets: [asset()])
        let url = try temporaryVideo()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        controller.destinationChosen(url)
        await waitUntil { probe.callback != nil }
        probe.finish()
        await waitUntil { !controller.isBusy }
        guard case .succeeded(let result) = controller.state else { return XCTFail("Expected success") }
        XCTAssertEqual(results.latest?.id, result.id)
        XCTAssertEqual(result.url, url)
        XCTAssertEqual(announcements.filter { $0 == L10n.string("Timelapse ready") }.count, 1)
        XCTAssertNil(controller.completionNote)
    }

    private func makeController(
        probe: ExportProbe? = nil
    ) -> TimelapseExportController {
        let probe = probe ?? ExportProbe()
        return TimelapseExportController(
            results: testResultStore(),
            generator: { assets, url, callback in try await probe.generate(assets, url, callback) },
            announce: { _ in }
        )
    }

    private func testResultStore() -> TimelapseResultStore {
        TimelapseResultStore(defaults: UserDefaults(suiteName: "timelapse-tests-" + UUID().uuidString)!)
    }

    private func asset() -> ChameoAsset { ChameoAsset(asset: TimelapseTestPhoto()) }

    private func temporaryVideo() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("timelapse.mp4")
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<500 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
        XCTFail("Export did not reach the expected state")
    }
}

@MainActor
private final class ExportProbe {
    var calls = 0
    var selectionCount = 0
    var callback: TimelapseService.ProgressHandler?
    var failure: Error?
    private var finished = false

    func generate(_ assets: [ChameoAsset], _ url: URL, _ callback: @escaping TimelapseService.ProgressHandler) async throws {
        calls += 1
        selectionCount = assets.count
        self.callback = callback
        finished = false
        while !finished { try await Task.sleep(for: .milliseconds(2)) }
        if let failure { throw failure }
        try Data("video".utf8).write(to: url)
    }
    func send(_ event: TimelapseProgress) async { await callback?(event) }
    func finish() { finished = true }
}

extension TimelapseExportTests {
    func testPhotoStackKeepsLoadedThumbnailsAcrossCreationAndCompletion() async throws {
        let probe = ExportProbe()
        let controller = makeController(probe: probe)
        let photos = [asset(), asset(), asset()]
        controller.prepare(assets: photos)
        var requests: [String: Int] = [:]
        let view = TimelapseExportView(thumbnailLoader: { photo in
            requests[photo.id, default: 0] += 1
            return NSImage(size: NSSize(width: 32, height: 32))
        })
        .environmentObject(controller)
        .environmentObject(LibraryStore())
        .environmentObject(LocalizationController())
        let hosting = NSHostingView(rootView: view)
        let rect = NSRect(origin: .zero, size: TimelapseWindowController.contentSize)
        let window = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        hosting.frame = rect
        hosting.layoutSubtreeIfNeeded()
        defer { window.close() }
        await waitUntil { requests.count == 3 }
        let video = try temporaryVideo()
        defer { try? FileManager.default.removeItem(at: video.deletingLastPathComponent()) }
        controller.destinationChosen(video)
        await waitUntil { probe.callback != nil }
        await probe.send(.framesWritten(2))
        hosting.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(30))
        probe.finish()
        await waitUntil { !controller.isBusy }
        hosting.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(requests, Dictionary(uniqueKeysWithValues: photos.map { ($0.id, 1) }),
                       "State changes must preserve the thumbnail views rather than reload or replace the stack")
    }

    func testClosingExportWindowKeepsTaskAndReusesWindow() async throws {
        let probe = ExportProbe()
        let controller = makeController(probe: probe)
        controller.prepare(assets: [asset(), asset()])
        let video = try temporaryVideo()
        defer { try? FileManager.default.removeItem(at: video.deletingLastPathComponent()) }
        controller.destinationChosen(video)
        await waitUntil { probe.callback != nil }
        let presenter = TimelapseWindowController(export: controller, libraryStore: LibraryStore(),
                                                  localizationController: LocalizationController())
        let window = try XCTUnwrap(presenter.window)
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertEqual(window.contentMinSize, NSSize(width: 460, height: 420))
        XCTAssertEqual(TimelapseWindowController.contentSize, NSSize(width: 460, height: 480))
        window.close()
        XCTAssertTrue(presenter.window === window)
        XCTAssertEqual(controller.state, .running)
        await probe.send(.framesWritten(1))
        XCTAssertEqual(controller.completedPhotos, 1)
        probe.finish()
        await waitUntil { !controller.isBusy }
        guard case .succeeded = controller.state else { return XCTFail("Closing the window must not cancel export") }
    }

    func testClosingFinishedExportWindowResetsSummaryAndProgress() async throws {
        let probe = ExportProbe()
        let controller = makeController(probe: probe)
        controller.prepare(assets: [asset()])
        let video = try temporaryVideo()
        defer { try? FileManager.default.removeItem(at: video.deletingLastPathComponent()) }
        controller.destinationChosen(video)
        await waitUntil { probe.callback != nil }
        await probe.send(.framesWritten(1))
        probe.finish()
        await waitUntil { !controller.isBusy }
        guard case .succeeded = controller.state else { return XCTFail("Expected finished export") }
        let presenter = TimelapseWindowController(export: controller, libraryStore: LibraryStore(),
                                                  localizationController: LocalizationController())
        let window = try XCTUnwrap(presenter.window)
        window.close()
        XCTAssertEqual(controller.state, .summary)
        XCTAssertEqual(controller.progress, .preparing)
        XCTAssertEqual(controller.completedPhotos, 0)
        XCTAssertFalse(controller.hasStatus)
        XCTAssertNil(controller.resultActionError)
        XCTAssertNil(controller.completionNote)
        XCTAssertTrue(controller.assets.isEmpty, "Next export uses the current library snapshot")
        XCTAssertTrue(presenter.window === window)
    }

    func testExportScreenRendersAtWindowSizeInEveryLanguage() async throws {
        let previous = UserDefaults.standard.object(forKey: AppPreferenceKey.language)
        defer {
            if let previous { UserDefaults.standard.set(previous, forKey: AppPreferenceKey.language) }
            else { UserDefaults.standard.removeObject(forKey: AppPreferenceKey.language) }
        }
        let directory = URL(fileURLWithPath: "/private/tmp/chameo-timelapse-previews")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for language in [AppLanguage.english, .simplifiedChinese, .traditionalChinese] {
            UserDefaults.standard.set(language.rawValue, forKey: AppPreferenceKey.language)
            let probe = ExportProbe()
            let controller = makeController(probe: probe)
            controller.prepare(assets: [])
            try await render(controller, to: directory.appendingPathComponent(language.rawValue + "-empty.png"),
                       size: TimelapseWindowController.minimumContentSize)
            let first = Date(timeIntervalSince1970: 1772323200) // March 1, 2026
            let last = Date(timeIntervalSince1970: 1790899200) // October 2, 2026
            controller.prepare(assets: (0..<184).map { index in
                ChameoAsset(asset: TimelapseTestPhoto(date: first.addingTimeInterval(
                    last.timeIntervalSince(first) * Double(index) / 183)))
            })
            try await render(controller, to: directory.appendingPathComponent(language.rawValue + "-summary.png"))
            try await render(controller, to: directory.appendingPathComponent(language.rawValue + "-summary-minimum.png"),
                       size: TimelapseWindowController.minimumContentSize)
            let temporary = try temporaryVideo().deletingLastPathComponent()
            let movies = temporary.appendingPathComponent("Movies", isDirectory: true)
            try FileManager.default.createDirectory(at: movies, withIntermediateDirectories: true)
            let video = movies.appendingPathComponent("Chameo Timelapse.mp4")
            defer { try? FileManager.default.removeItem(at: temporary) }
            controller.destinationChosen(video)
            await waitUntil { probe.callback != nil }
            await probe.send(.downloadingPhoto(0, 0.45))
            try await render(controller, to: directory.appendingPathComponent(language.rawValue + "-progress.png"))
            try await render(controller, to: directory.appendingPathComponent(language.rawValue + "-progress-minimum.png"),
                       size: TimelapseWindowController.minimumContentSize)
            await probe.send(.framesWritten(132))
            try await render(controller, to: directory.appendingPathComponent(language.rawValue + "-encoding.png"))
            try await render(controller, to: directory.appendingPathComponent(language.rawValue + "-encoding-minimum.png"),
                       size: TimelapseWindowController.minimumContentSize)
            await probe.send(.saving)
            try await render(controller, to: directory.appendingPathComponent(language.rawValue + "-saving.png"),
                       size: TimelapseWindowController.minimumContentSize)
            probe.finish()
            await waitUntil { !controller.isBusy }
            try await render(controller, to: directory.appendingPathComponent(language.rawValue + "-result.png"))
            try await render(controller, to: directory.appendingPathComponent(language.rawValue + "-result-minimum.png"),
                       size: TimelapseWindowController.minimumContentSize)
            for appearance in [NSAppearance.Name.darkAqua, .accessibilityHighContrastAqua] {
                try await render(controller, to: directory.appendingPathComponent(language.rawValue + "-result-" + appearance.rawValue + ".png"),
                                 size: TimelapseWindowController.minimumContentSize, appearance: appearance)
            }
        }
    }

    private func render(_ controller: TimelapseExportController, to url: URL,
                        size: NSSize? = nil, appearance: NSAppearance.Name = .aqua) async throws {
        let renderSize = size ?? TimelapseWindowController.contentSize
        let fixtureImage = ProcessInfo.processInfo.environment["CHAMEO_TIMELAPSE_PREVIEW_IMAGE"].flatMap {
            NSImage(contentsOfFile: $0)
        }
        let view = TimelapseExportView(thumbnailLoader: { _ in fixtureImage })
            .environmentObject(LocalizationController())
            .environmentObject(AppState())
            .environmentObject(LibraryStore())
            .environmentObject(controller)
            .environment(\.locale, L10n.currentLocalization.displayLocale)
            .environment(\.colorScheme, appearance == .darkAqua ? .dark : .light)
            .frame(width: renderSize.width, height: renderSize.height)
            .background(Color(nsColor: .windowBackgroundColor))
        // ImageRenderer cannot draw AppKit-backed scroll views and controls.
        // Render a real hosting view in an offscreen window instead.
        let rect = NSRect(x: 0, y: 0, width: renderSize.width, height: renderSize.height)
        let hosting = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.appearance = NSAppearance(named: appearance)
        window.contentView = hosting
        hosting.frame = rect
        hosting.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(80))
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: rect))
        hosting.cacheDisplay(in: rect, to: bitmap)
        XCTAssertGreaterThanOrEqual(bitmap.pixelsWide, Int(renderSize.width))
        XCTAssertGreaterThanOrEqual(bitmap.pixelsHigh, Int(renderSize.height))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: url)
    }
}


private final class TimelapseTestPhoto: PHAsset, @unchecked Sendable {
    private let fixtureID = UUID().uuidString
    private let date: Date
    init(date: Date = Date(timeIntervalSince1970: 1740787200)) {
        self.date = date
        super.init()
    }
    override var localIdentifier: String { fixtureID }
    override var creationDate: Date? { date }
}
