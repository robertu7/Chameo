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

                Text("Welcome to Chameo")
                    .font(.title2.bold())
                    .padding(.top, 14)

                Text("Camera and Photos access are required.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }

            VStack(spacing: 10) {
                permissionRow(
                    kind: .camera,
                    title: "Camera",
                    explanation: "Take photos.",
                    systemImage: "camera.fill",
                    status: model.cameraStatus,
                    recoveryDestination: .camera
                )

                Divider()

                permissionRow(
                    kind: .photos,
                    title: "Photos",
                    explanation: "Save your Chameos.",
                    systemImage: "photo.on.rectangle.angled",
                    status: model.photosStatus,
                    recoveryDestination: .photos
                )
            }

            Text("Location and reminders are optional.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Quit", role: .cancel, action: onQuit)

                Spacer()

                Button("Continue", action: onContinue)
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
                .accessibilityLabel("Requesting permission")
        } else {
            switch status {
            case .notDetermined:
                Button("Allow") {
                    Task {
                        await model.request(kind)
                        onPermissionRequestFinished()
                    }
                }
                .frame(minWidth: 84)
                .disabled(model.permissionBeingRequested != nil)

            case .authorized:
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
                    .frame(minWidth: 84)

            case .denied:
                Button("Open Settings") {
                    PermissionRecoveryService.open(recoveryDestination)
                }
                .frame(minWidth: 84)

            case .restricted:
                Label("Restricted", systemImage: "lock.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 84)
            }
        }
    }
}
