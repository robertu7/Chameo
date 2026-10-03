import SwiftUI

struct LocalPhotoSettingsView: View {
    @EnvironmentObject private var localPhotos: LocalPhotoSettingsController

    @State private var showsExplanation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(L10n.string("Local Copies")).font(.subheadline.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Button { showsExplanation = true } label: {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("How local copies work"))
                .help(L10n.string("How local copies work"))
                .popover(isPresented: $showsExplanation, arrowEdge: .top) {
                    LocalCopyExplanation(folderPath: localPhotos.configuration.activeFolder?.displayPath)
                }
            }
            .padding(.horizontal, 4)
            SettingsGroup {
                SettingsToggle(title: L10n.string("Keep Local Copies"),
                    description: L10n.string("Saves new captures and export originals."),
                    isOn: Binding(
                        get: { localPhotos.configuration.isEnabled },
                        set: { enabled in Task { await localPhotos.setEnabled(enabled) } }
                    ))
                .disabled(localPhotos.isBusy)
                .help(L10n.string("Turning this off keeps your saved files."))
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
            if let error = localPhotos.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).accessibilityLabel(error)
            }
        }
    }

}

struct LocalCopyExplanation: View {
    let folderPath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("How local copies work")).font(.headline)
            Text(L10n.string("Saves new captures and downloads older originals during timelapse export."))
            Text(L10n.string("Local copies are independent of Photos and iCloud. Deleting from either keeps the other copy."))
            Text(L10n.string("Files removed from the folder stay removed. Use Save Local Copy in a photo's menu to restore a copy."))
            Text(L10n.string("Turning this off keeps your saved files."))
            if let folderPath {
                Divider()
                Text(folderPath).font(.caption).textSelection(.enabled)
            }
        }
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }
}
