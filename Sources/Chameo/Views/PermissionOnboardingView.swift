import AppKit
import SwiftUI

enum PermissionOnboardingStep: Int, CaseIterable, Equatable {
    case camera
    case library
    case permissions

    var previous: PermissionOnboardingStep? {
        PermissionOnboardingStep(rawValue: rawValue - 1)
    }

    var next: PermissionOnboardingStep? {
        PermissionOnboardingStep(rawValue: rawValue + 1)
    }
}

struct PermissionOnboardingView: View {
    @ObservedObject var model: PermissionOnboardingModel
    @State private var step: PermissionOnboardingStep = .camera

    let onContinue: () -> Void
    let onQuit: () -> Void
    let onPermissionRequestFinished: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .camera:
                    featureIntroduction(
                        title: L10n.string("Capture with confidence"),
                        explanation: L10n.string("Use live framing guidance to keep every Chameo consistent."),
                        imageName: "onboarding-feature-camera",
                        accessibilityLabel: L10n.string("Chameo Camera feature preview")
                    )
                case .library:
                    featureIntroduction(
                        title: L10n.string("See your story grow"),
                        explanation: L10n.string("Review your daily photos and turn your history into a timelapse."),
                        imageName: "onboarding-feature-library",
                        accessibilityLabel: L10n.string("Chameo Library feature preview")
                    )
                case .permissions:
                    permissions
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            progress
                .padding(.bottom, 18)

            navigation
        }
        .padding(24)
        .frame(width: 520, height: 560)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private func featureIntroduction(
        title: String,
        explanation: String,
        imageName: String,
        accessibilityLabel: String
    ) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: 7) {
                Text(title)
                    .font(.title2.bold())

                Text(explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Image(nsImage: onboardingImage(named: imageName))
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 300, maxHeight: 350)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.separator.opacity(0.6), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
                .accessibilityLabel(accessibilityLabel)
        }
        .padding(.top, 4)
    }

    private var permissions: some View {
        VStack(spacing: 20) {
            VStack(spacing: 7) {
                Text(L10n.string("Always close at hand"))
                    .font(.title2.bold())

                Text(L10n.string("Open Chameo from the eye in your menu bar whenever you’re ready for today’s photo."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 24)

            VStack(spacing: 0) {
                permissionRow(
                    kind: .camera,
                    title: L10n.string("Camera"),
                    explanation: L10n.string("Take your daily Chameo."),
                    systemImage: "camera.fill",
                    status: model.cameraStatus,
                    recoveryDestination: .camera
                )

                Divider()
                    .padding(.leading, 58)

                permissionRow(
                    kind: .photos,
                    title: L10n.string("Photos"),
                    explanation: L10n.string("Save Chameos in a dedicated album."),
                    systemImage: "photo.on.rectangle.angled",
                    status: model.photosStatus,
                    recoveryDestination: .photos
                )
            }
            .background(
                .quaternary.opacity(0.55),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.separator.opacity(0.45), lineWidth: 1)
            }

            Spacer(minLength: 24)

            VStack(spacing: 4) {
                Text(permissionFooterText)
                if model.cameraStatus != .restricted && model.photosStatus != .restricted {
                    Text(L10n.string("You can change access later in System Settings."))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: 380)
        .padding(.top, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func onboardingImage(named name: String) -> NSImage {
        let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "Onboarding"
        ) ?? Bundle.module.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "Onboarding"
        )

        return url.flatMap(NSImage.init(contentsOf:)) ?? NSImage()
    }

    private var progress: some View {
        HStack(spacing: 7) {
            ForEach(PermissionOnboardingStep.allCases, id: \.rawValue) { item in
                Circle()
                    .fill(item == step ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L10n.format(
                "Step %lld of %lld",
                step.rawValue + 1,
                PermissionOnboardingStep.allCases.count
            )
        )
    }

    private var navigation: some View {
        HStack {
            if step == .camera {
                Button(L10n.string("Quit"), role: .cancel, action: onQuit)
            } else {
                Button(L10n.string("Back")) {
                    if let previous = step.previous {
                        step = previous
                    }
                }
            }

            Spacer()

            if step == .permissions {
                Button(L10n.string("Continue"), action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canContinue || model.permissionBeingRequested != nil)
            } else {
                Button(L10n.string("Next")) {
                    if let next = step.next {
                        step = next
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func permissionRow(
        kind: RequiredPermissionKind,
        title: String,
        explanation: String,
        systemImage: String,
        status: RequiredPermissionStatus,
        recoveryDestination: PermissionRecoveryDestination
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(
                    Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))

                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            permissionAction(
                kind: kind,
                status: status,
                recoveryDestination: recoveryDestination
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func permissionAction(
        kind: RequiredPermissionKind,
        status: RequiredPermissionStatus,
        recoveryDestination: PermissionRecoveryDestination
    ) -> some View {
        if model.permissionBeingRequested == kind {
            ProgressView()
                .controlSize(.small)
                .frame(width: 84)
                .accessibilityLabel(L10n.string("Requesting permission"))
        } else {
            switch status {
            case .notDetermined:
                Button(L10n.string("Allow")) {
                    Task {
                        await model.request(kind)
                        onPermissionRequestFinished()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .frame(minWidth: 84)
                .disabled(model.permissionBeingRequested != nil)

            case .authorized:
                Label(L10n.string("Allowed"), systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
                    .frame(minWidth: 84)

            case .denied:
                Button(L10n.string("Open System Settings")) {
                    PermissionRecoveryService.open(recoveryDestination)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .frame(minWidth: 84)

            case .restricted:
                Label(L10n.string("Restricted"), systemImage: "lock.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 84)
            }
        }
    }

    private var permissionFooterText: String {
        if model.cameraStatus == .restricted || model.photosStatus == .restricted {
            return L10n.string("Access is restricted by macOS or device management. Remove the restriction or contact your administrator to continue.")
        }

        return L10n.string("Location and notifications are optional and requested only when needed.")
    }
}
