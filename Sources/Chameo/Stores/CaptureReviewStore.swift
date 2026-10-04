import AppKit
import CoreLocation
import OSLog
import Photos

/// Owns the draft and its work across tab, popover, and window lifetimes.
@MainActor
final class CaptureReviewStore: ObservableObject {
    private static let captureQualityLogger = Logger(
        subsystem: AppDistribution.current.bundleIdentifier,
        category: "capture-quality"
    )

    @Published private(set) var isSaving = false
    @Published private(set) var capturedPreview: CapturedPreview?
    @Published var statusMessage: LocalizedMessage?
    @Published private(set) var photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
    @Published private(set) var locationPermissionDenied = false
    private let locationService = LocationService()
    private var operationTask: Task<Void, Never>?

    func refreshPermissions() {
        photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
        locationPermissionDenied = locationService.isPermissionDenied
    }

    func capture(cameraService: CameraService, autoAlignPhotos: Bool) {
        capture { try await self.takeChameo(cameraService: cameraService, autoAlignPhotos: autoAlignPhotos) }
    }

    func save(albumName: String, saveLocation: Bool, libraryStore: LibraryStore,
              localPhotos: LocalPhotoSettingsController) {
        save { preview in
            try await self.keepCapturedPreview(preview, albumName: albumName, saveLocation: saveLocation,
                libraryStore: libraryStore, localPhotos: localPhotos)
        }
    }

    func capture(using prepare: @escaping @MainActor () async throws -> CapturedPreview) {
        guard capturedPreview == nil else { return }
        perform {
            self.statusMessage = nil
            do { self.capturedPreview = try await prepare() }
            catch { self.statusMessage = .error(error) }
        }
    }

    func save(using persist: @escaping @MainActor (CapturedPreview) async throws -> LocalizedMessage) {
        guard let capturedPreview else { return }
        perform {
            do {
                self.statusMessage = try await persist(capturedPreview)
                self.capturedPreview = nil
            } catch {
                self.statusMessage = .error(error)
            }
            self.refreshPermissions()
        }
    }

    private func perform(_ operation: @escaping @MainActor () async -> Void) {
        guard !isSaving else { return }
        isSaving = true
        operationTask = Task {
            await operation()
            isSaving = false
            operationTask = nil
        }
    }

    private func takeChameo(cameraService: CameraService, autoAlignPhotos: Bool) async throws -> CapturedPreview {
        let data = try await cameraService.capturePhoto(mirrored: false)
        statusMessage = .localized("Preparing photo…")
        let qualityEvaluation = await FaceCaptureQualityService.evaluation(from: data)
        logCaptureQuality(qualityEvaluation)
        let qualitySuggestion = CaptureQualityPolicy.suggestion(
            for: qualityEvaluation,
            acceptedScores: CaptureQualityHistoryStore.acceptedScores()
        )

        if autoAlignPhotos {
            statusMessage = .localized("Aligning photo…")
            let result = await FaceAlignmentService.alignmentResult(from: data)
            statusMessage = previewStatusMessage(
                alignmentError: result.error,
                qualitySuggestion: qualitySuggestion
            )
            return CapturedPreview(data: result.data, qualityEvaluation: qualityEvaluation,
                qualitySuggestion: qualitySuggestion)
        } else {
            statusMessage = previewStatusMessage(
                alignmentError: nil,
                qualitySuggestion: qualitySuggestion
            )
            return CapturedPreview(data: data, qualityEvaluation: qualityEvaluation,
                qualitySuggestion: qualitySuggestion)
        }
    }

    private func previewStatusMessage(
        alignmentError: FaceAlignmentError?,
        qualitySuggestion: CaptureQualitySuggestion?
    ) -> LocalizedMessage {
        if let alignmentError {
            return .error(alignmentError)
        }
        if qualitySuggestion != nil {
            return .localized("Preview ready. Retake recommended, or save anyway.")
        }
        return .localized("Review your Chameo before saving.")
    }

    private func logCaptureQuality(_ evaluation: FaceCaptureQualityEvaluation) {
        switch evaluation {
        case .scored(let score):
            Self.captureQualityLogger.debug(
                "Vision face capture quality: \(score, privacy: .public)"
            )
        case .noFace:
            Self.captureQualityLogger.debug("Vision capture quality found no face")
        case .scoreUnavailable:
            Self.captureQualityLogger.debug("Vision capture quality returned no score")
        case .unreadableImage:
            Self.captureQualityLogger.debug("Vision capture quality could not read the image")
        case .analysisFailed:
            Self.captureQualityLogger.debug("Vision capture quality analysis failed")
        }
    }

    private func keepCapturedPreview(_ capturedPreview: CapturedPreview, albumName: String,
                                     saveLocation: Bool, libraryStore: LibraryStore,
                                     localPhotos: LocalPhotoSettingsController) async throws -> LocalizedMessage {
        var location = Optional.none as CLLocation?
        if saveLocation {
            statusMessage = .localized("Getting location…")
            location = await locationService.requestCurrentLocation()
            locationPermissionDenied = locationService.isPermissionDenied
            if location == nil {
                statusMessage = .localized("Location unavailable. Saving without location…")
            }
        }

        if location != nil || !saveLocation {
            statusMessage = .localized("Saving to Photos…")
        }

        let saved = try await CapturePhotoSaveService.save(
            data: capturedPreview.data,
            saveToPhotos: { data in
                try await PhotoLibraryService.savePhoto(data: data, albumName: albumName, location: location)
            },
            saveLocally: { data, asset in
                try await localPhotos.store.saveOriginal(data, source: LocalPhotoSnapshot(asset: asset.asset))
            }
        )
        CaptureQualityHistoryStore.recordAccepted(
            capturedPreview.qualityEvaluation
        )
        await ReminderService.recordSelfieTaken()
        photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
        await libraryStore.reloadAfterSaving(albumName: albumName)
        if saved.localCopyFailed {
            return .localized("Saved to Photos. The local copy could not be saved.")
        } else if saveLocation && location == nil {
            return .localized("Saved to Photos without location")
        } else {
            return .formatted(
                "Saved to %@ in Photos",
                PhotoLibraryService.normalizedAlbumName(albumName)
            )
        }
    }

    func retake() {
        guard !isSaving else { return }
        self.capturedPreview = nil
        statusMessage = .localized("Discarded preview")
    }
}
