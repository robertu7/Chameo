import SwiftUI

struct LocalPhotoSettingsView: View {
    @EnvironmentObject private var localPhotos: LocalPhotoSettingsController

    var body: some View {
        Toggle(L10n.string("Save Original Photos to a Folder"), isOn: Binding(
            get: { localPhotos.configuration.isEnabled },
            set: { enabled in Task { await localPhotos.setEnabled(enabled) } }
        ))
        .disabled(localPhotos.isBusy)
        .accessibilityHint(L10n.string("Saves new captures and downloads older originals during timelapse export."))

        Text(L10n.string("Saves new captures and downloads older originals during timelapse export."))
            .font(.caption)
            .foregroundStyle(.secondary)

        if let folder = localPhotos.configuration.activeFolder {
            Text(folder.displayPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .accessibilityLabel(L10n.format("Photo folder: %@", folder.displayPath))
        }

        HStack {
            if localPhotos.isBusy {
                ProgressView().controlSize(.small)
                    .accessibilityLabel(L10n.string("Updating photo folder"))
            }
            Spacer()
            Button(L10n.string("Choose Folder…")) {
                Task { await localPhotos.chooseFolder() }
            }
            Button(L10n.string("Open Folder")) {
                Task { await localPhotos.openFolder() }
            }
            .disabled(localPhotos.configuration.activeFolder == nil)
        }
        .disabled(localPhotos.isBusy)

        Text(L10n.string("Changing folders leaves existing copies in place. Turning this off keeps your saved files."))
            .font(.caption)
            .foregroundStyle(.secondary)

        if let error = localPhotos.errorMessage {
            Text(error).font(.caption).foregroundStyle(.red)
                .accessibilityLabel(error)
        }
    }
}
