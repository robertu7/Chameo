import AppKit
import Combine
import Foundation

@MainActor
final class LocalPhotoSettingsController: ObservableObject {
    @Published private(set) var configuration = LocalPhotoConfiguration()
    @Published private(set) var isBusy = false
    @Published private(set) var errorMessage: String?
    let store: LocalPhotoStore
    init(store: LocalPhotoStore = .shared) {
        self.store = store
    }

    func refresh() async { configuration = await store.settings() }

    func setEnabled(_ enabled: Bool) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await store.setEnabled(enabled)
            await refresh()
        } catch { report(error) }
    }

    func openFolder() async {
        errorMessage = nil
        do {
            let url = try await store.activeFolderURL()
            guard NSWorkspace.shared.open(url) else { throw LocalPhotoError.folderUnavailable }
            await refresh()
        } catch { report(error) }
    }

    private func report(_ error: Error) {
        errorMessage = error.localizedDescription
        AccessibilityAnnouncement.post(error.localizedDescription, priority: .high)
    }
}
