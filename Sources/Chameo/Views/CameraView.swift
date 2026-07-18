import CoreLocation
import OSLog
import SwiftUI

struct CameraView: View {
    private static let captureQualityLogger = Logger(
        subsystem: "com.robertu.Chameo",
        category: "capture-quality"
    )

    @EnvironmentObject private var cameraService: CameraService
    @EnvironmentObject private var libraryStore: LibraryStore
    @AppStorage(AppPreferenceKey.autoAlignPhotos) private var autoAlignPhotos = true

    let albumName: String
    let showFaceGuide: Bool
    let saveLocation: Bool
    @Binding var statusMessage: String?

    @State private var isSaving = false
    @State private var capturedPreview: CapturedPreview?
    @State private var locationService = LocationService()
    @State private var photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
    @State private var locationPermissionDenied = false

    var body: some View {
        VStack(spacing: 12) {
            if let capturedPreview {
                CapturedPreviewView(
                    preview: capturedPreview,
                    isSaving: isSaving,
                    photosPermissionDenied: isPhotosPermissionDenied,
                    locationPermissionDenied: saveLocation && locationPermissionDenied,
                    onRetake: {
                        retakeCapturedPreview()
                    },
                    onKeep: {
                        beginSavingCapturedPreview()
                    }
                )
            } else {
                ZStack {
                    CameraPreviewView(
                        session: cameraService.session,
                        mirrored: cameraService.isPreviewMirrored
                    )
                        .overlay {
                            if shouldShowFaceGuide {
                                CameraGuideView()
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    cameraOverlay
                }
                .frame(width: 392, height: 294)
                .padding(.top, 14)

                Button {
                    beginCapture()
                } label: {
                    Label(isSaving ? "Saving…" : "Take Photo", systemImage: "camera.circle.fill")
                        .frame(minWidth: 104)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!canCapture || isSaving)

                if case .unauthorized = cameraService.status {
                    PermissionStatusInline(
                        message: "Camera permission is required to take a Chameo.",
                        destination: .camera
                    )
                    .padding(.horizontal, 18)
                }

                if saveLocation && locationPermissionDenied {
                    PermissionStatusInline(
                        message: "Location permission is off. Chameo will save without location.",
                        destination: .location
                    )
                    .padding(.horizontal, 18)
                }
            }
        }
        .frame(width: 420, height: 380, alignment: .top)
        .task {
            photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
        }
    }

    @ViewBuilder
    private var cameraOverlay: some View {
        switch cameraService.status {
        case .requestingPermission:
            StatusOverlay(title: "Requesting camera access", systemImage: "camera")
        case .unauthorized:
            StatusOverlay(
                title: "Camera access is off",
                systemImage: "camera.fill",
                recoveryDestination: .camera
            )
        case .unavailable(let message):
            StatusOverlay(title: message, systemImage: "exclamationmark.triangle")
        case .idle:
            StatusOverlay(title: "Starting camera", systemImage: "camera")
        case .capturing:
            ProgressView("Capturing")
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        case .ready:
            EmptyView()
        }
    }

    private var canCapture: Bool {
        if case .ready = cameraService.status {
            return true
        }
        return false
    }

    private var shouldShowFaceGuide: Bool {
        showFaceGuide && canCapture
    }

    private var isPhotosPermissionDenied: Bool {
        switch photosAuthorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    private func beginCapture() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            await takeChameo()
        }
    }

    private func takeChameo() async {
        statusMessage = nil

        do {
            let data = try await cameraService.capturePhoto(mirrored: false)
            statusMessage = "Checking photo…"
            let qualityEvaluation = await FaceCaptureQualityService.evaluation(from: data)
            logCaptureQuality(qualityEvaluation)
            let qualitySuggestion = CaptureQualityPolicy.suggestion(
                for: qualityEvaluation,
                acceptedScores: CaptureQualityHistoryStore.acceptedScores()
            )

            if autoAlignPhotos {
                statusMessage = "Aligning photo…"
                let result = await FaceAlignmentService.alignmentResult(from: data)
                capturedPreview = CapturedPreview(
                    data: result.data,
                    qualityEvaluation: qualityEvaluation,
                    qualitySuggestion: qualitySuggestion
                )
                statusMessage = previewStatusMessage(
                    alignmentMessage: result.message,
                    qualitySuggestion: qualitySuggestion
                )
            } else {
                capturedPreview = CapturedPreview(
                    data: data,
                    qualityEvaluation: qualityEvaluation,
                    qualitySuggestion: qualitySuggestion
                )
                statusMessage = previewStatusMessage(
                    alignmentMessage: nil,
                    qualitySuggestion: qualitySuggestion
                )
            }
        } catch {
            statusMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func previewStatusMessage(
        alignmentMessage: String?,
        qualitySuggestion: CaptureQualitySuggestion?
    ) -> String {
        if let alignmentMessage {
            return alignmentMessage
        }
        if qualitySuggestion != nil {
            return "Preview ready. Retake recommended or keep anyway."
        }
        return "Preview ready. Keep or Retake."
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

    private func beginSavingCapturedPreview() {
        guard capturedPreview != nil, !isSaving else { return }
        isSaving = true
        Task {
            await keepCapturedPreview()
        }
    }

    private func keepCapturedPreview() async {
        guard let capturedPreview else {
            return
        }

        do {
            var location = Optional.none as CLLocation?
            if saveLocation {
                statusMessage = "Getting location…"
                location = await locationService.requestCurrentLocation()
                locationPermissionDenied = locationService.isPermissionDenied
                if location == nil {
                    statusMessage = "Location unavailable. Saving without location…"
                }
            }

            if statusMessage != "Location unavailable. Saving without location…" {
                statusMessage = "Saving to Photos…"
            }

            _ = try await PhotoLibraryService.savePhoto(
                data: capturedPreview.data,
                albumName: albumName,
                location: location
            )
            CaptureQualityHistoryStore.recordAccepted(
                capturedPreview.qualityEvaluation
            )
            await ReminderService.recordSelfieTaken()
            photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
            await libraryStore.reload(albumName: albumName)
            self.capturedPreview = nil
            if saveLocation && location == nil {
                statusMessage = "Saved without location"
            } else {
                statusMessage = "Saved to \(PhotoLibraryService.normalizedAlbumName(albumName))"
            }
        } catch {
            photosAuthorizationStatus = PhotoLibraryService.authorizationStatus()
            statusMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func retakeCapturedPreview() {
        self.capturedPreview = nil
        statusMessage = "Discarded preview"
    }
}

private struct CapturedPreview: Identifiable {
    let id = UUID()
    let data: Data
    let image: NSImage?
    let qualityEvaluation: FaceCaptureQualityEvaluation
    let qualitySuggestion: CaptureQualitySuggestion?

    init(
        data: Data,
        qualityEvaluation: FaceCaptureQualityEvaluation,
        qualitySuggestion: CaptureQualitySuggestion?
    ) {
        self.data = data
        self.image = NSImage(data: data)
        self.qualityEvaluation = qualityEvaluation
        self.qualitySuggestion = qualitySuggestion
    }
}

private struct CapturedPreviewView: View {
    let preview: CapturedPreview
    let isSaving: Bool
    let photosPermissionDenied: Bool
    let locationPermissionDenied: Bool
    let onRetake: () -> Void
    let onKeep: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if let image = preview.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 392, height: 294)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .bottom) {
                        qualitySuggestionBanner
                    }
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 392, height: 294)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .bottom) {
                        qualitySuggestionBanner
                    }
            }

            HStack {
                actionButtons
            }
            .frame(width: 392)

            if photosPermissionDenied {
                PermissionStatusInline(
                    message: "Photos permission is required to save this Chameo.",
                    destination: .photos
                )
                .frame(width: 392)
            }

            if locationPermissionDenied {
                PermissionStatusInline(
                    message: "Location permission is off. Save will continue without location.",
                    destination: .location
                )
                .frame(width: 392)
            }
        }
        .frame(width: 420, height: 380, alignment: .top)
        .padding(.top, 14)
    }

    @ViewBuilder
    private var qualitySuggestionBanner: some View {
        if let suggestion = preview.qualitySuggestion {
            Label(suggestion.message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
                .accessibilityLabel("Retake suggested. \(suggestion.message)")
        }
    }

    private var keepButtonTitle: String {
        if isSaving {
            return "Saving…"
        }
        return preview.qualitySuggestion == nil ? "Save to Photos" : "Keep Anyway"
    }

    @ViewBuilder
    private var actionButtons: some View {
        if preview.qualitySuggestion != nil {
            Button("Retake", role: .destructive, action: onRetake)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.cancelAction)
                .disabled(isSaving)

            Spacer()

            Button(keepButtonTitle, action: onKeep)
                .buttonStyle(.bordered)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(isSaving)
        } else {
            Button("Retake", role: .destructive, action: onRetake)
                .keyboardShortcut(.cancelAction)
                .disabled(isSaving)

            Spacer()

            Button(keepButtonTitle, action: onKeep)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving)
        }
    }
}

private struct StatusOverlay: View {
    let title: String
    let systemImage: String
    var recoveryDestination: PermissionRecoveryDestination?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
            Text(title)
                .font(.callout)
                .multilineTextAlignment(.center)

            if let recoveryDestination {
                Button(recoveryDestination.title) {
                    PermissionRecoveryService.open(recoveryDestination)
                }
                .controlSize(.small)
            }
        }
        .foregroundStyle(.secondary)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding()
    }
}
