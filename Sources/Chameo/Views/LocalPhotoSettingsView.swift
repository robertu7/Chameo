import SwiftUI

struct LocalPhotoSettingsView: View {
    @EnvironmentObject private var localPhotos: LocalPhotoSettingsController

    @State private var showsExplanation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsGroup(title: L10n.string("Local Copies")) {
                SettingsToggle(title: L10n.string("Keep Local Copies"),
                    description: L10n.string("Saves new captures and export originals."),
                    isOn: Binding(
                        get: { localPhotos.configuration.isEnabled },
                        set: { enabled in Task { await localPhotos.setEnabled(enabled) } }
                    ))
                .disabled(localPhotos.isBusy)
                .accessibilityHint(L10n.string("Saves new captures and downloads older originals during timelapse export."))
                Divider()
                HStack(spacing: 8) {
                    if let folder = localPhotos.configuration.activeFolder {
                        Label(URL(fileURLWithPath: folder.displayPath).lastPathComponent, systemImage: "folder")
                            .font(.caption).lineLimit(1).truncationMode(.middle)
                            .help(folder.displayPath)
                            .accessibilityLabel(L10n.format("Photo folder: %@", folder.displayPath))
                    }
                    if localPhotos.isBusy {
                        ProgressView().controlSize(.small)
                            .accessibilityLabel(L10n.string("Updating photo folder"))
                    }
                    Spacer(minLength: 4)
                    Button(L10n.string("Open Folder")) { Task { await localPhotos.openFolder() } }
                        .disabled(localPhotos.configuration.activeFolder == nil)
                }
                .disabled(localPhotos.isBusy)
            }
            DisclosureGroup(L10n.string("How local copies work"), isExpanded: $showsExplanation) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("Saves new captures and downloads older originals during timelapse export."))
                    Text(L10n.string("Local copies are independent of Photos and iCloud. Deleting from either keeps the other copy."))
                    Text(L10n.string("Files removed from the folder stay removed. Use Save Local Copy in a photo's menu to restore a copy."))
                    if let folder = localPhotos.configuration.activeFolder {
                        Text(folder.displayPath).textSelection(.enabled)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .font(.caption)
            Text(L10n.string("Turning this off keeps your saved files."))
                .font(.caption).foregroundStyle(.secondary)
            if let error = localPhotos.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).accessibilityLabel(error)
            }
        }
    }
}
