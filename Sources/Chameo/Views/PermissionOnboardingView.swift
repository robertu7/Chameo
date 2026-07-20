import AppKit
import SwiftUI

struct PermissionOnboardingView: View {
    @ObservedObject var model: PermissionOnboardingModel

    let onContinue: () -> Void
    let onQuit: () -> Void
    let onPermissionRequestFinished: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 0) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)

                Text(L10n.string("Welcome to Chameo"))
                    .font(.title2.bold())
                    .padding(.top, 14)

                Text(L10n.string("To take and save Chameos, allow access to Camera and Photos."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }

            VStack(spacing: 10) {
                permissionRow(
                    kind: .camera,
                    title: L10n.string("Camera"),
                    explanation: L10n.string("Take your daily Chameo."),
                    systemImage: "camera.fill",
                    status: model.cameraStatus,
                    recoveryDestination: .camera
                )

                Divider()

                permissionRow(
                    kind: .photos,
                    title: L10n.string("Photos"),
                    explanation: L10n.string("Save Chameos in a dedicated album."),
                    systemImage: "photo.on.rectangle.angled",
                    status: model.photosStatus,
                    recoveryDestination: .photos
                )
            }

            Text(permissionFooterText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                Button(L10n.string("Quit"), role: .cancel, action: onQuit)

                Spacer()

                Button(L10n.string("Continue"), action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canContinue || model.permissionBeingRequested != nil)
            }
        }
        .padding(20)
        .frame(width: 420, height: 420)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
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
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            permissionAction(
                kind: kind,
                status: status,
                recoveryDestination: recoveryDestination
            )
        }
        .padding(.vertical, 4)
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
