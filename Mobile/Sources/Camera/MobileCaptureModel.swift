import ChameoCore
import Foundation
import Observation

@MainActor
@Observable
final class MobileCaptureModel {
    let camera = MobileCameraService()
    private(set) var pending: PendingChameo?
    private(set) var isSaving = false
    private(set) var isRestoring = true
    private(set) var guidance: LiveFramingGuidanceState = .neutral
    private(set) var countdown: Int?
    private(set) var qualitySuggestion: CaptureQualitySuggestion?
    var message: String?

    private let pendingStore: PendingChameoStore
    @ObservationIgnored private var locationServiceStorage: MobileLocationService?
    private var guidanceEvaluator = LiveFramingGuidanceEvaluator()
    private var countdownMachine = HandsFreeCountdownMachine()
    private var countdownTask: Task<Void, Never>?

    init(
        pendingStore: PendingChameoStore = PendingChameoStore(),
        locationService: MobileLocationService? = nil
    ) {
        self.pendingStore = pendingStore
        locationServiceStorage = locationService
    }

    private var locationService: MobileLocationService {
        if let locationServiceStorage {
            return locationServiceStorage
        }
        let service = MobileLocationService()
        locationServiceStorage = service
        return service
    }

    func restorePending() async {
        guard isRestoring else { return }
        defer { isRestoring = false }
        do {
            pending = try await pendingStore.load()
            if let pending {
                camera.stop()
                qualitySuggestion = suggestion(for: pending.metadata.faceCaptureQualityScore)
            }
        } catch {
            message = String(localized: "The previous preview could not be restored.")
        }
    }

    func setCameraActive(_ active: Bool) {
        guard pending == nil, !isRestoring else {
            camera.stop()
            return
        }
        active ? camera.start() : camera.stop()
        handleCountdown(.setVisible(active && pending == nil))
        handleCountdown(.setEnabled(handsFreeEnabled))
        if !active {
            guidance = guidanceEvaluator.reset()
        }
    }

    func consumeLiveFrame(_ frame: LiveFramingFrame, previewSize: CGSize) {
        guard previewSize.width > 0, previewSize.height > 0 else { return }
        guidance = guidanceEvaluator.evaluate(
            frame: frame,
            previewSize: previewSize,
            mirrored: true
        )
        handleCountdown(.setEnabled(handsFreeEnabled))
        handleCountdown(.guidanceChanged(guidance))
    }

    func takeChameo() async {
        guard pending == nil, camera.status == .ready else { return }
        handleCountdown(.manualCapture)
        message = nil
        let wantsLocation = UserDefaults.standard.bool(forKey: "saveLocation")
        let locationTask: Task<CaptureLocation?, Never>? = wantsLocation
            ? Task { await locationService.captureLocation() }
            : nil
        do {
            let originalData = try await camera.capturePhoto()
            let capturedAt = Date()
            message = String(localized: "Preparing photo…")
            let evaluation = await MobileFaceProcessingService.qualityEvaluation(from: originalData)
            let score: Float? = if case .scored(let value) = evaluation { value } else { nil }
            qualitySuggestion = CaptureQualityPolicy.suggestion(
                for: evaluation,
                acceptedScores: MobileCaptureQualityStore.acceptedScores()
            )
            let data: Data
            if UserDefaults.standard.object(forKey: "autoAlignPhotos") as? Bool ?? true {
                message = String(localized: "Aligning photo…")
                data = await MobileFaceProcessingService.alignmentResult(from: originalData).data
            } else {
                data = originalData
            }
            let location = await locationTask?.value
            let pending = PendingChameo(
                data: data,
                metadata: PendingChameoMetadata(
                    capturedAt: capturedAt,
                    location: location,
                    faceCaptureQualityScore: score
                )
            )
            try await pendingStore.save(pending)
            self.pending = pending
            camera.stop()
            message = qualitySuggestion == nil
                ? String(localized: "Preview ready. Save to Photos or retake.")
                : String(localized: "Preview ready. Retake recommended, or save anyway.")
        } catch {
            locationTask?.cancel()
            message = String(localized: "The camera could not take a photo. Try again.")
        }
    }

    func save() async -> Bool {
        guard let pending, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            let albumName = UserDefaults.standard.string(forKey: "albumName") ?? "Chameo"
            _ = try await MobilePhotoLibraryService.save(
                data: pending.data,
                albumName: albumName,
                capturedAt: pending.metadata.capturedAt,
                location: pending.metadata.location
            )
            try await pendingStore.discard()
            self.pending = nil
            await MobileReminderService.recordChameo(at: pending.metadata.capturedAt)
            MobileCaptureQualityStore.record(
                score: pending.metadata.faceCaptureQualityScore
            )
            message = String(localized: "Saved to Photos")
            qualitySuggestion = nil
            return true
        } catch {
            message = String(localized: "The Chameo could not be saved. Check Photos access and try again.")
            return false
        }
    }

    func retake() async {
        do {
            try await pendingStore.discard()
            pending = nil
            qualitySuggestion = nil
            message = String(localized: "Discarded preview")
            camera.start()
        } catch {
            message = String(localized: "The preview could not be discarded.")
        }
    }

    private var handsFreeEnabled: Bool {
        UserDefaults.standard.bool(forKey: "handsFreeCountdown")
            && (UserDefaults.standard.object(forKey: "showGrid") as? Bool ?? true)
    }

    private func suggestion(for score: Float?) -> CaptureQualitySuggestion? {
        guard let score else { return nil }
        return CaptureQualityPolicy.suggestion(
            for: .scored(score),
            acceptedScores: MobileCaptureQualityStore.acceptedScores()
        )
    }

    private func handleCountdown(_ event: HandsFreeCountdownEvent) {
        let effects = countdownMachine.handle(event)
        countdown = countdownMachine.phase.displayedCount
        for effect in effects {
            switch effect {
            case .startTimer:
                countdownTask?.cancel()
                countdownTask = Task { [weak self] in
                    for _ in 0..<3 {
                        do { try await Task.sleep(for: .seconds(1)) }
                        catch { return }
                        guard let self else { return }
                        self.handleCountdown(.tick)
                    }
                }
            case .cancelTimer:
                countdownTask?.cancel()
                countdownTask = nil
            case .capture:
                countdownTask = nil
                Task { [weak self] in await self?.takeChameo() }
            }
        }
    }
}
