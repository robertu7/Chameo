import AppKit
import SwiftUI

struct CameraView: View {
    @EnvironmentObject private var cameraService: CameraService
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var libraryStore: LibraryStore
    @ObservedObject var review: CaptureReviewStore
    @EnvironmentObject private var localPhotos: LocalPhotoSettingsController
    @AppStorage(AppPreferenceKey.autoAlignPhotos) private var autoAlignPhotos = true

    let surface: ChameoMainSurface
    let albumName: String
    let handsFreeCountdown: Bool
    let showFaceGuide: Bool
    let saveLocation: Bool

    private var isSaving: Bool { review.isSaving }
    private var capturedPreview: CapturedPreview? { review.capturedPreview }
    private var locationPermissionDenied: Bool { review.locationPermissionDenied }
    @State private var handsFreeCountdownMachine = HandsFreeCountdownMachine()
    @State private var handsFreeCountdownTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: ChameoLayout.sectionSpacing) {
            if let capturedPreview {
                CapturedPreviewView(
                    preview: capturedPreview,
                    isSaving: isSaving,
                    photosPermissionDenied: isPhotosPermissionDenied,
                    locationPermissionDenied: saveLocation && locationPermissionDenied,
                    onRetake: {
                        review.retake()
                    },
                    onKeep: {
                        beginSavingCapturedPreview()
                    }
                )
            } else {
                GlassEffectContainer(spacing: 12) {
                    ZStack {
                        CameraPreviewView(
                            session: cameraService.session,
                            mirrored: cameraService.isPreviewMirrored
                        )
                            .overlay {
                                if shouldShowFaceGuide {
                                    CameraGuideView(
                                        guidanceState: cameraService.liveFramingGuidanceState
                                    )
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: ChameoLayout.cornerRadius))

                        cameraOverlay

                        cameraSelectionOverlay

                        if let count = handsFreeCountdownMachine.phase.displayedCount {
                            HandsFreeCountdownOverlay(count: count)
                        }
                    }
                    .frame(width: ChameoLayout.previewWidth, height: livePreviewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: ChameoLayout.cornerRadius))
                    .chameoImageOutline(cornerRadius: ChameoLayout.cornerRadius)
                }

                Button {
                    beginCapture(trigger: .manual)
                } label: {
                    Label(
                        isSaving
                            ? L10n.string("Taking photo…")
                            : L10n.string("Take Chameo"),
                        systemImage: "camera.circle.fill"
                    )
                        .frame(minWidth: 190)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!canCapture || isSaving)

                if case .unauthorized = cameraService.status {
                    PermissionStatusInline(
                        message: L10n.string("Allow Camera access to take a Chameo."),
                        destination: .camera
                    )
                    .padding(.horizontal, 18)
                }

                if saveLocation && locationPermissionDenied {
                    PermissionStatusInline(
                        message: L10n.string("Location access is off. Chameo will save without location data."),
                        destination: .location
                    )
                    .padding(.horizontal, 18)
                }
            }
        }
        .frame(
            width: ChameoLayout.contentWidth,
            height: ChameoLayout.contentHeight,
            alignment: .top
        )
        .task {
            review.refreshPermissions()
        }
        .onAppear {
            syncLiveFramingGuidance()
            syncHandsFreeCountdown()
        }
        .onChange(of: isVisible) { _, visible in
            if visible {
                review.refreshPermissions()
                syncLiveFramingGuidance()
            }
            syncHandsFreeCountdown()
        }
        .onChange(of: showFaceGuide) { _, _ in
            syncLiveFramingGuidance()
            syncHandsFreeCountdown()
        }
        .onChange(of: livePreviewHeight) { _, _ in
            syncLiveFramingGuidance()
        }
        .onChange(of: handsFreeCountdown) { _, _ in
            syncHandsFreeCountdown()
        }
        .onChange(of: cameraService.liveFramingGuidanceState) { _, guidance in
            handleHandsFreeCountdown(.guidanceChanged(guidance))
        }
        .onChange(of: cameraService.status) { _, _ in
            syncHandsFreeCountdown()
        }
        .onChange(of: isSaving) { _, _ in syncHandsFreeCountdown() }
        .onChange(of: capturedPreview?.id) { _, _ in
            syncHandsFreeCountdown()
        }
        .onDisappear {
            handleHandsFreeCountdown(.setVisible(false))
        }
    }

    private var isVisible: Bool {
        appState.isCameraVisible(on: surface)
    }

    private func syncLiveFramingGuidance() {
        guard isVisible else { return }
        cameraService.setLiveFramingPreviewSize(
            CGSize(width: ChameoLayout.previewWidth, height: livePreviewHeight)
        )
        cameraService.setLiveFramingGuidanceEnabled(showFaceGuide)
    }

    private var livePreviewHeight: CGFloat {
        var height = ChameoLayout.livePreviewHeight

        if case .unauthorized = cameraService.status {
            height -= 28
        }
        if saveLocation && locationPermissionDenied {
            height -= 28
        }

        return height
    }

    @ViewBuilder
    private var cameraOverlay: some View {
        switch cameraService.status {
        case .requestingPermission:
            StatusOverlay(title: L10n.string("Requesting camera access"), systemImage: "camera")
        case .unauthorized:
            StatusOverlay(
                title: L10n.string("Camera access is off"),
                systemImage: "camera.fill",
                recoveryDestination: .camera
            )
        case .unavailable(let message):
            StatusOverlay(title: message.text, systemImage: "exclamationmark.triangle")
        case .idle:
            StatusOverlay(title: L10n.string("Starting camera"), systemImage: "camera")
        case .capturing:
            ProgressView(L10n.string("Taking photo…"))
                .padding(12)
                .chameoReadableSurface(in: RoundedRectangle(cornerRadius: 8))
        case .switchingCamera:
            ProgressView(L10n.string("Switching camera"))
                .padding(12)
                .chameoReadableSurface(in: RoundedRectangle(cornerRadius: 8))
        case .ready:
            EmptyView()
        }
    }

    @ViewBuilder
    private var cameraSelectionOverlay: some View {
        if !cameraService.availableCameras.isEmpty,
           let activeCameraName = cameraService.activeCameraName {
            Menu {
                ForEach(cameraService.availableCameras) { camera in
                    Button {
                        selectCamera(uniqueID: camera.id)
                    } label: {
                        HStack {
                            Label(
                                camera.displayName,
                                systemImage: camera.isContinuityCamera
                                    ? "iphone"
                                    : "video"
                            )
                            if camera.id == cameraService.activeCameraID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                cameraSelectionLabel(
                    activeCameraName,
                    isContinuityCamera: activeCameraIsContinuity
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .accessibilityLabel(L10n.string("Camera"))
            .disabled(!canCapture || isSaving)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var activeCameraIsContinuity: Bool {
        cameraService.availableCameras.first(
            where: { $0.id == cameraService.activeCameraID }
        )?.isContinuityCamera ?? false
    }

    private func cameraSelectionLabel(
        _ name: String,
        isContinuityCamera: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isContinuityCamera ? "iphone" : "video")
                .foregroundStyle(.secondary)

            Text(name)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .frame(width: 220, height: ChameoLayout.compactControlSize)
        .chameoGlassControl(in: Capsule())
        .contentShape(Capsule())
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
        switch review.photosAuthorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    private func beginCapture(trigger: CaptureTrigger) {
        guard isVisible, !isSaving else { return }
        if trigger == .manual {
            handleHandsFreeCountdown(.manualCapture)
        }
        guard canCapture, capturedPreview == nil else { return }
        review.capture(cameraService: cameraService, autoAlignPhotos: autoAlignPhotos)
    }

    private func selectCamera(uniqueID: String) {
        guard uniqueID != cameraService.activeCameraID else {
            return
        }

        Task {
            do {
                try await cameraService.selectCamera(uniqueID: uniqueID)
                let cameraName = cameraService.availableCameras.first(
                    where: { $0.id == uniqueID }
                )?.name ?? L10n.string("selected camera")
                review.statusMessage = .formatted("Switched to %@", cameraName)
            } catch {
                review.statusMessage = .error(error)
            }
        }
    }

    private func beginSavingCapturedPreview() {
        guard isVisible else { return }
        review.save(albumName: albumName, saveLocation: saveLocation,
                    libraryStore: libraryStore, localPhotos: localPhotos)
    }

    private var isHandsFreeCountdownEnabled: Bool {
        handsFreeCountdown && showFaceGuide
    }

    private var isHandsFreeCountdownVisible: Bool {
        isVisible && capturedPreview == nil && canCapture && !isSaving
    }

    private func syncHandsFreeCountdown() {
        handleHandsFreeCountdown(
            .setEnabled(isHandsFreeCountdownEnabled)
        )
        handleHandsFreeCountdown(
            .setVisible(isHandsFreeCountdownVisible)
        )
        if isHandsFreeCountdownEnabled && isHandsFreeCountdownVisible {
            handleHandsFreeCountdown(
                .guidanceChanged(cameraService.liveFramingGuidanceState)
            )
        }
    }

    private func handleHandsFreeCountdown(
        _ event: HandsFreeCountdownEvent
    ) {
        let previousCount = handsFreeCountdownMachine.phase.displayedCount
        let effects = handsFreeCountdownMachine.handle(event)
        let currentCount = handsFreeCountdownMachine.phase.displayedCount

        if currentCount != previousCount, let currentCount {
            announceHandsFreeCountdown(currentCount)
        }

        for effect in effects {
            switch effect {
            case .startTimer:
                startHandsFreeCountdownTimer()
            case .cancelTimer:
                cancelHandsFreeCountdownTimer()
            case .capture:
                handsFreeCountdownTask = nil
                beginCapture(trigger: .handsFree)
            }
        }
    }

    private func startHandsFreeCountdownTimer() {
        handsFreeCountdownTask?.cancel()
        handsFreeCountdownTask = Task { @MainActor in
            do {
                for _ in 0..<3 {
                    try await Task.sleep(for: .seconds(1))
                    guard isHandsFreeCountdownVisible else {
                        handleHandsFreeCountdown(.setVisible(false))
                        return
                    }
                    handleHandsFreeCountdown(.tick)
                }
            } catch {
                return
            }
        }
    }

    private func cancelHandsFreeCountdownTimer() {
        handsFreeCountdownTask?.cancel()
        handsFreeCountdownTask = nil
    }

    private func announceHandsFreeCountdown(_ count: Int) {
        AccessibilityAnnouncement.post(
            L10n.format("Photo in %lld seconds", Int64(count)),
            priority: .high
        )
    }
}

private enum CaptureTrigger {
    case manual
    case handsFree
}

private struct HandsFreeCountdownOverlay: View {
    let count: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("\(count)")
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.primary)
            .frame(width: 108, height: 108)
            .chameoReadableSurface(in: Circle())
            .overlay {
                Circle()
                    .stroke(.green.opacity(0.65), lineWidth: 2)
            }
            .shadow(radius: 8)
            .id(count)
            .transition(
                reduceMotion
                    ? .opacity
                    : .scale(scale: 0.8).combined(with: .opacity)
            )
            .accessibilityLabel(L10n.format("Photo in %lld seconds", Int64(count)))
            .allowsHitTesting(false)
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
        .chameoReadableSurface(in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding()
    }
}
