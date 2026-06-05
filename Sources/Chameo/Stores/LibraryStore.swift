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

    func removeFromAlbum(_ asset: ChameoAsset, albumName: String) async {
        errorMessage = nil

        do {
            try await PhotoLibraryService.removeAssetFromAlbum(asset.asset, albumName: albumName)
            await reload(albumName: albumName)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restoreToAlbum(_ asset: ChameoAsset, albumName: String) async {
        errorMessage = nil

        do {
            try await PhotoLibraryService.restoreAssetToAlbum(asset.asset, albumName: albumName)
            await reload(albumName: albumName)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
