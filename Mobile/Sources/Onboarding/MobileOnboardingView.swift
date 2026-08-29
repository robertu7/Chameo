import ChameoCore
import SwiftUI
import UIKit

struct MobileOnboardingView: View {
    @Bindable var model: MobileAppModel
    @State private var step = OnboardingStep.camera
    @State private var requestedPermission: RequiredPermissionKind?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 12)
                content
                    .frame(maxWidth: 560)
                Spacer(minLength: 12)
                footer
                    .frame(maxWidth: 560)
            }
            .padding()
            .navigationTitle("Welcome to Chameo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .camera:
            EducationPage(
                imageName: "onboarding-feature-camera",
                title: "Capture with confidence",
                detail: "Use live framing guidance to keep every Chameo consistent."
            )
        case .library:
            EducationPage(
                imageName: "onboarding-feature-library",
                title: "See your story grow",
                detail: "Review your daily photos and turn your history into a timelapse."
            )
        case .permissions:
            permissionsPage
        }
    }

    private var permissionsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Finish Chameo Setup")
                .font(.title2.bold())
            Text("Camera and Full Photos Access are required to capture, save, and manage your Chameos.")
                .foregroundStyle(.secondary)
            PermissionRow(
                title: "Camera",
                status: model.permissions.cameraStatus,
                isRequesting: requestedPermission == .camera,
                request: { await request(.camera) }
            )
            PermissionRow(
                title: "Photos",
                status: model.permissions.photosStatus,
                isRequesting: requestedPermission == .photos,
                request: { await request(.photos) }
            )
            Text("Location and notifications are optional and requested only when enabled in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            if step != .camera {
                Button("Back") { step = step.previous ?? step }
            }
            Spacer()
            if let next = step.next {
                Button("Next") { step = next }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Continue") { _ = model.completeOnboarding() }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        !model.permissions.cameraStatus.isGranted
                            || !model.permissions.photosStatus.isGranted
                    )
            }
        }
    }

    private func request(_ kind: RequiredPermissionKind) async {
        guard requestedPermission == nil else { return }
        requestedPermission = kind
        switch kind {
        case .camera:
            await model.permissions.requestCamera()
        case .photos:
            await model.permissions.requestPhotos()
        }
        requestedPermission = nil
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case camera
    case library
    case permissions

    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
}

private struct EducationPage: View {
    let imageName: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(spacing: 20) {
            BundledImage(name: imageName)
                .frame(maxHeight: 320)
            Text(title)
                .font(.title2.bold())
            Text(detail)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}

/// The onboarding illustrations are shared with the macOS target as loose
/// PNG resources, rather than asset-catalog image sets. `Image("name")` only
/// resolves asset-catalog names on iOS, so load the bundled file explicitly
/// and keep disk/decode work off the first SwiftUI render.
private struct BundledImage: View {
    let name: String
    @State private var image: UIImage?
    @State private var loadCompleted = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 20))
                    .accessibilityHidden(true)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.quaternary)
                    .overlay {
                        if loadCompleted {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .accessibilityLabel(
                        loadCompleted ? "Illustration unavailable" : "Loading illustration"
                    )
            }
        }
        .task(id: name) {
            let loadedImage = await Self.loadImage(named: name)
            guard !Task.isCancelled else { return }
            image = loadedImage
            loadCompleted = true
        }
    }

    private static func loadImage(named name: String) async -> UIImage? {
        guard let url = resourceURL(named: name) else {
            return nil
        }

        let data = await Task.detached(priority: .utility) {
            try? Data(contentsOf: url)
        }.value

        return data.flatMap(UIImage.init(data:))
    }

    private static func resourceURL(named name: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: nil) {
            return url
        }

        for fileExtension in ["png", "jpg", "jpeg"] {
            if let url = Bundle.main.url(
                forResource: name,
                withExtension: fileExtension
            ) {
                return url
            }
        }

        return nil
    }
}

private struct PermissionRow: View {
    let title: LocalizedStringKey
    let status: RequiredPermissionStatus
    let isRequesting: Bool
    let request: () async -> Void

    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            action
        }
        .padding()
        .background(.quaternary, in: .rect(cornerRadius: 12))
    }

    @ViewBuilder
    private var action: some View {
        if isRequesting {
            ProgressView().accessibilityLabel("Requesting permission")
        } else {
            switch status {
            case .notDetermined:
                Button("Allow") { Task { await request() } }
            case .authorized:
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .limited:
                Button("Full Access Required", action: openSettings)
            case .denied:
                Button("Open Settings", action: openSettings)
            case .restricted:
                Label("Restricted", systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
