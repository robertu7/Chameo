import AppKit
import Combine
import UniformTypeIdentifiers
@preconcurrency import UserNotifications

@MainActor
final class TimelapseExportController: ObservableObject {
    enum State: Equatable {
        case summary, choosingDestination, running, cancelling, cancelled
        case succeeded(TimelapseResult)
        case failed(String)
    }

    typealias Generator = ([ChameoAsset], URL, @escaping TimelapseService.ProgressHandler) async throws -> Void
    @Published private(set) var state: State = .summary
    @Published private(set) var assets: [ChameoAsset] = []
    @Published private(set) var progress: TimelapseProgress = .preparing
    @Published private(set) var completedPhotos = 0
    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var resultActionError: String?
    @Published private(set) var completionNote: String?

    private let generator: Generator
    private let notifications: any TimelapseNotifying
    private let results: TimelapseResultStore
    private let announce: (String) -> Void
    private var task: Task<Void, Never>?
    private var runID: UUID?
    private var savePanel: NSSavePanel?
    private var previousDestination: URL?
    private var announcedPhases: Set<String> = []

    init(
        notifications: (any TimelapseNotifying)? = nil,
        results: TimelapseResultStore? = nil,
        generator: @escaping Generator = { assets, url, progress in
            try await TimelapseService.generate(assets: assets, to: url, onProgress: progress)
        },
        announce: @escaping (String) -> Void = { AccessibilityAnnouncement.post($0) }
    ) {
        self.notifications = notifications ?? TimelapseNotificationService()
        self.results = results ?? TimelapseResultStore()
        self.generator = generator
        self.announce = announce
    }

    var isBusy: Bool { state == .choosingDestination || task != nil }
    var isGenerating: Bool { state == .running || state == .cancelling }
    var duration: Double { Double(assets.count) / Double(TimelapseService.framesPerSecond) }
    var footerText: String {
        switch state {
        case .succeeded: return L10n.string("Timelapse ready")
        case .failed: return L10n.string("Timelapse export failed")
        case .cancelling: return L10n.string("Cancelling…")
        case .cancelled: return L10n.string("Export cancelled")
        default: return progress.text(total: assets.count)
        }
    }
    var hasStatus: Bool { state != .summary }

    func prepare(assets: [ChameoAsset]) {
        guard !isBusy else { return }
        self.assets = assets
        state = .summary
        progress = .preparing
        completedPhotos = 0
        completionNote = nil
        resultActionError = nil
    }

    func refreshNotificationStatus() async {
        notificationStatus = await notifications.authorizationStatus()
    }

    func chooseDestination() {
        guard !isBusy, !assets.isEmpty else { return }
        state = .choosingDestination
        let panel = NSSavePanel()
        savePanel = panel
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = previousDestination?.lastPathComponent ?? L10n.string("Chameo Timelapse.mp4")
        panel.directoryURL = previousDestination?.deletingLastPathComponent()
        panel.prompt = L10n.string("Save")
        panel.begin { [weak self] response in
            guard let self else { return }
            self.savePanel = nil
            self.destinationChosen(response == .OK ? panel.url : nil)
        }
    }

    /// Kept separate from NSSavePanel so destination cancellation is testable.
    func destinationChosen(_ url: URL?) {
        guard task == nil else { return }
        guard let url else { state = .summary; return }
        guard !assets.isEmpty else { state = .summary; return }
        previousDestination = url
        let id = UUID()
        runID = id
        let selection = assets
        completedPhotos = 0
        progress = .preparing
        resultActionError = nil
        completionNote = nil
        state = .running
        announcedPhases = [TimelapseProgress.preparing.announcementKey]
        announce(L10n.string("Preparing timelapse…"))
        let authorization = Task {
            let status = await notifications.prepareAuthorization()
            notificationStatus = status
            return status
        }
        task = Task { [self] in
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
                task = nil
            }
            do {
                try Task.checkCancellation()
                try await generator(selection, url) { [weak self] event in
                    await self?.receive(event, runID: id)
                }
                // Generation has committed the destination. Late cancellation must
                // not relabel a valid video as cancelled or delete it.
                let result = results.save(id: id, url: url)
                state = .succeeded(result)
                announce(L10n.string("Timelapse ready"))
                if result.bookmark == nil {
                    completionNote = L10n.string("Video saved. Open it before quitting; its location could not be remembered.")
                }
                Task {
                    notificationStatus = await authorization.value
                    // Another export may have completed while permission was pending.
                    guard results.latest?.id == id else { return }
                    do { try await notifications.deliver(exportID: id, filename: url.lastPathComponent) }
                    catch {
                        if results.latest?.id == id {
                            completionNote = L10n.string("Video saved. The completion notification could not be sent.")
                        }
                    }
                }
            } catch is CancellationError {
                state = .cancelled
                announce(L10n.string("Export cancelled"))
            } catch {
                if Task.isCancelled {
                    state = .cancelled
                    announce(L10n.string("Export cancelled"))
                } else {
                    let message = Self.failureMessage(error)
                    state = .failed(message)
                    announce(message)
                }
            }
        }
    }

    func receive(_ event: TimelapseProgress, runID id: UUID) {
        guard runID == id, state == .running, event.order >= progress.order else { return }
        if case .downloadingPhoto(_, let fraction) = event,
           case .downloadingPhoto(_, let previous) = progress, fraction < previous { return }
        progress = event
        if case .framesWritten(let count) = event { completedPhotos = count }
        if announcedPhases.insert(event.announcementKey).inserted {
            announce(L10n.string(event.announcementKey))
        }
    }

    func cancel() {
        guard state == .running else { return }
        state = .cancelling
        task?.cancel()
    }

    func cancelAndWait() async {
        let runningTask = task
        cancel()
        await runningTask?.value
    }

    func cancelDestinationPanel() { savePanel?.cancel(nil) }

    func openResult(id: UUID, play: Bool = false) {
        resultActionError = nil
        do {
            try results.withURL(id: id) { url in
                if play {
                    guard NSWorkspace.shared.open(url) else { throw TimelapseResultError.unavailable }
                } else {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        } catch {
            resultActionError = error.localizedDescription
            announce(error.localizedDescription)
        }
    }

    private static func failureMessage(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == NSFileWriteOutOfSpaceError {
            return L10n.string("Not enough disk space. Free some space or choose another destination, then retry.")
        }
        if error as? TimelapseError == .imageUnavailable || nsError.domain == NSURLErrorDomain {
            return L10n.string("Could not load a photo. Check your connection and Photos access, then retry.")
        }
        return error.localizedDescription + " " + L10n.string("Check Photos access and the save destination, then retry.")
    }
}
