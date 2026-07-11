import Foundation
import Photos

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var assets: [ChameoAsset] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func reload(albumName: String) async {
        isLoading = true
        errorMessage = nil

        do {
            assets = try await PhotoLibraryService.fetchAssets(albumName: albumName)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func deleteFromLibrary(_ asset: ChameoAsset, albumName: String) async -> Bool {
        errorMessage = nil
        let previousAssets = assets
        assets.removeAll { $0.id == asset.id }

        do {
            try await PhotoLibraryService.deleteAsset(asset.asset)
            return true
        } catch {
            assets = previousAssets
            errorMessage = error.localizedDescription
            await reload(albumName: albumName, preservingError: true)
            return false
        }
    }

    private func reload(albumName: String, preservingError shouldPreserveError: Bool) async {
        let currentError = shouldPreserveError ? errorMessage : nil
        await reload(albumName: albumName)

        if shouldPreserveError {
            errorMessage = currentError
        }
    }

    func timelapseAssets() -> [ChameoAsset] {
        TimelapseSelection.mostRecentDailyItems(
            from: assets,
            limit: 30,
            date: \.createdAt
        )
    }
}
