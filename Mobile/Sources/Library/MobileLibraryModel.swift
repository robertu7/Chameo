import Foundation
import Observation

@MainActor
@Observable
final class MobileLibraryModel {
    private(set) var assets: [MobileChameoAsset] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var errorMessage: String?

    func reload(albumName: String) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            assets = try await MobilePhotoLibraryService.fetchAssets(albumName: albumName)
            hasLoaded = true
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "The Chameo album could not be loaded.")
        }
    }

    func delete(_ asset: MobileChameoAsset, albumName: String) async {
        do {
            try await MobilePhotoLibraryService.delete(asset)
            assets.removeAll { $0.id == asset.id }
        } catch {
            errorMessage = String(localized: "The photo could not be deleted from Photos.")
            await reload(albumName: albumName)
        }
    }

    func assets(on date: Date, calendar: Calendar = .current) -> [MobileChameoAsset] {
        assets.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
    }
}
