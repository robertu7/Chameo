import Foundation
import Photos

@MainActor
final class LibraryStore: ObservableObject {
    typealias AssetLoader = (String) async throws -> [ChameoAsset]

    @Published private(set) var assets: [ChameoAsset] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published var errorMessage: String?

    private let assetLoader: AssetLoader
    private var reloadGeneration = 0
    private var requestedAlbumName: String?

    init(assetLoader: @escaping AssetLoader = PhotoLibraryService.fetchAssets) {
        self.assetLoader = assetLoader
    }

    func reload(albumName: String) async {
        reloadGeneration += 1
        let generation = reloadGeneration

        if requestedAlbumName != albumName {
            requestedAlbumName = albumName
            assets = []
            hasLoaded = false
        }

        isLoading = true
        errorMessage = nil

        do {
            let loadedAssets = try await assetLoader(albumName)
            guard generation == reloadGeneration else {
                return
            }
            assets = loadedAssets
            hasLoaded = true
        } catch {
            guard generation == reloadGeneration else {
                return
            }
            errorMessage = error.localizedDescription
        }

        if generation == reloadGeneration {
            isLoading = false
        }
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

    func dailyStatus(
        on date: Date = Date(),
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> DailyCaptureStatus {
        let hasUsableSnapshot = (hasLoaded || !assets.isEmpty)
            && (errorMessage == nil || !assets.isEmpty)

        return DailyCaptureHistory.status(
            for: date,
            captureDates: assets.compactMap(\.createdAt),
            today: today,
            calendar: calendar,
            isAvailable: hasUsableSnapshot
        )
    }
}
