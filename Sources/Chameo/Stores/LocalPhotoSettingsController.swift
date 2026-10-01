import AppKit
import Combine
import Darwin
import Foundation

@MainActor
enum LocalPhotoFolderPicker {
    static func choose() async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = L10n.string("Choose Folder")
        panel.message = L10n.format("Choose or create a folder, such as Pictures/%@.", AppDistribution.current.defaultAlbumName)
        // NSHomeDirectory points into the container in a sandboxed process. The
        // system account's home is only a suggestion to the permission-granting picker.
        if let home = getpwuid(getuid())?.pointee.pw_dir {
            let pictures = URL(fileURLWithPath: String(cString: home)).appendingPathComponent("Pictures", isDirectory: true)
            let suggested = pictures.appendingPathComponent(AppDistribution.current.defaultAlbumName, isDirectory: true)
            panel.directoryURL = FileManager.default.fileExists(atPath: suggested.path) ? suggested : pictures
        }
        NSApp.activate()
        return await withCheckedContinuation { continuation in
            panel.begin { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }
}

@MainActor
final class LocalPhotoSettingsController: ObservableObject {
    @Published private(set) var configuration = LocalPhotoConfiguration()
    @Published private(set) var isBusy = false
    @Published private(set) var errorMessage: String?
    let store: LocalPhotoStore
    private let picker: () async -> URL?

    init(store: LocalPhotoStore = .shared, picker: @escaping () async -> URL? = LocalPhotoFolderPicker.choose) {
        self.store = store
        self.picker = picker
    }

    func refresh() async { configuration = await store.settings() }

    func setEnabled(_ enabled: Bool) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let current = await store.settings()
            if enabled && current.activeFolder == nil {
                guard let url = await picker() else { return }
                try await store.selectFolder(url)
            } else {
                try await store.setEnabled(enabled)
            }
            await refresh()
        } catch { report(error) }
    }

    func chooseFolder() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        guard let url = await picker() else { return }
        do {
            let current = await store.settings()
            try await store.selectFolder(url, enable: current.isEnabled)
            await refresh()
        } catch { report(error) }
    }

    func openFolder() async {
        errorMessage = nil
        do {
            let url = try await store.activeFolderURL()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard NSWorkspace.shared.open(url) else { throw LocalPhotoError.folderUnavailable }
            await refresh()
        } catch { report(error) }
    }

    private func report(_ error: Error) {
        errorMessage = error.localizedDescription
        AccessibilityAnnouncement.post(error.localizedDescription, priority: .high)
    }
}
