import Foundation
import Photos

@MainActor
final class LibraryStore: ObservableObject {
    typealias AssetLoader = (String) async throws -> [ChameoAsset]
    typealias AssetDeleter = (PHAsset) async throws -> Void

    @Published private(set) var assets: [ChameoAsset] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published var errorMessage: LocalizedMessage?
    @Published private(set) var deletionWarning: LocalizedMessage?

    private let assetLoader: AssetLoader
    private let assetDeleter: AssetDeleter
    private var reloadGeneration = 0
    private var requestedAlbumName: String?

    init(assetDeleter: @escaping AssetDeleter = PhotoLibraryService.deleteAsset,
         assetLoader: @escaping AssetLoader = PhotoLibraryService.fetchAssets) {
        self.assetLoader = assetLoader
        self.assetDeleter = assetDeleter
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
        deletionWarning = nil

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
            errorMessage = .error(error)
        }

        if generation == reloadGeneration {
            isLoading = false
        }
    }

    func deleteFromLibrary(_ asset: ChameoAsset, albumName: String,
                           trashLocalCopy: Bool = false, localPhotos: LocalPhotoStore = .shared) async -> Bool {
        errorMessage = nil
        deletionWarning = nil
        let previousAssets = assets
        assets.removeAll { $0.id == asset.id }

        do {
            let localError = try await PhotoDeletionService.delete {
                try await assetDeleter(asset.asset)
            } trashLocalCopy: {
                if trashLocalCopy { try await localPhotos.trashOriginal(for: asset.id) }
            }
            if localError != nil {
                deletionWarning = .localized("Deleted from Photos. Could not move the local copy to Trash. Open Folder in Settings to manage it.")
            }
            return true
        } catch {
            assets = previousAssets
            errorMessage = .error(error)
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
        TimelapseSelection.allItemsChronologically(
            from: assets,
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
