import ChameoCore
import SwiftUI
import UIKit

struct MobileCameraView: View {
    @Environment(MobileAppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("showGrid") private var showFaceGuide = true
    @AppStorage("handsFreeCountdown") private var handsFreeCountdown = false
    @State private var captureModel = MobileCaptureModel()
    @State private var isFullScreen = true
    @State private var previewSize = CGSize.zero

    var body: some View {
        Group {
            if model.permissions.cameraStatus.isGranted,
               model.permissions.photosStatus.isGranted {
                cameraContent
            } else {
                PermissionRecoveryView(
                    title: "Camera unavailable",
                    message: recoveryMessage,
                    systemImage: "camera.fill"
                )
            }
        }
        .navigationTitle("Camera")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            FullScreenRequirementReader { fullScreen, orientation in
                isFullScreen = fullScreen
                captureModel.camera.updateOrientation(orientation)
            }
                .frame(width: 0, height: 0)
        }
        .onChange(of: isFullScreen) { updateCameraActivity() }
        .onChange(of: showFaceGuide) { updateCameraActivity() }
        .onChange(of: handsFreeCountdown) { updateCameraActivity() }
        .onChange(of: captureModel.camera.liveFrame) {
            guard showFaceGuide, let frame = captureModel.camera.liveFrame else { return }
            captureModel.consumeLiveFrame(frame, previewSize: previewSize)
        }
        .onChange(of: scenePhase, initial: true) {
            if scenePhase == .active {
                model.permissions.refresh()
            }
            updateCameraActivity()
        }
        .task {
            await captureModel.restorePending()
            updateCameraActivity()
        }
        .onDisappear {
            captureModel.setCameraActive(false)
        }
    }

    @ViewBuilder
    private var cameraContent: some View {
        if UIDevice.current.userInterfaceIdiom == .pad, !isFullScreen {
            ContentUnavailableView {
                Label("Full Screen Required", systemImage: "rectangle.expand.vertical")
            } description: {
                Text("Open Chameo full screen to use the camera.")
            }
        } else if captureModel.isRestoring {
            ProgressView("Preparing camera…")
        } else if let pending = captureModel.pending {
            PendingPreviewView(
                pending: pending,
                isSaving: captureModel.isSaving,
                onRetake: { Task { await captureModel.retake() } },
                onSave: { Task { _ = await captureModel.save() } }
            )
        } else {
            liveCamera
        }
    }

    private var liveCamera: some View {
        GeometryReader { proxy in
            ZStack {
                CameraPreview(session: captureModel.camera.session)
                    .ignoresSafeArea(edges: .horizontal)
                if showFaceGuide {
                    FaceGuidanceOverlay(
                        guidance: captureModel.guidance,
                        previewSize: proxy.size
                    )
                }
                if let countdown = captureModel.countdown {
                    Text("\(countdown)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 108, height: 108)
                        .background(.regularMaterial, in: .circle)
                        .accessibilityLabel("Photo in \(countdown) seconds")
                }
                VStack {
                    Spacer()
                    if let message = captureModel.message {
                        Text(message)
                            .font(.callout)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: .capsule)
                    }
                    Button {
                        Task { await captureModel.takeChameo() }
                    } label: {
                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: 68))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .tint)
                    }
                    .accessibilityLabel("Take Chameo")
                    .disabled(captureModel.camera.status != .ready)
                    .padding(.bottom, 24)
                }
            }
            .onAppear { previewSize = proxy.size }
            .onChange(of: proxy.size) { previewSize = proxy.size }
        }
    }

    private func updateCameraActivity() {
        let shouldRun = scenePhase == .active
            && (UIDevice.current.userInterfaceIdiom != .pad || isFullScreen)
            && model.permissions.cameraStatus.isGranted
            && model.permissions.photosStatus.isGranted
        captureModel.setCameraActive(shouldRun)
    }

    private var recoveryMessage: LocalizedStringKey {
        if model.permissions.cameraStatus != .authorized {
            return "Allow Camera access in Settings to take a Chameo."
        }
        if model.permissions.photosStatus == .limited {
            return "Full Photos Access is required to manage the Chameo album."
        }
        return "Allow Photos access in Settings to save and manage Chameos."
    }
}

private struct FaceGuidanceOverlay: View {
    let guidance: LiveFramingGuidanceState
    let previewSize: CGSize

    var body: some View {
        let guide = FaceGuideGeometry.rect(in: previewSize)
        ZStack {
            RoundedRectangle(cornerRadius: guide.width * 0.22)
                .stroke(guidance == .ready ? .green : .white.opacity(0.85), lineWidth: 2)
                .frame(width: guide.width, height: guide.height)
                .position(x: guide.midX, y: guide.midY)
            VStack {
                Text(guidanceText)
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: .capsule)
                Spacer()
            }
            .padding(.top, 18)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(guidanceText)
    }

    private var guidanceText: String {
        switch guidance {
        case .neutral: String(localized: "Center your face")
        case .ready: String(localized: "Ready")
        case .adjusting(let hint):
            switch hint {
            case .centerFace: String(localized: "Center your face")
            case .onePerson: String(localized: "One person at a time")
            case .moveCloser: String(localized: "Move closer")
            case .moveBack: String(localized: "Move back")
            case .moveTowardCenter: String(localized: "Move toward center")
            case .moveHigher: String(localized: "Move higher")
            case .moveLower: String(localized: "Move lower")
            case .holdStill: String(localized: "Hold still")
            }
        }
    }
}

private struct PendingPreviewView: View {
    let pending: PendingChameo
    let isSaving: Bool
    let onRetake: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            if let image = UIImage(data: pending.data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 16))
                    .accessibilityLabel("Chameo preview")
            } else {
                ContentUnavailableView("Preview unavailable", systemImage: "photo")
            }
            HStack {
                Button("Retake", role: .destructive, action: onRetake)
                    .disabled(isSaving)
                Spacer()
                Button(isSaving ? "Saving…" : "Save to Photos", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
            }
            Spacer()
        }
        .padding()
    }
}

struct PermissionRecoveryView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            Button("Open Settings", action: openSettings)
                .buttonStyle(.borderedProminent)
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
